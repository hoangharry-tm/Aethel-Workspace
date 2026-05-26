-- Migration 15 UP: Admin-configured escalation rules (US-12).
-- The escalation scheduler checks dispatches against these rules.

CREATE TABLE {{ .Schema }}.{{ T "escalation_rules" }} (
    id                  uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id     uuid         NOT NULL,
    name                varchar(255) NOT NULL,
    trigger_hours       int          NOT NULL,
    escalate_to_user_id uuid,
    escalate_to_role    varchar(20),
    is_active           boolean      NOT NULL DEFAULT true,
    created_at          timestamptz  NOT NULL DEFAULT now(),
    updated_at          timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "escalation_rules" }}_pkey    PRIMARY KEY (id),
    CONSTRAINT {{ T "escalation_rules" }}_org_fk  FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "escalation_rules" }}_user_fk FOREIGN KEY (escalate_to_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT,
    -- At least one escalation target must be defined
    CONSTRAINT {{ T "escalation_rules" }}_target_ck CHECK (
        escalate_to_user_id IS NOT NULL OR escalate_to_role IS NOT NULL
    )
);

CREATE INDEX {{ T "escalation_rules" }}_org_active_idx
    ON {{ .Schema }}.{{ T "escalation_rules" }} (organization_id)
    WHERE is_active = true;
