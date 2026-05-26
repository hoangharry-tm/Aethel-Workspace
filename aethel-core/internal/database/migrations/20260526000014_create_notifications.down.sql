-- Migration 14 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "notifications" }};
