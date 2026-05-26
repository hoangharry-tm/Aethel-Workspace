-- Migration 19 UP: Pre-provision monthly partitions for audit_ledger.
-- Creates partitions for 12 months back, current month, and 3 months ahead.
-- The maintenance scheduler (aethel-scripts) handles ongoing provisioning.
--
-- Partition naming: {{ T "audit_ledger" }}_YYYY_MM
-- Note: {{ T "audit_ledger" }} is resolved at render time; partition names
-- will follow the alias if one is configured.

DO $$
DECLARE
    v_schema  text := '{{ .Schema }}';
    v_parent  text := '{{ T "audit_ledger" }}';
    v_month   date;
    v_name    text;
    v_from    text;
    v_to      text;
BEGIN
    -- Range: 12 months ago to 3 months ahead (16 partitions total)
    FOR i IN -12..3 LOOP
        v_month := date_trunc('month', now()) + (i || ' months')::interval;
        v_name  := v_parent || '_' || to_char(v_month, 'YYYY_MM');
        v_from  := to_char(v_month,                              'YYYY-MM-DD');
        v_to    := to_char(v_month + '1 month'::interval,       'YYYY-MM-DD');

        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I.%I '
            'PARTITION OF %I.%I '
            'FOR VALUES FROM (%L::timestamptz) TO (%L::timestamptz)',
            v_schema, v_name,
            v_schema, v_parent,
            v_from, v_to
        );
    END LOOP;
END;
$$;
