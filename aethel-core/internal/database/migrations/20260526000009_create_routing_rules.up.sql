-- Migration 09 UP: Routing rule definitions (US-05, US-06).
-- Lower priority_order integer = higher precedence when matching.

CREATE TABLE {{ .Schema }}.{{ T "routing_rules" }} (
    id                 uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id    uuid         NOT NULL,
    name               varchar(255) NOT NULL,
    priority_order     int          NOT NULL,
    is_active          boolean      NOT NULL DEFAULT true,
    is_multi_stop      boolean      NOT NULL DEFAULT false,
    created_by_user_id uuid         NOT NULL,
    created_at         timestamptz  NOT NULL DEFAULT now(),
    updated_at         timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "routing_rules" }}_pkey      PRIMARY KEY (id),
    CONSTRAINT {{ T "routing_rules" }}_org_pri_uk UNIQUE (organization_id, priority_order),
    CONSTRAINT {{ T "routing_rules" }}_org_fk    FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "routing_rules" }}_creator_fk FOREIGN KEY (created_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);

CREATE INDEX {{ T "routing_rules" }}_org_active_pri_idx
    ON {{ .Schema }}.{{ T "routing_rules" }} (organization_id, priority_order)
    WHERE is_active = true;
