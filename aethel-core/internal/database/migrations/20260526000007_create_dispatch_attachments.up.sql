-- Migration 07 UP: File attachments for dispatch records (US-03 optional scan).

CREATE TABLE {{ .Schema }}.{{ T "dispatch_attachments" }} (
    id                  uuid         NOT NULL DEFAULT gen_random_uuid(),
    dispatch_id         uuid         NOT NULL,
    file_name           varchar(500) NOT NULL,
    file_size_bytes     bigint       NOT NULL,
    mime_type           varchar(100) NOT NULL,
    storage_path        text         NOT NULL,
    uploaded_by_user_id uuid         NOT NULL,
    created_at          timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "dispatch_attachments" }}_pkey        PRIMARY KEY (id),
    CONSTRAINT {{ T "dispatch_attachments" }}_dispatch_fk FOREIGN KEY (dispatch_id)
        REFERENCES {{ .Schema }}.{{ T "dispatches" }} (id) ON DELETE CASCADE,
    CONSTRAINT {{ T "dispatch_attachments" }}_uploader_fk FOREIGN KEY (uploaded_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);

CREATE INDEX {{ T "dispatch_attachments" }}_dispatch_idx
    ON {{ .Schema }}.{{ T "dispatch_attachments" }} (dispatch_id);
