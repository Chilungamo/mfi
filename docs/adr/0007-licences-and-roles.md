# ADR 0007 — Licence tags, API keys and database roles

**Status:** Accepted · 2026-10-06

## Context

Guide §2 and §10 enforce access rules in the database: separate login roles, licence tags on
data, API keys stored as hashes, and later row-level security on marts.

## Decision

**Licence tags.** A domain `ref.license_tag` with values `public`, `research_only`,
`licensed_internal` (e.g. newspaper-derived) and `permission_pending`.

* Set on `source.source_organization`, **defaulting to `permission_pending`**, with an optional
  per-document override on `source.document`. `source.v_document_license` resolves the
  effective tag.
* The default is the most restrictive value so that forgetting to clear a source hides its data
  instead of publishing it. Sources must be cleared explicitly.
* Marts (roadmap step 11) carry the effective tag; RLS policies (step 12) filter on it.

**API keys.** `auth.api_key` stores only a SHA-256 hex digest (enforced by a CHECK), a label,
a tier (`public` / `research`) and revocation time. Plain keys are shown once at issue and never
stored.

**Roles.** Created by `db/roles/000_roles.sql` (idempotent, no passwords):

| Role | Can | Cannot |
|---|---|---|
| `al_mfi_pipeline` | SELECT, INSERT, UPDATE on data schemas | DELETE anything; read `auth` |
| `al_mfi_reviewer` | SELECT on data schemas (INSERT on `core.review` from step 9) | write data |
| `al_mfi_api` | SELECT on `auth.api_key` (marts from step 12) | read raw/core data; write anything |
| `al_mfi_dbt` | SELECT on data schemas (owns staging/marts from step 11) | write data schemas |

Grants are issued by the migration that creates the objects, with `ALTER DEFAULT PRIVILEGES`
so tables added later by the owner inherit them. Migrations stop with a clear error if the roles
do not exist.

## Consequences

* The seeded source organizations start as `permission_pending`; clearing them is a deliberate
  data-rights decision, not a code change.
* Configuration: tools that only touch the database (`scripts/init_db.py`) read
  `DatabaseSettings` and do not require S3 secrets.
