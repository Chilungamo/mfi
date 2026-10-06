# ADR 0005 — Forward-only numbered migrations

**Status:** Accepted · 2026-10-06

## Decision

* Migrations 001 and 002 are frozen. Every change, including those from the guide, is a new
  file `db/migrations/NNN_<description>.sql`, applied in order by `scripts/init_db.py`.
* No down-migrations: recovery is restore-from-backup (guide §2, §10).
* Role creation (`CREATE ROLE`) needs cluster privileges and passwords set outside version
  control, so it lives in `db/roles/000_roles.sql`, run once by the owner — not in the
  migration sequence.

## Rationale

Nothing is deployed yet, so editing 001–002 would be possible; establishing the forward-only
habit now avoids an unsafe practice once a database holds real data.
