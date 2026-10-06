# ADR 0001 — Merge the Malawi Markets Data implementation guide into AL-MFI-001

**Status:** Accepted · 2026-10-06

## Context

Two designs now exist for the same platform:

* **AL-MFI-001 v0.2** (this repository): a canonical, provenance-preserving PostgreSQL model with
  11 domain schemas (`ref`, `source`, `institution`, `core`, `reporting`, `government`, `market`,
  `finance`, `ownership`, `economy`, `analytics`).
* **Malawi Markets Data: Tech Stack Implementation Guide** (2026-10-06): a step-by-step build
  plan — raw archive, PDF extraction, human review, append-only facts, dbt validation, API with
  row-level security, Next.js portal — targeting a June 2027 prototype.

They agree on the core ideas and differ mainly in naming and in what is already built.

## Decision

AL-MFI-001's **data model** is the base; the guide's **build plan, operational mechanisms and
toolchain** are layered on top of it. Concretely:

| Guide concept | AL-MFI-001 home |
|---|---|
| `raw.source`, `raw.document` | `source.source_organization`, `source.document`, `source.document_version` (already content-hashed) |
| `raw.document_page`, `raw.extraction` | New tables in `source` (pages, extractions with bounding boxes) |
| `core.extraction` → review → `core.fact` | `core.observation` → new `core.review` → `core.fact` |
| `core.concept` holding `ifrs-full:*` | `ref.taxonomy_concept` (see ADR 0002) |
| `core.concept_map` | `ref.concept_mapping` (exists; `exact` / `broader` / `narrower`) |
| `core.concept_relationship` (calculation) | New `ref.taxonomy_relationship` |
| `core.taxonomy` versions | `ref.taxonomy`, `ref.taxonomy_version` (exist) |
| `core.entity`, geography | `core.entity`, `institution.administrative_area` (exist) |
| `core.filing` | `reporting.filing` (exists) |
| `fact.superseded_at`, `dims_key`, `basis`, append-only trigger | Added to `core.fact` (ADR 0006) |
| `license_tag`, roles, RLS, `auth.api_key` | New migration; `auth` schema added |
| `staging`, `marts` | dbt-owned schemas, added when dbt lands |
| `mw-co`, `mw-ps`, `mw-stat` extensions | Rows in `ref.taxonomy` / `ref.taxonomy_concept`, loaded from CSV |

Principles from the guide adopted unchanged: fail-fast typed configuration; invariants enforced
in the database (roles, triggers, RLS) rather than in application code; content-addressed raw
archive; extraction never loses provenance coordinates; human review before facts; validation
tests gate publication; amounts stored in units, never thousands; every data table has a
provenance link.

## Consequences

* No v0.2 table is discarded; the guide's features arrive as forward migrations (ADR 0005).
* Code samples in the guide are translated to this repo's names; the guide remains the
  reference for *why* and *how*, `docs/roadmap.md` for *where* and *when*.
