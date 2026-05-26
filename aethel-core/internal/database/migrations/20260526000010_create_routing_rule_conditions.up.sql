-- Migration 10 UP: Condition predicates for each routing rule (US-05).
-- All conditions on a rule are AND-ed together.

CREATE TABLE {{ .Schema }}.{{ T "routing_rule_conditions" }} (
    id              uuid         NOT NULL DEFAULT gen_random_uuid(),
    routing_rule_id uuid         NOT NULL,
    condition_type  varchar(50)  NOT NULL
        CONSTRAINT {{ T "routing_rule_conditions" }}_type_ck
            CHECK (condition_type IN (
                'DOCUMENT_TYPE', 'SENDER_NAME', 'SENDER_ORG', 'URGENCY_LEVEL'
            )),
    condition_value varchar(500) NOT NULL,
    match_operator  varchar(20)  NOT NULL DEFAULT 'EQUALS'
        CONSTRAINT {{ T "routing_rule_conditions" }}_op_ck
            CHECK (match_operator IN ('EQUALS', 'CONTAINS', 'STARTS_WITH', 'REGEX')),
    CONSTRAINT {{ T "routing_rule_conditions" }}_pkey    PRIMARY KEY (id),
    CONSTRAINT {{ T "routing_rule_conditions" }}_rule_fk FOREIGN KEY (routing_rule_id)
        REFERENCES {{ .Schema }}.{{ T "routing_rules" }} (id) ON DELETE CASCADE
);

CREATE INDEX {{ T "routing_rule_conditions" }}_rule_idx
    ON {{ .Schema }}.{{ T "routing_rule_conditions" }} (routing_rule_id);
