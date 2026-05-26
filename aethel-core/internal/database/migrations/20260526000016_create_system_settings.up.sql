-- Migration 16 UP: Key-value store for admin-configurable settings (US-19).
-- Each setting change is written to audit_ledger by the application layer.

CREATE TABLE {{ .Schema }}.{{ T "system_settings" }} (
    id                  uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id     uuid         NOT NULL,
    key                 varchar(255) NOT NULL,
    value               text         NOT NULL,
    value_type          varchar(20)  NOT NULL DEFAULT 'STRING'
        CONSTRAINT {{ T "system_settings" }}_vtype_ck
            CHECK (value_type IN ('STRING', 'INTEGER', 'BOOLEAN', 'JSON')),
    description         text,
    updated_by_user_id  uuid,
    updated_at          timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "system_settings" }}_pkey   PRIMARY KEY (id),
    CONSTRAINT {{ T "system_settings" }}_key_uk UNIQUE (organization_id, key),
    CONSTRAINT {{ T "system_settings" }}_org_fk FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "system_settings" }}_user_fk FOREIGN KEY (updated_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);

-- Seed default settings for the demo organization
-- (The Go backend seeder, not this migration, inserts tenant-specific defaults.)
