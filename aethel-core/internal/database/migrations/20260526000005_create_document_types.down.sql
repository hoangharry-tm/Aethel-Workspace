-- Migration 05 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "document_types" }};
