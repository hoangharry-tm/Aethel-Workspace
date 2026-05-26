-- Migration 20 UP: Shared functions and triggers.
--
-- 1. set_updated_at()   — keeps updated_at in sync on every UPDATE
-- 2. Triggers applied to every table with an updated_at column

-- ── Function: set_updated_at ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION {{ .Schema }}.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql AS
$$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

-- ── updated_at triggers ───────────────────────────────────────────────────────
-- One trigger per table that has an updated_at column.

CREATE TRIGGER trg_{{ T "organizations" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "organizations" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "departments" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "departments" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "users" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "users" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "document_types" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "document_types" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "dispatches" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "dispatches" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "routing_rules" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "routing_rules" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "minute_sheets" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "minute_sheets" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();

CREATE TRIGGER trg_{{ T "escalation_rules" }}_updated_at
    BEFORE UPDATE ON {{ .Schema }}.{{ T "escalation_rules" }}
    FOR EACH ROW EXECUTE FUNCTION {{ .Schema }}.set_updated_at();
