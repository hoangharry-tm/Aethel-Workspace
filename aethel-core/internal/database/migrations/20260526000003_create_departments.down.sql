-- Migration 03 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "departments" }};
