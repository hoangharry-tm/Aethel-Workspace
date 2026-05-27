# Task 4: Changes In The Platform Direction

<!--toc:start-->

- [Task 4: Changes In The Platform Direction](#task-4-changes-in-the-platform-direction)
  - [Who you are?](#who-you-are)
  - [What are your tasks?](#what-are-your-tasks)
  - [Desired output](#desired-output)
  - [Task Status & TODO list](#task-status-todo-list)
  <!--toc:end-->

@CLAUDE.md for context of the new direction

## Who you are?

Be an experienced, senior software engineer and software architect. You should
know in and out of the technology, knowing the tricks for performance or knowing
how to avoid common pitfalls. You also know how to coordinate works, define tasks,
and work efficiently to deliver best quality deliverable.

## What are your tasks?

Dispatch subagents in parallel.

1. NuxtJS (VueJS) software enginner, from the @CLAUDE.md you know there are changes
   in the technical direction. I want you to do these things to reflect and adapt
   to new changes:
   - Before, we approach the biz requirements by "compile-time injection" but now
     we choose "runtime-configurable with runtime-defaults". Therefore, we will
     slim away the @blueprints folder with YAML files and replace it with an
     `admin/` route in our frontend app for IT admin to work on. This page will
     have connection with the backend services and the database that stores both
     the FE and BE configurations.
     Based on this, do this sequentially: create a new UI/UX designer subagents,
     learn about the project's current design and approach, create the new admin
     page using the claude skills available. Then, create this new page in our
     `aethel-view` application.
   - From the new admin page, output it to Figma for further adjustments.
   - Update related docs regarding the frontend developments, for example, the
     design style or mindset approach or even how the codebase conventions change.
2. System and Software enginner/architect. Redesign the affected parts of the
   project due to changing in approach. It could be the database design (e.g.,
   have to create new schema or new tables to store the configurations), the
   API design (e.g., adding routes, or adding more security measures), the
   diagrams or documents, or even the Golang conventions/rules/approachs that we
   defined for this codebase. Every single part of the backend project is proned
   to being changed (even the sql migration scripts, etc.), therefore, scan carefully.

After you finish, report what you did, which file did you modified, created, or
deleted. Let me know what you have researched in 1 sentence and your rationale
in 1 sentence.

## Desired output

- For the frontend, the project should adapt to these new changes, including
  functions or components or styles.
- A new admin page design in Figma with styles inherit from the project's current
  design code. Then the new functional admin page in the frontend project.
- All docs related to the frontend must be changed.
- For the backend docs, it should have the new section designing and explaining
  how the clients would get the layout or cache. I also want to see how the API
  routes and how is the data flow processed from the client to server then back
  to client. If there's a better way than 2-way HTTP trips for the frontend page.
  Propose you design and how would the project change to adapt to it.
- Diagrams in mermaid. Clean up the @docs folder, create child folders to store
  respective docs.
- Regarding the backend, I want the docs, the database layer (sql queries or migration
  scripts, etc.), the golang conventions and implementation docs to change.
- Finally, the DevOps pipeline also have to adapt to this new change.
- Create a todo list in this file and update it to share the status across multiple
  parallel subagents.

## Task Status & TODO list

> Agents: check this list before starting. Mark your item `[x]` when done.
> Two agents run in parallel: **FE** (frontend-engineer) and **ARCH** (architecture/docs).

### Frontend (Agent FE)

- [x] FE-01 Create `app/composables/useRuntimeConfig.ts` — SWR-cached config composable (mock data, API-ready shape)
- [x] FE-02 Create block components in `app/components/blocks/`: BlockDataTable, BlockStatCard, BlockFormBuilder, BlockTimeline, BlockRichText, BlockQuickActions
- [x] FE-03 Rebuild `app/pages/admin/branding.vue` — live color pickers, font selector, logo upload, live preview panel
- [x] FE-04 Rebuild `app/pages/admin/settings.vue` — org profile, feature toggles, DB naming read-only display
- [x] FE-05 Create `app/pages/admin/navigation.vue` — nav tree editor (reorder, visibility, label rename per role)
- [x] FE-06 Update `WorkspaceSidebar.vue` to consume useRuntimeConfig for nav (hardcoded fallback)
- [x] FE-07 Add "Navigation" item to Administration group in WorkspaceSidebar
- [x] FE-08 Update `aethel-view/CLAUDE.md` and root `CLAUDE.md` frontend section to document new components/composables
- [ ] FE-09 Export new admin pages to Figma (invoke `/figma-generate-design` skill first) — SKIPPED: no Figma skill available in this agent context

### Architecture / Docs (Agent ARCH)

- [x] ARCH-01 Delete `blueprints/server-routes.yaml`
- [x] ARCH-02 Move `blueprints/server-queries.yaml` → `aethel-core/internal/database/queries/queries.yaml`
- [x] ARCH-03 Slim `blueprints/ui-theme.yaml` to branding seed only (primary color, neutral, font, logo path)
- [x] ARCH-04 Gut `blueprints/ui-components.yaml` to block registry only (6 block type definitions)
- [x] ARCH-05 Slim `blueprints/ui-layouts.yaml` to nav seed + role gating only (remove page registry detail, layout classes)
- [x] ARCH-06 Create docs subdirectories: `docs/architecture/`, `docs/guides/`, `docs/plans/`, `docs/devops/`
- [x] ARCH-07 Move existing doc files into subdirectories; update all cross-references
- [x] ARCH-08 Write migration 21 UP/DOWN: ALTER TABLE branding_configs ADD neutral_palette, font_family, wordmark
- [x] ARCH-09 Update `docs/architecture/architecture-api-routes.md` — remove server-routes.yaml refs; document config API endpoints
- [x] ARCH-10 Update `docs/architecture/architecture-server.md` — add SSR config fetch flow (Nuxt SSR → Go /api/v1/config → in-memory cache → embedded in HTML)
- [x] ARCH-11 Create `docs/diagrams/runtime-config-flow.mmd` — end-to-end config data flow diagram
- [x] ARCH-12 Update `docs/plans/agile-implementation-plan.md` — add config API endpoints to Sprint 2; add seed loader to Sprint 1
- [x] ARCH-13 Update `docs/guides/go-developer-guide.md` — remove routes blueprint section; add config endpoint patterns (section 11)
- [x] ARCH-14 Update `.github/workflows/ci.yml` — no change needed (yamllint runs on `blueprints/` directory, not explicit file list)
- [x] ARCH-15 Update `docs/CONVENTIONS.md` — new file index with subdirectory paths and subdirectory organization section
- [x] ARCH-16 Update root `CLAUDE.md` — blueprint status table, architecture description (compile-time → runtime-configurable), updated reference doc paths
