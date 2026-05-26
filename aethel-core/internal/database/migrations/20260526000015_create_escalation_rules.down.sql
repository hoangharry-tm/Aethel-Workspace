-- Migration 15 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "escalation_rules" }};
