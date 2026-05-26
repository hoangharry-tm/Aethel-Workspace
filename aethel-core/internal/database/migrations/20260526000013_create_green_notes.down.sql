-- Migration 13 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "green_notes" }};
