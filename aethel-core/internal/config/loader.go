package config

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
)

const cacheTTL = 5 * time.Minute

// OrgConfig mirrors the AppRuntimeConfig shape expected by the Nuxt frontend.
type OrgConfig struct {
	Branding BrandingConfig `json:"branding"`
	Nav      []NavGroup     `json:"nav"`
	Features FeatureFlags   `json:"features"`
	Org      OrgProfile     `json:"org"`
}

type BrandingConfig struct {
	PrimaryColor   string `json:"primaryColor"`
	NeutralPalette string `json:"neutralPalette"`
	FontFamily     string `json:"fontFamily"`
	Wordmark       string `json:"wordmark"`
	LogoPath       string `json:"logoPath"`
}

type NavGroup struct {
	Label string    `json:"label"`
	Roles []string  `json:"roles"`
	Items []NavItem `json:"items"`
}

type NavItem struct {
	Label string  `json:"label"`
	Icon  string  `json:"icon"`
	To    string  `json:"to"`
	Badge *int    `json:"badge"`
}

type FeatureFlags struct {
	GreenNotingEnabled  bool `json:"greenNotingEnabled"`
	ExternalSmtpEnabled bool `json:"externalSmtpEnabled"`
	Require2faForAdmin  bool `json:"require2faForAdmin"`
}

type OrgProfile struct {
	Name         string `json:"name"`
	Timezone     string `json:"timezone"`
	Locale       string `json:"locale"`
	ContactEmail string `json:"contactEmail"`
}

// LoadOrgConfig queries branding_configs and system_settings to build an OrgConfig.
func LoadOrgConfig(ctx context.Context, db *sql.DB, orgID uuid.UUID) (*OrgConfig, error) {
	cfg := &OrgConfig{
		Branding: BrandingConfig{
			PrimaryColor:   "#4f46e5",
			NeutralPalette: "slate",
			FontFamily:     "Inter",
			Wordmark:       "Aethel Workspace",
		},
		Features: FeatureFlags{},
		Org: OrgProfile{
			Timezone: "UTC",
			Locale:   "en-US",
		},
	}

	row := db.QueryRowContext(ctx, `
		SELECT
			COALESCE(primary_color, '#4f46e5'),
			COALESCE(neutral_palette, 'slate'),
			COALESCE(font_family, 'Inter'),
			COALESCE(wordmark, 'Aethel Workspace'),
			COALESCE(logo_path, ''),
			COALESCE(feature_flags::text, '{}')
		FROM branding_configs
		WHERE organization_id = $1
		LIMIT 1
	`, orgID)

	var featureFlagsJSON string
	err := row.Scan(
		&cfg.Branding.PrimaryColor,
		&cfg.Branding.NeutralPalette,
		&cfg.Branding.FontFamily,
		&cfg.Branding.Wordmark,
		&cfg.Branding.LogoPath,
		&featureFlagsJSON,
	)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("load branding config: %w", err)
	}
	if featureFlagsJSON != "" && featureFlagsJSON != "{}" {
		_ = json.Unmarshal([]byte(featureFlagsJSON), &cfg.Features)
	}

	// Load nav config from system_settings.
	var navJSON sql.NullString
	err = db.QueryRowContext(ctx, `
		SELECT setting_value
		FROM system_settings
		WHERE organization_id = $1
		  AND setting_key = 'nav_config'
		LIMIT 1
	`, orgID).Scan(&navJSON)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("load nav config: %w", err)
	}
	if navJSON.Valid && navJSON.String != "" {
		_ = json.Unmarshal([]byte(navJSON.String), &cfg.Nav)
	}

	// Load org profile from organizations table.
	err = db.QueryRowContext(ctx, `
		SELECT
			COALESCE(name, ''),
			COALESCE(timezone, 'UTC'),
			COALESCE(locale, 'en-US'),
			COALESCE(contact_email, '')
		FROM organizations
		WHERE id = $1
		LIMIT 1
	`, orgID).Scan(
		&cfg.Org.Name,
		&cfg.Org.Timezone,
		&cfg.Org.Locale,
		&cfg.Org.ContactEmail,
	)
	if err != nil && err != sql.ErrNoRows {
		return nil, fmt.Errorf("load org profile: %w", err)
	}

	return cfg, nil
}
