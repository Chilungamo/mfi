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
  `superseded_at` from NULL. The comparison is over the whole row (`to_jsonb(NEW)` minus
  `superseded_at` and `status`), so columns added by later migrations are protected without
  editing the trigger;
* `BEFORE TRUNCATE` triggers (row triggers do not fire on TRUNCATE);
* the same protection on `core.fact_dimension` and `core.fact_observation`, because changing a
  fact's dimensions or evidence changes what the fact means;
* a partial unique index guaranteeing at most one current fact per
  (entity, organizational unit, area, filing, canonical concept, taxonomy concept, period,
  dims_key, basis), with `NULLS NOT DISTINCT` so facts without a filing are covered too;
* `core.facts_as_of(timestamptz)` for point-in-time reads.

`status` and `supersedes_fact_id` remain for compatibility; `superseded_at` is authoritative.
A CHECK keeps them consistent (`superseded_at IS NULL` ⇔ `status = 'validated'`); the trigger
sets `status = 'superseded'` automatically, or accepts `'retracted'` when a fact is withdrawn
without a replacement.

## Consequences

* Corrections are new rows; point-in-time queries ("what did we publish on 1 March?") become
  `WHERE recorded_at <= t AND (superseded_at IS NULL OR superseded_at > t)`.
* Promotion must supersede and insert inside one transaction (guide §6).
* Tests prove the trigger rejects UPDATE, DELETE and TRUNCATE
  (`tests/integration/test_facts_licences_roles.py`).
* The table owner can still `ALTER TABLE ... DISABLE TRIGGER`; that is an auditable DDL action,
  and application roles do not own the table.
