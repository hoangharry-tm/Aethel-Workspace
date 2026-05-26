-- Migration 17 UP: Per-organization logo and colour branding (US-20).

CREATE TABLE {{ .Schema }}.{{ T "branding_configs" }} (
    id                  uuid        NOT NULL DEFAULT gen_random_uuid(),
    organization_id     uuid        NOT NULL,
    logo_file_path      text,
    logo_mime_type      varchar(50),
    primary_brand_color varchar(7)
        CONSTRAINT {{ T "branding_configs" }}_color_ck
            CHECK (primary_brand_color ~ '^#[0-9a-fA-F]{6}$'),
    updated_by_user_id  uuid,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "branding_configs" }}_pkey   PRIMARY KEY (id),
    CONSTRAINT {{ T "branding_configs" }}_org_uk UNIQUE (organization_id),
    CONSTRAINT {{ T "branding_configs" }}_org_fk FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "branding_configs" }}_user_fk FOREIGN KEY (updated_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);
