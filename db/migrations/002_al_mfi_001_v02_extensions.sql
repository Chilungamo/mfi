-- ============================================================
-- AL-MFI-001 v0.2 — Institutional, claims, XBRL and
-- government-finance extensions
--
-- Requires: 001_al_mfi_001_canonical_model.sql
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS institution;
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE SCHEMA IF NOT EXISTS government;

-- ------------------------------------------------------------
-- ref: reporting frameworks, taxonomies and dimensions
-- ------------------------------------------------------------

CREATE TABLE ref.reporting_framework (
    reporting_framework_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,          -- IFRS, IFRS_SME, IPSAS, MW_PUBLIC, MW_LOCAL_GOV
    name              text NOT NULL,
    issuer            text,
    basis_of_accounting text CHECK (
        basis_of_accounting IN ('accrual', 'modified_accrual', 'cash', 'modified_cash', 'mixed')
    ),
    sector_scope      text NOT NULL DEFAULT 'private' CHECK (
        sector_scope IN ('private', 'public', 'local_government', 'financial_sector', 'mixed')
    ),
    description       text
);

CREATE TABLE ref.taxonomy (
    taxonomy_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporting_framework_id uuid NOT NULL REFERENCES ref.reporting_framework (reporting_framework_id),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    publisher         text,
    jurisdiction_id   uuid REFERENCES ref.jurisdiction (jurisdiction_id)
);

CREATE TABLE ref.taxonomy_version (
    taxonomy_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    taxonomy_id       uuid NOT NULL REFERENCES ref.taxonomy (taxonomy_id),
    version_label     text NOT NULL,
    namespace_uri     text,
    entry_point_uri   text,
    effective_from    date,
    effective_to      date,
    UNIQUE (taxonomy_id, version_label)
);

CREATE TABLE ref.taxonomy_concept (
    taxonomy_concept_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    taxonomy_version_id uuid NOT NULL REFERENCES ref.taxonomy_version (taxonomy_version_id) ON DELETE CASCADE,
    qname             text NOT NULL,                 -- e.g. ifrs-full:Revenue
    label             text,
    data_type         text,
    period_type       text CHECK (period_type IN ('instant', 'duration')),
    balance           text CHECK (balance IN ('debit', 'credit')),
    is_abstract       boolean NOT NULL DEFAULT false,
    UNIQUE (taxonomy_version_id, qname)
);

-- Canonical concept ↔ taxonomy concept mapping, scoped by context.
CREATE TABLE ref.concept_mapping (
    concept_mapping_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id        uuid NOT NULL REFERENCES ref.concept (concept_id),
    taxonomy_concept_id uuid NOT NULL REFERENCES ref.taxonomy_concept (taxonomy_concept_id),
    mapping_kind      text NOT NULL DEFAULT 'exact' CHECK (
        mapping_kind IN ('exact', 'broader', 'narrower', 'related', 'component')
    ),
    jurisdiction_id   uuid REFERENCES ref.jurisdiction (jurisdiction_id),
    entity_kind       text,
    dimensional_context jsonb NOT NULL DEFAULT '{}'::jsonb,
    sign_multiplier   smallint NOT NULL DEFAULT 1 CHECK (sign_multiplier IN (-1, 1)),
    notes             text,
    UNIQUE NULLS NOT DISTINCT (concept_id, taxonomy_concept_id, jurisdiction_id, entity_kind)
);

CREATE TABLE ref.dimension (
    dimension_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    taxonomy_version_id uuid REFERENCES ref.taxonomy_version (taxonomy_version_id),
    code              text NOT NULL,                 -- canonical code or axis qname
    label             text NOT NULL,
    is_typed          boolean NOT NULL DEFAULT false,
    UNIQUE NULLS NOT DISTINCT (taxonomy_version_id, code)
);

CREATE TABLE ref.dimension_member (
    dimension_member_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    dimension_id      uuid NOT NULL REFERENCES ref.dimension (dimension_id) ON DELETE CASCADE,
    code              text NOT NULL,
    label             text NOT NULL,
    parent_id         uuid REFERENCES ref.dimension_member (dimension_member_id),
    is_default        boolean NOT NULL DEFAULT false,
    UNIQUE (dimension_id, code)
);

-- ------------------------------------------------------------
-- institution: administrative geography and organizational structure
-- ------------------------------------------------------------

CREATE TABLE institution.administrative_area (
    administrative_area_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    jurisdiction_id   uuid NOT NULL REFERENCES ref.jurisdiction (jurisdiction_id),
    area_level        text NOT NULL CHECK (
        area_level IN ('country', 'region', 'district', 'city', 'municipality', 'town',
                       'constituency', 'ward', 'traditional_authority', 'other')
    ),
    code              text,
    name              text NOT NULL,
    parent_id         uuid REFERENCES institution.administrative_area (administrative_area_id),
    valid_from        date,
    valid_to          date,
    UNIQUE NULLS NOT DISTINCT (jurisdiction_id, area_level, code)
);

-- An organizational unit is a structural part of an organization (core.entity):
-- a ministry, department, directorate, district office, council secretariat, branch.
CREATE TABLE institution.organizational_unit (
    organizational_unit_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid NOT NULL REFERENCES core.entity (entity_id),
    parent_unit_id    uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    unit_kind         text NOT NULL CHECK (
        unit_kind IN ('ministry', 'department', 'directorate', 'agency', 'division', 'section',
                      'office', 'council', 'secretariat', 'committee', 'branch',
                      'constitutional_body', 'statutory_body', 'other')
    ),
    name              text NOT NULL,
    code              text,
    administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    valid_from        date,
    valid_to          date,
    CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);

CREATE TABLE institution.person (
    person_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name         text NOT NULL,
    honorific         text,
    gender            text,
    birth_year        smallint,
    entity_id         uuid REFERENCES core.entity (entity_id),  -- optional link when person is also a core.entity
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE institution.position (
    position_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title             text NOT NULL,                 -- e.g. District Commissioner
    organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    entity_id         uuid REFERENCES core.entity (entity_id),
    administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    position_kind     text NOT NULL DEFAULT 'executive' CHECK (
        position_kind IN ('political', 'executive', 'civil_service', 'board', 'judicial',
                          'legislative', 'traditional', 'advisory', 'other')
    ),
    authority_note    text,
    CHECK (organizational_unit_id IS NOT NULL OR entity_id IS NOT NULL)
);

CREATE TABLE institution.appointment (
    appointment_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id         uuid NOT NULL REFERENCES institution.person (person_id),
    position_id       uuid NOT NULL REFERENCES institution.position (position_id),
    start_date        date,
    end_date          date,
    appointment_kind  text NOT NULL DEFAULT 'substantive' CHECK (
        appointment_kind IN ('substantive', 'acting', 'interim', 'elected', 'ex_officio', 'other')
    ),
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE institution.institutional_relationship (
    institutional_relationship_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_type_code text NOT NULL REFERENCES ref.relationship_type (relationship_type_code),
    subject_entity_id uuid REFERENCES core.entity (entity_id),
    subject_unit_id   uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    subject_person_id uuid REFERENCES institution.person (person_id),
    object_entity_id  uuid REFERENCES core.entity (entity_id),
    object_unit_id    uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    object_person_id  uuid REFERENCES institution.person (person_id),
    valid_from        date,
    valid_to          date,
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    CHECK (num_nonnulls(subject_entity_id, subject_unit_id, subject_person_id) = 1),
    CHECK (num_nonnulls(object_entity_id, object_unit_id, object_person_id) = 1)
);

-- ------------------------------------------------------------
-- source: claims (evidence, not truth)
-- ------------------------------------------------------------

CREATE TABLE source.claim (
    claim_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_location_id uuid NOT NULL REFERENCES source.document_location (document_location_id),
    claim_text        text NOT NULL,
    claim_kind        text NOT NULL DEFAULT 'statement' CHECK (
        claim_kind IN ('statement', 'quantity', 'appointment', 'relationship', 'event',
                       'allegation', 'forecast', 'other')
    ),
    attributed_to_person_id uuid REFERENCES institution.person (person_id),
    attributed_to_entity_id uuid REFERENCES core.entity (entity_id),
    about_entity_id   uuid REFERENCES core.entity (entity_id),
    about_unit_id     uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    about_area_id     uuid REFERENCES institution.administrative_area (administrative_area_id),
    concept_id        uuid REFERENCES ref.concept (concept_id),
    value_numeric     numeric,
    unit_code         text REFERENCES ref.unit (unit_code),
    claimed_event_date date,
    verification_status text NOT NULL DEFAULT 'unverified' CHECK (
        verification_status IN ('unverified', 'corroborated', 'contradicted', 'verified',
                                'refuted', 'unverifiable')
    ),
    extracted_by      text,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE source.claim_evidence (
    claim_evidence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id          uuid NOT NULL REFERENCES source.claim (claim_id) ON DELETE CASCADE,
    evidence_claim_id uuid REFERENCES source.claim (claim_id),
    evidence_fact_id  uuid REFERENCES core.fact (fact_id),
    evidence_document_location_id uuid REFERENCES source.document_location (document_location_id),
    relation          text NOT NULL CHECK (relation IN ('corroborates', 'contradicts', 'qualifies', 'supersedes')),
    assessed_by       text,
    assessed_at       timestamptz NOT NULL DEFAULT now(),
    note              text,
    CHECK (num_nonnulls(evidence_claim_id, evidence_fact_id, evidence_document_location_id) >= 1),
    CHECK (evidence_claim_id IS NULL OR evidence_claim_id <> claim_id)
);

-- ------------------------------------------------------------
-- core: institutional and geographic dimensions on observations/facts
-- ------------------------------------------------------------

ALTER TABLE core.observation
    ADD COLUMN organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    ADD COLUMN administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    ADD COLUMN reporting_framework_id uuid REFERENCES ref.reporting_framework (reporting_framework_id),
    ADD COLUMN source_claim_id uuid REFERENCES source.claim (claim_id);

ALTER TABLE core.fact
    ADD COLUMN organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    ADD COLUMN administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    ADD COLUMN reporting_framework_id uuid REFERENCES ref.reporting_framework (reporting_framework_id);

-- At least one subject anchor is required for an observation or fact.
ALTER TABLE core.observation
    ADD CONSTRAINT observation_has_subject_chk
    CHECK (num_nonnulls(entity_id, organizational_unit_id, administrative_area_id) >= 1);

ALTER TABLE core.fact
    ADD CONSTRAINT fact_has_subject_chk
    CHECK (num_nonnulls(entity_id, organizational_unit_id, administrative_area_id) >= 1);

CREATE TABLE core.observation_dimension (
    observation_id    uuid NOT NULL REFERENCES core.observation (observation_id) ON DELETE CASCADE,
    dimension_id      uuid NOT NULL REFERENCES ref.dimension (dimension_id),
    dimension_member_id uuid REFERENCES ref.dimension_member (dimension_member_id),
    typed_value       text,
    PRIMARY KEY (observation_id, dimension_id),
    CHECK (num_nonnulls(dimension_member_id, typed_value) = 1)
);

CREATE TABLE core.fact_dimension (
    fact_id           uuid NOT NULL REFERENCES core.fact (fact_id) ON DELETE CASCADE,
    dimension_id      uuid NOT NULL REFERENCES ref.dimension (dimension_id),
    dimension_member_id uuid REFERENCES ref.dimension_member (dimension_member_id),
    typed_value       text,
    PRIMARY KEY (fact_id, dimension_id),
    CHECK (num_nonnulls(dimension_member_id, typed_value) = 1)
);

-- ------------------------------------------------------------
-- reporting: digital filings / XBRL ingestion
-- ------------------------------------------------------------

CREATE TABLE reporting.reporting_entity (
    reporting_entity_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid REFERENCES core.entity (entity_id),
    organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    identifier_scheme text NOT NULL,                 -- XBRL entity identifier scheme URI
    identifier_value  text NOT NULL,
    UNIQUE (identifier_scheme, identifier_value),
    CHECK (num_nonnulls(entity_id, organizational_unit_id) >= 1)
);

CREATE TABLE reporting.filing (
    filing_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporting_entity_id uuid NOT NULL REFERENCES reporting.reporting_entity (reporting_entity_id),
    taxonomy_version_id uuid REFERENCES ref.taxonomy_version (taxonomy_version_id),
    reporting_framework_id uuid REFERENCES ref.reporting_framework (reporting_framework_id),
    document_version_id uuid REFERENCES source.document_version (document_version_id),
    filing_format     text NOT NULL CHECK (filing_format IN ('xbrl', 'ixbrl', 'xbrl_json', 'csv', 'pdf', 'other')),
    filing_kind       text,                          -- annual, interim, regulatory_return, ...
    period_end        date,
    filed_at          timestamptz,
    supersedes_filing_id uuid REFERENCES reporting.filing (filing_id)
);

CREATE TABLE reporting.filing_context (
    filing_context_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    filing_id         uuid NOT NULL REFERENCES reporting.filing (filing_id) ON DELETE CASCADE,
    context_ref       text NOT NULL,                 -- XBRL @id
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    UNIQUE (filing_id, context_ref)
);

CREATE TABLE reporting.filing_dimension (
    filing_context_id uuid NOT NULL REFERENCES reporting.filing_context (filing_context_id) ON DELETE CASCADE,
    dimension_id      uuid NOT NULL REFERENCES ref.dimension (dimension_id),
    dimension_member_id uuid REFERENCES ref.dimension_member (dimension_member_id),
    typed_value       text,
    PRIMARY KEY (filing_context_id, dimension_id),
    CHECK (num_nonnulls(dimension_member_id, typed_value) = 1)
);

CREATE TABLE reporting.filing_fact (
    filing_fact_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    filing_id         uuid NOT NULL REFERENCES reporting.filing (filing_id) ON DELETE CASCADE,
    filing_context_id uuid NOT NULL REFERENCES reporting.filing_context (filing_context_id),
    taxonomy_concept_id uuid REFERENCES ref.taxonomy_concept (taxonomy_concept_id),
    concept_qname     text NOT NULL,                 -- preserved even when not resolvable
    unit_ref          text,
    unit_code         text REFERENCES ref.unit (unit_code),
    decimals          text,
    value_numeric     numeric,
    value_text        text,
    is_nil            boolean NOT NULL DEFAULT false,
    fact_ref          text,                          -- XBRL fact @id
    observation_id    uuid REFERENCES core.observation (observation_id)
);

-- ------------------------------------------------------------
-- government: public finance and public projects
-- ------------------------------------------------------------

CREATE TABLE government.program (
    program_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text,
    name              text NOT NULL,
    organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    parent_program_id uuid REFERENCES government.program (program_id),
    valid_from        date,
    valid_to          date
);

CREATE TABLE government.fund (
    fund_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text,
    name              text NOT NULL,
    fund_kind         text NOT NULL CHECK (
        fund_kind IN ('consolidated', 'development', 'donor', 'special', 'trust',
                      'revolving', 'local_development', 'other')
    ),
    entity_id         uuid REFERENCES core.entity (entity_id)
);

CREATE TABLE government.revenue (
    revenue_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid REFERENCES core.entity (entity_id),
    organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    fund_id           uuid REFERENCES government.fund (fund_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    revenue_category  text NOT NULL,                 -- tax, grant, fee, transfer, ...
    economic_classification text,
    amount_kind       text NOT NULL CHECK (amount_kind IN ('budget', 'revised_budget', 'actual')),
    amount            numeric NOT NULL,
    currency_code     char(3) NOT NULL REFERENCES ref.currency (currency_code),
    observation_id    uuid REFERENCES core.observation (observation_id),
    CHECK (num_nonnulls(entity_id, organizational_unit_id, administrative_area_id) >= 1)
);

CREATE TABLE government.expenditure (
    expenditure_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid REFERENCES core.entity (entity_id),
    organizational_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    program_id        uuid REFERENCES government.program (program_id),
    fund_id           uuid REFERENCES government.fund (fund_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    economic_classification text,                    -- compensation, goods_services, capital, ...
    functional_classification text,                  -- COFOG or national function code
    amount_kind       text NOT NULL CHECK (
        amount_kind IN ('budget', 'revised_budget', 'commitment', 'actual')
    ),
    amount            numeric NOT NULL,
    currency_code     char(3) NOT NULL REFERENCES ref.currency (currency_code),
    observation_id    uuid REFERENCES core.observation (observation_id),
    CHECK (num_nonnulls(entity_id, organizational_unit_id, administrative_area_id) >= 1)
);

CREATE TABLE government.transfer (
    transfer_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    from_entity_id    uuid REFERENCES core.entity (entity_id),
    from_unit_id      uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    to_entity_id      uuid REFERENCES core.entity (entity_id),
    to_unit_id        uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    to_area_id        uuid REFERENCES institution.administrative_area (administrative_area_id),
    transfer_kind     text NOT NULL,                 -- general_resource, sector_conditional, cdf, ...
    fund_id           uuid REFERENCES government.fund (fund_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    amount_kind       text NOT NULL CHECK (amount_kind IN ('budget', 'revised_budget', 'actual')),
    amount            numeric NOT NULL,
    currency_code     char(3) NOT NULL REFERENCES ref.currency (currency_code),
    observation_id    uuid REFERENCES core.observation (observation_id),
    CHECK (num_nonnulls(from_entity_id, from_unit_id) >= 1),
    CHECK (num_nonnulls(to_entity_id, to_unit_id, to_area_id) >= 1)
);

CREATE TABLE government.project (
    project_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text,
    name              text NOT NULL,
    implementing_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    implementing_entity_id uuid REFERENCES core.entity (entity_id),
    administrative_area_id uuid REFERENCES institution.administrative_area (administrative_area_id),
    program_id        uuid REFERENCES government.program (program_id),
    fund_id           uuid REFERENCES government.fund (fund_id),
    status            text CHECK (
        status IN ('proposed', 'approved', 'in_progress', 'completed', 'suspended', 'cancelled')
    ),
    start_date        date,
    planned_end_date  date,
    actual_end_date   date,
    approved_cost     numeric,
    currency_code     char(3) REFERENCES ref.currency (currency_code)
);

CREATE TABLE government.procurement_event (
    procurement_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    procuring_unit_id uuid REFERENCES institution.organizational_unit (organizational_unit_id),
    procuring_entity_id uuid REFERENCES core.entity (entity_id),
    project_id        uuid REFERENCES government.project (project_id),
    reference_number  text,
    event_kind        text NOT NULL CHECK (
        event_kind IN ('plan', 'tender', 'bid', 'evaluation', 'award', 'contract',
                       'amendment', 'payment', 'termination', 'complaint')
    ),
    procurement_method text,
    event_date        date,
    supplier_entity_id uuid REFERENCES core.entity (entity_id),
    amount            numeric,
    currency_code     char(3) REFERENCES ref.currency (currency_code),
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    CHECK (num_nonnulls(procuring_unit_id, procuring_entity_id) >= 1)
);

-- ------------------------------------------------------------
-- indexes
-- ------------------------------------------------------------

CREATE INDEX appointment_position_dates_idx
    ON institution.appointment (position_id, start_date, end_date);
CREATE INDEX appointment_person_idx
    ON institution.appointment (person_id);
CREATE INDEX organizational_unit_entity_idx
    ON institution.organizational_unit (entity_id, parent_unit_id);
CREATE INDEX administrative_area_parent_idx
    ON institution.administrative_area (parent_id);
CREATE INDEX claim_status_idx
    ON source.claim (verification_status);
CREATE INDEX claim_about_entity_idx
    ON source.claim (about_entity_id);
CREATE INDEX observation_unit_area_idx
    ON core.observation (organizational_unit_id, administrative_area_id);
CREATE INDEX fact_unit_area_idx
    ON core.fact (organizational_unit_id, administrative_area_id);
CREATE INDEX filing_fact_filing_idx
    ON reporting.filing_fact (filing_id, concept_qname);
CREATE INDEX expenditure_period_idx
    ON government.expenditure (period_id, organizational_unit_id);
CREATE INDEX procurement_supplier_idx
    ON government.procurement_event (supplier_entity_id);

-- ------------------------------------------------------------
-- views
-- ------------------------------------------------------------

-- Who held which position, with the owning unit and area, over time.
CREATE VIEW institution.v_position_holder AS
SELECT
    a.appointment_id,
    p.person_id,
    p.full_name,
    pos.position_id,
    pos.title,
    a.appointment_kind,
    a.start_date,
    a.end_date,
    ou.organizational_unit_id,
    ou.name AS organizational_unit_name,
    COALESCE(pos.administrative_area_id, ou.administrative_area_id) AS administrative_area_id,
    COALESCE(pos.entity_id, ou.entity_id) AS entity_id
FROM institution.appointment a
JOIN institution.person p ON p.person_id = a.person_id
JOIN institution.position pos ON pos.position_id = a.position_id
LEFT JOIN institution.organizational_unit ou ON ou.organizational_unit_id = pos.organizational_unit_id;

-- Point-in-time lookup: who held positions on a given date.
CREATE FUNCTION institution.position_holders_on(as_of date)
RETURNS SETOF institution.v_position_holder
LANGUAGE sql STABLE AS $$
    SELECT *
    FROM institution.v_position_holder
    WHERE (start_date IS NULL OR start_date <= as_of)
      AND (end_date IS NULL OR end_date >= as_of)
$$;

COMMIT;
