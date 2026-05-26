-- Migration 19 DOWN: Drop all pre-provisioned partitions.
-- The parent table (migration 18) remains; only the child partitions are dropped.

DO $$
DECLARE
    v_schema text := '{{ .Schema }}';
    v_parent text := '{{ T "audit_ledger" }}';
    v_month  date;
    v_name   text;
BEGIN
    FOR i IN -12..3 LOOP
        v_month := date_trunc('month', now()) + (i || ' months')::interval;
        v_name  := v_parent || '_' || to_char(v_month, 'YYYY_MM');
        EXECUTE format(
            'DROP TABLE IF EXISTS %I.%I', v_schema, v_name
        );
    END LOOP;
END;
$$;
