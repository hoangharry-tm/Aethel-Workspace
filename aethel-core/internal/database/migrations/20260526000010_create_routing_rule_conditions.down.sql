-- Migration 10 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "routing_rule_conditions" }};
