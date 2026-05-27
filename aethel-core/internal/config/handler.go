package config

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
)

// Handler exposes GET /api/v1/config and PATCH /api/v1/admin/config/* endpoints.
type Handler struct {
	db    *sql.DB
	cache *ConfigCache
}

func NewHandler(db *sql.DB, cache *ConfigCache) *Handler {
	return &Handler{db: db, cache: cache}
}

type ctxKey string

// OrgIDContextKey is exported so api/server.go can inject the org UUID.
const OrgIDContextKey ctxKey = "orgID"

func orgIDFromCtx(r *http.Request) (uuid.UUID, bool) {
	v := r.Context().Value(OrgIDContextKey)
	if v == nil {
		return uuid.UUID{}, false
	}
	id, ok := v.(uuid.UUID)
	return id, ok
}

func (h *Handler) GetConfig(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}

	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to load config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg)
}

func (h *Handler) GetBranding(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}
	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to load config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg.Branding)
}

func (h *Handler) GetNav(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}
	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to load config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg.Nav)
}

func (h *Handler) GetFeatures(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}
	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to load config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg.Features)
}

func (h *Handler) PatchBranding(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}

	var input BrandingConfig
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	_, err := h.db.ExecContext(r.Context(), `
		UPDATE branding_configs SET
			primary_color   = COALESCE(NULLIF($2, ''), primary_color),
			neutral_palette = COALESCE(NULLIF($3, ''), neutral_palette),
			font_family     = COALESCE(NULLIF($4, ''), font_family),
			wordmark        = COALESCE(NULLIF($5, ''), wordmark),
			logo_path       = COALESCE(NULLIF($6, ''), logo_path),
			updated_at      = now()
		WHERE organization_id = $1
	`, orgID,
		input.PrimaryColor, input.NeutralPalette, input.FontFamily,
		input.Wordmark, input.LogoPath,
	)
	if err != nil {
		http.Error(w, "failed to update branding", http.StatusInternalServerError)
		return
	}

	h.cache.Invalidate(orgID)

	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to reload config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg)
}

func (h *Handler) PatchNav(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}

	var nav []NavGroup
	if err := json.NewDecoder(r.Body).Decode(&nav); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	navJSON, err := json.Marshal(nav)
	if err != nil {
		http.Error(w, "failed to encode nav", http.StatusInternalServerError)
		return
	}

	_, err = h.db.ExecContext(r.Context(), `
		INSERT INTO system_settings (organization_id, setting_key, setting_value, updated_at)
		VALUES ($1, 'nav_config', $2, now())
		ON CONFLICT (organization_id, setting_key)
		DO UPDATE SET setting_value = EXCLUDED.setting_value, updated_at = now()
	`, orgID, string(navJSON))
	if err != nil {
		http.Error(w, "failed to update nav", http.StatusInternalServerError)
		return
	}

	h.cache.Invalidate(orgID)

	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to reload config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg)
}

func (h *Handler) PatchFeatures(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}

	var features FeatureFlags
	if err := json.NewDecoder(r.Body).Decode(&features); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	featuresJSON, err := json.Marshal(features)
	if err != nil {
		http.Error(w, "failed to encode features", http.StatusInternalServerError)
		return
	}

	_, err = h.db.ExecContext(r.Context(), `
		UPDATE branding_configs SET feature_flags = $2, updated_at = now()
		WHERE organization_id = $1
	`, orgID, string(featuresJSON))
	if err != nil {
		http.Error(w, "failed to update features", http.StatusInternalServerError)
		return
	}

	h.cache.Invalidate(orgID)

	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to reload config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg)
}

func (h *Handler) PatchOrg(w http.ResponseWriter, r *http.Request) {
	orgID, ok := orgIDFromCtx(r)
	if !ok {
		http.Error(w, "missing org context", http.StatusInternalServerError)
		return
	}

	var input OrgProfile
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	_, err := h.db.ExecContext(r.Context(), `
		UPDATE organizations SET
			name          = COALESCE(NULLIF($2, ''), name),
			timezone      = COALESCE(NULLIF($3, ''), timezone),
			locale        = COALESCE(NULLIF($4, ''), locale),
			contact_email = COALESCE(NULLIF($5, ''), contact_email),
			updated_at    = now()
		WHERE id = $1
	`, orgID, input.Name, input.Timezone, input.Locale, input.ContactEmail)
	if err != nil {
		http.Error(w, "failed to update org", http.StatusInternalServerError)
		return
	}

	h.cache.Invalidate(orgID)

	cfg, err := h.loadCached(r.Context(), orgID)
	if err != nil {
		http.Error(w, "failed to reload config", http.StatusInternalServerError)
		return
	}
	writeJSON(w, cfg)
}

func (h *Handler) loadCached(ctx context.Context, orgID uuid.UUID) (*OrgConfig, error) {
	if cfg, ok := h.cache.Get(orgID); ok {
		return cfg, nil
	}
	cfg, err := LoadOrgConfig(ctx, h.db, orgID)
	if err != nil {
		return nil, err
	}
	h.cache.Set(orgID, cfg, cacheTTL)
	return cfg, nil
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
