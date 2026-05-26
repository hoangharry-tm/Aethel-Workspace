-- Migration 18 DOWN
-- Dropping the parent table drops all child partitions.

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "audit_ledger" }};
