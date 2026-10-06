# Operations

## Local setup

Requires [uv](https://docs.astral.sh/uv/) and Docker. uv installs Python 3.12 itself
(pinned in `.python-version`) and the exact package versions in `uv.lock`.

```bash
cp .env.example .env   # then change the S3 keys and the USER_AGENT contact
make install           # uv sync --extra dev
make services-up       # PostgreSQL 16 + MinIO (S3 API :9000, console :9001), bucket created
make db-init           # apply migrations, seeds and schema checks
make api               # http://localhost:8000/health
```

`scripts/init_db.py` first applies `db/roles/` (idempotent; creates the `al_mfi_*` login roles
without passwords — set them with `ALTER ROLE ... PASSWORD` outside version control), then
records applied migrations in `public.schema_migration` and skips them on
re-run. Seeds are idempotent and are re-applied each run. Schema checks in `db/checks/` return
zero rows on a healthy database; any row is reported as a failure.

Settings are read only by `app/config.py`. Secrets (`S3_ACCESS_KEY`, `S3_SECRET_KEY`) have no
defaults: a missing one stops the program at start-up. Database-only tools use
`DatabaseSettings` and need just `DATABASE_URL`.

## Data rights

Every source organization starts as `permission_pending` and is invisible to the API. Clear a
source only once its terms are confirmed:

```sql
UPDATE source.source_organization
SET license_tag = 'public', license_note = 'Terms checked <date>: <url>'
WHERE name = 'Reserve Bank of Malawi';
```

## Tests and CI

```bash
make check                                 # ruff, pyright, unit tests
AL_MFI_TEST_DATABASE_URL=postgresql://al_mfi:al_mfi@localhost:5432/al_mfi_test make test-integration
```

Integration tests apply all migrations and seeds to the target database, so point them at an
empty, disposable database.

`.github/workflows/ci.yml` runs on every pull request and every push to `main`: install from
`uv.lock` (`--frozen` fails if the lockfile is stale), lint, format check, typecheck, build the
database from scratch with `init_db.py`, run it a second time to prove it is re-runnable, then
run unit and integration tests against PostgreSQL 16.

To add a dependency: `uv add <package>` (updates `pyproject.toml` and `uv.lock`; commit both).

## Importing an external AL-MFI-001 source tree

`scripts/import_al_mfi_001.sh` copies an AL-MFI-001 source folder into the current Git
repository (excluding VCS and Python cache directories), stages the result, and optionally
commits and pushes. Run it from the repository root:

```bash
./scripts/import_al_mfi_001.sh
```
