# Task 3: Detailed Foundational Software Engineering

<!--toc:start-->

- [Task 3: Detailed Foundational Software Engineering](#task-3-detailed-foundational-software-engineering)
  - [1. Who you are?](#1-who-you-are)
  - [2. What are your tasks?](#2-what-are-your-tasks)
  - [3. Desired outputs](#3-desired-outputs)
  <!--toc:end-->

Read all the docs about this project. Get the context, understand the requirements
before move on.

## 1. Who you are?

You are an experienced, senior software architect and familiar with designing
complex system for handling large operations, especially the database. Learn
all of the best practices from the largest technology companies like Meta,
Google, Amazon, Netflix, Paypal, etc.

You know these things extremely well:

- Golang
- Postgresql
- NuxtJS (VueJS)

You should know how to setup, tricks to optimize them, and how to design smartly.
Knowing that this project, though it is open-sourced, it might be used by a
variety of team scales: small-medium-large-super large. Therefore, the system
design besides being modern and the technology besides following the newest
trends, still has to satisfy these conditions:

- It has to work flawlessly, no matter the scale of the team. Which means, not
  only it has to work for a 5-people team, it also has to work for an 100-people
  company or even more than that.
- It is easy to use, and most importantly, easy to spot and debug the code. Hence,
  for all the code that you write in this project, it has to center around these
  keywords: clean, clear, concise, D.R.Y, modular, uniform, and logically correct.
  Moreover, handle all scenario, detect and exit early whenever possible.
- After finishing coding, run the code, fix the bugs as well as satisfy all
  linter or formatter requirements

## 2. What are your tasks?

Dispatch and coordinate subagents smartly. You assign roles, and number of
subagents in the best way. Here are the tasks I want you to do:

- Organize and plan the conventions for the @docs folder, avoid cluttering the
  codebase with docs.
- Research and propose the backend architecture of this project. Using
  the mermaid `.mmd` files to illustrate your design and write your rationale
  in a markdown file. Your design should demonstrate the following things, note
  that the 'i.e.' is just recommendation of what you should have, not restrictions.
  Thus, you can and you should expand more if it's possible. Only write docs,
  do not write code until I approve your designs and approach.
  - The architecture of the project (i.e., what is the code design pattern, how
    to structure the package or the codebase)
  - The architecture of the server (i.e., the components of the system, how they
    interact, and what is the flow of data or requests)
  - Since we provide a solution to general public (i.e., both individuals and
    businesses) we have to limit the use of 3rd party providers (e.g., supabase,
    etc.) and we have to leave those as options, not requirements. Propose
    security measures that we can provide and embed in our platform for the
    developers to adopt, config, and use.
  - The API routes that will be available. I want the API routes to also be
    available for configurations in the YAML files in @blueprints/ . We could
    have a default routes then only when the user provide configurations, we
    switch to the user's. The config field for the API routes has to have a
    special mechanism to handle dev's parameters or regex match cases.
  - Consolidate how the communication between the server's services and the DB
    should be when our approach is unique.
- DevOps pipelines, you're allowed to write the code or configurations necessary
  for the pipelines. Create respective folders if needed, following the best
  practices of that technology.
  - For the own sake of myself in this project, I want to adopt Docker, Kubernetes,
    and GitHub Workflow for the CI/CD of this project.
  - Research and suggest other DevSecOps toolings that help with the development
    and running of this project. It should provide a convenient, uniform, and
    easy development of the project, not only for the contributors but also for
    future users adopting this platform.
  - Write shell scripts or Makefile to run commands like rolling up FE + BE
    containers or rolling down services or monitoring services, etc. Consider
    all possible scenario that may happen during the process of developing this
    platform to write the scripts. Some examples of this might be a script to
    run build commands or running in dev mode or many other things.

## 3. Desired outputs

- @docs folder conventions in a file that's easy to spot
- Mermaid files to display diagram of all of the designs, from system designs to
  HTTP flow, to DevOps diagram.
- Detailed markdown docs of the design rationale, the technical decisions and choices.
- Provide a concise and scientific agile plan of implementation for the golang
  backend.
- A clear and ready DevOps pipeline. Setup important technology first, for the
  remaining, you can provide a skeleton then write a TODO list of tasks that are
  left to be done.
- Update your status in this file and update @CLAUDE.md or related documents for
  future session. Report back to me what you did and the files that you have
  modified, created, or deleted.

---

## Status: COMPLETE — 2026-05-26

### Docs created

| File | Purpose |
|---|---|
| `docs/CONVENTIONS.md` | Docs folder organization rules, naming conventions, full file index |
| `docs/architecture-code.md` | Package layout, Clean Architecture rationale, dependency rules, DI pattern |
| `docs/architecture-server.md` | Server components, 9-step middleware stack, JWT/SSE/worker/health design |
| `docs/architecture-api-routes.md` | API route blueprint design, path constraints, 50+ real routes documented |
| `docs/architecture-security.md` | Argon2id, JWT, CSRF, rate limiting, audit chain, secrets policy |
| `docs/agile-implementation-plan.md` | 7-sprint plan (Sprint 0–6), each with Goal/Deliverables/DoD/Dependencies |
| `docs/devops-tooling.md` | DevSecOps recommendations: registry, observability, scanning, secrets |

### Diagrams created

| File | Type |
|---|---|
| `docs/diagrams/architecture-overview.mmd` | `flowchart LR` — system overview |
| `docs/diagrams/architecture-code.mmd` | `flowchart TD` — package dependency graph |
| `docs/diagrams/server-request-flow.mmd` | `sequenceDiagram` — HTTP lifecycle through 9-step middleware chain |
| `docs/diagrams/api-route-resolution.mmd` | `flowchart TD` — startup route registry resolution |
| `docs/diagrams/devops-pipeline.mmd` | `flowchart LR` — CI/CD pipeline and production K8s infrastructure |

### Blueprint created

| File | Purpose |
|---|---|
| `blueprints/server-routes.yaml` | New: API route configuration (defaults + override mechanism + regex params) |

### DevOps created

| File | Purpose |
|---|---|
| `Makefile` | 30 targets: dev/build/test/lint/database/k8s/utilities |
| `docker-compose.yml` | Local dev: postgres + backend + frontend |
| `docker-compose.prod.yml` | Production overrides: limits, internal network, no volume mounts |
| `.env.example` | All required env vars with safe dev defaults |
| `aethel-view/Dockerfile` | 2-stage Nuxt production image (node:20-alpine) |
| `aethel-core/Dockerfile` | 2-stage Go distroless image (golang:1.23-alpine → distroless) |
| `k8s/namespace.yaml` | Namespace: aethel-workspace |
| `k8s/postgres/` | StatefulSet, Service, Secret placeholder (20Gi PVC) |
| `k8s/backend/` | Deployment, HPA (2–10 replicas), ConfigMap, Secret placeholder |
| `k8s/frontend/` | Deployment, HPA, Service |
| `k8s/ingress.yaml` | nginx ingress: /api → backend, / → frontend, TLS ready |
| `.github/workflows/ci.yml` | Parallel: test-backend + test-frontend + lint-yaml |
| `.github/workflows/cd.yml` | Build + push GHCR → deploy staging; workflow_dispatch for prod |
| `.github/workflows/security.yml` | Trivy + govulncheck + gosec → GitHub Security tab (weekly) |
| `aethel-scripts/setup-dev.sh` | First-time dev environment setup |
| `aethel-scripts/health-check.sh` | Verify all services running |
| `aethel-scripts/rotate-jwt-secret.sh` | JWT secret rotation checklist |
| `aethel-scripts/db-backup.sh` | pg_dump + gzip + optional S3 upload |
| `aethel-scripts/k8s-rollout.sh` | Production: migrate-then-rollout coordinator |

### Modified

| File | Change |
|---|---|
| `CLAUDE.md` | Updated Phase 2 status; added DevOps layout section; expanded reference docs table |
| `docs/CONVENTIONS.md` | Added devops-tooling.md and devops-pipeline.mmd to index |

### Next step

Task 03 is complete. Go implementation begins with Sprint 0 (see `docs/agile-implementation-plan.md`). Approval required before writing Go code.
