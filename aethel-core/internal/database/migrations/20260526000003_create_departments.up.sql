-- Migration 03 UP: Create departments with optional self-referencing hierarchy.

CREATE TABLE {{ .Schema }}.{{ T "departments" }} (
    id                   uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id      uuid         NOT NULL,
    parent_department_id uuid,
    name                 varchar(255) NOT NULL,
    code                 varchar(50),
    is_active            boolean      NOT NULL DEFAULT true,
    created_at           timestamptz  NOT NULL DEFAULT now(),
    updated_at           timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "departments" }}_pkey      PRIMARY KEY (id),
    CONSTRAINT {{ T "departments" }}_org_fk    FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "departments" }}_parent_fk FOREIGN KEY (parent_department_id)
        REFERENCES {{ .Schema }}.{{ T "departments" }} (id) ON DELETE RESTRICT
);

CREATE INDEX {{ T "departments" }}_org_idx
    ON {{ .Schema }}.{{ T "departments" }} (organization_id);
CREATE INDEX {{ T "departments" }}_parent_idx
    ON {{ .Schema }}.{{ T "departments" }} (parent_department_id)
    WHERE parent_department_id IS NOT NULL;
