# Aethel Workspace — IT Customization Guide

**Audience:** IT administrators deploying and customizing Aethel Workspace for a large organization.  
**Scope:** Database setup, schema customization, migrations, and query tuning via YAML blueprints.  
**Prerequisite:** PostgreSQL 16 or later, access to the production secrets manager, and the compiled `aethel` binary.

---

## How the blueprint system works

Before touching any configuration, understand this core concept: **Aethel Workspace has no runtime configuration UI for database settings.** Everything is controlled by two YAML files that the Go backend loads once at startup:

| Blueprint file | What it controls |
|---|---|
| `blueprints/server-database.yaml` | Connection strings, connection pooling, migrations, table name aliases, partitioning, extensions, and performance guardrails |
| `blueprints/server-queries.yaml` | Externalized SQL statements for complex queries — IT can tune SQL without recompiling the Go backend |

Changes to either file require a **service restart** to take effect. Hot-reload is not supported in v1.

The system is intentionally designed so that IT departments can restyle, restructure, and reconfigure the database layer by editing YAML — without ever touching Go source code.

---

## Phase 1: First-time database configuration

### 1.1 The file you are editing

Open `blueprints/server-database.yaml`. The top of the file contains a security notice — read it. Passwords are never stored in YAML. The file is committed to version control, so treat it as public.

The file has seven top-level sections. Here is what each one does and when a large organization would change it.

---

### 1.2 `metadata` — blueprint version and loader behavior

```yaml
metadata:
  version: "1.0.0"
  engine_target: "postgresql-16+"
  strict_validation: true
```

| Field | What it does | When to change it |
|---|---|---|
| `version` | Identifies the blueprint schema version. The backend loader validates this against its accepted range. | Only change when the Aethel team publishes a new schema version and provides an upgrade path. |
| `engine_target` | Tells the migrator which PostgreSQL version-specific DDL is safe to use. | Only if you're running an older PostgreSQL cluster (contact the Aethel team before downgrading). |
| `strict_validation` | When `true`, any unrecognized YAML field in this file causes a fatal startup error. | Set to `false` only if you are in the process of migrating between blueprint schema versions. In normal operation, leave it `true` — it protects you from typos. |

**Do not set `strict_validation: false` in production.** A misspelled field that silently does nothing is worse than a startup failure that tells you exactly what went wrong.

---

### 1.3 `global_database_defaults` — applies to all environments

```yaml
global_database_defaults:
  dialect: "postgres"
  encoding: "UTF8"
  timezone: "UTC"
  logging:
    log_queries: false
    slow_query_threshold_ms: 200
    log_level: "warn"
```

| Field | What it does | Recommended setting |
|---|---|---|
| `dialect` | Fixed to `"postgres"`. Do not change. | `"postgres"` |
| `encoding` | Character encoding. Only change if your PostgreSQL cluster was initialized with a different encoding (very rare). | `"UTF8"` |
| `timezone` | All `timestamptz` values are stored in UTC. This is correct and matches international best practices. | `"UTC"` |
| `logging.log_queries` | Logs every SQL statement. Useful for debugging, but generates extremely high log volume. | `false` in production, `true` only during active debugging |
| `logging.slow_query_threshold_ms` | Any query that takes longer than this (in milliseconds) is always logged, regardless of `log_queries`. | Start at `200` (200ms). Tune down to `100` once the system is stable. |
| `logging.log_level` | Controls overall verbosity. Options: `debug`, `info`, `warn`, `error`. | `"warn"` for production, `"info"` for staging |

**Why would a large organization change the slow query threshold?** If your organization has 500+ users generating high concurrent load, you may find that a 200ms threshold generates too many log entries during peak hours. Raise it to `500` during initial rollout, then tune it down as query performance improves.

---

### 1.4 `environments` — per-environment connection configuration

This is the most important section. Each key under `environments` is a named deployment environment. The Go backend selects the active environment based on the `AETHEL_ENV` environment variable (default: `"development"`).

The shipping blueprint includes three environments: `development`, `staging`, and `production`. You can add more (e.g., `uat`, `dr`) by adding new keys.

#### Connection fields

```yaml
environments:
  production:
    connection:
      host: "prod-pg-primary.internal"
      port: 5432
      database: "aethel_workspace_prod"
      user: "aethel_prod_app"
      ssl_mode: "verify-full"
      ssl_root_cert_path: "/etc/ssl/certs/aethel-pg-root.crt"
      connection_string_env: "AETHEL_DB_DSN"
```

| Field | What it does |
|---|---|
| `host` | Hostname or IP of the PostgreSQL server. Use a DNS name, not an IP, so you can update it without touching this file. |
| `port` | PostgreSQL port. Almost always `5432`. |
| `database` | The database name. Use separate databases for each environment — never point staging at the production database. |
| `user` | The PostgreSQL role used by the application. This role should have DML permissions only (`SELECT`, `INSERT`, `UPDATE`, `DELETE`). It should not be a superuser. |
| `ssl_mode` | Controls TLS verification. Use `"verify-full"` in production — this validates both the certificate and the hostname. |
| `ssl_root_cert_path` | Path to the CA certificate PEM file on the server running the Go binary. Required when `ssl_mode` is `verify-full`. |
| `connection_string_env` | If set, the value is the name of an environment variable that holds a full `postgres://` DSN. When this is set, all other connection fields (`host`, `port`, `database`, `user`) are ignored. Useful when your secrets manager injects a complete DSN. |

**SSL mode reference:**

| `ssl_mode` value | When to use it |
|---|---|
| `disable` | Local development only. Never in any shared environment. |
| `require` | Encrypts the connection but does not verify the certificate. Use for staging if your CA is self-signed and you do not have a cert chain. |
| `verify-ca` | Verifies the certificate is signed by a trusted CA, but not the hostname. |
| `verify-full` | Verifies both the CA signature and the hostname. Required for production. |

#### Password handling — environment variables

Passwords are **never** in the YAML file. Set them as environment variables before starting the service:

| Variable | Purpose |
|---|---|
| `AETHEL_DB_PASSWORD` | Used when `connection_string_env` is empty. The backend constructs the DSN from the individual connection fields plus this password. |
| `AETHEL_DB_DSN` | A full `postgres://user:password@host:port/dbname?sslmode=verify-full` DSN. Used when `connection_string_env: "AETHEL_DB_DSN"` is set. The entire DSN is read from this variable, including the password. |

For Kubernetes: inject via a Secret. For HashiCorp Vault: use the Vault agent sidecar. For AWS: use Secrets Manager with the SSM Parameter Store or ECS secrets injection. The exact mechanism is up to your infrastructure team — Aethel does not care how the variable gets set, only that it exists at process start time.

#### Pooling fields

```yaml
    pooling:
      max_open_connections: 100
      max_idle_connections: 25
      connection_max_lifetime_minutes: 60
      connection_max_idle_time_minutes: 15
```

| Field | What it does |
|---|---|
| `max_open_connections` | Maximum number of database connections this application instance will hold open simultaneously. |
| `max_idle_connections` | Connections kept open and ready even when no requests are being processed. |
| `connection_max_lifetime_minutes` | Forces a connection to be closed and reopened after this many minutes. Prevents stale socket issues after network blips or database failover. |
| `connection_max_idle_time_minutes` | Closes connections that have been idle for this long. Reduces resource consumption during off-peak hours. |

**Sizing rule:** The total number of connections across all running application instances must not exceed your PostgreSQL `max_connections` setting minus 10 (reserved for `psql` admin sessions and monitoring tools). If you are running three application pods, each with `max_open_connections: 100`, your PostgreSQL server must have `max_connections >= 310`.

For a PgBouncer setup, set `max_open_connections` to a much lower value (25–50 per instance) and let PgBouncer handle the multiplexing.

#### Migration fields

```yaml
    migrations:
      directory: "./internal/database/migrations"
      auto_run_on_startup: false
      table_name: "schema_migrations_history"
      lock_timeout_seconds: 300
```

| Field | What it does |
|---|---|
| `directory` | Path to the SQL migration files, relative to the binary's working directory. Do not change this unless you have moved the migration files. |
| `auto_run_on_startup` | When `true`, the backend runs pending migrations every time it starts. **Set to `false` in production and staging.** Run migrations as a separate step before deploying the new binary. |
| `table_name` | The PostgreSQL table used to track which migrations have been applied. Do not change this after first run unless you also rename the physical table. |
| `lock_timeout_seconds` | How long the migrator will wait to acquire the advisory lock before giving up. In a high-availability deployment with rolling restarts, multiple pods may try to run migrations simultaneously; the lock ensures only one succeeds. Increase this if your migrations take more than a minute. |

---

### 1.5 Setting up multiple environments

A large organization typically needs at minimum: `development`, `staging`, and `production`. Some add `uat` (user acceptance testing) or `dr` (disaster recovery).

To add a new environment:

1. Add a new key under `environments` in `server-database.yaml`:

```yaml
environments:
  development:
    # ... existing config

  staging:
    # ... existing config

  production:
    # ... existing config

  uat:
    connection:
      host: "uat-pg.internal"
      port: 5432
      database: "aethel_workspace_uat"
      user: "aethel_uat_app"
      ssl_mode: "require"
      connection_string_env: "AETHEL_DB_DSN"
    pooling:
      max_open_connections: 30
      max_idle_connections: 5
      connection_max_lifetime_minutes: 30
      connection_max_idle_time_minutes: 10
    migrations:
      directory: "./internal/database/migrations"
      auto_run_on_startup: false
      table_name: "schema_migrations_history"
      lock_timeout_seconds: 120
```

2. Set `AETHEL_ENV=uat` before starting the service in that environment.
3. Set `AETHEL_DB_DSN` (or `AETHEL_DB_PASSWORD`) for the UAT environment's secrets.

---

### 1.6 Concrete example: large company with read replicas

A large organization with high read traffic might route reporting queries to a read replica while keeping writes on the primary. The blueprint does not currently have a built-in `read_replica` field (that is planned for v1.1), but the recommended approach is:

1. Use `connection_string_env: "AETHEL_DB_DSN"` for the primary write connection.
2. Configure PgBouncer or a proxy layer (e.g., RDS Proxy, pgpool-II) to route read queries to the replica. The application connects to the proxy endpoint.
3. Set `max_open_connections` to a value appropriate for the proxy's pool size, not the raw PostgreSQL `max_connections`.

Example production configuration for a company with a PgBouncer proxy:

```yaml
  production:
    connection:
      host: "pgbouncer.internal"        # proxy endpoint, not the raw PG primary
      port: 6432                        # PgBouncer default port
      database: "aethel_workspace_prod"
      user: "aethel_prod_app"
      ssl_mode: "require"               # PgBouncer handles TLS to PG backend
      connection_string_env: "AETHEL_DB_DSN"
    pooling:
      max_open_connections: 50          # lower — PgBouncer multiplexes; avoid overloading it
      max_idle_connections: 10
      connection_max_lifetime_minutes: 30
      connection_max_idle_time_minutes: 10
    migrations:
      directory: "./internal/database/migrations"
      auto_run_on_startup: false
      table_name: "schema_migrations_history"
      lock_timeout_seconds: 300
```

> **Note:** When using PgBouncer in transaction pooling mode, you cannot use prepared statements. Ensure `enable_query_plan_caching: false` in `server-queries.yaml` for this setup, or switch PgBouncer to session pooling mode.

---

## Phase 2: Understanding the schema

### 2.1 The three domain pillars

Aethel Workspace's database is organized around three independent but connected pillars. Every table belongs to one of them.

| Pillar | Tables | What it does |
|---|---|---|
| **Pillar 1 — DAK Diarization** | `dispatches`, `dispatch_attachments`, `dispatch_events`, `document_types`, `routing_rules`, `routing_rule_conditions`, `routing_rule_destinations` | Tracks every piece of inbound and outbound correspondence: logging, routing, priority assignment, delivery acknowledgment, and escalation. |
| **Pillar 2 — Green Noting Canvas** | `minute_sheets`, `green_notes` | Manages the institutional minute sheet attached to each dispatch. Green notes are appended sequentially and cryptographically chained so the sequence cannot be tampered with. |
| **Pillar 3 — RBAC Audit Ledger** | `audit_ledger` (partitioned), `users`, `user_sessions`, `password_reset_tokens`, `notification_preferences` | Immutable security event log. Records every significant action performed in the system. Partitioned by month for manageability at scale. |

**Supporting infrastructure tables** (not part of any pillar, but required by all three): `organizations`, `departments`, `escalation_rules`, `notifications`, `system_settings`, `branding_configs`.

For the full entity-relationship diagram with all column types and foreign key relationships, see `docs/db-design.mmd`. Any Mermaid-compatible viewer (GitHub, the Mermaid Live Editor, or a VS Code extension) will render it.

---

### 2.2 Key design decisions to understand

**Multi-tenancy via `organization_id`**

Every major table contains an `organization_id` column that references `organizations.id`. This means a single Aethel Workspace instance can serve multiple organizations (tenants). Each organization's data is logically isolated — all queries in production should include `WHERE organization_id = $N` to prevent cross-tenant data leakage. The RBAC middleware enforces this automatically, but it is important to understand when writing custom queries in `server-queries.yaml`.

**Append-only audit ledger with monthly partitions**

The `audit_ledger` table is designed to be immutable: rows are only ever inserted, never updated or deleted. It is range-partitioned by `created_at` into monthly child tables (e.g., `audit_ledger_2026_05`, `audit_ledger_2026_06`). This means:

- Queries that filter by date range are extremely fast — PostgreSQL prunes irrelevant partitions automatically.
- Dropping old records is done by dropping an entire partition child table, not by running `DELETE` — which is orders of magnitude faster and avoids table bloat.
- The partition structure is managed by the migration runner and a scheduled maintenance job. See Phase 6 for details.

**Cryptographic chaining in `green_notes`**

Each green note has a `cryptographic_hash` column computed as a SHA-256 digest of the note content plus the hash of the previous note in the sequence. This chains notes together: you cannot delete or modify a note in the middle of a sequence without breaking all subsequent hashes. The `pgcrypto` extension (required) provides the `digest()` function used to compute these hashes.

This means: **do not delete rows from `green_notes` directly.** There is no supported undo operation — this is by design for compliance reasons.

---

## Phase 3: Running migrations

### 3.1 How Blueprint-Rendered SQL migrations work

Aethel's migration system has one unusual property: SQL migration files are Go `text/template` documents. Before the migrator executes any SQL, it substitutes template variables with values from `server-database.yaml`. This is called **blueprint-rendered migration**.

This separation means:
- The SQL files (committed to the repository) describe the schema structure.
- The YAML blueprint controls what physical names are used in your specific deployment.

An IT admin who wants the `dispatches` table to be named `dak_letters` edits the YAML — they do not touch the SQL files. The template renderer handles the substitution at migration time.

### 3.2 Template syntax reference

Three template functions are available inside migration files:

| Template call | Resolves to | Source in YAML |
|---|---|---|
| `{{ .Schema }}` | The PostgreSQL schema namespace (usually `public`) | `schema.default_schema` |
| `{{ T "tablename" }}` | The deployed table name (alias if set, canonical name if not) | `schema.name_aliases` |
| `{{ E "enumname" }}` | The deployed enum type name | `schema.enum_aliases` |

**Example migration file snippet:**

```sql
-- 20260526000005_create_dispatches.up.sql

CREATE TYPE {{ .Schema }}.{{ E "priority_level" }} AS ENUM (
    'ROUTINE', 'PRIORITY', 'IMMEDIATE'
);

CREATE TABLE {{ .Schema }}.{{ T "dispatches" }} (
    id              uuid         NOT NULL DEFAULT gen_random_uuid(),
    organization_id uuid         NOT NULL,
    tracking_number varchar(50)  NOT NULL,
    -- ... more columns
    CONSTRAINT {{ T "dispatches" }}_pkey PRIMARY KEY (id)
);
```

If `schema.name_aliases` has `dispatches: "dak_letters"`, the rendered SQL becomes:

```sql
CREATE TYPE public.priority_level AS ENUM ('ROUTINE', 'PRIORITY', 'IMMEDIATE');

CREATE TABLE public.dak_letters (
    id              uuid         NOT NULL DEFAULT gen_random_uuid(),
    -- ...
    CONSTRAINT dak_letters_pkey PRIMARY KEY (id)
);
```

If no alias is set, `{{ T "dispatches" }}` resolves to `"dispatches"` — the canonical name.

---

### 3.3 CLI commands

All migration commands are run from the `aethel-core/` directory using the `aethel` binary:

```bash
# Apply all pending migrations (runs up.sql files not yet in schema_migrations_history)
aethel migrate up

# Show the status of all migrations — applied timestamps and pending versions
aethel migrate status

# Dry-run: render all templates and validate SQL syntax, but do not execute anything
aethel migrate validate

# Roll back the most recent migration (runs the corresponding .down.sql file)
aethel migrate down --steps 1

# Roll back the last 3 migrations
aethel migrate down --steps 3
```

> **Production workflow:** Always run `aethel migrate validate` before `aethel migrate up` in production. The validate command renders all templates and checks SQL syntax without touching the database.

---

### 3.4 What happens on first run

When you run `aethel migrate up` on a brand-new database, the migrator executes the following sequence:

1. Acquires a PostgreSQL advisory lock to prevent concurrent migration runs.
2. Loads `blueprints/server-database.yaml` and builds the `BlueprintContext` (table name aliases, enum aliases, schema name).
3. Creates the `schema_migrations_history` table if it does not exist. This table is immune to aliasing — it must exist before any alias can be resolved.
4. Reads all `*.up.sql` files from `./internal/database/migrations/`, sorted lexicographically (the timestamp prefix ensures correct order).
5. For each file, checks whether its version is already in `schema_migrations_history`. If yes, skips it.
6. Renders the SQL template using the `BlueprintContext`.
7. Executes the rendered SQL inside a transaction.
8. On success: inserts a row into `schema_migrations_history` with the version, description, timestamp, and a SHA-256 checksum of the rendered SQL.
9. On failure: rolls back the transaction and aborts — no partial state.
10. Releases the advisory lock.

The planned migration execution order for a fresh database:

| Order | Migration | Description |
|---|---|---|
| 01 | `create_extensions` | Installs `uuid-ossp`, `pgcrypto`, `pg_trgm` |
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
| 17 | `create_branding_configs` | Logo and colour branding |
| 18 | `create_audit_ledger` | Pillar 3 — partitioned, immutable |
| 19 | `create_audit_ledger_partitions` | Pre-provisions monthly partitions |
| 20 | `create_functions_and_triggers` | `updated_at` trigger, audit hook |

---

### 3.5 Verifying migrations worked

After running migrations, verify they applied correctly:

```sql
-- Connect to your database and run:
SELECT version, description, applied_at, checksum
FROM schema_migrations_history
ORDER BY version ASC;
```

You should see one row for each migration file that was applied. The `applied_at` column shows when it ran, and `checksum` is the SHA-256 of the rendered SQL at the time of execution.

To see only the most recent migration:

```sql
SELECT * FROM schema_migrations_history ORDER BY applied_at DESC LIMIT 1;
```

You can also run `aethel migrate status` from the CLI, which produces the same information in a human-readable table format.

---

## Phase 4: Customizing table names (the alias system)

### 4.1 How aliases work

The alias system lets you deploy Aethel with table names that match your organization's naming conventions, without editing any SQL migration files. For example:

- Your DMS team uses the naming convention `dak_*` for all dispatch-related tables.
- Your HR system already has a table called `users`, so you need Aethel's `users` table to be named `staff_directory` to avoid conflicts if they ever share a schema.

The alias map in `schema.name_aliases` is a simple key-value map: canonical name → deployed name.

**Critical rule to understand:** An alias applies to tables created *after* the alias is introduced. If the table already exists in the database (because migrations already ran), you must write a separate `ALTER TABLE ... RENAME TO ...` migration to rename the existing physical table. The alias alone does not rename anything that already exists.

---

### 4.2 Worked example: renaming `dispatches` and `users`

**Goal:** Rename `dispatches` → `dak_letters` and `users` → `staff_directory`.

#### Step 1: Determine whether migrations have already run

```bash
aethel migrate status
```

- If the output shows migrations 01–20 as applied, the tables already exist and you need an ALTER TABLE migration (proceed to Step 3).
- If this is a fresh database with no migrations applied, you only need to edit the YAML (proceed to Step 2 and skip Step 3).

#### Step 2: Edit the YAML blueprint

Open `blueprints/server-database.yaml` and update the `schema` section:

```yaml
schema:
  default_schema: "public"
  name_aliases:
    dispatches: "dak_letters"
    users: "staff_directory"
  enum_aliases: {}
```

Save the file. From this point on, every future `{{ T "dispatches" }}` call in a migration file resolves to `"dak_letters"`, and every `{{ T "users" }}` call resolves to `"staff_directory"`.

**If this is a fresh database (no migrations applied yet),** stop here. Run `aethel migrate up` and the tables will be created with the aliased names from the start.

#### Step 3: Write the ALTER TABLE migration (existing database only)

If the tables already exist, create two new migration files in `aethel-core/internal/database/migrations/`:

**File: `20260601000001_rename_dispatches_to_dak_letters.up.sql`**

```sql
-- Renames the dispatches table and all its constraints/indexes to match the
-- new blueprint alias. Run after setting name_aliases.dispatches = "dak_letters".

ALTER TABLE {{ .Schema }}.dispatches RENAME TO {{ T "dispatches" }};

-- Rename the primary key constraint (optional but keeps names consistent)
ALTER TABLE {{ .Schema }}.{{ T "dispatches" }}
    RENAME CONSTRAINT dispatches_pkey TO {{ T "dispatches" }}_pkey;

-- Rename indexes
ALTER INDEX {{ .Schema }}.dispatches_org_status_idx
    RENAME TO {{ T "dispatches" }}_org_status_idx;

ALTER INDEX {{ .Schema }}.dispatches_tracking_idx
    RENAME TO {{ T "dispatches" }}_tracking_idx;

ALTER INDEX {{ .Schema }}.dispatches_created_at_idx
    RENAME TO {{ T "dispatches" }}_created_at_idx;
```

**File: `20260601000001_rename_dispatches_to_dak_letters.down.sql`**

```sql
-- Reverts the rename. Note: the left side uses the current physical name (the alias),
-- the right side restores the canonical name.

ALTER TABLE {{ .Schema }}.{{ T "dispatches" }} RENAME TO dispatches;

ALTER TABLE {{ .Schema }}.dispatches
    RENAME CONSTRAINT {{ T "dispatches" }}_pkey TO dispatches_pkey;

ALTER INDEX {{ .Schema }}.{{ T "dispatches" }}_org_status_idx
    RENAME TO dispatches_org_status_idx;
```

**File: `20260601000002_rename_users_to_staff_directory.up.sql`**

```sql
ALTER TABLE {{ .Schema }}.users RENAME TO {{ T "users" }};

ALTER TABLE {{ .Schema }}.{{ T "users" }}
    RENAME CONSTRAINT users_pkey TO {{ T "users" }}_pkey;

ALTER INDEX {{ .Schema }}.users_email_idx
    RENAME TO {{ T "users" }}_email_idx;
```

**File: `20260601000002_rename_users_to_staff_directory.down.sql`**

```sql
ALTER TABLE {{ .Schema }}.{{ T "users" }} RENAME TO users;

ALTER TABLE {{ .Schema }}.users
    RENAME CONSTRAINT {{ T "users" }}_pkey TO users_pkey;
```

#### Step 4: Validate and run

```bash
# Preview the rendered SQL without touching the database
aethel migrate validate

# Review the output carefully — confirm the table names look correct

# Apply the rename migrations
aethel migrate up
```

#### Step 5: Verify

```sql
-- Confirm the tables exist with their new names
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('dak_letters', 'staff_directory')
ORDER BY tablename;

-- Should return both rows:
--  dak_letters
--  staff_directory

-- Confirm schema_migrations_history recorded the renames
SELECT version, description, applied_at
FROM schema_migrations_history
WHERE description LIKE 'rename_%'
ORDER BY version;
```

#### What just happened

```
Before:                          After:
public.dispatches          →     public.dak_letters
public.users               →     public.staff_directory

Template call result:
{{ T "dispatches" }}       →     "dak_letters"
{{ T "users" }}            →     "staff_directory"
```

All future migrations that reference `{{ T "dispatches" }}` will automatically target `dak_letters`. No SQL file changes required.

---

### 4.3 Enum type renaming

The same pattern applies to PostgreSQL enum types via `enum_aliases`. For example, to rename `priority_level` to `urgency_class`:

```yaml
schema:
  enum_aliases:
    priority_level: "urgency_class"
```

For an existing database, the ALTER equivalent for enum types:

```sql
-- 20260601000003_rename_priority_level_enum.up.sql
ALTER TYPE {{ .Schema }}.priority_level RENAME TO {{ E "priority_level" }};
```

---

## Phase 5: Customizing queries (`server-queries.yaml`)

### 5.1 Why queries are externalized

Complex SQL queries — inbox sorting logic, full-text search, report aggregations — are not hardcoded in the Go source. They live in `blueprints/server-queries.yaml`. This means:

- IT can tune query performance (change `ORDER BY`, add filters, adjust pagination limits) **without recompiling the backend**.
- The DBA can add hints or restructure joins to match the specific execution plan characteristics of the production cluster.
- A service restart applies the new queries — no code deployment required.

This applies only to complex, performance-sensitive queries. Simple CRUD operations are handled by the repository layer in the Go source and are not externalizable.

---

### 5.2 Structure of a query definition

```yaml
queries:
  dispatch:                          # pillar group key
    fetch_active_inbox:              # query name (Go identifier)
      statement: |                   # raw SQL; positional params use $1, $2, ...
        SELECT id, tracking_number, sender_name, subject_line, priority_level, created_at
        FROM dispatches
        WHERE assigned_department_id = $1
          AND status_state IN ('PENDING_ASSIGNMENT', 'UNDER_REVIEW')
        ORDER BY
          CASE priority_level
            WHEN 'IMMEDIATE' THEN 1
            WHEN 'PRIORITY'  THEN 2
            WHEN 'ROUTINE'   THEN 3
          END ASC,
          created_at DESC
        LIMIT $2 OFFSET $3;
      params:
        - name: "department_id"
          type: "uuid"
          nullable: false
        - name: "limit"
          type: "integer"
          nullable: false
        - name: "offset"
          type: "integer"
          nullable: false
      timeout_ms: 3000               # overrides global_query_defaults.timeout_ms
      cache_ttl_seconds: 0           # 0 = no caching; >0 enables result cache
      required_permission: "dispatch.view"
      description: "Fetch active inbox items for a department, sorted by urgency then recency."
```

**Field reference:**

| Field | Required | What it does |
|---|---|---|
| `statement` | yes | The raw SQL. Use `$1`, `$2`, etc. for positional parameters. |
| `params` | yes | Ordered list of parameters. The order must match `$1`, `$2`, etc. in the statement. |
| `params[].name` | yes | Human-readable name for the parameter. Used in error messages and documentation. |
| `params[].type` | yes | PostgreSQL type name. See the type reference table below. |
| `params[].nullable` | yes | Whether the parameter can be `NULL`. |
| `timeout_ms` | no | Per-query timeout in milliseconds. Overrides `global_query_defaults.timeout_ms`. |
| `cache_ttl_seconds` | no | If greater than 0, the result is cached for this many seconds. |
| `required_permission` | no | RBAC permission that the calling user must hold. Enforced by middleware before the query runs. |
| `description` | no | Documentation string. Ignored by the runtime. |

---

### 5.3 Parameter type reference

| YAML type | PostgreSQL type | Notes |
|---|---|---|
| `uuid` | `uuid` | Standard UUID format |
| `varchar` | `varchar(n)` | Variable-length string |
| `text` | `text` | Unlimited-length string |
| `integer` | `integer` | 32-bit signed integer |
| `bigint` | `bigint` | 64-bit signed integer |
| `smallint` | `smallint` | 16-bit signed integer |
| `boolean` | `boolean` | `true` / `false` |
| `timestamptz` | `timestamptz` | Timestamp with timezone (always UTC internally) |
| `inet` | `inet` | IP address (IPv4 or IPv6) |
| `jsonb` | `jsonb` | Binary JSON |

---

### 5.4 Worked example: changing inbox sort order

Your operations team has requested that the inbox sort items by **arrival time first** (oldest first) rather than by urgency. Here is how to make that change:

**Before** (current behavior — urgency first, then recency):

```yaml
queries:
  dispatch:
    fetch_active_inbox_by_department:
      statement: |
        SELECT id, tracking_number, sender_name, subject_line, priority_level, created_at
        FROM dispatches
        WHERE assigned_department_id = $1
          AND status_state IN ('PENDING_ASSIGNMENT', 'UNDER_REVIEW')
        ORDER BY
          CASE priority_level
            WHEN 'IMMEDIATE' THEN 1
            WHEN 'PRIORITY'  THEN 2
            WHEN 'ROUTINE'   THEN 3
            ELSE 4
          END ASC,
          created_at DESC
        LIMIT $2 OFFSET $3;
```

**After** (arrival time first, oldest at the top):

```yaml
queries:
  dispatch:
    fetch_active_inbox_by_department:
      statement: |
        SELECT id, tracking_number, sender_name, subject_line, priority_level, created_at
        FROM dispatches
        WHERE assigned_department_id = $1
          AND status_state IN ('PENDING_ASSIGNMENT', 'UNDER_REVIEW')
        ORDER BY created_at ASC
        LIMIT $2 OFFSET $3;
      description: "Inbox sorted oldest-first per operations team request (2026-06-01)."
```

Save the file and restart the backend service. The new sort order takes effect immediately on next startup — no code deployment, no migration needed.

---

### 5.5 Permission identifiers reference

The `required_permission` field references the RBAC permission tree:

| Permission | Who has it | What it guards |
|---|---|---|
| `dispatch.view` | RECEPTION, ADMIN | Reading the dispatch queue |
| `dispatch.create` | RECEPTION | Logging new inbound/outbound items |
| `dispatch.deliver` | RECEPTION | Marking a dispatch as delivered |
| `workflow.view` | USER, RECEPTION, ADMIN | Reading minute sheets |
| `workflow.approve` | USER, RECEPTION | Appending green notes |
| `admin.access` | ADMIN | Any admin panel operation |
| `admin.audit` | SYS_ADMIN | Reading the audit ledger |
| `archive.view` | RECEPTION, ADMIN | Searching historical records |

---

### 5.6 Pillar grouping convention

Organize your queries under the correct group key. The Go repository layer uses these keys to look up queries at startup:

| Group key | Pillar | Examples |
|---|---|---|
| `dispatch` | Pillar 1 | Inbox fetching, tracking lookups, status updates |
| `workflow` | Pillar 2 | Minute sheet fetching, green note appending |
| `governance` | Pillar 3 | Audit ledger writes, tamper detection reads |
| `admin` | Cross-pillar | User management, document type CRUD, routing rule management |
| `reports` | Cross-pillar | Aggregation queries, dashboard statistics |
| `search` | Cross-pillar | Full-text search, filtered search |

---

## Phase 6: Advanced — partition management for large deployments

### 6.1 How the `audit_ledger` partitioning works

The `audit_ledger` table is a PostgreSQL range-partitioned table. The partition key is the `created_at` column. Monthly partitioning means that instead of one monolithic `audit_ledger` table, the database maintains child tables like:

```
public.audit_ledger              ← the parent table (never queried directly)
public.audit_ledger_2026_05      ← records where created_at is in May 2026
public.audit_ledger_2026_06      ← records where created_at is in June 2026
public.audit_ledger_2026_07      ← records where created_at is in July 2026
```

When a query includes a `WHERE created_at >= '2026-05-01' AND created_at < '2026-06-01'` filter, PostgreSQL scans only `audit_ledger_2026_05` — it prunes all other child tables. This makes compliance queries over date ranges fast even with billions of records.

**The migration runner** (migration 19 — `create_audit_ledger_partitions`) pre-provisions partitions for:
- The current month
- The next 3 months (forward buffer)
- The previous 12 months (backfill buffer)

A separately scheduled maintenance job (configured outside this blueprint) is responsible for creating future partitions and dropping expired ones.

---

### 6.2 Configuring retention policy

The `partitioning` section controls how long audit data is retained:

```yaml
partitioning:
  audit_ledger:
    type: "range"
    column: "created_at"
    interval: "monthly"
    retention_policy:
      enabled: false
      retain_months: 84    # 7 years = 84 months
```

| Field | What it does |
|---|---|
| `retention_policy.enabled` | When `true`, the maintenance job automatically drops partition child tables older than `retain_months`. |
| `retention_policy.retain_months` | How many months of audit data to keep. Partitions older than this are dropped by the maintenance job. |

**Dropping a partition is not the same as running `DELETE`.** It is a metadata operation — the child table and all its data are removed in milliseconds, with no table bloat or VACUUM overhead. This is the primary advantage of partitioning for append-only data.

---

### 6.3 Configuration for a large organization (7+ years of records)

Many organizations have compliance requirements that mandate retaining security audit records for 7 years (84 months). The recommended configuration:

```yaml
partitioning:
  audit_ledger:
    type: "range"
    column: "created_at"
    interval: "monthly"
    retention_policy:
      enabled: true
      retain_months: 84    # exactly 7 years — adjust to match your legal/compliance requirement
```

For organizations with stricter requirements (e.g., financial services requiring 10 years):

```yaml
    retention_policy:
      enabled: true
      retain_months: 120   # 10 years
```

For organizations that must never auto-delete audit records (some government regulations):

```yaml
    retention_policy:
      enabled: false       # partitions are never automatically dropped
      retain_months: 0     # irrelevant when enabled is false
```

When `enabled: false`, partitions accumulate indefinitely. The database team is responsible for manually archiving and dropping old partitions after exporting them to cold storage (e.g., S3 Glacier, Azure Archive).

---

### 6.4 Storage sizing guidance

A rough estimate for planning storage:

- Average audit ledger row size: approximately 500 bytes (varies by payload size).
- A busy organization with 500 users performing 50 audited actions per user per day generates approximately:
  - 25,000 rows/day × 500 bytes = 12.5 MB/day
  - 375 MB/month per partition
  - 4.5 GB/year
  - 31.5 GB for 7 years (84 months)

At this volume, monthly partitioning is appropriate. If your organization generates significantly higher volumes (millions of events per day), consider switching to `interval: "quarterly"` to reduce partition management overhead, at the cost of less granular pruning.

---

## Phase 7: Troubleshooting common issues

### 7.1 Migration lock timeout

**Symptom:** `aethel migrate up` exits with an error like:

```
ERROR: failed to acquire advisory lock after 300 seconds
```

**What it means:** Another `aethel migrate up` process is already running (or was running and crashed without releasing the lock). PostgreSQL advisory locks are released automatically when the session that holds them closes, but if the previous process exited cleanly before committing, the lock may still be held.

**How to check:**

```sql
-- Check for active advisory locks
SELECT pid, usename, application_name, state, query_start, query
FROM pg_stat_activity
WHERE application_name LIKE '%aethel%';
```

**How to release:**

If the process is still running and stuck, find its PID and terminate it:

```sql
SELECT pg_terminate_backend(<pid>);
```

If no process is running but the lock is still held (rare — indicates a crash without proper cleanup), the lock will be released automatically when PostgreSQL detects the backend is gone. You can also connect with a superuser and manually release the lock:

```sql
SELECT pg_advisory_unlock_all();
```

Then retry `aethel migrate up`.

---

### 7.2 "Unknown field" errors with `strict_validation: true`

**Symptom:** The backend fails to start with:

```
FATAL: blueprint validation failed: unknown field "connection_timeout" in environments.production.connection
```

**What it means:** You added a field to the YAML that is not in the blueprint schema. When `strict_validation: true`, this is a fatal startup error.

**How to fix:** Remove or rename the field. Refer to `docs/server-blueprint-conventions.md` for the complete list of valid fields. If you believe the field should exist (it is a new feature not yet in the schema), contact the Aethel team — do not set `strict_validation: false` as a workaround in production.

---

### 7.3 SSL connection failures (staging/production)

**Symptom:** The backend starts but fails to connect with:

```
ERROR: SSL connection failed: certificate verify failed
```

**Common causes and fixes:**

| Cause | Fix |
|---|---|
| `ssl_root_cert_path` points to the wrong file or a non-existent path | Verify the path exists on the server running the Go binary: `ls -la /etc/ssl/certs/aethel-pg-root.crt` |
| The CA certificate has expired | Renew the CA cert and update it on all servers. Also update the cert on the PostgreSQL server. |
| The PostgreSQL server's hostname does not match the certificate's Common Name or SAN | Either update the cert to include the correct hostname, or switch `ssl_mode` from `verify-full` to `verify-ca` (less secure — only for debugging) |
| The `ssl_root_cert_path` is correct but the file permissions prevent the Go process from reading it | `chmod 644 /etc/ssl/certs/aethel-pg-root.crt` |

To debug the SSL handshake directly:

```bash
openssl s_client -connect prod-pg-primary.internal:5432 -starttls postgres \
  -CAfile /etc/ssl/certs/aethel-pg-root.crt
```

A successful handshake shows `Verify return code: 0 (ok)`.

---

### 7.4 Slow queries: using `slow_query_threshold_ms`

**Symptom:** Users report that certain pages are slow. You want to identify which database queries are responsible.

**How the threshold works:** Any query that takes longer than `slow_query_threshold_ms` milliseconds is written to the application log at `warn` level, regardless of the `log_queries` setting. The log entry includes the query text and execution time.

**To identify slow queries:**

1. Ensure `logging.log_level` is at `"warn"` or lower.
2. Temporarily lower `slow_query_threshold_ms` to catch more queries:

```yaml
global_database_defaults:
  logging:
    slow_query_threshold_ms: 100    # temporarily lower from 200 to 100ms
    log_level: "warn"
```

3. Restart the service and reproduce the slow behavior.
4. Search the application logs for lines containing `slow_query`.
5. Restore `slow_query_threshold_ms` to `200` after the investigation.

For deeper analysis, enable the `pg_stat_statements` extension (listed under `extensions.optional`) and query it from psql:

```sql
SELECT query, calls, mean_exec_time, max_exec_time, rows
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

This shows the 20 slowest queries by average execution time since the last `pg_stat_reset()`.

---

### 7.5 Partition missing: no partition for a given month

**Symptom:** An INSERT into `audit_ledger` fails with:

```
ERROR: no partition of relation "audit_ledger" found for row
DETAIL: Partition key of the failing row contains (created_at) = (2027-03-15 14:32:00+00).
```

**What it means:** A row is being inserted with a `created_at` value that falls outside the range of any existing partition child table. This happens when:

- The maintenance job that creates future partitions has not run (or failed to run) before the month rolled over.
- The system clock on the application server is significantly ahead of the database server's clock.

**Immediate fix — manually create the missing partition:**

```sql
-- Create a partition for March 2027
CREATE TABLE audit_ledger_2027_03
    PARTITION OF audit_ledger
    FOR VALUES FROM ('2027-03-01') TO ('2027-04-01');
```

**How to check which partitions exist:**

```sql
SELECT child.relname AS partition_name,
       pg_get_expr(child.relpartbound, child.oid) AS partition_range
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class child  ON pg_inherits.inhrelid  = child.oid
WHERE parent.relname = 'audit_ledger'
ORDER BY child.relname;
```

**Permanent fix:** Ensure the scheduled maintenance job (which pre-provisions future partitions) is configured and running reliably. The maintenance job should run at least once per month, before the end of the current month. Best practice is to run it weekly.

---

## Quick reference: environment variables

| Variable | Required | When used |
|---|---|---|
| `AETHEL_ENV` | No (default: `development`) | Selects the active environment block in `server-database.yaml` |
| `AETHEL_DB_PASSWORD` | Yes (if `connection_string_env` is empty) | PostgreSQL password for the configured user |
| `AETHEL_DB_DSN` | Yes (if `connection_string_env: "AETHEL_DB_DSN"`) | Full `postgres://` DSN including password |
| `AETHEL_SMTP_PASSWORD` | No | SMTP relay password (if email notifications are configured) |

---

## Quick reference: blueprint files

| File | Restart required | What to edit |
|---|---|---|
| `blueprints/server-database.yaml` | Yes | Connection, pooling, migrations, table/enum aliases, partitioning, extensions, performance |
| `blueprints/server-queries.yaml` | Yes | SQL statement text, sort order, parameter types, timeouts, permissions |

Both files are loaded once at startup. There is no hot-reload in v1. Plan service restarts when rolling out blueprint changes in production.
