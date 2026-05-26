-- Migration 17 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "branding_configs" }};
