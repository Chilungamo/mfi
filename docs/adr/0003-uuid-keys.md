# ADR 0003 — Keep UUID primary keys

**Status:** Accepted · 2026-10-06

## Context

The guide's examples use `bigserial` / `int` keys. Migrations 001–002 use `uuid` keys generated
by `gen_random_uuid()`.

## Decision

Keep UUIDs everywhere, including new tables added from the guide.

## Rationale

* Rewriting 001–002 brings no functional gain.
* UUIDs can be minted by ingestion code before insert (useful for batch loads and for linking an
  extraction to its page in one round-trip) and do not leak row counts through the public API
  (`/v1/facts/{fact_id}/source`).
* Cost: 16 bytes vs 8 per key and less compact indexes; irrelevant at the expected scale
  (17 listed companies, 28 districts, tens of thousands of facts per year).

## Consequences

Code samples from the guide that use integer ids are translated to `uuid` when implemented.
