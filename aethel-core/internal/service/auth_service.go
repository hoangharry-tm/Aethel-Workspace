package service

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/argon2"

	"aethel-core/internal/domain"
)

const (
	defaultMemoryKiB     = 65536
	defaultIterations    = 3
	defaultParallelism   = 4
	saltLength           = 16
	keyLength            = 32
	accessTokenDuration  = 15 * time.Minute
	refreshTokenDuration = 7 * 24 * time.Hour
)

type AuthService struct {
	users    domain.UserRepository
	sessions domain.SessionRepository
	pwReset  domain.PasswordResetRepository
	audit    domain.AuditRepository
}

func NewAuthService(
	users domain.UserRepository,
	sessions domain.SessionRepository,
	pwReset domain.PasswordResetRepository,
	audit domain.AuditRepository,
) *AuthService {
	return &AuthService{
		users:    users,
		sessions: sessions,
		pwReset:  pwReset,
		audit:    audit,
	}
}

type LoginResult struct {
	AccessToken  string       `json:"accessToken"`
	RefreshToken string       `json:"refreshToken"`
	User         *domain.User `json:"user"`
}

func (s *AuthService) Login(ctx context.Context, orgID uuid.UUID, email, password, ip, ua string) (*LoginResult, error) {
	user, err := s.users.GetByEmail(ctx, orgID, email)
	if err != nil {
		_ = s.writeAudit(ctx, orgID, nil, domain.AuditUserLoginFailed, nil, ip, ua)
		return nil, domain.ErrUnauthorized
	}

	if !user.IsActive {
		_ = s.writeAudit(ctx, orgID, &user.ID, domain.AuditUserLoginFailed, nil, ip, ua)
		return nil, domain.ErrUnauthorized
	}

	if user.LockedUntil != nil && time.Now().Before(*user.LockedUntil) {
		return nil, domain.ErrAccountLocked
	}

	if !s.verifyPassword(password, user.PasswordHash) {
		_ = s.users.IncrementFailedLogins(ctx, user.ID)
		_ = s.writeAudit(ctx, orgID, &user.ID, domain.AuditUserLoginFailed, nil, ip, ua)
		return nil, domain.ErrUnauthorized
	}

	_ = s.users.ResetFailedLogins(ctx, user.ID)
	_ = s.users.SetLastLogin(ctx, user.ID)

	accessToken, err := s.issueAccessToken(user)
	if err != nil {
		return nil, fmt.Errorf("issue access token: %w", err)
	}

	refreshToken, tokenHash, err := s.generateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	expiresAt := time.Now().Add(refreshTokenDuration)
	session := &domain.Session{
		ID:               uuid.New(),
		UserID:           user.ID,
		SessionTokenHash: tokenHash,
		ExpiresAt:        expiresAt,
		ClientIPAddress:  &ip,
		UserAgent:        &ua,
	}
	if err := s.sessions.Create(ctx, session); err != nil {
		return nil, fmt.Errorf("create session: %w", err)
	}

	_ = s.writeAudit(ctx, orgID, &user.ID, domain.AuditUserLogin, nil, ip, ua)

	return &LoginResult{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         user,
	}, nil
}

func (s *AuthService) RefreshSession(ctx context.Context, refreshToken string) (*LoginResult, error) {
	tokenHash := hashToken(refreshToken)

	session, err := s.sessions.GetByTokenHash(ctx, tokenHash)
	if err != nil {
		return nil, domain.ErrUnauthorized
	}

	if time.Now().After(session.ExpiresAt) {
		_ = s.sessions.DeleteByID(ctx, session.ID)
		return nil, domain.ErrUnauthorized
	}

	// We need user+orgID to issue new token; the handler must provide orgID via context.
	// For simplicity we embed orgID in the refresh token as a lookup join in production;
	// here we look up the user and their org directly.
	user, err := s.users.GetByID(ctx, uuid.UUID{}, session.UserID)
	if err != nil {
		return nil, domain.ErrUnauthorized
	}

	_ = s.sessions.DeleteByID(ctx, session.ID)

	accessToken, err := s.issueAccessToken(user)
	if err != nil {
		return nil, fmt.Errorf("issue access token: %w", err)
	}

	newRefresh, newHash, err := s.generateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("generate refresh token: %w", err)
	}

	newSession := &domain.Session{
		ID:               uuid.New(),
		UserID:           user.ID,
		SessionTokenHash: newHash,
		ExpiresAt:        time.Now().Add(refreshTokenDuration),
		ClientIPAddress:  session.ClientIPAddress,
		UserAgent:        session.UserAgent,
	}
	if err := s.sessions.Create(ctx, newSession); err != nil {
		return nil, fmt.Errorf("create session: %w", err)
	}

	return &LoginResult{
		AccessToken:  accessToken,
		RefreshToken: newRefresh,
		User:         user,
	}, nil
}

func (s *AuthService) Logout(ctx context.Context, orgID, userID uuid.UUID, ip, ua string) error {
	_ = s.sessions.DeleteByUserID(ctx, userID)
	_ = s.writeAudit(ctx, orgID, &userID, domain.AuditUserLogout, nil, ip, ua)
	return nil
}

func (s *AuthService) RequestPasswordReset(ctx context.Context, orgID uuid.UUID, email string) error {
	user, err := s.users.GetByEmail(ctx, orgID, email)
	if err != nil {
		// Return nil to avoid user enumeration.
		return nil
	}

	token, tokenHash, err := s.generateRefreshToken()
	if err != nil {
		return err
	}
	_ = token // In production: send token via email.

	prt := &domain.PasswordResetToken{
		ID:        uuid.New(),
		UserID:    user.ID,
		TokenHash: tokenHash,
		ExpiresAt: time.Now().Add(1 * time.Hour),
	}
	return s.pwReset.Create(ctx, prt)
}

func (s *AuthService) ConfirmPasswordReset(ctx context.Context, token, newPassword string) error {
	tokenHash := hashToken(token)
	prt, err := s.pwReset.GetByTokenHash(ctx, tokenHash)
	if err != nil {
		return domain.ErrUnauthorized
	}
	if prt.UsedAt != nil || time.Now().After(prt.ExpiresAt) {
		return domain.ErrUnauthorized
	}

	hash, err := s.hashPassword(newPassword)
	if err != nil {
		return err
	}

	if err := s.users.UpdatePasswordHash(ctx, prt.UserID, hash); err != nil {
		return err
	}
	return s.pwReset.MarkUsed(ctx, prt.ID)
}

// issueAccessToken issues a signed JWT for the given user.
func (s *AuthService) issueAccessToken(user *domain.User) (string, error) {
	secret := os.Getenv("AETHEL_JWT_SECRET")
	if secret == "" {
		secret = "dev-secret-change-in-production"
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"sub":  user.ID.String(),
		"org":  user.OrganizationID.String(),
		"role": string(user.Role),
		"iat":  now.Unix(),
		"exp":  now.Add(accessTokenDuration).Unix(),
		"jti":  uuid.New().String(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

func (s *AuthService) hashPassword(password string) (string, error) {
	salt := make([]byte, saltLength)
	if _, err := rand.Read(salt); err != nil {
		return "", fmt.Errorf("generate salt: %w", err)
	}

	memory := argon2Param("AETHEL_ARGON2_MEMORY_KIB", defaultMemoryKiB)
	iterations := uint32(argon2Param("AETHEL_ARGON2_ITERATIONS", defaultIterations))
	parallelism := uint8(argon2Param("AETHEL_ARGON2_PARALLELISM", defaultParallelism))

	hash := argon2.IDKey([]byte(password), salt, iterations, memory, parallelism, keyLength)

	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)

	return fmt.Sprintf(
		"$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
		memory, iterations, parallelism, b64Salt, b64Hash,
	), nil
}

func (s *AuthService) verifyPassword(password, phc string) bool {
	var version int
	var memory, iterations uint32
	var parallelism uint8
	var b64Salt, b64Hash string

	_, err := fmt.Sscanf(phc,
		"$argon2id$v=%d$m=%d,t=%d,p=%d$%s",
		&version, &memory, &iterations, &parallelism, &b64Salt,
	)
	if err != nil {
		return false
	}

	// Split b64Salt and b64Hash on the last '$'.
	for i := len(b64Salt) - 1; i >= 0; i-- {
		if b64Salt[i] == '$' {
			b64Hash = b64Salt[i+1:]
			b64Salt = b64Salt[:i]
			break
		}
	}

	salt, err := base64.RawStdEncoding.DecodeString(b64Salt)
	if err != nil {
		return false
	}
	expectedHash, err := base64.RawStdEncoding.DecodeString(b64Hash)
	if err != nil {
		return false
	}

	computed := argon2.IDKey([]byte(password), salt, iterations, memory, parallelism, uint32(len(expectedHash)))

	// Constant-time comparison.
	if len(computed) != len(expectedHash) {
		return false
	}
	var diff byte
	for i := range computed {
		diff |= computed[i] ^ expectedHash[i]
	}
	return diff == 0
}

func (s *AuthService) generateRefreshToken() (token, hash string, err error) {
	b := make([]byte, 32)
	if _, err = rand.Read(b); err != nil {
		return "", "", fmt.Errorf("generate token: %w", err)
	}
	token = base64.URLEncoding.EncodeToString(b)
	hash = hashToken(token)
	return token, hash, nil
}

func (s *AuthService) writeAudit(
	ctx context.Context,
	orgID uuid.UUID,
	actorID *uuid.UUID,
	eventType domain.AuditEventType,
	targetID *uuid.UUID,
	ip, ua string,
) error {
	entry := &domain.AuditEntry{
		OrganizationID:   orgID,
		ActorUserID:      actorID,
		ActionEventType:  eventType,
		TargetResourceID: targetID,
		IPAddress:        &ip,
		UserAgent:        &ua,
	}
	return s.audit.Write(ctx, entry)
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

func argon2Param(env string, def uint32) uint32 {
	if v := os.Getenv(env); v != "" {
		if n, err := strconv.ParseUint(v, 10, 32); err == nil {
			return uint32(n)
		}
	}
	return def
}
