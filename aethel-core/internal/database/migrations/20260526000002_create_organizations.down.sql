-- Migration 02 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "organizations" }};
