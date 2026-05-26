-- Migration 08 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "dispatch_events" }};
