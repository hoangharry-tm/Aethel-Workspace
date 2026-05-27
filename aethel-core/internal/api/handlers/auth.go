package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"

	"aethel-core/internal/domain"
	"aethel-core/internal/rbac"
	"aethel-core/internal/service"
)

type AuthHandler struct {
	svc *service.AuthService
}

func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	OrgID    string `json:"orgId"`
}

type loginResponse struct {
	AccessToken  string       `json:"accessToken"`
	RefreshToken string       `json:"refreshToken"`
	User         *domain.User `json:"user"`
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Email == "" || req.Password == "" {
		writeError(w, "email and password are required", http.StatusBadRequest)
		return
	}

	orgID, err := uuid.Parse(req.OrgID)
	if err != nil {
		writeError(w, "invalid org_id", http.StatusBadRequest)
		return
	}

	ip := clientIP(r)
	ua := r.UserAgent()

	result, err := h.svc.Login(r.Context(), orgID, req.Email, req.Password, ip, ua)
	if err != nil {
		switch err {
		case domain.ErrUnauthorized:
			writeError(w, "invalid credentials", http.StatusUnauthorized)
		case domain.ErrAccountLocked:
			writeError(w, "account locked", http.StatusForbidden)
		default:
			writeError(w, "login failed", http.StatusInternalServerError)
		}
		return
	}

	writeJSON(w, http.StatusOK, loginResponse{
		AccessToken:  result.AccessToken,
		RefreshToken: result.RefreshToken,
		User:         result.User,
	})
}

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RefreshToken == "" {
		writeError(w, "refreshToken is required", http.StatusBadRequest)
		return
	}

	result, err := h.svc.RefreshSession(r.Context(), req.RefreshToken)
	if err != nil {
		writeError(w, "invalid or expired refresh token", http.StatusUnauthorized)
		return
	}

	writeJSON(w, http.StatusOK, loginResponse{
		AccessToken:  result.AccessToken,
		RefreshToken: result.RefreshToken,
		User:         result.User,
	})
}

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	userIDStr, ok := rbac.UserIDFromCtx(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	orgIDStr, _ := rbac.OrgIDFromCtx(r.Context())

	userID, _ := uuid.Parse(userIDStr)
	orgID, _ := uuid.Parse(orgIDStr)

	_ = h.svc.Logout(r.Context(), orgID, userID, clientIP(r), r.UserAgent())
	w.WriteHeader(http.StatusNoContent)
}

func (h *AuthHandler) RequestPasswordReset(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
		OrgID string `json:"orgId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	orgID, err := uuid.Parse(req.OrgID)
	if err != nil {
		writeError(w, "invalid org_id", http.StatusBadRequest)
		return
	}

	// Always return 202 to avoid user enumeration.
	_ = h.svc.RequestPasswordReset(r.Context(), orgID, req.Email)
	w.WriteHeader(http.StatusAccepted)
}

func (h *AuthHandler) ConfirmPasswordReset(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Token       string `json:"token"`
		NewPassword string `json:"newPassword"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Token == "" || req.NewPassword == "" {
		writeError(w, "token and newPassword are required", http.StatusBadRequest)
		return
	}

	if err := h.svc.ConfirmPasswordReset(r.Context(), req.Token, req.NewPassword); err != nil {
		writeError(w, "invalid or expired token", http.StatusUnauthorized)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
