**STATUS: COMPLETE — 2026-05-29**
Verification grep returns zero matches. TypeScript typecheck passes. Committed as `feat(frontend): migrate all Vue files to three-layer CSS semantic token system` on `dev` branch.

---

You are working in /Users/hoangharry/mh_code/internships/Bravo/aethel-workspace/aethel-view/.

Objective

Migrate all Vue files under app/ from hardcoded Tailwind palette classes to a three-layer CSS
variable-based semantic token system. Every change must be surgical — only touch color-semantic
classes. Never touch layout, spacing, sizing, typography scale, border-radius, or transition
classes.

---

The Three-Layer System

Layer 1 — app/assets/css/main.css (update in place):

Add the following block immediately after the existing :root { font-family: ... } block (before
the file ends). Do not remove the existing content:

:root {
--color-text-body: theme(colors.slate.800);
--color-text-muted: theme(colors.slate.500);
--color-text-accent: theme(colors.indigo.600);
--color-bg-surface: theme(colors.white);
--color-bg-subtle: theme(colors.slate.50);
--color-bg-subtle-2: theme(colors.slate.100);
--color-border: theme(colors.slate.200);
--color-border-faint: theme(colors.slate.100);
--color-border-muted: theme(colors.slate.300);
--color-icon-faint: theme(colors.slate.300);
--color-icon-disabled: theme(colors.slate.400);
--color-divider-line: theme(colors.slate.200);
}

@theme {
--color-body: var(--color-text-body);
--color-muted: var(--color-text-muted);
--color-accent: var(--color-text-accent);
--color-surface: var(--color-bg-surface);
--color-subtle: var(--color-bg-subtle);
--color-subtle-2: var(--color-bg-subtle-2);
--color-border-base: var(--color-border);
--color-border-faint: var(--color-border-faint);
--color-border-muted: var(--color-border-muted);
--color-icon-faint: var(--color-icon-faint);
--color-icon-disabled: var(--color-icon-disabled);
--color-divider: var(--color-divider-line);
}

Layer 2 — app/app.vue (update in place). Replace current content with:

  <script setup lang="ts">
  const { config } = useAppRuntimeConfig()

  useHead({
    style: [
      {
        innerHTML: computed(
          () => `:root {
    --color-text-accent: ${config.value.branding.primaryColor};
    --ui-primary: ${config.value.branding.primaryColor};
  }`,
        ),
      },
    ],
  })
  </script>

  <template>
    <NuxtRouteAnnouncer />
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </template>

Layer 3 — Component files: apply the semantic token mapping table below to every .vue file listed
in the audit section.

---

Semantic Token Mapping Table

Text colors

┌─────────────────┬──────────────────────┐
│ Hardcoded class │ Semantic replacement │
├─────────────────┼──────────────────────┤
│ text-slate-800 │ text-body │
├─────────────────┼──────────────────────┤
│ text-slate-900 │ text-body │
├─────────────────┼──────────────────────┤
│ text-slate-700 │ text-body │
├─────────────────┼──────────────────────┤
│ text-slate-600 │ text-muted │
├─────────────────┼──────────────────────┤
│ text-slate-500 │ text-muted │
├─────────────────┼──────────────────────┤
│ text-slate-400 │ text-icon-disabled │
├─────────────────┼──────────────────────┤
│ text-slate-300 │ text-icon-faint │
├─────────────────┼──────────────────────┤
│ text-slate-200 │ text-icon-faint │
├─────────────────┼──────────────────────┤
│ text-indigo-600 │ text-accent │
├─────────────────┼──────────────────────┤
│ text-indigo-700 │ text-accent │
└─────────────────┴──────────────────────┘

Background colors

┌─────────────────┬──────────────────────┐
│ Hardcoded class │ Semantic replacement │
├─────────────────┼──────────────────────┤
│ bg-white │ bg-surface │
├─────────────────┼──────────────────────┤
│ bg-slate-50 │ bg-subtle │
├─────────────────┼──────────────────────┤
│ bg-slate-100 │ bg-subtle-2 │
├─────────────────┼──────────────────────┤
│ bg-slate-200 │ bg-divider │
├─────────────────┼──────────────────────┤
│ bg-indigo-600 │ bg-accent │
├─────────────────┼──────────────────────┤
│ bg-indigo-500 │ bg-accent │
├─────────────────┼──────────────────────┤
│ bg-indigo-100 │ bg-accent/10 │
├─────────────────┼──────────────────────┤
│ bg-indigo-50 │ bg-accent/5 │
├─────────────────┼──────────────────────┤
│ bg-indigo-50/50 │ bg-accent/5 │
└─────────────────┴──────────────────────┘

Border colors

┌───────────────────┬──────────────────────┐
│ Hardcoded class │ Semantic replacement │
├───────────────────┼──────────────────────┤
│ border-slate-100 │ border-border-faint │
├───────────────────┼──────────────────────┤
│ border-slate-200 │ border-border-base │
├───────────────────┼──────────────────────┤
│ border-slate-300 │ border-border-muted │
├───────────────────┼──────────────────────┤
│ border-indigo-600 │ border-accent │
├───────────────────┼──────────────────────┤
│ border-indigo-500 │ border-accent │
├───────────────────┼──────────────────────┤
│ border-indigo-300 │ border-accent/50 │
├───────────────────┼──────────────────────┤
│ border-indigo-100 │ border-accent/20 │
└───────────────────┴──────────────────────┘

Do NOT touch

- Nuxt UI component props: color="primary", color="gray", etc.
- Urgency/status colors: rose-_, amber-_, emerald-_, sky-_, violet-\*
- ring-_, shadow-_, opacity-\*
- All structural classes (flex, grid, p-, m-, w-, h-, rounded-, text-sm, font-, etc.)

---

Files to Audit

Process in this order:

Layout: app/components/layout/WorkspaceSidebar.vue, WorkspaceNavbar.vue, NotificationDrawer.vue
Shared: app/components/shared/EventTimeline.vue
Blocks: app/components/blocks/BlockStatCard.vue, BlockDataTable.vue, BlockFormBuilder.vue,
BlockQuickActions.vue, BlockRichText.vue, BlockTimeline.vue
Layouts: app/layouts/auth.vue, app/layouts/workspace.vue
Pages: app/pages/auth/login.vue, dashboard.vue, dispatch/inbound/index.vue,
dispatch/inbound/new.vue, dispatch/outbound/index.vue, documents/[id].vue, my-documents.vue,
outgoing/new.vue, search.vue, admin/audit-log.vue, admin/branding.vue, admin/document-types.vue,
admin/escalation.vue, admin/navigation.vue, admin/reports.vue, admin/routing-rules.vue,
admin/settings.vue, admin/users.vue

---

Execution Order

1. Update app/assets/css/main.css
2. Read aethel-view/.claude-devtools/settings.json — if criticalFiles.autoConfirm is false, ask
   before touching app/app.vue
3. Update app/app.vue
4. Process every file in the audit list — read each file fully before editing

---

Verification

# Must return zero matches

grep -rn
"text-slate\|text-gray\|text-indigo\|bg-white\|bg-slate\|bg-gray\|border-slate\|border-indigo"
app/ --include="_.vue" --include="_.ts" --include="\*.css"

# Must pass with zero errors

pnpm exec nuxi typecheck

Report any files that required special handling (dynamic class expressions, etc.) and confirm the
final grep is clean.
