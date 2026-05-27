# Server Blueprint Conventions
## `blueprints/server-database.yaml` & `blueprints/server-queries.yaml`

Aethel Workspace ships two server-side blueprint files. The Go backend
(`aethel-core`) loads them at startup and fails hard if validation fails.
Both files follow the same structural contract: `metadata` → global defaults
→ domain-specific sections. IT departments may edit any field documented
here; anything not listed is reserved for future versions.

---

## 1. `blueprints/server-database.yaml`

This file configures the PostgreSQL runtime: connection strings, connection
pooling, migration runner behaviour, schema customisation, and extension
requirements. It does **not** define table schemas — those live in SQL
migration files.

### 1.1 Top-level sections

| Section | Required | Purpose |
|---|---|---|
| `metadata` | yes | Blueprint versioning and loader behaviour |
| `global_database_defaults` | yes | Dialect, encoding, timezone, query logging |
| `environments` | yes | Per-environment connection + pool + migration config |
| `schema` | yes | PostgreSQL schema name and table/enum alias map |
| `partitioning` | no | Partition strategy for large append-only tables |
| `extensions` | no | PostgreSQL extensions to `CREATE EXTENSION IF NOT EXISTS` |
| `performance` | no | Statement timeouts, vacuum hints, index hints |

---

### 1.2 `metadata`

```yaml
metadata:
  version: "1.0.0"            # SemVer — bump minor on new fields, major on breaking
  engine_target: "postgresql-16+"   # minimum PostgreSQL version the schema requires
  strict_validation: true     # true = unknown fields are a fatal loader error
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `version` | string | yes | SemVer; must match the loader's accepted range |
| `engine_target` | string | yes | Used by the migrator to gate version-specific DDL |
| `strict_validation` | boolean | yes | Set `false` only during active migration of the file format |

---

### 1.3 `global_database_defaults`

Applied to all environments unless overridden.

```yaml
global_database_defaults:
  dialect: "postgres"
  encoding: "UTF8"
  timezone: "UTC"
  logging:
    log_queries: false
    slow_query_threshold_ms: 200
    log_level: "warn"       # debug | info | warn | error
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `dialect` | string | `"postgres"` | Fixed — only PostgreSQL is supported |
| `encoding` | string | `"UTF8"` | Do not change unless the cluster was initialised with a different encoding |
| `timezone` | string | `"UTC"` | All `timestamptz` values are stored in UTC |
| `logging.log_queries` | boolean | `false` | Enable only for deep debugging; generates large log volumes |
| `logging.slow_query_threshold_ms` | integer | `200` | Queries above this threshold are always logged regardless of `log_queries` |
| `logging.log_level` | enum | `"warn"` | `debug` | `info` | `warn` | `error` |

---

### 1.4 `environments`

Each key under `environments` is an environment name (free-form string).
The Go backend selects the active environment via the `AETHEL_ENV`
environment variable (default: `"development"`).

```yaml
environments:
  development:
    connection:
      host: "127.0.0.1"
      port: 5432
      database: "aethel_workspace_dev"
      user: "aethel_dev_user"
      # Password is NEVER stored here.
      # Set via: AETHEL_DB_PASSWORD environment variable.
      ssl_mode: "disable"             # disable | require | verify-ca | verify-full
      ssl_root_cert_path: ""          # path to PEM CA cert (required when verify-full)
      connection_string_env: ""       # optional: env var with a full DSN (takes precedence)
    pooling:
      max_open_connections: 25
      max_idle_connections: 5
      connection_max_lifetime_minutes: 15
      connection_max_idle_time_minutes: 5
    migrations:
      directory: "./internal/database/migrations"
      auto_run_on_startup: true       # NEVER true in production
      table_name: "schema_migrations_history"
      lock_timeout_seconds: 60        # advisory lock timeout for concurrent runner safety
```

#### `connection` fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `host` | string | yes | Hostname or IP of the PostgreSQL server |
| `port` | integer | yes | Usually `5432` |
| `database` | string | yes | Database name |
| `user` | string | yes | Database role/user |
| `ssl_mode` | enum | yes | `disable` | `require` | `verify-ca` | `verify-full` |
| `ssl_root_cert_path` | string | no | Required when `ssl_mode: verify-full` |
| `connection_string_env` | string | no | If set, the value is the name of an env var holding a full `postgres://` DSN; all other connection fields are ignored |

> **Security note:** Passwords are always supplied via `AETHEL_DB_PASSWORD`
> (or the full DSN via `connection_string_env`). Never write passwords in YAML.

#### `pooling` fields

| Field | Type | Default | Notes |
|---|---|---|---|
| `max_open_connections` | integer | `25` | Maximum total connections to the PG server |
| `max_idle_connections` | integer | `5` | Idle connections kept alive in the pool |
| `connection_max_lifetime_minutes` | integer | `15` | Force-recycle connections after N minutes (prevents stale socket issues) |
| `connection_max_idle_time_minutes` | integer | `5` | Close idle connections after N minutes of inactivity |

> **Sizing rule of thumb:** `max_open_connections` across all app instances
> should not exceed `max_connections` on the PG server minus 10 (reserved
> for admin/maintenance sessions).

#### `migrations` fields

| Field | Type | Default | Notes |
|---|---|---|---|
| `directory` | string | yes | Path to migration files, relative to the binary's working directory |
| `auto_run_on_startup` | boolean | `false` | `true` only in development; production requires out-of-band `aethel migrate up` |
| `table_name` | string | `"schema_migrations_history"` | Table used to track applied migrations; can be renamed via `schema.name_aliases` |
| `lock_timeout_seconds` | integer | `60` | Advisory lock prevents two processes running migrations concurrently |

---

### 1.5 `schema`

Controls table and enum naming. Changing a `name_aliases` entry renames the
physical table in all future migrations without touching any migration file.

```yaml
schema:
  default_schema: "public"
  name_aliases:
    # Canonical name → deployed name.
    # Omitting a canonical name means the canonical name is used as-is.
    # Example:
    # dispatches: "dak_dispatches"
    # audit_ledger: "security_ledger"
    # users: "employees"
  enum_aliases:
    # Same pattern for custom PostgreSQL enum type names.
    # priority_level: "urgency_class"
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `default_schema` | string | `"public"` | PostgreSQL schema (namespace) for all tables |
| `name_aliases` | map | `{}` | Canonical table name → deployed table name |
| `enum_aliases` | map | `{}` | Canonical enum name → deployed enum type name |

> **Alias rules:** An alias applies only to tables created after the alias
> is introduced. To rename an existing table, write a dedicated
> `ALTER TABLE … RENAME TO …` migration — aliases alone do not trigger a
> rename on existing databases.

---

### 1.6 `partitioning`

Declares partition strategies for tables that support it. Currently only
`audit_ledger` is partitioned.

```yaml
partitioning:
  audit_ledger:
    type: "range"               # only "range" is supported in v1
    column: "created_at"        # partition key column
    interval: "monthly"         # monthly | quarterly | yearly
    retention_policy:
      enabled: false
      retain_months: 84         # drop partitions older than N months (7 years)
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `type` | enum | `"range"` | Partition type; only `range` supported |
| `column` | string | `"created_at"` | Must be a `timestamptz` column |
| `interval` | enum | `"monthly"` | `monthly` | `quarterly` | `yearly` |
| `retention_policy.enabled` | boolean | `false` | Enable automatic partition dropping |
| `retention_policy.retain_months` | integer | `84` | Partitions older than this are dropped by the maintenance job |

> **Pre-provisioning:** The migration runner creates partitions for the
> current month, the next 3 months, and the previous 12 months on first run.
> A scheduled maintenance job (configured separately) creates future
> partitions and drops expired ones.

---

### 1.7 `extensions`

```yaml
extensions:
  required:
    - "uuid-ossp"           # gen_random_uuid()
    - "pgcrypto"            # digest() for SHA-256 hashes in green_notes / audit_ledger
    - "pg_trgm"             # GIN trigram indexes for fuzzy name search
  optional:
    - "pg_stat_statements"  # query performance monitoring (strongly recommended for production)
```

The migration runner executes `CREATE EXTENSION IF NOT EXISTS "<name>"`
for each entry in `required`. Failure to create a required extension is a
fatal startup error. Optional extensions generate a warning log entry.

---

### 1.8 `performance`

```yaml
performance:
  statement_timeout_ms: 30000     # 30s hard limit; overrides per-query settings
  idle_in_transaction_timeout_ms: 10000
  lock_timeout_ms: 5000
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `statement_timeout_ms` | integer | `30000` | PostgreSQL `statement_timeout` session default |
| `idle_in_transaction_timeout_ms` | integer | `10000` | Kills idle transactions that hold locks |
| `lock_timeout_ms` | integer | `5000` | Abort if a lock cannot be acquired within this window |

---

## 2. `blueprints/server-queries.yaml`

This file externalises performance-critical SQL statements. The Go backend
loads named queries at startup and executes them via prepared statements.
Only queries that benefit from externalisation (complex JOINs, UNION
aggregations, report queries) belong here; simple CRUD can be generated
by the repository layer.

### 2.1 Top-level sections

| Section | Required | Purpose |
|---|---|---|
| `metadata` | yes | Blueprint versioning and loader behaviour |
| `global_query_defaults` | yes | Timeout, pagination limits, caching defaults |
| `queries` | yes | Named SQL statements grouped by domain pillar |

---

### 2.2 `metadata`

```yaml
metadata:
  version: "1.0.0"
  engine_target: "postgresql-16-sql"
  strict_validation: true
```

Same fields as `server-database.yaml` metadata. `engine_target` identifies
the SQL dialect variant (e.g., `postgresql-16-sql` vs `postgresql-14-sql`).

---

### 2.3 `global_query_defaults`

```yaml
global_query_defaults:
  timeout_ms: 5000
  enable_query_plan_caching: true
  max_rows_per_page: 50
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `timeout_ms` | integer | `5000` | Default per-query timeout; individual queries can override |
| `enable_query_plan_caching` | boolean | `true` | Enables `PREPARE` / prepared statement reuse for named queries |
| `max_rows_per_page` | integer | `50` | Default `LIMIT` value; prevents accidentally unbounded queries |

---

### 2.4 `queries`

Queries are grouped by domain pillar. Each group key is a Go identifier
used by the repository layer to look up the statement.

```
queries:
  <pillar_group>:           # e.g., dispatch | workflow | governance | reports
    <query_name>:           # e.g., fetch_active_inbox
      statement: |          # raw SQL; positional params use $1, $2, ...
        SELECT ...
      params:               # ordered parameter list (matches $1, $2, ...)
        - name: "param_name"
          type: "pg_type"   # PostgreSQL type name: uuid, varchar, integer, timestamptz, inet, text, boolean
          nullable: false
      timeout_ms: 3000      # optional — overrides global_query_defaults.timeout_ms
      cache_ttl_seconds: 0  # optional — 0 means no caching; >0 enables result cache
      required_permission: "dispatch.view"   # optional — enforced by middleware
      description: "..."    # optional — documentation string
```

#### Parameter type reference

| YAML type value | PostgreSQL type | Go binding type |
|---|---|---|
| `uuid` | `uuid` | `[16]byte` / `pgtype.UUID` |
| `varchar` | `varchar(n)` | `string` |
| `text` | `text` | `string` |
| `integer` | `integer` | `int32` |
| `bigint` | `bigint` | `int64` |
| `boolean` | `boolean` | `bool` |
| `timestamptz` | `timestamptz` | `time.Time` |
| `inet` | `inet` | `net.IP` / `pgtype.Inet` |
| `jsonb` | `jsonb` | `json.RawMessage` |
| `smallint` | `smallint` | `int16` |

#### Permission identifiers

The `required_permission` field references the RBAC permission tree:

| Permission | Roles | Description |
|---|---|---|
| `dispatch.view` | RECEPTION, ADMIN | Read dispatch queue |
| `dispatch.create` | RECEPTION | Log new inbound/outbound |
| `dispatch.deliver` | RECEPTION | Mark handoff / delivered |
| `workflow.view` | USER, RECEPTION, ADMIN | Read minute sheets |
| `workflow.approve` | USER, RECEPTION | Append green notes |
| `admin.access` | ADMIN | Any admin-panel operation |
| `admin.audit` | SYS_ADMIN | Read audit ledger |
| `archive.view` | RECEPTION, ADMIN | Search historical records |

---

### 2.5 Pillar grouping convention

| Group key | Pillar | Description |
|---|---|---|
| `dispatch` | Pillar 1 | Inbound/outbound queue operations |
| `workflow` | Pillar 2 | Minute sheet and green note operations |
| `governance` | Pillar 3 | Audit ledger reads/writes |
| `admin` | Cross-pillar | User, document type, routing rule management |
| `reports` | Cross-pillar | Aggregation and reporting queries |
| `search` | Cross-pillar | Full-text and filtered search |

---

## 3. Shared conventions

### 3.1 Field naming

- All YAML keys use `snake_case`.
- Boolean fields that represent a feature flag use the `is_` prefix or `enable_` prefix.
- Duration fields always include the unit suffix: `_ms`, `_seconds`, `_minutes`, `_hours`, `_months`.

### 3.2 Secret handling

Passwords, TLS private keys, and API tokens are **never** stored in YAML
blueprint files. They are always injected via environment variables. The
convention for the required variables:

| Variable | Purpose |
|---|---|
| `AETHEL_DB_PASSWORD` | PostgreSQL password for the configured user |
| `AETHEL_DB_DSN` | Full DSN (when `connection_string_env` is set to this name) |
| `AETHEL_SMTP_PASSWORD` | SMTP relay password (configured in system_settings) |

### 3.3 Reload behaviour

`server-database.yaml` is loaded **once at startup**. Changes to this file
require a service restart. `server-queries.yaml` follows the same pattern
for consistency; hot-reloading query changes is not supported in v1.

### 3.4 Blueprint versioning contract

When a new field is added to either blueprint schema:
1. The field must be `optional` with a documented default.
2. The loader must apply that default if the field is absent.
3. The `metadata.version` minor version increments.
4. Breaking changes (field removed or type changed) increment the major version
   and require an explicit migration path documented in `CHANGELOG.md`.
