-- Migration 14 UP: In-app notification records (US-08, US-11, US-12).

CREATE TABLE {{ .Schema }}.{{ T "notifications" }} (
    id                uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id   uuid         NOT NULL,
    recipient_user_id uuid         NOT NULL,
    dispatch_id       uuid,
    type              varchar(50)  NOT NULL
        CONSTRAINT {{ T "notifications" }}_type_ck
            CHECK (type IN (
                'DOCUMENT_ARRIVAL', 'REMINDER', 'ESCALATION', 'SYSTEM'
            )),
    title             varchar(500) NOT NULL,
    body              text,
    is_read           boolean      NOT NULL DEFAULT false,
    read_at           timestamptz,
    email_sent_at     timestamptz,
    email_failed      boolean      NOT NULL DEFAULT false,
    created_at        timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "notifications" }}_pkey        PRIMARY KEY (id),
    CONSTRAINT {{ T "notifications" }}_org_fk      FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "notifications" }}_recipient_fk FOREIGN KEY (recipient_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE CASCADE,
    CONSTRAINT {{ T "notifications" }}_dispatch_fk  FOREIGN KEY (dispatch_id)
        REFERENCES {{ .Schema }}.{{ T "dispatches" }} (id) ON DELETE CASCADE
);

-- Notification bell: unread count for a user
CREATE INDEX {{ T "notifications" }}_unread_idx
    ON {{ .Schema }}.{{ T "notifications" }} (recipient_user_id, created_at DESC)
    WHERE is_read = false;

-- Reminder job: find un-emailed notifications older than N hours
CREATE INDEX {{ T "notifications" }}_email_pending_idx
    ON {{ .Schema }}.{{ T "notifications" }} (created_at)
    WHERE email_sent_at IS NULL AND email_failed = false;
