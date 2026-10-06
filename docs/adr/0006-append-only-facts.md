# ADR 0006 — Append-only facts enforced in the database

**Status:** Accepted · 2026-10-06

## Context

v0.2 `core.fact` has a `status` column (`validated` / `superseded` / `retracted`) and
`supersedes_fact_id`, but nothing prevents an UPDATE from silently changing a published value.
The guide makes facts an immutable log: rows are never deleted, and the only permitted update is
setting `superseded_at` once.

## Decision

Migration 003 adds to `core.fact`:

* `filing_id uuid` → `reporting.filing` — the filing the value was reported in (a period's figure
  can appear in two filings: its own year's and next year's comparative);
* `taxonomy_concept_id uuid` → `ref.taxonomy_concept` — the concept as tagged (ADR 0002);
* `superseded_at timestamptz` — NULL means current;
* `dims_key text NOT NULL DEFAULT ''` — sorted, canonical encoding of the fact's dimensions;
* `basis text` — `as_reported` or `derived` (consolidations, guide §7);
* `decimals integer` — XBRL precision, `-scale`;
* `recorded_at timestamptz`;
* a `BEFORE UPDATE OR DELETE` trigger rejecting deletes and any change other than setting
  `superseded_at` from NULL;
* a partial unique index guaranteeing at most one current fact per
  (filing, concept, period, dims_key, basis).

`status` and `supersedes_fact_id` remain for compatibility; `superseded_at` is authoritative.

## Consequences

* Corrections are new rows; point-in-time queries ("what did we publish on 1 March?") become
  `WHERE recorded_at <= t AND (superseded_at IS NULL OR superseded_at > t)`.
* Promotion must supersede and insert inside one transaction (guide §6).
* Tests must prove the trigger rejects UPDATE and DELETE.
