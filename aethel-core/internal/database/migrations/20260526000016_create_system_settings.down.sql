-- Migration 16 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "system_settings" }};
