-- Migration 06 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "dispatches" }};
DROP TYPE  IF EXISTS {{ .Schema }}.{{ E "dispatch_status" }};
DROP TYPE  IF EXISTS {{ .Schema }}.{{ E "priority_level" }};
