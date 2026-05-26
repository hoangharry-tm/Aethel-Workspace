-- Migration 11 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "routing_rule_destinations" }};
