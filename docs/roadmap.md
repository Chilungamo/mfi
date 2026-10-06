# Roadmap — AL-MFI-001 × Malawi Markets Data implementation guide

Build order follows the guide: bottom-up, each layer usable and tested before the next starts.
Every step is one reviewed commit. Decisions behind the mapping: [`docs/adr/`](adr/README.md).

| Step | Deliverable | Guide § | Guide due date | Status |
|---|---|---|---|---|
| 1 | Merge decisions (ADRs 0001–0006) and this roadmap | all | — | ✅ Done |
| 2 | Tooling: uv + `uv.lock`, Python 3.12, MinIO in Docker Compose, extended settings (S3, user agent, extractor version, API DB URL), GitHub Actions CI against Postgres 16 | 1, 11 | 2026-11-15 | ✅ Done |
| 3 | Migration 003: append-only facts (ADR 0006), `license_tag`, `auth` schema; `db/roles/000_roles.sql`; trigger tests | 2, 10 | 2026-11-30 | ✅ Done |
| 4 | Seeds: reporting bases (IFRS, IFRS_SME, IPSAS_CASH, IPSAS_MOD_CASH, IPSAS_MOD_ACCRUAL, IPSAS_ACCRUAL); 17 MSE-listed companies; NSO district codes. CSV-backed, idempotent | 2 | 2026-11-30 | ☐ |
| 5 | Taxonomies: `ref.taxonomy_relationship`; Arelle IFRS loader; `mw-co` / `mw-ps` / `mw-stat` extension CSVs; GFS concept maps; ~40-item v1 concept list | 3 | 2026-11-30 | ☐ |
| 6 | `app.extract.numbers`: `parse_amount`, `detect_scale` + exhaustive tests (pure functions) | 5 | 2026-12-20 | ☐ |
| 7 | Raw archive (content-addressed S3/MinIO), `Source` protocol, MSE monthly + annual-report catalogue adapters; polite HTTP (UA, delay, robots.txt) | 4 | 2027-01-31 | ☐ |
| 8 | Pages + OCR, statement locator, table extraction with bounding boxes (PyMuPDF space and PDF space), label → concept matching (`pg_trgm`), golden-file tests | 5 | 2026-12-20 | ☐ |
| 9 | `core.review` (append-only), promotion to facts in one transaction, Streamlit review app | 6 | 2026-12-20 | ☐ |
| 10 | Dagster assets, dynamic per-document partitions, sensor, schedules | 4 | 2027-01-31 | ☐ |
| 11 | dbt project: staging, `fct_financials` (latest vs first-reported), error/warn tests, audit queue | 7 | 2027-02-28 | ☐ |
| 12 | API v1: hashed API keys, tier via `set_config`, RLS post-hook, `/v1/facts/{id}/source`, xBRL-JSON export | 8, 10 | 2027-04-15 | ☐ |
| 13 | Next.js portal: tear sheets, PDF source viewer with highlighted box, ECharts | 9 | 2027-04-30 | ☐ |
| 14 | Data load: 17 companies + 5 macro series reviewed and passing error tests | — | 2027-03-31 | ☐ |
| 15 | Flagship mart (nominal / real / USD returns); staging deploy; Sentry; pilot keys; Arelle-validated export | 7, 9, 11 | 2027-05 – 06 | ☐ |

Steps 6 and 8–9 are ahead of step 7 in the guide's calendar; that is intentional — extraction and
review can be developed against local PDFs before automated collection exists.

## Out of scope until the data-protection impact assessment is done

`institution.person`, `institution.appointment` and newspaper-derived claims stay empty in
production (guide §10: "no personal data in v1"). The tables remain in the schema.
