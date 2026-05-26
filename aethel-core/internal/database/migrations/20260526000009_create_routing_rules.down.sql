-- Migration 09 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "routing_rules" }};
