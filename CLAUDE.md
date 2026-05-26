# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aethel Workspace is a configuration-driven e-office platform. Its defining architectural trait is **compile-time injection**: YAML blueprints are baked into the binary at build time rather than loaded at runtime. IT admins edit blueprints to restyle, restructure, or reconfigure the system without touching source code.

The system is organized around three domain pillars:
1. **DAK Diarization** — inbound correspondence intake and tracking
2. **Green Noting Canvas** — institutional minute sheets and approval workflows
3. **RBAC Audit Ledger** — immutable security event log with tamper detection

## Repository Layout

```
aethel-view/        # Nuxt 4 frontend — UI/UX prototype COMPLETE (Phase 1 done)
aethel-core/        # Go backend — scaffolded, currently empty (Phase 2)
aethel-scripts/     # Build scripts — scaffolded, currently empty
blueprints/         # Declarative YAML configuration files (see Blueprint Status below)
  examples/         # Reference blueprints (do not edit — source of truth for schema)
build/bin/          # Compiled output
```

## Current Phase Status

**Phase 1 — UI/UX Prototype**: Complete as of 2026-05-25.
- 17 pages, 20 user stories, 3 roles (ADMIN / RECEPTION / USER), 0 TypeScript errors
- Figma design export complete: file key `aqW7snNu6m0RoD0ZXrMH0f` (5 pages: Design System, Login, Dashboard, Intake Form + Document Detail, Mobile + Admin)

**Phase 2 — Go Backend** (`aethel-core/`): Database design complete as of 2026-05-26. Migration SQL written; Go implementation not yet started.

## Frontend — `aethel-view/`

**Stack**: Nuxt 4 (`compatibilityDate: "2025-07-15"`), Vue 3, Pinia, Nuxt UI v4 (`@nuxt/ui` 4.8.0 / Tailwind CSS v4), TypeScript

All frontend commands run from `aethel-view/`:

```bash
pnpm dev            # Dev server at http://localhost:3000
pnpm build          # Production build
pnpm preview        # Preview production build

pnpm test           # All Vitest tests (unit + nuxt)
pnpm test:unit      # Unit tests only (test/unit/*.spec.ts, Node env)
pnpm test:nuxt      # Nuxt component tests (test/nuxt/*.spec.ts, happy-dom env)
pnpm test:coverage  # Tests with V8 coverage

pnpm test:e2e       # Playwright E2E (tests/*.spec.ts, Chromium)
pnpm test:e2e:ui    # Playwright with interactive UI
```

No lint script defined; ESLint via `eslint.config.mjs` (extends `.nuxt/eslint.config.mjs`). Test projects are named `unit` and `nuxt` — use `--project unit` or `--project nuxt` to target one.

### Critical config files

`aethel-view/CLAUDE.md` (auto-managed by `@oro.ad/nuxt-claude-devtools`) documents a **mandatory check** before modifying `nuxt.config.ts`, `app.config.ts`, or any other Nuxt restart-triggering file. Always read `.claude-devtools/settings.json` first. **autoConfirm is currently DISABLED** — stop and ask the user before touching those files.

### Design System

- **Primary**: Indigo (`indigo-600` = `#4f46e5`) — set via `app.config.ts` `ui.colors.primary: 'indigo'`
- **Neutral**: Slate — set via `ui.colors.neutral: 'slate'`
- **Font**: Inter (Google Fonts, imported in `app/assets/css/main.css`)
- **Mode**: Light only
- **Icons**: Lucide via `i-lucide-*` Iconify notation (no emoji icons)
- **Urgency colors**: IMMEDIATE → rose, PRIORITY → amber, ROUTINE → emerald
- **Document status colors**: PENDING_ASSIGNMENT → neutral, UNDER_REVIEW → primary/indigo, IN_TRANSIT → sky, ATTEMPTED_DELIVERY → amber, DELIVERED → emerald, ESCALATED → rose, DISPATCHED → violet

### Page Structure

All pages use either `layout: 'workspace'` or `layout: 'auth'`. The workspace layout (`app/layouts/workspace.vue`) is a fixed `h-dvh` shell: `WorkspaceSidebar` (left) + topbar `WorkspaceNavbar` + scrollable `<main>` + `NotificationDrawer` (right portal).

| Route | File | Roles |
|---|---|---|
| `/` | `pages/index.vue` | all (redirects to `/dashboard`) |
| `/auth/login` | `pages/auth/login.vue` | public |
| `/dashboard` | `pages/dashboard.vue` | RECEPTION |
| `/dispatch/inbound` | `pages/dispatch/inbound/index.vue` | RECEPTION |
| `/dispatch/inbound/new` | `pages/dispatch/inbound/new.vue` | RECEPTION |
| `/dispatch/outbound` | `pages/dispatch/outbound/index.vue` | RECEPTION |
| `/documents/[id]` | `pages/documents/[id].vue` | all |
| `/my-documents` | `pages/my-documents.vue` | USER |
| `/outgoing/new` | `pages/outgoing/new.vue` | USER |
| `/search` | `pages/search.vue` | all |
| `/admin/users` | `pages/admin/users.vue` | ADMIN |
| `/admin/routing-rules` | `pages/admin/routing-rules.vue` | ADMIN |
| `/admin/document-types` | `pages/admin/document-types.vue` | ADMIN |
| `/admin/escalation` | `pages/admin/escalation.vue` | ADMIN |
| `/admin/audit-log` | `pages/admin/audit-log.vue` | ADMIN (sys_admin) |
| `/admin/reports` | `pages/admin/reports.vue` | ADMIN |
| `/admin/settings` | `pages/admin/settings.vue` | ADMIN |
| `/admin/branding` | `pages/admin/branding.vue` | ADMIN |

### Components

**Layout** (`app/components/layout/`):
- `WorkspaceSidebar.vue` — collapsible (`w-64`/`w-16`), role-gated nav groups, active state with indigo-50 bg + 3px left accent bar; mobile via `USlideover` + `useSidebarDrawer`
- `WorkspaceNavbar.vue` — 56px topbar; profile dropdown with role switcher (ADMIN / RECEPTION / USER) for prototype demo; notification bell opens `useNotificationDrawer`
- `NotificationDrawer.vue` — `USlideover` from right, w-96; unread items styled with `border-l-2 border-indigo-500 bg-indigo-50/50`

**Shared** (`app/components/shared/`):
- `UrgencyBadge.vue` — `UBadge` wrapping IMMEDIATE/PRIORITY/ROUTINE with color/icon from blueprint
- `DocumentStatusBadge.vue` — `UBadge` for all 7 status states
- `EventTimeline.vue` — vertical step list with colored dot + connector line; read-only audit trail

### Composables

- `useMockData()` — `useState`-backed shared state; exports `currentUser` (switchable via `setRole(role)`), `documents` (10 records), `notifications` (5), `routingRules` (5), `users` (8). Default user on load: Marcus Webb (RECEPTION). Role map: ADMIN → Alice Thornton, RECEPTION → Marcus Webb, USER → Priya Sharma.
- `useNotificationDrawer()` — `useState('notif-drawer')` boolean; exposes `open()`, `close()`, `toggle()`
- `useSidebarDrawer()` — same pattern for mobile sidebar

## Blueprint System

| File | Status |
|---|---|
| `blueprints/ui-theme.yaml` | **FILLED** — indigo/slate palette, urgency + status color maps, surface tokens, type scale, animation tokens |
| `blueprints/ui-components.yaml` | **FILLED** — 7 components: urgency_badge, document_status_badge, queue_card, event_timeline, intake_form, notification_item, routing_rule_row |
| `blueprints/ui-layouts.yaml` | **FILLED** — auth + workspace + document_examiner layouts, full nav tree, 17-route page registry |
| `blueprints/server-database.yaml` | **FILLED** — connection, pooling, schema aliases, partitioning, extensions, performance guardrails. JSON Schema at `blueprints/schemas/server-database.schema.json`. |
| `blueprints/server-queries.yaml` | stub — placeholder queries present; full queries to be added in Phase 2. JSON Schema at `blueprints/schemas/server-queries.schema.json`. |

`blueprints/examples/` holds reference schemas — do not modify; they are the canonical source for future blueprint authors.

`blueprints/schemas/` holds JSON Schema files for editor validation (`yaml-language-server` modeline is set at the top of each blueprint file so Neovim/VS Code validates against the project's own schema, not SchemaStore's "Quali Torque" schema which falsely matches `**/blueprints/**.yaml`).

## Go Backend — `aethel-core/`

**Stack**: Go (to be scaffolded), PostgreSQL 16+

### Database layout

```
aethel-core/
└── internal/
    └── database/
        ├── migrator.go           # (to be written) blueprint-rendered migration runner
        ├── blueprint_context.go  # (to be written) T(), E(), Schema template helpers
        └── migrations/           # 40 SQL files (20 up + 20 down) — WRITTEN ✓
```

### Migration system

Migrations use Go `text/template` syntax for customisable identifiers:
- `{{ .Schema }}` → resolves to `schema.default_schema` from the blueprint
- `{{ T "tablename" }}` → resolves canonical name through `schema.name_aliases`
- `{{ E "enumname" }}` → resolves canonical name through `schema.enum_aliases`

Run from `aethel-core/` (commands pending Go CLI scaffold):
```bash
aethel migrate up          # apply all pending migrations
aethel migrate status      # list applied / pending
aethel migrate validate    # dry-run: render templates, check SQL syntax
aethel migrate down --steps 1   # roll back last migration
```

### Database schema (20 tables, 3 pillars)

ER diagram: `docs/db-design.mmd` — open with any Mermaid renderer.

| Migration | Tables / Objects |
|---|---|
| 01 | Extensions: uuid-ossp, pgcrypto, pg_trgm |
| 02 | `organizations` (tenant root) |
| 03 | `departments` (self-referencing hierarchy) |
| 04 | `users`, `user_sessions`, `password_reset_tokens`, `notification_preferences`; enum: `user_role` |
| 05 | `document_types` |
| 06 | `dispatches`; enums: `priority_level`, `dispatch_status` |
| 07 | `dispatch_attachments` |
| 08 | `dispatch_events` (unified timeline log for US-14) |
| 09 | `routing_rules` |
| 10 | `routing_rule_conditions` |
| 11 | `routing_rule_destinations` |
| 12 | `minute_sheets` (Pillar 2) |
| 13 | `green_notes` (Pillar 2 — cryptographic chain) |
| 14 | `notifications` |
| 15 | `escalation_rules` |
| 16 | `system_settings` (key-value store) |
| 17 | `branding_configs` |
| 18 | `audit_ledger` (Pillar 3 — PARTITION BY RANGE monthly) |
| 19 | Pre-provisioned audit_ledger monthly partitions (12 back, 3 ahead) |
| 20 | `set_updated_at()` function + triggers on all `updated_at` tables |

### Key schema decisions

- **Multi-tenancy**: `organization_id uuid` on every table; RLS to be added in a future migration once the Go layer is ready.
- **Audit ledger**: `bigserial` PK (not UUID) for partition performance; `organization_id` is a plain `uuid` (not FK) so records survive org deletion; `previous_checksum` chains rows for tamper detection.
- **Green notes**: Immutable after insert — no `updated_at`. `cryptographic_hash = SHA-256(content || sequence || author)`, `previous_hash` links to prior note.
- **Dispatch events**: Single `dispatch_events` table aggregates all timeline events (routing, handoff, escalation) — avoids multi-table UNIONs in the timeline view.

### Reference docs

| Document | Location |
|---|---|
| ER diagram | `docs/db-design.mmd` |
| Blueprint YAML conventions | `docs/server-blueprint-conventions.md` |
| Migration system design | `docs/migration-strategy.md` |
| IT customisation guide | `docs/it-customization-guide.md` |

## Key Domain Concepts

- **Dispatch** (`dispatches` table) — a tracked inbound/outbound correspondence item with `priority_level` (`ROUTINE` / `PRIORITY` / `IMMEDIATE`) and `status_state`
- **Minute Sheet + Green Notes** — each dispatch has one minute sheet; green notes are appended sequentially with cryptographic hashes and optional digital signatures
- **Audit Ledger** — append-only, monthly range-partitioned table; `sys_admin` role required to view; tamper events include `SECURITY_BREACH_ATTEMPT`, `UNAUTHORIZED_ACCESS_BYPASSED`, `RBAC_ELEVATION_ATTEMPT`
- **RBAC** — permissions are hierarchical (`dispatch.view`, `workflow.approve`, `archive.view`); some routes additionally check `required_role: "sys_admin"`

## Nuxt Configuration Notes

- `compatibilityDate: "2025-07-15"` — uses Nuxt 4 behavior
- Active modules: `@nuxt/ui`, `@pinia/nuxt`, `@nuxt/eslint`, `@nuxt/image`, `@nuxt/a11y`, `@nuxt/scripts`, `@nuxt/test-utils`, `@nuxtjs/mcp-toolkit`, `@oro.ad/nuxt-claude-devtools`
- `app.config.ts` sets `ui.colors.primary = 'indigo'` and `ui.colors.neutral = 'slate'`
- `nuxt.config.ts` adds `css: ['~/assets/css/main.css']` for Inter font import
