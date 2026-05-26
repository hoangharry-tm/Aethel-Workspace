-- Migration 05 UP: IT-managed document type catalogue.
-- Reception selects from this list during intake (US-03, US-16).

CREATE TABLE {{ .Schema }}.{{ T "document_types" }} (
    id                    uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id       uuid         NOT NULL,
    name                  varchar(255) NOT NULL,
    description           text,
    default_urgency_level varchar(20)  NOT NULL DEFAULT 'ROUTINE'
        CONSTRAINT {{ T "document_types" }}_urgency_ck
            CHECK (default_urgency_level IN ('ROUTINE', 'PRIORITY', 'IMMEDIATE')),
    is_active             boolean      NOT NULL DEFAULT true,
    sort_order            smallint     NOT NULL DEFAULT 0,
    created_at            timestamptz  NOT NULL DEFAULT now(),
    updated_at            timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "document_types" }}_pkey    PRIMARY KEY (id),
    CONSTRAINT {{ T "document_types" }}_name_uk UNIQUE (organization_id, name),
    CONSTRAINT {{ T "document_types" }}_org_fk  FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT
);

-- Index supporting alphabetical dropdown in intake form (US-03)
CREATE INDEX {{ T "document_types" }}_org_active_sort_idx
    ON {{ .Schema }}.{{ T "document_types" }} (organization_id, sort_order, name)
    WHERE is_active = true;
