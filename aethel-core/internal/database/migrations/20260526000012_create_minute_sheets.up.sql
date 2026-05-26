-- Migration 12 UP: Pillar 2 — minute sheets (one per dispatch).
-- A minute sheet is the formal institutional record attached to each dispatch.
-- Green notes are appended sequentially to the sheet.

CREATE TABLE {{ .Schema }}.{{ T "minute_sheets" }} (
    id          uuid        NOT NULL DEFAULT gen_random_uuid(),
    dispatch_id uuid        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "minute_sheets" }}_pkey        PRIMARY KEY (id),
    CONSTRAINT {{ T "minute_sheets" }}_dispatch_uk UNIQUE (dispatch_id),
    CONSTRAINT {{ T "minute_sheets" }}_dispatch_fk FOREIGN KEY (dispatch_id)
        REFERENCES {{ .Schema }}.{{ T "dispatches" }} (id) ON DELETE CASCADE
);
