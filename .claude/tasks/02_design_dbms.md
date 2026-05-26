# Task 2: Design DBMS for Aethel-Workspace

<!--toc:start-->
- [Task 2: Design DBMS for Aethel-Workspace](#task-2-design-dbms-for-aethel-workspace)
  - [1. Who you are?](#1-who-you-are)
  - [2. What are your tasks?](#2-what-are-your-tasks)
  - [3. Desired outputs](#3-desired-outputs)
  - [4. Status](#4-status)
<!--toc:end-->

Read @CLAUDE.md and @docs/E-Office_Use_Cases.docx for context of the project.

## 1. Who you are?

You are an experienced, senior software architect and familiar with designing
complex system for handling large operations, especially the database. You
know these things extremely well:

- Postgresql
- Golang
- NuxtJS (VueJS)

You should know how to setup, tricks to optimize them, and how to design smartly.

## 2. What are your tasks?

This project has a special requirement: customizability. Every migration script,
or query or even the UI has to be able to changed by the IT department. Thus,
these configurations has to be centralized at @blueprints/ folder. Reading the
documents, I want you to do these following things. Fan out subagents smartly.

- Research and propose the topology or the design of the database (i.e., schema,
tables, functions, or procedures). Knowing that this project is subject to be
used not only by individuals or small teams/companies but also corporations or
large scale operations. Design the Postgresql DBMS smartly, following best
practices, the atomic of the data, smart relationships between tables, etc.
- Since we will use YAML configurations files for this project, research and
propose possible tags or fields for the developers to define and config. I want
you to do 2 things, examples could be found at @blueprints/examples though they
seem wrong in terms of YAML rules.
  - Write the conventions for two files @blueprints/server-database.yaml and
  @blueprints/server-queries.yaml (i.e. the YAML tags or fields) into a technical
  documents.
  - Write this project configurations into @blueprints/server-database.yaml
  following the YAML file rules and conventions. This file should define the
  configurations of how the Postgresql database should be running. Do not define
  the tables yet in this file, even though the example file has it.
  - Wait for the database design to be finished and have my approval, think of
  a way to write migration scripts that is customizable (e.g. easy to change the
  name of schema, or tables, or the columns, or even adding or removing columns).
  Whatever it is, all configurations has to be in the @blueprints folder and
  it should promote easiness of use and good developer experience.

## 3. Desired outputs

- The design of tables should be in the mermaid file `.mmd` erDiagram format
- Technical documents outline the conventions, YAML fields and tags for these
configurations files @blueprints/server-database.yaml and
@blueprints/server-queries.yaml
- Have a clear, well-designed configurations files ready to run in dev environment
- Have a clever design in how migration scripts work and it's clean, easy to
customize.

## 4. Status — COMPLETE ✓

All deliverables produced as of 2026-05-26:

| Output | File | Notes |
|---|---|---|
| ER diagram | `docs/db-design.mmd` | 20 tables, Mermaid erDiagram format |
| Blueprint conventions | `docs/server-blueprint-conventions.md` | Fields for both server-database.yaml and server-queries.yaml |
| Migration strategy | `docs/migration-strategy.md` | Blueprint-rendered SQL template approach |
| IT customisation guide | `docs/it-customization-guide.md` | 7-phase walkthrough for new IT admins |
| Database config | `blueprints/server-database.yaml` | dev/staging/prod environments, yamllint clean |
| Queries stub | `blueprints/server-queries.yaml` | Placeholder queries, yamllint clean |
| JSON schemas | `blueprints/schemas/*.schema.json` | Fixes Neovim yamlls false positives from Quali Torque SchemaStore match |
| Migration SQL | `aethel-core/internal/database/migrations/` | 40 files (20 up + 20 down), migrations 01–20 |

**Next step**: Scaffold `aethel-core/` Go module, implement `migrator.go` and
`blueprint_context.go`, then run `aethel migrate up` against a local PostgreSQL
instance to verify all 20 migrations apply cleanly.
