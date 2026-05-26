-- Migration 18 UP: Pillar 3 — immutable, monthly range-partitioned audit ledger.
--
-- Design invariants:
--   - Rows are INSERT-only. No UPDATE or DELETE is permitted at the app layer.
--   - organization_id is a plain uuid column (NOT a FK) so ledger entries
--     survive even if the org row is deleted — legal preservation requirement.
--   - payload_checksum = SHA-256(payload_snapshot::text)
--   - previous_checksum = payload_checksum of the immediately preceding row
--     for this organization, enabling tamper detection across the chain.
--   - The table is PARTITIONED BY RANGE (created_at); monthly child tables
--     are created by migration 19 and the maintenance scheduler thereafter.

CREATE TABLE {{ .Schema }}.{{ T "audit_ledger" }} (
    id                   bigserial    NOT NULL,
    organization_id      uuid         NOT NULL,
    actor_user_id        uuid,
    action_event_type    varchar(100) NOT NULL,
    target_resource_type varchar(100),
    target_resource_id   uuid,
    payload_snapshot     jsonb,
    payload_checksum     varchar(128) NOT NULL,
    previous_checksum    varchar(128),
    client_ip_address    inet,
    user_agent           text,
    created_at           timestamptz  NOT NULL,
    CONSTRAINT {{ T "audit_ledger" }}_pkey     PRIMARY KEY (id, created_at),
    CONSTRAINT {{ T "audit_ledger" }}_actor_fk FOREIGN KEY (actor_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE NO ACTION
) PARTITION BY RANGE (created_at);

-- Indexes are created on each partition automatically via inheritance, but we
-- define them on the parent so they apply to all current and future partitions.
CREATE INDEX {{ T "audit_ledger" }}_org_time_idx
    ON {{ .Schema }}.{{ T "audit_ledger" }} (organization_id, created_at DESC);

CREATE INDEX {{ T "audit_ledger" }}_event_type_idx
    ON {{ .Schema }}.{{ T "audit_ledger" }} (action_event_type, created_at DESC);

CREATE INDEX {{ T "audit_ledger" }}_actor_idx
    ON {{ .Schema }}.{{ T "audit_ledger" }} (actor_user_id, created_at DESC)
    WHERE actor_user_id IS NOT NULL;
