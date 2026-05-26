-- Migration 06 UP: Core Pillar 1 entity — dispatch records.
-- Covers both inbound (US-03) and outbound (US-09) document flows.

-- ── Enums ─────────────────────────────────────────────────────────────────────
CREATE TYPE {{ .Schema }}.{{ E "priority_level" }} AS ENUM (
    'ROUTINE', 'PRIORITY', 'IMMEDIATE'
);

CREATE TYPE {{ .Schema }}.{{ E "dispatch_status" }} AS ENUM (
    'PENDING_ASSIGNMENT',
    'UNDER_REVIEW',
    'IN_TRANSIT',
    'ATTEMPTED_DELIVERY',
    'DELIVERED',
    'ESCALATED',
    'DISPATCHED',
    'REJECTED'
);

-- ── dispatches ────────────────────────────────────────────────────────────────
CREATE TABLE {{ .Schema }}.{{ T "dispatches" }} (
    id                         uuid                            NOT NULL DEFAULT gen_random_uuid(),
    organization_id            uuid                            NOT NULL,
    tracking_number            varchar(50)                     NOT NULL,
    direction                  varchar(10)                     NOT NULL
        CONSTRAINT {{ T "dispatches" }}_direction_ck
            CHECK (direction IN ('INBOUND', 'OUTBOUND')),
    document_type_id           uuid                            NOT NULL,
    sender_name                varchar(255)                    NOT NULL,
    sender_organization        varchar(255),
    recipient_name             varchar(255),
    recipient_organization     varchar(255),
    recipient_address          text,
    assigned_user_id           uuid,
    assigned_department_id     uuid,
    submitted_by_user_id       uuid                            NOT NULL,
    priority_level             {{ .Schema }}.{{ E "priority_level" }}  NOT NULL DEFAULT 'ROUTINE',
    status_state               {{ .Schema }}.{{ E "dispatch_status" }} NOT NULL DEFAULT 'PENDING_ASSIGNMENT',
    subject_line               text,
    delivery_mode              varchar(100),
    is_manually_routed         boolean                         NOT NULL DEFAULT false,
    original_suggested_user_id uuid,
    overdue_at                 timestamptz,
    acknowledged_at            timestamptz,
    acknowledged_by_user_id    uuid,
    handoff_signature_data     jsonb,
    is_escalated               boolean                         NOT NULL DEFAULT false,
    created_at                 timestamptz                     NOT NULL DEFAULT now(),
    updated_at                 timestamptz                     NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "dispatches" }}_pkey        PRIMARY KEY (id),
    CONSTRAINT {{ T "dispatches" }}_tracking_uk UNIQUE (tracking_number),
    CONSTRAINT {{ T "dispatches" }}_org_fk      FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_doctype_fk  FOREIGN KEY (document_type_id)
        REFERENCES {{ .Schema }}.{{ T "document_types" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_assignee_fk FOREIGN KEY (assigned_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_dept_fk     FOREIGN KEY (assigned_department_id)
        REFERENCES {{ .Schema }}.{{ T "departments" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_submitter_fk FOREIGN KEY (submitted_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_orig_user_fk FOREIGN KEY (original_suggested_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_ack_user_fk  FOREIGN KEY (acknowledged_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);

-- Reception dashboard queue (US-10): filter by org + status, sort by priority
CREATE INDEX {{ T "dispatches" }}_queue_idx
    ON {{ .Schema }}.{{ T "dispatches" }} (organization_id, status_state, priority_level, created_at DESC);

-- Tracking number lookup (QR scan, US-07)
CREATE INDEX {{ T "dispatches" }}_tracking_idx
    ON {{ .Schema }}.{{ T "dispatches" }} (tracking_number);

-- Trigram index for sender_name fuzzy search (US-13)
CREATE INDEX {{ T "dispatches" }}_sender_trgm_idx
    ON {{ .Schema }}.{{ T "dispatches" }} USING GIN (sender_name gin_trgm_ops);

-- Escalation monitor: find non-escalated dispatches past their SLA deadline
CREATE INDEX {{ T "dispatches" }}_overdue_idx
    ON {{ .Schema }}.{{ T "dispatches" }} (organization_id, overdue_at)
    WHERE is_escalated = false AND overdue_at IS NOT NULL;
