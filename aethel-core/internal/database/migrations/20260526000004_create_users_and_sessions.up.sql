-- Migration 04 UP: Create users, sessions, password reset tokens,
-- and notification preferences.

-- ── Enum: user_role ──────────────────────────────────────────────────────────
CREATE TYPE {{ .Schema }}.{{ E "user_role" }} AS ENUM (
    'ADMIN',
    'RECEPTION',
    'USER',
    'SYS_ADMIN'
);

-- ── users ─────────────────────────────────────────────────────────────────────
CREATE TABLE {{ .Schema }}.{{ T "users" }} (
    id                    uuid NOT NULL DEFAULT gen_random_uuid(),
    organization_id       uuid NOT NULL,
    department_id         uuid,

    email_address         varchar(255) NOT NULL,
    full_name             varchar(255) NOT NULL,
    job_title             varchar(255),

    role                  {{ .Schema }}.{{ E "user_role" }}
                          NOT NULL DEFAULT 'USER',

    is_active             boolean NOT NULL DEFAULT true,

    password_hash         varchar(255) NOT NULL,

    failed_login_attempts smallint NOT NULL DEFAULT 0,
    locked_until          timestamptz,
    last_login_at         timestamptz,

    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT {{ T "users" }}_pkey
        PRIMARY KEY (id),

    CONSTRAINT {{ T "users" }}_email_uk
        UNIQUE (organization_id, email_address),

    CONSTRAINT {{ T "users" }}_org_fk
        FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id)
        ON DELETE RESTRICT,

    CONSTRAINT {{ T "users" }}_dept_fk
        FOREIGN KEY (department_id)
        REFERENCES {{ .Schema }}.{{ T "departments" }} (id)
        ON DELETE RESTRICT
);

-- Role lookup (RBAC filtering)
CREATE INDEX {{ T "users" }}_org_role_idx
    ON {{ .Schema }}.{{ T "users" }}
    (organization_id, role);

-- Fast ILIKE / fuzzy search on name
CREATE INDEX {{ T "users" }}_name_trgm_idx
    ON {{ .Schema }}.{{ T "users" }}
    USING GIN (full_name gin_trgm_ops);

-- Query inactive users quickly
CREATE INDEX {{ T "users" }}_inactive_idx
    ON {{ .Schema }}.{{ T "users" }}
    (organization_id)
    WHERE is_active = false;

-- ── user_sessions ─────────────────────────────────────────────────────────────
CREATE TABLE {{ .Schema }}.{{ T "user_sessions" }} (
    id                   uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id              uuid NOT NULL,

    session_token_hash   varchar(255) NOT NULL,
    expires_at           timestamptz NOT NULL,

    client_ip_address    inet,
    user_agent           text,

    created_at           timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT {{ T "user_sessions" }}_pkey
        PRIMARY KEY (id),

    CONSTRAINT {{ T "user_sessions" }}_token_uk
        UNIQUE (session_token_hash),

    CONSTRAINT {{ T "user_sessions" }}_user_fk
        FOREIGN KEY (user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id)
        ON DELETE CASCADE
);

-- Get all sessions of a user
CREATE INDEX {{ T "user_sessions" }}_user_id_idx
    ON {{ .Schema }}.{{ T "user_sessions" }}
    (user_id);

-- Hot path:
-- SELECT * FROM user_sessions
-- WHERE session_token_hash = ?
-- AND expires_at > now()
CREATE INDEX {{ T "user_sessions" }}_token_expiry_idx
    ON {{ .Schema }}.{{ T "user_sessions" }}
    (session_token_hash, expires_at);

-- Cleanup expired sessions efficiently
CREATE INDEX {{ T "user_sessions" }}_expires_at_idx
    ON {{ .Schema }}.{{ T "user_sessions" }}
    (expires_at);

-- ── password_reset_tokens ─────────────────────────────────────────────────────
CREATE TABLE {{ .Schema }}.{{ T "password_reset_tokens" }} (
    id           uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id      uuid NOT NULL,

    token_hash   varchar(255) NOT NULL,
    expires_at   timestamptz NOT NULL,
    used_at      timestamptz,

    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT {{ T "password_reset_tokens" }}_pkey
        PRIMARY KEY (id),

    CONSTRAINT {{ T "password_reset_tokens" }}_token_uk
        UNIQUE (token_hash),

    CONSTRAINT {{ T "password_reset_tokens" }}_user_fk
        FOREIGN KEY (user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id)
        ON DELETE CASCADE
);

-- Fast lookup for active reset tokens
CREATE INDEX {{ T "password_reset_tokens" }}_live_idx
    ON {{ .Schema }}.{{ T "password_reset_tokens" }}
    (token_hash, expires_at)
    WHERE used_at IS NULL;

-- Cleanup expired reset tokens
CREATE INDEX {{ T "password_reset_tokens" }}_expires_at_idx
    ON {{ .Schema }}.{{ T "password_reset_tokens" }}
    (expires_at);

-- ── notification_preferences ──────────────────────────────────────────────────
CREATE TABLE {{ .Schema }}.{{ T "notification_preferences" }} (
    id                        uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id                   uuid NOT NULL,

    in_app_enabled            boolean NOT NULL DEFAULT true,
    email_enabled             boolean NOT NULL DEFAULT true,

    reminder_interval_hours   smallint NOT NULL DEFAULT 24,

    CONSTRAINT {{ T "notification_preferences" }}_pkey
        PRIMARY KEY (id),

    CONSTRAINT {{ T "notification_preferences" }}_user_uk
        UNIQUE (user_id),

    CONSTRAINT {{ T "notification_preferences" }}_user_fk
        FOREIGN KEY (user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id)
        ON DELETE CASCADE
);