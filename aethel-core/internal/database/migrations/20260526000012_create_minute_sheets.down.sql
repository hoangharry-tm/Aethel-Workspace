-- Migration 12 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "minute_sheets" }};
