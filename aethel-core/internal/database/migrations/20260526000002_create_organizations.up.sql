-- Migration 02 UP: Create the organizations (tenant) table.
-- Every subsequent table references organization_id for row-level multi-tenancy.

CREATE TABLE {{ .Schema }}.{{ T "organizations" }} (
    id         uuid         NOT NULL DEFAULT gen_random_uuid(),
    name       varchar(255) NOT NULL,
    slug       varchar(100) NOT NULL,
    is_active  boolean      NOT NULL DEFAULT true,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "organizations" }}_pkey    PRIMARY KEY (id),
    CONSTRAINT {{ T "organizations" }}_slug_uk UNIQUE (slug)
);

CREATE INDEX {{ T "organizations" }}_is_active_idx
    ON {{ .Schema }}.{{ T "organizations" }} (is_active);
