-- ============================================================
-- AL-MFI-001 — Database roles (cluster-level; run before migrations)
--
-- Idempotent: creates each role only if it does not exist. Roles are created
-- WITHOUT passwords; set them outside version control, e.g.
--   ALTER ROLE al_mfi_api PASSWORD '...';
-- Privileges are granted in the migrations that create the objects.
-- ============================================================

DO $$
DECLARE
    r text;
BEGIN
    FOREACH r IN ARRAY ARRAY[
        'al_mfi_pipeline',   -- ingestion, extraction, promotion: reads and writes data schemas
        'al_mfi_reviewer',   -- review app: reads everything, writes only review decisions
        'al_mfi_api',        -- public API: reads published marts and API keys only
        'al_mfi_dbt'         -- transformation: reads data schemas, owns staging and marts
    ]
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I LOGIN', r);
        END IF;
    END LOOP;
END
$$;
