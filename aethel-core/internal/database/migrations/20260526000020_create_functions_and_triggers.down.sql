-- Migration 20 DOWN: Drop triggers then the function.

DROP TRIGGER IF EXISTS trg_{{ T "escalation_rules" }}_updated_at
    ON {{ .Schema }}.{{ T "escalation_rules" }};
DROP TRIGGER IF EXISTS trg_{{ T "minute_sheets" }}_updated_at
    ON {{ .Schema }}.{{ T "minute_sheets" }};
DROP TRIGGER IF EXISTS trg_{{ T "routing_rules" }}_updated_at
    ON {{ .Schema }}.{{ T "routing_rules" }};
DROP TRIGGER IF EXISTS trg_{{ T "dispatches" }}_updated_at
    ON {{ .Schema }}.{{ T "dispatches" }};
DROP TRIGGER IF EXISTS trg_{{ T "document_types" }}_updated_at
    ON {{ .Schema }}.{{ T "document_types" }};
DROP TRIGGER IF EXISTS trg_{{ T "users" }}_updated_at
    ON {{ .Schema }}.{{ T "users" }};
DROP TRIGGER IF EXISTS trg_{{ T "departments" }}_updated_at
    ON {{ .Schema }}.{{ T "departments" }};
DROP TRIGGER IF EXISTS trg_{{ T "organizations" }}_updated_at
    ON {{ .Schema }}.{{ T "organizations" }};

DROP FUNCTION IF EXISTS {{ .Schema }}.set_updated_at();
