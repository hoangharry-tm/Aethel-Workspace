-- Migration 21 UP: Add font, neutral palette, and wordmark to branding_configs (US-20 extension).
-- These fields support the runtime branding editor at /admin/branding.

ALTER TABLE {{ .Schema }}.{{ T "branding_configs" }}
    ADD COLUMN IF NOT EXISTS neutral_palette  varchar(20)  DEFAULT 'slate'
        CONSTRAINT {{ T "branding_configs" }}_neutral_ck
            CHECK (neutral_palette IN ('slate','zinc','gray','stone','neutral')),
    ADD COLUMN IF NOT EXISTS font_family      varchar(100) DEFAULT 'Inter',
    ADD COLUMN IF NOT EXISTS wordmark         varchar(200) DEFAULT 'Aethel Workspace';

-- Seed defaults for any existing rows (idempotent).
UPDATE {{ .Schema }}.{{ T "branding_configs" }}
SET
    neutral_palette = COALESCE(neutral_palette, 'slate'),
    font_family     = COALESCE(font_family, 'Inter'),
    wordmark        = COALESCE(wordmark, 'Aethel Workspace')
WHERE neutral_palette IS NULL
   OR font_family IS NULL
   OR wordmark IS NULL;
