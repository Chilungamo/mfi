-- ============================================================
-- AL-MFI-001 v0.1 — Canonical Malawi Financial & Economic
-- Intelligence Data Model
--
-- Lineage:
--   SOURCE → DOCUMENT → OBSERVATION → FACT → FEATURE → INFERENCE
--   → INDEX → INSIGHT
-- ============================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS source;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS market;
CREATE SCHEMA IF NOT EXISTS finance;
CREATE SCHEMA IF NOT EXISTS ownership;
CREATE SCHEMA IF NOT EXISTS economy;
CREATE SCHEMA IF NOT EXISTS analytics;

-- ------------------------------------------------------------
-- ref: reference and semantic registry
-- ------------------------------------------------------------

CREATE TABLE ref.jurisdiction (
    jurisdiction_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,          -- ISO 3166-1 alpha-2 or sub-national code
    name              text NOT NULL,
    parent_id         uuid REFERENCES ref.jurisdiction (jurisdiction_id),
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ref.currency (
    currency_code     char(3) PRIMARY KEY,           -- ISO 4217
    name              text NOT NULL,
    minor_units       smallint NOT NULL DEFAULT 2 CHECK (minor_units >= 0)
);

CREATE TABLE ref.unit (
    unit_code         text PRIMARY KEY,
    name              text NOT NULL,
    unit_kind         text NOT NULL CHECK (
        unit_kind IN ('monetary', 'ratio', 'percent', 'count', 'index', 'physical', 'other')
    ),
    currency_code     char(3) REFERENCES ref.currency (currency_code),
    scale             integer NOT NULL DEFAULT 0     -- power of ten (e.g. 6 = millions)
);

CREATE TABLE ref.sector (
    sector_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    scheme            text NOT NULL,                 -- e.g. ISIC4, MSE, internal
    code              text NOT NULL,
    name              text NOT NULL,
    parent_id         uuid REFERENCES ref.sector (sector_id),
    UNIQUE (scheme, code)
);

CREATE TABLE ref.concept (
    concept_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,          -- canonical concept, e.g. 'revenue'
    label             text NOT NULL,
    definition        text,
    data_type         text NOT NULL DEFAULT 'monetary' CHECK (
        data_type IN ('monetary', 'decimal', 'integer', 'percent', 'text', 'boolean', 'date')
    ),
    period_type       text NOT NULL DEFAULT 'duration' CHECK (period_type IN ('instant', 'duration')),
    balance           text CHECK (balance IN ('debit', 'credit')),
    parent_id         uuid REFERENCES ref.concept (concept_id),
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ref.relationship_type (
    relationship_type_code text PRIMARY KEY,
    name              text NOT NULL,
    description       text,
    is_directed       boolean NOT NULL DEFAULT true
);

-- ------------------------------------------------------------
-- source: evidence and provenance
-- ------------------------------------------------------------

CREATE TABLE source.source_organization (
    source_organization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name              text NOT NULL UNIQUE,
    source_kind       text NOT NULL CHECK (
        source_kind IN (
            'government', 'regulator', 'exchange', 'company', 'media',
            'multilateral', 'statistical_agency', 'academic', 'other'
        )
    ),
    website           text,
    reliability_tier  smallint CHECK (reliability_tier BETWEEN 1 AND 5),
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE source.document (
    document_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_organization_id uuid NOT NULL REFERENCES source.source_organization (source_organization_id),
    document_type     text NOT NULL,                 -- annual_report, gazette, article, ...
    title             text NOT NULL,
    published_on      date,
    language          text NOT NULL DEFAULT 'en',
    canonical_url     text,
    license_note      text,
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE source.document_version (
    document_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id       uuid NOT NULL REFERENCES source.document (document_id) ON DELETE CASCADE,
    version_label     text NOT NULL DEFAULT '1',
    content_sha256    char(64) NOT NULL,
    media_type        text,
    byte_size         bigint CHECK (byte_size >= 0),
    retrieved_at      timestamptz NOT NULL DEFAULT now(),
    storage_uri       text,
    UNIQUE (document_id, content_sha256)
);

CREATE TABLE source.document_location (
    document_location_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_version_id uuid NOT NULL REFERENCES source.document_version (document_version_id) ON DELETE CASCADE,
    page_number       integer CHECK (page_number > 0),
    section_label     text,
    table_label       text,
    row_label         text,
    column_label      text,
    char_start        integer,
    char_end          integer,
    excerpt           text,
    CHECK (char_start IS NULL OR char_end IS NULL OR char_end >= char_start)
);

-- ------------------------------------------------------------
-- core: canonical entities and facts
-- ------------------------------------------------------------

CREATE TABLE core.entity (
    entity_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_kind       text NOT NULL CHECK (
        entity_kind IN (
            'company', 'bank', 'insurer', 'government', 'government_body',
            'local_authority', 'state_owned_enterprise', 'regulator', 'ngo',
            'multilateral', 'fund', 'person', 'other'
        )
    ),
    legal_name        text NOT NULL,
    short_name        text,
    jurisdiction_id   uuid REFERENCES ref.jurisdiction (jurisdiction_id),
    sector_id         uuid REFERENCES ref.sector (sector_id),
    incorporated_on   date,
    dissolved_on      date,
    created_at        timestamptz NOT NULL DEFAULT now(),
    CHECK (dissolved_on IS NULL OR incorporated_on IS NULL OR dissolved_on >= incorporated_on)
);

CREATE TABLE core.entity_identifier (
    entity_identifier_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid NOT NULL REFERENCES core.entity (entity_id) ON DELETE CASCADE,
    scheme            text NOT NULL,                 -- LEI, MRA_TPIN, REG_NO, MSE_TICKER, ...
    value             text NOT NULL,
    valid_from        date,
    valid_to          date,
    UNIQUE (scheme, value)
);

CREATE TABLE core.entity_alias (
    entity_alias_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid NOT NULL REFERENCES core.entity (entity_id) ON DELETE CASCADE,
    alias             text NOT NULL,
    alias_kind        text NOT NULL DEFAULT 'other' CHECK (
        alias_kind IN ('former_name', 'trading_name', 'abbreviation', 'misspelling', 'other')
    ),
    valid_from        date,
    valid_to          date,
    UNIQUE (entity_id, alias)
);

CREATE TABLE core.entity_relationship (
    entity_relationship_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_entity_id uuid NOT NULL REFERENCES core.entity (entity_id) ON DELETE CASCADE,
    relationship_type_code text NOT NULL REFERENCES ref.relationship_type (relationship_type_code),
    object_entity_id  uuid NOT NULL REFERENCES core.entity (entity_id) ON DELETE CASCADE,
    valid_from        date,
    valid_to          date,
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    CHECK (subject_entity_id <> object_entity_id)
);

CREATE TABLE core.period (
    period_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    period_type       text NOT NULL CHECK (period_type IN ('instant', 'duration')),
    start_date        date,
    end_date          date NOT NULL,
    label             text,
    CHECK (
        (period_type = 'instant' AND start_date IS NULL)
        OR (period_type = 'duration' AND start_date IS NOT NULL AND end_date >= start_date)
    ),
    UNIQUE NULLS NOT DISTINCT (period_type, start_date, end_date)
);

CREATE TABLE core.observation (
    observation_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id        uuid NOT NULL REFERENCES ref.concept (concept_id),
    entity_id         uuid REFERENCES core.entity (entity_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    unit_code         text REFERENCES ref.unit (unit_code),
    value_numeric     numeric,
    value_text        text,
    reported_label    text,                          -- label as printed in the source
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    extraction_method text NOT NULL DEFAULT 'manual' CHECK (
        extraction_method IN ('manual', 'parser', 'ocr', 'xbrl', 'api', 'model')
    ),
    confidence        numeric(4, 3) CHECK (confidence BETWEEN 0 AND 1),
    observed_at       timestamptz NOT NULL DEFAULT now(),
    CHECK (value_numeric IS NOT NULL OR value_text IS NOT NULL)
);

CREATE TABLE core.fact (
    fact_id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    concept_id        uuid NOT NULL REFERENCES ref.concept (concept_id),
    entity_id         uuid REFERENCES core.entity (entity_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    unit_code         text REFERENCES ref.unit (unit_code),
    value_numeric     numeric,
    value_text        text,
    status            text NOT NULL DEFAULT 'validated' CHECK (
        status IN ('validated', 'superseded', 'retracted')
    ),
    validated_at      timestamptz NOT NULL DEFAULT now(),
    validated_by      text,
    supersedes_fact_id uuid REFERENCES core.fact (fact_id),
    CHECK (value_numeric IS NOT NULL OR value_text IS NOT NULL)
);

CREATE TABLE core.fact_observation (
    fact_id           uuid NOT NULL REFERENCES core.fact (fact_id) ON DELETE CASCADE,
    observation_id    uuid NOT NULL REFERENCES core.observation (observation_id),
    role              text NOT NULL DEFAULT 'support' CHECK (role IN ('primary', 'support', 'contradiction')),
    PRIMARY KEY (fact_id, observation_id)
);

-- ------------------------------------------------------------
-- market
-- ------------------------------------------------------------

CREATE TABLE market.exchange (
    exchange_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    mic               text UNIQUE,                   -- ISO 10383
    name              text NOT NULL,
    jurisdiction_id   uuid REFERENCES ref.jurisdiction (jurisdiction_id)
);

CREATE TABLE market.security (
    security_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer_entity_id  uuid NOT NULL REFERENCES core.entity (entity_id),
    security_kind     text NOT NULL CHECK (
        security_kind IN ('equity', 'bond', 'treasury_bill', 'treasury_note', 'fund_unit', 'other')
    ),
    isin              text UNIQUE,
    name              text NOT NULL,
    currency_code     char(3) REFERENCES ref.currency (currency_code)
);

CREATE TABLE market.listing (
    listing_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    security_id       uuid NOT NULL REFERENCES market.security (security_id),
    exchange_id       uuid NOT NULL REFERENCES market.exchange (exchange_id),
    ticker            text NOT NULL,
    listed_on         date,
    delisted_on       date,
    UNIQUE (exchange_id, ticker, listed_on)
);

CREATE TABLE market.market_observation (
    market_observation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id        uuid NOT NULL REFERENCES market.listing (listing_id),
    trade_date        date NOT NULL,
    open_price        numeric,
    high_price        numeric,
    low_price         numeric,
    close_price       numeric,
    volume            numeric CHECK (volume >= 0),
    turnover          numeric,
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    UNIQUE (listing_id, trade_date)
);

-- ------------------------------------------------------------
-- finance
-- ------------------------------------------------------------

CREATE TABLE finance.financial_statement (
    financial_statement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id         uuid NOT NULL REFERENCES core.entity (entity_id),
    statement_kind    text NOT NULL CHECK (
        statement_kind IN (
            'financial_position', 'profit_or_loss', 'comprehensive_income',
            'cash_flows', 'changes_in_equity', 'budget_execution', 'other'
        )
    ),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    consolidation     text NOT NULL DEFAULT 'separate' CHECK (consolidation IN ('separate', 'consolidated')),
    currency_code     char(3) REFERENCES ref.currency (currency_code),
    document_version_id uuid REFERENCES source.document_version (document_version_id),
    is_audited        boolean,
    is_restated       boolean NOT NULL DEFAULT false
);

CREATE TABLE finance.financial_line_item (
    financial_line_item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    financial_statement_id uuid NOT NULL REFERENCES finance.financial_statement (financial_statement_id) ON DELETE CASCADE,
    line_order        integer NOT NULL,
    reported_label    text NOT NULL,
    concept_id        uuid REFERENCES ref.concept (concept_id),
    value_numeric     numeric,
    unit_code         text REFERENCES ref.unit (unit_code),
    observation_id    uuid REFERENCES core.observation (observation_id),
    UNIQUE (financial_statement_id, line_order)
);

-- ------------------------------------------------------------
-- ownership
-- ------------------------------------------------------------

CREATE TABLE ownership.ownership_position (
    ownership_position_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_entity_id   uuid NOT NULL REFERENCES core.entity (entity_id),
    owned_entity_id   uuid NOT NULL REFERENCES core.entity (entity_id),
    security_id       uuid REFERENCES market.security (security_id),
    shares_held       numeric CHECK (shares_held >= 0),
    percent_held      numeric(7, 4) CHECK (percent_held BETWEEN 0 AND 100),
    as_of_date        date NOT NULL,
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    CHECK (owner_entity_id <> owned_entity_id)
);

-- ------------------------------------------------------------
-- economy
-- ------------------------------------------------------------

CREATE TABLE economy.indicator (
    indicator_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL UNIQUE,
    name              text NOT NULL,
    concept_id        uuid REFERENCES ref.concept (concept_id),
    unit_code         text REFERENCES ref.unit (unit_code),
    frequency         text NOT NULL CHECK (frequency IN ('D', 'W', 'M', 'Q', 'S', 'A', 'irregular')),
    source_organization_id uuid REFERENCES source.source_organization (source_organization_id)
);

CREATE TABLE economy.indicator_observation (
    indicator_observation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    indicator_id      uuid NOT NULL REFERENCES economy.indicator (indicator_id),
    jurisdiction_id   uuid REFERENCES ref.jurisdiction (jurisdiction_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    value_numeric     numeric NOT NULL,
    vintage_date      date NOT NULL DEFAULT current_date,
    document_location_id uuid REFERENCES source.document_location (document_location_id),
    UNIQUE NULLS NOT DISTINCT (indicator_id, jurisdiction_id, period_id, vintage_date)
);

-- ------------------------------------------------------------
-- analytics: FEATURE → INFERENCE → INDEX → INSIGHT
-- ------------------------------------------------------------

CREATE TABLE analytics.feature (
    feature_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL,
    version           text NOT NULL DEFAULT '1',
    description       text,
    definition        jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (code, version)
);

CREATE TABLE analytics.feature_value (
    feature_value_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    feature_id        uuid NOT NULL REFERENCES analytics.feature (feature_id),
    entity_id         uuid REFERENCES core.entity (entity_id),
    period_id         uuid REFERENCES core.period (period_id),
    value_numeric     numeric,
    input_fact_ids    uuid[] NOT NULL DEFAULT '{}',
    computed_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE analytics.inference (
    inference_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    model_code        text NOT NULL,
    model_version     text NOT NULL,
    entity_id         uuid REFERENCES core.entity (entity_id),
    period_id         uuid REFERENCES core.period (period_id),
    output            jsonb NOT NULL,
    input_feature_value_ids uuid[] NOT NULL DEFAULT '{}',
    confidence        numeric(4, 3) CHECK (confidence BETWEEN 0 AND 1),
    computed_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE analytics.index_definition (
    index_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code              text NOT NULL,
    version           text NOT NULL DEFAULT '1',
    name              text NOT NULL,
    methodology       text,
    UNIQUE (code, version)
);

CREATE TABLE analytics.index_value (
    index_value_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    index_definition_id uuid NOT NULL REFERENCES analytics.index_definition (index_definition_id),
    entity_id         uuid REFERENCES core.entity (entity_id),
    period_id         uuid NOT NULL REFERENCES core.period (period_id),
    value_numeric     numeric NOT NULL,
    computed_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE analytics.insight (
    insight_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title             text NOT NULL,
    body              text NOT NULL,
    entity_id         uuid REFERENCES core.entity (entity_id),
    supporting_fact_ids uuid[] NOT NULL DEFAULT '{}',
    supporting_inference_ids uuid[] NOT NULL DEFAULT '{}',
    status            text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewed', 'published', 'withdrawn')),
    created_at        timestamptz NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- indexes
-- ------------------------------------------------------------

CREATE INDEX observation_concept_entity_period_idx
    ON core.observation (concept_id, entity_id, period_id);
CREATE INDEX fact_concept_entity_period_idx
    ON core.fact (concept_id, entity_id, period_id);
CREATE INDEX entity_relationship_subject_idx
    ON core.entity_relationship (subject_entity_id, relationship_type_code);
CREATE INDEX entity_relationship_object_idx
    ON core.entity_relationship (object_entity_id, relationship_type_code);
CREATE INDEX document_published_idx
    ON source.document (source_organization_id, published_on);
CREATE INDEX market_observation_date_idx
    ON market.market_observation (trade_date);
CREATE INDEX ownership_owned_idx
    ON ownership.ownership_position (owned_entity_id, as_of_date);

COMMIT;
