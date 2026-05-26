-- Migration 11 UP: Ordered routing destinations for each rule (US-05, US-06).
-- Single-stop rules have exactly one row with stop_order = 1.
-- Multi-stop rules have one row per stop, ordered by stop_order ASC.

CREATE TABLE {{ .Schema }}.{{ T "routing_rule_destinations" }} (
    id                   uuid     NOT NULL DEFAULT gen_random_uuid(),
    routing_rule_id      uuid     NOT NULL,
    stop_order           smallint NOT NULL,
    target_user_id       uuid,
    target_department_id uuid,
    confirmation_required boolean NOT NULL DEFAULT true,
    CONSTRAINT {{ T "routing_rule_destinations" }}_pkey       PRIMARY KEY (id),
    CONSTRAINT {{ T "routing_rule_destinations" }}_stop_uk    UNIQUE (routing_rule_id, stop_order),
    CONSTRAINT {{ T "routing_rule_destinations" }}_rule_fk    FOREIGN KEY (routing_rule_id)
        REFERENCES {{ .Schema }}.{{ T "routing_rules" }} (id) ON DELETE CASCADE,
    CONSTRAINT {{ T "routing_rule_destinations" }}_user_fk    FOREIGN KEY (target_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "routing_rule_destinations" }}_dept_fk    FOREIGN KEY (target_department_id)
        REFERENCES {{ .Schema }}.{{ T "departments" }} (id) ON DELETE RESTRICT,
    -- Exactly one of target_user_id or target_department_id must be set
    CONSTRAINT {{ T "routing_rule_destinations" }}_target_ck  CHECK (
        (target_user_id IS NOT NULL)::int +
        (target_department_id IS NOT NULL)::int = 1
    )
);

CREATE INDEX {{ T "routing_rule_destinations" }}_rule_stop_idx
    ON {{ .Schema }}.{{ T "routing_rule_destinations" }} (routing_rule_id, stop_order);
