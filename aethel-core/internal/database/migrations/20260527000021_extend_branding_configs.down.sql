-- Migration 21 DOWN: Remove font, neutral palette, and wordmark from branding_configs.

ALTER TABLE {{ .Schema }}.{{ T "branding_configs" }}
    DROP COLUMN IF EXISTS neutral_palette,
    DROP COLUMN IF EXISTS font_family,
    DROP COLUMN IF EXISTS wordmark;
