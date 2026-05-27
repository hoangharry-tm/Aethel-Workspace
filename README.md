# Aethel Workspace

Æthel Workspace is a secure, open-source, configuration-driven e-office platform that centralizes administrative workflows, smart office dynamics, and secure information routing into a unified, high-performance digital ecosystem.

The system follows a **runtime-configurable** architecture: two IT-facing YAML blueprints provide seed values loaded at first boot; all runtime configuration (branding, navigation, feature flags) is stored in PostgreSQL and managed through the `/admin/*` pages — no recompilation required.

---

## System Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    Aethel Workspace                         │
│                                                             │
│   aethel-view/          aethel-core/         blueprints/   │
│   (Nuxt 4 Frontend)     (Go Backend)         (YAML seeds)  │
│                                                             │
│   ┌─────────────┐      ┌─────────────┐      ┌───────────┐  │
│   │  Vue 3 +    │◄────►│ chi router  │◄────►│ server-   │  │
│   │  Nuxt UI v4 │      │ + RBAC      │      │ database  │  │
│   │  + Pinia    │      │ + JWT auth  │      │ .yaml     │  │
│   └─────────────┘      └──────┬──────┘      └───────────┘  │
│                               │                             │
│                        ┌──────▼──────┐                      │
│                        │ PostgreSQL  │                      │
│                        │ (runtime    │                      │
│                        │  config +   │                      │
│                        │  all data)  │                      │
│                        └─────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Go | 1.22+ |
| Node.js | 20+ |
| pnpm | 9+ |
| Docker + Docker Compose | v2+ |
| PostgreSQL | 16+ (or use Docker) |
| `make` | any |

---

## Quick Start

```bash
# 1. Copy environment config
cp .env.example .env          # edit DB credentials as needed

# 2. Start all services (postgres + backend + frontend)
make dev

# 3. Apply database migrations
make migrate-up
```

Frontend: http://localhost:3000  
Backend API: http://localhost:8080/api/v1  
Health probe: http://localhost:8080/healthz

---

## Available Commands

### Top-level (`make`)

```bash
make help               # Print all available make targets
```

#### Development

```bash
make dev                # Start all services via Docker Compose (postgres + backend + frontend)
make dev-fe             # Start only the Nuxt dev server (hot reload, no Docker)
make dev-be             # Start only the Go backend (requires postgres running separately)
make dev-db             # Start only the postgres container
make dev-down           # Stop and remove all dev containers (volumes preserved)
make dev-reset          # Full reset — stop, delete volumes, start fresh database
```

#### Build

```bash
make build              # Build frontend and backend
make build-fe           # Build the Nuxt app  (→ aethel-view/.output/)
make build-be           # Compile Go binary   (→ aethel-core/bin/aethel)
make build-docker       # Build both Docker images locally (does not push)
```

#### Testing

```bash
make test               # Run all tests (frontend + backend)
make test-fe            # Run frontend Vitest tests (unit + component)
make test-be            # Run Go tests with race detector
make test-e2e           # Run Playwright end-to-end tests (requires dev server)
```

#### Linting & Formatting

```bash
make lint               # Lint everything (frontend + backend + YAML blueprints)
make lint-fe            # ESLint the frontend
make lint-be            # golangci-lint the backend
make lint-yaml          # yamllint on blueprints/
make fmt                # Format Go (gofmt) and frontend (prettier)
```

#### Database & Migrations

```bash
make migrate-up         # Apply all pending migrations
make migrate-down       # Roll back the last applied migration
make migrate-status     # Show applied and pending migrations
make migrate-validate   # Dry-run: render templates, validate SQL (no DB writes)
make db-shell           # Open a psql shell into the dev database
make db-dump            # Dump the dev database to /tmp/aethel-dump-<timestamp>.sql
```

#### Kubernetes

```bash
make k8s-apply-dev      # Apply all k8s manifests to the dev namespace
make k8s-apply-prod     # Apply all k8s manifests to the production namespace
make k8s-status         # Show all resources in the production namespace
```

#### Utilities

```bash
make clean              # Remove build artifacts, .nuxt cache, and Go build cache
```

---

### Frontend (`aethel-view/` — pnpm)

```bash
pnpm dev                # Dev server at http://localhost:3000 (hot reload)
pnpm build              # Production build
pnpm preview            # Preview production build locally
pnpm postinstall        # Re-run nuxt prepare (auto-runs after pnpm install)

pnpm test               # Run all Vitest tests
pnpm test:unit          # Unit tests only  (test/unit/*.spec.ts, Node env)
pnpm test:nuxt          # Component tests  (test/nuxt/*.spec.ts, happy-dom env)
pnpm test:coverage      # Tests with V8 coverage report
pnpm test:watch         # Vitest in watch mode

pnpm test:e2e           # Playwright E2E tests (Chromium)
pnpm test:e2e:ui        # Playwright with interactive UI
```

---

### Backend CLI (`aethel-core/` — Go)

Build once, then use the binary:

```bash
cd aethel-core
go build -o bin/aethel ./cmd/aethel
```

Or run directly with `go run`:

```bash
go run ./cmd/aethel <command>
```

#### Server

```bash
aethel serve                    # Start the HTTP server (default port 8080)
```

#### Migrations

```bash
aethel migrate up               # Apply all pending migrations
aethel migrate down             # Roll back 1 migration (default)
aethel migrate down --steps N   # Roll back N migrations
aethel migrate status           # List applied / pending migrations
aethel migrate validate         # Render templates and validate SQL (no DB writes)
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `AETHEL_ENV` | No | Runtime environment: `development` (default) or `production` |
| `AETHEL_PORT` | No | HTTP listen port (default `8080`) |
| `AETHEL_DB_PASSWORD` | Yes | PostgreSQL password |
| `AETHEL_DB_DSN` | No | Full DSN (overrides individual connection fields) |
| `AETHEL_JWT_SECRET` | Yes (prod) | HS256 signing secret (defaults to a dev-only value) |
| `AETHEL_ARGON2_MEMORY_KIB` | No | Argon2id memory cost in KiB (default `65536`) |
| `AETHEL_ARGON2_ITERATIONS` | No | Argon2id iteration count (default `3`) |
| `AETHEL_ARGON2_PARALLELISM` | No | Argon2id parallelism (default `4`) |

See `.env.example` for a full reference.

---

## Blueprint Files (IT-facing)

Only two YAML files are intended for IT administrators:

| File | Purpose |
|---|---|
| `blueprints/server-database.yaml` | DB connection, pool config, migration settings, schema aliases |
| `blueprints/ui-theme.yaml` | Branding seed (primary color, font, logo) — loaded once at first boot |

All other configuration (navigation, feature flags, org profile) is managed at runtime through the `/admin/*` pages and stored in PostgreSQL.

---

## Project Structure

```
aethel-workspace/
├── aethel-view/          # Nuxt 4 frontend
├── aethel-core/          # Go backend
│   ├── cmd/aethel/       # CLI entry point (cobra)
│   └── internal/
│       ├── api/          # HTTP server, routes, handlers
│       ├── blueprint/    # YAML config loaders
│       ├── config/       # Runtime config cache + admin API
│       ├── database/     # Migrator, query registry, connection
│       ├── domain/       # Domain types and repository interfaces
│       ├── rbac/         # Permission middleware
│       ├── service/      # Business logic (auth, dispatch, workflow)
│       ├── transport/    # SSE broker
│       └── worker/       # Background workers (escalation)
├── blueprints/           # IT-facing YAML seed files
├── docs/                 # Architecture docs, ER diagrams, guides
├── k8s/                  # Kubernetes manifests
├── aethel-scripts/       # Dev/ops shell scripts
├── docker-compose.yml    # Local dev stack
└── Makefile              # All dev/build/test/deploy commands
```

---

## License

See [NOTICE](./NOTICE) and [LICENSE](./LICENSE) for terms.
