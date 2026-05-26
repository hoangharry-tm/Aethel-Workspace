-- Migration 07 DOWN

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "dispatch_attachments" }};
