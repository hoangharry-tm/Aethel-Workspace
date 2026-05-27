# Project Guidelines

<!-- NUXT-DEVTOOLS:CRITICAL-FILES -->
## ⚠️ Critical Configuration Files

The following files trigger a full Nuxt restart when modified:
- `nuxt.config.ts`
- `nuxt.config.js`
- `app.config.ts`
- `app.config.js`
- `.nuxtrc`
- `tsconfig.json`

### 🔴 MANDATORY CHECK (EVERY TIME, NO EXCEPTIONS)

**BEFORE modifying ANY of these files, you MUST:**

```
1. READ .claude-devtools/settings.json
2. CHECK criticalFiles.autoConfirm value
3. IF false OR file missing → STOP and ASK user
4. IF true → inform user, then proceed
```

**This check is REQUIRED every single time, even if you checked before in this session.**

### Order of Operations

1. **Complete ALL prerequisite tasks FIRST**
   - Create all new files that will be referenced
   - Install all dependencies
   - Write all related code

2. **Verify prerequisites exist**
   - All files referenced in config change must exist
   - All imports must be valid

3. **Check settings file** (read `.claude-devtools/settings.json`)

4. **Act based on autoConfirm setting**

### Example: Adding i18n locale

```
Step 1: Create locales/es.json           ✓ prerequisite
Step 2: Read .claude-devtools/settings.json  ✓ check flag
Step 3: If autoConfirm=false → ask user
Step 4: Update nuxt.config.ts            ✓ only after confirmation
```

### Current Setting

**autoConfirm: DISABLED**

→ MUST ask user and WAIT for explicit "yes" before proceeding.

---
After restart, conversation history is preserved. User can send "continue" to resume.
<!-- /NUXT-DEVTOOLS:CRITICAL-FILES -->

## Runtime Configuration

Added in Phase 1.5 (2026-05-27). The platform pivoted from compile-time YAML injection to runtime-configurable defaults managed through the admin UI.

### Composable

**`app/composables/useRuntimeConfig.ts`** — `useAppRuntimeConfig()`
- Uses `useState<AppRuntimeConfig>('app-runtime-config', ...)` for SSR-safe shared state
- Exports: `config`, `isLoading`, `refresh()`, `updateBranding(partial)`, `updateOrg(partial)`, `updateFeatures(partial)`, `updateNav(groups)`
- Shape matches the planned `GET /api/v1/config` API response exactly
- Mock defaults: primaryColor `#4f46e5`, neutralPalette `slate`, fontFamily `Inter`, org name `Aethel Demo Org`, all features false

Exported types: `AppRuntimeConfig`, `NavGroup`, `NavItem`

### Block Components (`app/components/blocks/`)

Self-contained cards placeable on custom admin pages:

| Component | Props |
|---|---|
| `BlockStatCard.vue` | `title`, `value`, `icon`, `trend?`, `trendValue?` |
| `BlockDataTable.vue` | `title`, `columns`, `rows`, `emptyLabel?` |
| `BlockFormBuilder.vue` | `title`, `fields` (id, label, type, options?, required?) |
| `BlockTimeline.vue` | `title`, `events` (label, note?, timestamp, icon, color) |
| `BlockRichText.vue` | `title?`, `content`, `editable?` |
| `BlockQuickActions.vue` | `title?`, `actions` (label, icon, to?, color?) |

### Admin Pages Added/Rebuilt

| Route | File | Status |
|---|---|---|
| `/admin/branding` | `app/pages/admin/branding.vue` | Rebuilt — live color picker, font selector, logo upload, live preview panel |
| `/admin/settings` | `app/pages/admin/settings.vue` | Rebuilt — org profile, feature toggles (USwitch), DB aliases read-only |
| `/admin/navigation` | `app/pages/admin/navigation.vue` | New — nav tree editor with reorder, visibility, label rename, add item modal |
