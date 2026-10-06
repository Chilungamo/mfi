# ADR 0004 — Keep `app/`, adopt uv and Python 3.12, keep `init_db.py`

**Status:** Accepted · 2026-10-06

## Context

The guide uses a `src/mmd` package, uv, Python 3.12 and Alembic. This repository uses `app/`,
pip/setuptools, `requires-python >=3.13` and its own `scripts/init_db.py` runner.

## Decision

1. **Package layout:** keep `app/`. Guide subpackages map as follows:

   | Guide | Here |
   |---|---|
   | `mmd.archive` | `app.archive` |
   | `mmd.sources` | `app.sources` |
   | `mmd.pipelines` | `app.pipelines` |
   | `mmd.extract` | `app.extract` |
   | `mmd.promote` | `app.promote` |
   | `mmd.api` | `app.api` |
   | `review/`, `transform/`, `web/` | same top-level folders |

2. **Dependency management:** adopt **uv** with a committed `uv.lock` for reproducible installs;
   dbt is installed as an isolated uv tool (its pins clash with Dagster's).
3. **Python version:** target **3.12**, the version the guide's stack (Dagster, Arelle, Camelot,
   OCRmyPDF) is validated against.
4. **Migrations:** keep `scripts/init_db.py`. It already applies plain-SQL files once each and
   records them in `public.schema_migration` — the same contract as the guide's Alembic
   wrapper (each revision executes one reviewed SQL file; no downgrades), without another tool.

## Consequences

* No file moves; existing imports keep working.
* `Makefile` targets switch from `pip` to `uv run`.
* If branching migration histories are ever needed, Alembic can be introduced by turning each
  numbered SQL file into one revision — the SQL itself does not change.
