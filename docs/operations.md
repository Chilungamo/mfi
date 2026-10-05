# Operations

## Local setup

```bash
cp .env.example .env
make install       # editable install with dev + ingestion extras
make db-up         # PostgreSQL 17 via docker compose
make db-init       # apply migrations, seeds and schema checks
make api           # http://localhost:8000/health
```

`scripts/init_db.py` records applied migrations in `public.schema_migration` and skips them on
re-run. Seeds are idempotent and are re-applied each run. Schema checks in `db/checks/` return
zero rows on a healthy database; any row is reported as a failure.

## Tests

```bash
make test                                  # unit tests (no database)
AL_MFI_TEST_DATABASE_URL=postgresql://al_mfi:al_mfi@localhost:5432/al_mfi_test pytest tests/integration
```

Integration tests apply all migrations and seeds to the target database, so point them at an
empty, disposable database.

## Importing an external AL-MFI-001 source tree

`scripts/import_al_mfi_001.sh` copies an AL-MFI-001 source folder into the current Git
repository (excluding VCS and Python cache directories), stages the result, and optionally
commits and pushes. Run it from the repository root:

```bash
./scripts/import_al_mfi_001.sh
```
