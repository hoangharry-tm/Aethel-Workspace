# Architecture — API Route Design and Blueprint Configuration

**Audience:** Go engineers, IT administrators
**Status:** Active

Diagram: [docs/diagrams/api-route-resolution.mmd](diagrams/api-route-resolution.mmd)

---

## Design Philosophy

API routes in Aethel Core follow the same compile-time injection pattern as all other configurable elements. Each route has a set of hardcoded defaults baked into the Go binary: a pattern, an HTTP method, a handler reference, and a required permission. These defaults are production-ready and require no blueprint to function.

The `blueprints/server-routes.yaml` file is an **override layer**, not a definition layer. An IT admin who wants to rename `/api/v1/dispatches` to `/api/v1/dak/documents` edits the blueprint; they do not touch Go code. A deployment that has no `server-routes.yaml` overrides gets the default paths, default timeouts, and default rate limits.

This design has a specific consequence: every route must have a `permission` field. The blueprint loader rejects any route definition — default or override — that is missing a permission. A route with no permission check cannot exist in this system.

---

## Blueprint File Structure

The `blueprints/server-routes.yaml` file is documented in full below, and a working copy lives at `blueprints/server-routes.yaml`. This section describes the schema.

### `metadata`

```yaml
metadata:
  version: "1.0.0"
  engine_target: "aethel-core-1.x"
  strict_validation: true
```

Same structure as other blueprint files. `engine_target` identifies the minimum backend version that understands this schema.

### `global_route_defaults`

Applied to every route unless overridden at the group or route level.

```yaml
global_route_defaults:
  base_path: "/api/v1"
  timeout_ms: 10000
  rate_limit_rpm: 600
```

| Field | Type | Default | Notes |
|---|---|---|---|
| `base_path` | string | `"/api/v1"` | Prefix prepended to all route patterns. Change to `/api/v2` for a version migration. |
| `timeout_ms` | integer | `10000` | Maximum time a handler is allowed to run before the request is cancelled. |
| `rate_limit_rpm` | integer | `600` | Requests per minute per IP (unauthenticated) or per user (authenticated). |

### `route_groups`

Groups bundle related routes and allow group-level defaults to override globals.

```yaml
route_groups:
  dispatch:
    permission: "dispatch.view"
    rate_limit_rpm: 300
    routes:
      - method: GET
        pattern: "/dispatches"
        handler: "handlers.dispatch.ListInbox"
        permission: "dispatch.view"
        description: "List active inbound dispatch queue"
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `permission` | string | yes | Default permission for routes in this group. Individual routes may override. |
| `rate_limit_rpm` | integer | no | Overrides `global_route_defaults.rate_limit_rpm` for this group. |
| `routes` | list | yes | Route definitions (see below). |

### Route definition fields

| Field | Type | Required | Notes |
|---|---|---|---|
| `method` | string | yes | HTTP method: `GET`, `POST`, `PUT`, `PATCH`, `DELETE` |
| `pattern` | string | yes | URL pattern relative to `base_path` + group prefix. Supports `{param:regex}` constraints. |
| `handler` | string | yes | Dot-notation reference: `handlers.<group>.<FunctionName>`. Resolved at startup. |
| `permission` | string | yes | RBAC permission required. Blueprint loader rejects missing values. |
| `rate_limit_rpm` | integer | no | Per-route override. |
| `timeout_ms` | integer | no | Per-route override. |
| `description` | string | no | Human-readable description. Ignored at runtime. |

### `overrides`

Maps a default route pattern to a deployment-specific pattern. The Go binary uses the override value when building the chi router.

```yaml
overrides:
  - default: "/api/v1/dispatches"
    custom: "/api/v1/dak/documents"
  - default: "/api/v1/dispatches/{id:uuid}"
    custom: "/api/v1/dak/documents/{id:uuid}"
```

The override applies to the full path including `base_path`. Both the `default` and `custom` values must include the base path.

### `auth`

JWT configuration for the auth middleware.

```yaml
auth:
  jwt_algorithm: "RS256"          # HS256 | RS256
  access_token_ttl_minutes: 15
  refresh_token_ttl_days: 7
```

### `worker`

Background worker configuration.

```yaml
worker:
  escalation_tick_seconds: 60
```

---

## Path Parameter Type Constraints

Chi supports inline regex constraints on path parameters. The router validates the parameter before the handler runs; a request with an invalid parameter value receives `404 Not Found` without reaching the handler.

| Constraint syntax | What it validates | Example usage |
|---|---|---|
| `{id:uuid}` | Full UUID format (8-4-4-4-12 hex groups) | `/dispatches/{id:uuid}` |
| `{year:\d{4}}` | Exactly 4 digits | `/reports/{year:\d{4}}` |
| `{month:\d{2}}` | Exactly 2 digits | `/reports/{year:\d{4}}/{month:\d{2}}` |
| `{slug:[a-z0-9-]+}` | Lowercase alphanumeric with hyphens | `/doc-types/{slug:[a-z0-9-]+}` |

The `uuid` constraint is a named pattern registered in `api/server.go` at startup using `chi.RegisterPatternKey("uuid", "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")`. This keeps route definitions readable.

---

## Route Registry at Startup

The route registry is built in `api/server.go` during server initialization, after the blueprint is loaded. The process:

1. The hardcoded default routes are defined as a slice of `RouteDefinition` structs in the Go binary.
2. The `server-routes.yaml` blueprint is loaded and validated by `internal/blueprint/`.
3. For each route in the defaults slice, the registry checks whether an override exists in the blueprint's `overrides` section. If yes, the custom pattern replaces the default pattern.
4. Group-level and route-level `rate_limit_rpm` and `timeout_ms` overrides from the blueprint are applied.
5. Each route is validated: `permission` must be non-empty; pattern syntax must parse; handler reference must resolve to a registered function.
6. The chi router is populated: groups become sub-routers with scoped middleware; routes are registered with their (possibly overridden) patterns.
7. The RBAC middleware for each route is wired using the route's `permission` field, resolved at startup. A misconfigured permission string causes the process to exit at step 5, not at request time.

A blueprint that adds a completely new route (not in the defaults) is not supported in v1. The blueprint can only override, not extend, the default route set. This is intentional: new routes require Go code review and deployment.

---

## All Default API Routes

### Base path: `/api/v1`

#### Reception — Pillar 1 (DAK Diarization)

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| GET | `/dispatches` | `dispatch.ListInbox` | `dispatch.view` | Active inbound queue for the current user's department |
| POST | `/dispatches` | `dispatch.Create` | `dispatch.create` | Log a new inbound dispatch |
| GET | `/dispatches/{id:uuid}` | `dispatch.GetByID` | `dispatch.view` | Full dispatch detail with timeline |
| PATCH | `/dispatches/{id:uuid}/status` | `dispatch.UpdateStatus` | `dispatch.create` | Update status state |
| POST | `/dispatches/{id:uuid}/assign` | `dispatch.Assign` | `dispatch.assign` | Manually assign to a user or department |
| POST | `/dispatches/{id:uuid}/acknowledge` | `dispatch.Acknowledge` | `dispatch.deliver` | Record receipt acknowledgement |
| GET | `/dispatches/outbound` | `dispatch.ListOutbound` | `dispatch.view` | Outbound queue |
| POST | `/dispatches/outbound` | `dispatch.CreateOutbound` | `dispatch.create` | Log a new outbound dispatch |
| GET | `/dispatches/{id:uuid}/attachments` | `dispatch.ListAttachments` | `dispatch.view` | List file attachments for a dispatch |
| POST | `/dispatches/{id:uuid}/attachments` | `dispatch.UploadAttachment` | `dispatch.create` | Upload a file attachment |
| DELETE | `/dispatches/{id:uuid}/attachments/{att_id:uuid}` | `dispatch.DeleteAttachment` | `dispatch.assign` | Remove an attachment |

#### User — My Documents

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| GET | `/my-dispatches` | `dispatch.ListMyDispatches` | `workflow.view` | Dispatches assigned to the current user |
| GET | `/search` | `search.Search` | `dispatch.view` | Full-text search across dispatches |

#### Workflow — Pillar 2 (Green Noting Canvas)

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| GET | `/dispatches/{id:uuid}/minute-sheet` | `workflow.GetMinuteSheet` | `workflow.view` | Fetch the minute sheet and green note timeline |
| POST | `/dispatches/{id:uuid}/green-notes` | `workflow.AppendGreenNote` | `workflow.approve` | Append a new green note (hash chain enforced) |
| GET | `/dispatches/{id:uuid}/green-notes` | `workflow.ListGreenNotes` | `workflow.view` | List all green notes in sequence order |
| POST | `/dispatches/{id:uuid}/minute-sheet/approve` | `workflow.ApproveMinuteSheet` | `workflow.approve` | Mark the minute sheet as approved |

#### Governance — Pillar 3 (RBAC Audit Ledger)

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| GET | `/audit-log` | `governance.QueryAuditLog` | `admin.audit` | Query the audit ledger with date range and filters |
| GET | `/audit-log/verify` | `governance.VerifyChain` | `admin.audit` | Verify the checksum chain for a given date range |

#### Admin — Cross-Pillar

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| GET | `/admin/users` | `admin.ListUsers` | `admin.access` | List all users in the organization |
| POST | `/admin/users` | `admin.CreateUser` | `admin.access` | Create a new user account |
| GET | `/admin/users/{id:uuid}` | `admin.GetUser` | `admin.access` | Get user detail |
| PATCH | `/admin/users/{id:uuid}` | `admin.UpdateUser` | `admin.access` | Update user profile or role |
| DELETE | `/admin/users/{id:uuid}` | `admin.DeactivateUser` | `admin.access` | Deactivate a user account |
| GET | `/admin/document-types` | `admin.ListDocumentTypes` | `admin.access` | List document type catalogue |
| POST | `/admin/document-types` | `admin.CreateDocumentType` | `admin.access` | Create a document type |
| PATCH | `/admin/document-types/{id:uuid}` | `admin.UpdateDocumentType` | `admin.access` | Update a document type |
| DELETE | `/admin/document-types/{id:uuid}` | `admin.DeleteDocumentType` | `admin.access` | Delete a document type |
| GET | `/admin/routing-rules` | `admin.ListRoutingRules` | `admin.access` | List routing rules in priority order |
| POST | `/admin/routing-rules` | `admin.CreateRoutingRule` | `admin.access` | Create a routing rule |
| PUT | `/admin/routing-rules/{id:uuid}` | `admin.UpdateRoutingRule` | `admin.access` | Update a routing rule |
| DELETE | `/admin/routing-rules/{id:uuid}` | `admin.DeleteRoutingRule` | `admin.access` | Delete a routing rule |
| GET | `/admin/escalation-rules` | `admin.ListEscalationRules` | `admin.access` | List escalation rules |
| POST | `/admin/escalation-rules` | `admin.CreateEscalationRule` | `admin.access` | Create an escalation rule |
| PUT | `/admin/escalation-rules/{id:uuid}` | `admin.UpdateEscalationRule` | `admin.access` | Update an escalation rule |
| GET | `/admin/reports` | `admin.GetReports` | `admin.access` | Aggregated dispatch statistics |
| GET | `/admin/settings` | `admin.GetSettings` | `admin.access` | Read system settings key-value store |
| PATCH | `/admin/settings` | `admin.UpdateSettings` | `admin.access` | Update system settings |
| GET | `/admin/branding` | `admin.GetBranding` | `admin.access` | Read branding configuration |
| PUT | `/admin/branding` | `admin.UpdateBranding` | `admin.access` | Update branding configuration |

#### Auth

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| POST | `/auth/login` | `auth.Login` | `public` | Authenticate, receive access + refresh tokens |
| POST | `/auth/refresh` | `auth.Refresh` | `public` | Exchange refresh token for new access token |
| POST | `/auth/logout` | `auth.Logout` | `dispatch.view` | Revoke the current session |
| POST | `/auth/password-reset/request` | `auth.RequestPasswordReset` | `public` | Send password reset email |
| POST | `/auth/password-reset/confirm` | `auth.ConfirmPasswordReset` | `public` | Apply password reset token |

#### Notifications

| Method | Pattern | Handler | Permission | Description |
|---|---|---|---|---|
| GET | `/notifications` | `notifications.List` | `dispatch.view` | List recent notifications for the current user |
| PATCH | `/notifications/{id:uuid}/read` | `notifications.MarkRead` | `dispatch.view` | Mark a notification as read |
| GET | `/notifications/stream` | `notifications.Stream` | `dispatch.view` | SSE stream for real-time delivery |

---

## Security Constraint

The blueprint loader enforces at startup that every registered route has a non-empty `permission` field. The only exceptions are routes explicitly marked `permission: "public"` (login, refresh, password reset). A `public` route still passes through the Auth middleware, but the middleware skips the JWT requirement and allows unauthenticated access.

This constraint exists because a route that silently skips permission checking is a security defect. Making the absence of a permission a hard startup error means it cannot be introduced by accident.
