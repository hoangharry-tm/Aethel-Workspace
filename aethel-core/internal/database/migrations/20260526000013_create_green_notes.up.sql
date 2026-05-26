-- Migration 13 UP: Pillar 2 — cryptographically chained green notes.
-- Each note is immutable after insert. The chain is:
--   cryptographic_hash = SHA-256(content_body || sequence_order || author_id)
--   previous_hash      = cryptographic_hash of the immediately preceding note
--                        (NULL for the first note in a sheet)
-- Deleting or modifying any note breaks the chain and signals tampering.

CREATE TABLE {{ .Schema }}.{{ T "green_notes" }} (
    id                 uuid         NOT NULL DEFAULT gen_random_uuid(),
    minute_sheet_id    uuid         NOT NULL,
    sequence_order     int          NOT NULL,
    author_officer_id  uuid         NOT NULL,
    content_body       text         NOT NULL,
    cryptographic_hash varchar(512) NOT NULL,
    previous_hash      varchar(512),
    is_signed          boolean      NOT NULL DEFAULT false,
    digital_signature  text,
    -- created_at is the canonical timestamp; no updated_at — rows are immutable
    created_at         timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT {{ T "green_notes" }}_pkey       PRIMARY KEY (id),
    CONSTRAINT {{ T "green_notes" }}_seq_uk     UNIQUE (minute_sheet_id, sequence_order),
    CONSTRAINT {{ T "green_notes" }}_sheet_fk   FOREIGN KEY (minute_sheet_id)
        REFERENCES {{ .Schema }}.{{ T "minute_sheets" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "green_notes" }}_author_fk  FOREIGN KEY (author_officer_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);

-- Append a new note: look up the current max sequence to compute next
CREATE INDEX {{ T "green_notes" }}_sheet_seq_idx
    ON {{ .Schema }}.{{ T "green_notes" }} (minute_sheet_id, sequence_order DESC);
