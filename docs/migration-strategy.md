# Migration Strategy — Blueprint-Rendered SQL Migrations

## Overview

Aethel Workspace migrations must be fully customisable by IT departments
without touching source code. The solution is **blueprint-rendered
migrations**: SQL files contain Go `text/template` directives that the
migration runner substitutes from `blueprints/server-database.yaml` before
execution.

This separates two concerns:
- **What** the schema looks like (SQL files, committed to the repo)
- **What names** it uses in production (YAML blueprint, edited by IT)

---

## File layout

```
aethel-core/
└── internal/
    └── database/
        ├── migrator.go           ← migration runner (reads blueprint + executes SQL)
        ├── blueprint_context.go  ← template helpers (T, E, Schema)
        └── migrations/
            ├── 20260526000001_create_extensions.up.sql
            ├── 20260526000001_create_extensions.down.sql
            ├── 20260526000002_create_organizations.up.sql
            ├── 20260526000002_create_organizations.down.sql
            ├── 20260526000003_create_departments.up.sql
            ├── 20260526000003_create_departments.down.sql
            ├── ...
            └── 20260526000020_create_audit_ledger_partitions.up.sql
```

### File naming

```
{YYYYMMDDHHmmss}_{description}.{direction}.sql
```

- `timestamp` — UTC, 14 digits; lexicographic order defines execution order.
- `description` — lowercase snake_case, under 60 characters.
- `direction` — `up` (forward) or `down` (rollback).

---

## Template syntax

Migration files are Go `text/template` documents. Three helper functions are
available:

| Template call | Resolves to | Source |
|---|---|---|
| `{{ .Schema }}` | Schema name | `schema.default_schema` |
| `{{ T "dispatches" }}` | Table name (alias or canonical) | `schema.name_aliases` |
| `{{ E "priority_level" }}` | Enum type name | `schema.enum_aliases` |

### Example migration file

```sql
-- 20260526000005_create_dispatches.up.sql
-- Requires: organizations, users, departments, document_types tables.

CREATE TYPE {{ .Schema }}.{{ E "priority_level" }} AS ENUM (
    'ROUTINE', 'PRIORITY', 'IMMEDIATE'
);

CREATE TYPE {{ .Schema }}.{{ E "dispatch_status" }} AS ENUM (
    'PENDING_ASSIGNMENT', 'UNDER_REVIEW', 'IN_TRANSIT',
    'ATTEMPTED_DELIVERY', 'DELIVERED', 'ESCALATED',
    'DISPATCHED', 'REJECTED'
);

CREATE TABLE {{ .Schema }}.{{ T "dispatches" }} (
    id                       uuid             NOT NULL DEFAULT gen_random_uuid(),
    organization_id          uuid             NOT NULL,
    tracking_number          varchar(50)      NOT NULL,
    direction                varchar(10)      NOT NULL CHECK (direction IN ('INBOUND','OUTBOUND')),
    document_type_id         uuid             NOT NULL,
    sender_name              varchar(255)     NOT NULL,
    sender_organization      varchar(255),
    recipient_name           varchar(255),
    recipient_organization   varchar(255),
    recipient_address        text,
    assigned_user_id         uuid,
    assigned_department_id   uuid,
    submitted_by_user_id     uuid             NOT NULL,
    priority_level           {{ .Schema }}.{{ E "priority_level" }}  NOT NULL DEFAULT 'ROUTINE',
    status_state             {{ .Schema }}.{{ E "dispatch_status" }} NOT NULL DEFAULT 'PENDING_ASSIGNMENT',
    subject_line             text,
    delivery_mode            varchar(100),
    is_manually_routed       boolean          NOT NULL DEFAULT false,
    original_suggested_user_id uuid,
    overdue_at               timestamptz,
    acknowledged_at          timestamptz,
    acknowledged_by_user_id  uuid,
    handoff_signature_data   jsonb,
    is_escalated             boolean          NOT NULL DEFAULT false,
    created_at               timestamptz      NOT NULL DEFAULT now(),
    updated_at               timestamptz      NOT NULL DEFAULT now(),

    CONSTRAINT {{ T "dispatches" }}_pkey           PRIMARY KEY (id),
    CONSTRAINT {{ T "dispatches" }}_tracking_uk    UNIQUE (tracking_number),
    CONSTRAINT {{ T "dispatches" }}_org_fk         FOREIGN KEY (organization_id)
        REFERENCES {{ .Schema }}.{{ T "organizations" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_doctype_fk     FOREIGN KEY (document_type_id)
        REFERENCES {{ .Schema }}.{{ T "document_types" }} (id) ON DELETE RESTRICT,
    CONSTRAINT {{ T "dispatches" }}_submitter_fk   FOREIGN KEY (submitted_by_user_id)
        REFERENCES {{ .Schema }}.{{ T "users" }} (id) ON DELETE RESTRICT
);

CREATE INDEX {{ T "dispatches" }}_org_status_idx
    ON {{ .Schema }}.{{ T "dispatches" }} (organization_id, status_state, priority_level);

CREATE INDEX {{ T "dispatches" }}_tracking_idx
    ON {{ .Schema }}.{{ T "dispatches" }} (tracking_number);

CREATE INDEX {{ T "dispatches" }}_created_at_idx
    ON {{ .Schema }}.{{ T "dispatches" }} (created_at DESC);
```

```sql
-- 20260526000005_create_dispatches.down.sql

DROP TABLE IF EXISTS {{ .Schema }}.{{ T "dispatches" }};
DROP TYPE  IF EXISTS {{ .Schema }}.{{ E "dispatch_status" }};
DROP TYPE  IF EXISTS {{ .Schema }}.{{ E "priority_level" }};
```

---

## Migrator implementation (Go)

### `BlueprintContext` struct

```go
// blueprint_context.go
package database

import "blueprints"

type BlueprintContext struct {
    Schema string            // schema.default_schema
    tables map[string]string // canonical → alias
    enums  map[string]string // canonical → alias
}

// T resolves a table name from the blueprint alias map.
// Falls back to the canonical name if no alias is configured.
func (b *BlueprintContext) T(canonical string) string {
    if alias, ok := b.tables[canonical]; ok && alias != "" {
        return alias
    }
    return canonical
}

// E resolves an enum type name from the blueprint alias map.
func (b *BlueprintContext) E(canonical string) string {
    if alias, ok := b.enums[canonical]; ok && alias != "" {
        return alias
    }
    return canonical
}

func NewBlueprintContext(cfg blueprints.DatabaseConfig) *BlueprintContext {
    return &BlueprintContext{
        Schema: cfg.Schema.DefaultSchema,
        tables: cfg.Schema.NameAliases,
        enums:  cfg.Schema.EnumAliases,
    }
}
```

### `Migrator.Up()` flow

```
1. Acquire advisory lock on the database (prevents concurrent migrations)
2. Load + render blueprints/server-database.yaml into BlueprintContext
3. CREATE TABLE IF NOT EXISTS <schema_migrations_history> (version bigint PK, applied_at timestamptz)
4. Read all *.up.sql files in migrations/ sorted lexicographically
5. For each file:
   a. Parse version from filename prefix
   b. Check if version already in schema_migrations_history → skip if yes
   c. Render the SQL template using BlueprintContext
   d. BEGIN TRANSACTION
   e. Execute rendered SQL
   f. INSERT INTO schema_migrations_history (version, applied_at) VALUES (...)
   g. COMMIT (or ROLLBACK + abort on error)
6. Release advisory lock
```

### `Migrator.Down(steps int)` flow

Same as Up but in reverse: reads `.down.sql`, removes from
`schema_migrations_history`, limited to `steps` reverts.

---

## IT customisation workflow

An IT admin who wants to rename the `dispatches` table to `dak_dispatches`:

1. Edit `blueprints/server-database.yaml`:
   ```yaml
   schema:
     name_aliases:
       dispatches: "dak_dispatches"
   ```

2. Write a new migration that performs the rename on the existing database:
   ```sql
   -- 20260601000001_rename_dispatches.up.sql
   ALTER TABLE {{ .Schema }}.dispatches RENAME TO {{ T "dispatches" }};
   ```
   > The `T "dispatches"` call now resolves to `"dak_dispatches"`, while
   > the literal `dispatches` on the left is the old name that the admin
   > knows exists on disk.

3. Run `aethel migrate up` — the runner renders and applies the rename.

All future migrations that reference `{{ T "dispatches" }}` now target
`dak_dispatches` transparently.

---

## Schema migrations history table

The migration tracking table itself is immune to aliasing (it must exist
before aliases can be resolved). Its name defaults to
`schema_migrations_history` and is set via
`environments.<env>.migrations.table_name` in the blueprint.

```sql
CREATE TABLE IF NOT EXISTS {{ .Schema }}.schema_migrations_history (
    version     bigint       NOT NULL,
    description varchar(255) NOT NULL,
    applied_at  timestamptz  NOT NULL DEFAULT now(),
    checksum    varchar(64)  NOT NULL,  -- SHA-256 of the rendered SQL
    CONSTRAINT schema_migrations_history_pkey PRIMARY KEY (version)
);
```

The `checksum` column lets the runner warn when an already-applied
migration file has been edited on disk, which is a dangerous operation.

---

## CLI commands

```bash
# (from aethel-core/ after the backend is scaffolded)
go run ./cmd/aethel migrate up           # apply all pending migrations
go run ./cmd/aethel migrate down --steps 1   # roll back the last migration
go run ./cmd/aethel migrate status       # list applied and pending versions
go run ./cmd/aethel migrate validate     # dry-run: render all templates, check SQL syntax
```

---

## Design principles

| Principle | Implementation |
|---|---|
| **No rename = no code change** | All table refs go through `T()` — swap an alias, done |
| **Idempotent** | Each migration is applied exactly once, tracked by version |
| **Reversible** | Every `.up.sql` has a corresponding `.down.sql` |
| **Auditable** | `schema_migrations_history` records version, timestamp, checksum |
| **Safe** | Each migration executes inside a single transaction; partial state is impossible |
| **Transparent** | `migrate validate` renders templates without executing — IT can review the final SQL |

---

## Ordering: planned migration sequence

Once the database design is approved, migrations will be written in this
dependency order:

| # | File prefix | Description |
|---|---|---|
| 01 | `create_extensions` | `uuid-ossp`, `pgcrypto`, `pg_trgm` |
| 02 | `create_organizations` | Tenant root table |
| 03 | `create_departments` | Org hierarchy |
| 04 | `create_users_and_sessions` | Users, sessions, reset tokens, notification prefs |
| 05 | `create_document_types` | IT-managed document type catalogue |
| 06 | `create_dispatches` | Core Pillar 1 entity + enums |
| 07 | `create_dispatch_attachments` | File attachments |
| 08 | `create_dispatch_events` | Unified event/timeline log |
| 09 | `create_routing_rules` | Rule definitions |
| 10 | `create_routing_rule_conditions` | Rule condition predicates |
| 11 | `create_routing_rule_destinations` | Ordered stop list |
| 12 | `create_minute_sheets` | Pillar 2 — one per dispatch |
| 13 | `create_green_notes` | Pillar 2 — chained, signed notes |
| 14 | `create_notifications` | In-app notification records |
| 15 | `create_escalation_rules` | Admin-configured escalation config |
| 16 | `create_system_settings` | Key-value config store |
| 17 | `create_branding_configs` | Logo + colour branding |
| 18 | `create_audit_ledger` | Pillar 3 — partitioned, immutable |
| 19 | `create_audit_ledger_partitions` | Pre-provision monthly partitions |
| 20 | `create_functions_and_triggers` | `updated_at` trigger, audit hook |
