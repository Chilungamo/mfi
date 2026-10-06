-- ============================================================
-- AL-MFI-001 — 003: append-only facts, licence tags, API keys, role grants
--
-- Requires: 001, 002 and db/roles/000_roles.sql
-- Decisions: docs/adr/0006-append-only-facts.md, docs/adr/0007-licences-and-roles.md
-- ============================================================

BEGIN;

-- Fail fast with a clear message if the roles were not created first.
DO $$
BEGIN
    IF (SELECT count(*) FROM pg_roles
        WHERE rolname IN ('al_mfi_pipeline', 'al_mfi_reviewer', 'al_mfi_api', 'al_mfi_dbt')) <> 4 THEN
        RAISE EXCEPTION 'roles missing: run db/roles/000_roles.sql before migration 003';
    END IF;
END
$$;

-- ------------------------------------------------------------
-- 1. Append-only facts
-- ------------------------------------------------------------

ALTER TABLE core.fact
    ADD COLUMN filing_id           uuid REFERENCES reporting.filing (filing_id),
    ADD COLUMN taxonomy_concept_id uuid REFERENCES ref.taxonomy_concept (taxonomy_concept_id),
    ADD COLUMN dims_key            text NOT NULL DEFAULT '',
    ADD COLUMN basis               text NOT NULL DEFAULT 'as_reported'
        CHECK (basis IN ('as_reported', 'derived')),
    ADD COLUMN decimals            integer,
    ADD COLUMN recorded_at         timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN superseded_at       timestamptz;

-- `superseded_at` is authoritative; the legacy `status` must agree with it.
ALTER TABLE core.fact
    ADD CONSTRAINT fact_status_matches_superseded_chk
        CHECK ((superseded_at IS NULL) = (status = 'validated')),
    ADD CONSTRAINT fact_superseded_after_recorded_chk
        CHECK (superseded_at IS NULL OR superseded_at >= recorded_at);

-- The only permitted change to a fact: set superseded_at once (optionally marking it
-- 'retracted' instead of 'superseded'). Every other column is compared as a whole row, so a
-- column added by a future migration is protected automatically.
CREATE FUNCTION core.fact_append_only() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'core.fact is append-only: facts are never deleted (supersede instead)';
    END IF;

    IF OLD.superseded_at IS NOT NULL THEN
        RAISE EXCEPTION 'core.fact %: already superseded at %', OLD.fact_id, OLD.superseded_at;
    END IF;

    IF NEW.superseded_at IS NULL
       OR (to_jsonb(NEW) - 'superseded_at' - 'status')
          IS DISTINCT FROM (to_jsonb(OLD) - 'superseded_at' - 'status') THEN
        RAISE EXCEPTION 'core.fact is append-only: only superseded_at may be set, once';
    END IF;

    IF NEW.status = 'validated' THEN
        NEW.status := 'superseded';
    ELSIF NEW.status NOT IN ('superseded', 'retracted') THEN
        RAISE EXCEPTION 'core.fact %: invalid status % on supersede', OLD.fact_id, NEW.status;
    END IF;

    RETURN NEW;
END
$$;

CREATE TRIGGER fact_append_only
    BEFORE UPDATE OR DELETE ON core.fact
    FOR EACH ROW EXECUTE FUNCTION core.fact_append_only();

-- Rows that define what a fact means are as immutable as the fact itself.
CREATE FUNCTION core.reject_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION '% is append-only: % is not allowed', TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, TG_OP;
END
$$;

CREATE TRIGGER fact_dimension_append_only
    BEFORE UPDATE OR DELETE ON core.fact_dimension
    FOR EACH ROW EXECUTE FUNCTION core.reject_change();

CREATE TRIGGER fact_observation_append_only
    BEFORE UPDATE OR DELETE ON core.fact_observation
    FOR EACH ROW EXECUTE FUNCTION core.reject_change();

-- Row triggers do not fire on TRUNCATE; block it separately.
CREATE TRIGGER fact_no_truncate
    BEFORE TRUNCATE ON core.fact
    FOR EACH STATEMENT EXECUTE FUNCTION core.reject_change();
CREATE TRIGGER fact_dimension_no_truncate
    BEFORE TRUNCATE ON core.fact_dimension
    FOR EACH STATEMENT EXECUTE FUNCTION core.reject_change();
CREATE TRIGGER fact_observation_no_truncate
    BEFORE TRUNCATE ON core.fact_observation
    FOR EACH STATEMENT EXECUTE FUNCTION core.reject_change();

-- At most one current fact per subject, filing, concept, period, dimensions and basis.
-- NULLS NOT DISTINCT: a missing filing or subject column still counts as "the same".
CREATE UNIQUE INDEX fact_current_uidx
    ON core.fact (entity_id, organizational_unit_id, administrative_area_id, filing_id,
                  concept_id, taxonomy_concept_id, period_id, dims_key, basis)
    NULLS NOT DISTINCT
    WHERE superseded_at IS NULL;

CREATE INDEX fact_filing_idx ON core.fact (filing_id);

-- Point-in-time view of the fact log: what was published at time `as_of`.
CREATE FUNCTION core.facts_as_of(as_of timestamptz)
RETURNS SETOF core.fact
LANGUAGE sql STABLE AS $$
    SELECT *
    FROM core.fact
    WHERE recorded_at <= as_of
      AND (superseded_at IS NULL OR superseded_at > as_of)
$$;

-- ------------------------------------------------------------
-- 2. Licence tags
-- ------------------------------------------------------------

CREATE DOMAIN ref.license_tag AS text
    CHECK (VALUE IN ('public', 'research_only', 'licensed_internal', 'permission_pending'));

-- Default is the most restrictive: a source nobody has cleared is invisible to the API.
ALTER TABLE source.source_organization
    ADD COLUMN license_tag ref.license_tag NOT NULL DEFAULT 'permission_pending',
    ADD COLUMN license_note text;

-- Optional per-document override (NULL = inherit from the source organization).
ALTER TABLE source.document
    ADD COLUMN license_tag ref.license_tag;

CREATE VIEW source.v_document_license AS
SELECT
    d.document_id,
    d.source_organization_id,
    COALESCE(d.license_tag, so.license_tag) AS license_tag,
    d.license_tag IS NOT NULL               AS is_overridden
FROM source.document d
JOIN source.source_organization so USING (source_organization_id);

-- ------------------------------------------------------------
-- 3. API keys (stored as SHA-256 hashes only)
-- ------------------------------------------------------------

CREATE SCHEMA auth;

CREATE TABLE auth.api_key (
    api_key_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    key_hash     char(64) NOT NULL UNIQUE CHECK (key_hash ~ '^[0-9a-f]{64}$'),
    label        text NOT NULL,                       -- who the key was issued to
    tier         text NOT NULL CHECK (tier IN ('public', 'research')),
    created_at   timestamptz NOT NULL DEFAULT now(),
    revoked_at   timestamptz,
    CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);

-- ------------------------------------------------------------
-- 4. Grants (least privilege; nobody but the owner may DELETE)
-- ------------------------------------------------------------

DO $$
DECLARE
    s text;
    data_schemas text[] := ARRAY['ref', 'source', 'institution', 'core', 'reporting',
                                 'government', 'market', 'finance', 'ownership',
                                 'economy', 'analytics'];
BEGIN
    FOREACH s IN ARRAY data_schemas LOOP
        -- pipeline: read and write data, never delete
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO al_mfi_pipeline', s);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA %I TO al_mfi_pipeline', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT, INSERT, UPDATE ON TABLES TO al_mfi_pipeline', s);

        -- reviewer and dbt: read only (reviewer gets INSERT on core.review when it exists)
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO al_mfi_reviewer, al_mfi_dbt', s);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO al_mfi_reviewer, al_mfi_dbt', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO al_mfi_reviewer, al_mfi_dbt', s);
    END LOOP;
END
$$;

-- api: only API keys for now; published marts are granted when they exist (roadmap step 11-12).
GRANT USAGE ON SCHEMA auth TO al_mfi_api;
GRANT SELECT ON auth.api_key TO al_mfi_api;

COMMIT;
