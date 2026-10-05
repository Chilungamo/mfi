-- ============================================================
-- AL-MFI-001 v0.2 — Reference seed
-- Idempotent: safe to re-run.
--
-- Deliberately does NOT seed taxonomy packages or concepts:
-- proprietary taxonomies are not copied into the repository, and
-- no Malawi national XBRL taxonomy is asserted here.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- Reporting frameworks
-- ------------------------------------------------------------

INSERT INTO ref.reporting_framework (code, name, issuer, basis_of_accounting, sector_scope, description) VALUES
    ('IFRS',         'IFRS Accounting Standards',        'IFRS Foundation / IASB', 'accrual', 'private',
        'Full IFRS for listed and public-interest entities.'),
    ('IFRS_SME',     'IFRS for SMEs',                    'IFRS Foundation / IASB', 'accrual', 'private',
        'IFRS for small and medium-sized entities.'),
    ('IPSAS',        'International Public Sector Accounting Standards', 'IPSASB', 'accrual', 'public',
        'Accrual-basis IPSAS.'),
    ('IPSAS_CASH',   'Cash Basis IPSAS',                 'IPSASB',                 'cash',    'public',
        'Financial Reporting under the Cash Basis of Accounting.'),
    ('MW_PUBLIC',    'Malawi public-sector reporting profile', NULL,               'mixed',   'public',
        'AL-MFI profile for Malawi central-government reporting; basis may vary by period.'),
    ('MW_LOCAL_GOV', 'Malawi local-government reporting profile', NULL,            'mixed',   'local_government',
        'AL-MFI profile for Malawi local-authority reporting; basis may vary by period.'),
    ('GFS',          'Government Finance Statistics',    'IMF',                    'accrual', 'public',
        'IMF GFSM statistical framework.')
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- Institutional relationship types
-- ------------------------------------------------------------

INSERT INTO ref.relationship_type (relationship_type_code, name, is_directed) VALUES
    ('part_of',           'Part of',                  true),
    ('reports_to',        'Reports to',               true),
    ('oversees',          'Oversees',                 true),
    ('funds',             'Funds',                    true),
    ('appoints',          'Appoints',                 true),
    ('board_member_of',   'Board member of',          true),
    ('director_of',       'Director of',              true),
    ('shareholder_of',    'Shareholder of',           true),
    ('contracted_by',     'Contracted by',            true),
    ('located_in',        'Located in',               true),
    ('family_of',         'Family relationship',      false)
ON CONFLICT (relationship_type_code) DO NOTHING;

-- ------------------------------------------------------------
-- Additional canonical concepts for public finance
-- ------------------------------------------------------------

INSERT INTO ref.concept (code, label, data_type, period_type, balance) VALUES
    ('tax_revenue',               'Tax revenue',                       'monetary', 'duration', 'credit'),
    ('grant_revenue',             'Grant revenue',                     'monetary', 'duration', 'credit'),
    ('total_expenditure',         'Total expenditure',                 'monetary', 'duration', 'debit'),
    ('compensation_of_employees', 'Compensation of employees',         'monetary', 'duration', 'debit'),
    ('capital_expenditure',       'Capital expenditure',               'monetary', 'duration', 'debit'),
    ('intergovernmental_transfer','Intergovernmental transfer',        'monetary', 'duration', NULL),
    ('public_debt',               'Public debt',                       'monetary', 'instant',  'credit'),
    ('budget_balance',            'Budget balance',                    'monetary', 'duration', NULL)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- Canonical (taxonomy-independent) dimensions
-- ------------------------------------------------------------

INSERT INTO ref.dimension (taxonomy_version_id, code, label) VALUES
    (NULL, 'consolidation',         'Consolidation scope'),
    (NULL, 'amount_kind',           'Budget / actual'),
    (NULL, 'economic_classification','Economic classification'),
    (NULL, 'funding_source',        'Funding source')
ON CONFLICT (taxonomy_version_id, code) DO NOTHING;

INSERT INTO ref.dimension_member (dimension_id, code, label, is_default)
SELECT d.dimension_id, m.code, m.label, m.is_default
FROM ref.dimension d
JOIN (VALUES
    ('consolidation', 'separate',       'Separate',        true),
    ('consolidation', 'consolidated',   'Consolidated',    false),
    ('amount_kind',   'budget',         'Approved budget', false),
    ('amount_kind',   'revised_budget', 'Revised budget',  false),
    ('amount_kind',   'actual',         'Actual',          true),
    ('funding_source','domestic',       'Domestic',        true),
    ('funding_source','donor',          'Donor',           false),
    ('funding_source','loan',           'Loan',            false)
) AS m (dimension_code, code, label, is_default) ON m.dimension_code = d.code
WHERE d.taxonomy_version_id IS NULL
ON CONFLICT (dimension_id, code) DO NOTHING;

-- ------------------------------------------------------------
-- Administrative geography: country, regions, districts
-- ------------------------------------------------------------

INSERT INTO institution.administrative_area (jurisdiction_id, area_level, code, name)
SELECT j.jurisdiction_id, 'country', 'MW', 'Malawi'
FROM ref.jurisdiction j WHERE j.code = 'MW'
ON CONFLICT (jurisdiction_id, area_level, code) DO NOTHING;

INSERT INTO institution.administrative_area (jurisdiction_id, area_level, code, name, parent_id)
SELECT j.jurisdiction_id, 'region', r.code, r.name, c.administrative_area_id
FROM ref.jurisdiction j
JOIN institution.administrative_area c
  ON c.jurisdiction_id = j.jurisdiction_id AND c.area_level = 'country' AND c.code = 'MW'
CROSS JOIN (VALUES
    ('MW-N', 'Northern Region'),
    ('MW-C', 'Central Region'),
    ('MW-S', 'Southern Region')
) AS r (code, name)
WHERE j.code = 'MW'
ON CONFLICT (jurisdiction_id, area_level, code) DO NOTHING;

INSERT INTO institution.administrative_area (jurisdiction_id, area_level, code, name, parent_id)
SELECT j.jurisdiction_id, 'district', d.code, d.name, r.administrative_area_id
FROM ref.jurisdiction j
CROSS JOIN (VALUES
    ('MW-N', 'MW-CT', 'Chitipa'),
    ('MW-N', 'MW-KR', 'Karonga'),
    ('MW-N', 'MW-LK', 'Likoma'),
    ('MW-N', 'MW-MZ', 'Mzimba'),
    ('MW-N', 'MW-NB', 'Nkhata Bay'),
    ('MW-N', 'MW-RU', 'Rumphi'),
    ('MW-C', 'MW-DE', 'Dedza'),
    ('MW-C', 'MW-DO', 'Dowa'),
    ('MW-C', 'MW-KS', 'Kasungu'),
    ('MW-C', 'MW-LI', 'Lilongwe'),
    ('MW-C', 'MW-MC', 'Mchinji'),
    ('MW-C', 'MW-NK', 'Nkhotakota'),
    ('MW-C', 'MW-NU', 'Ntcheu'),
    ('MW-C', 'MW-NI', 'Ntchisi'),
    ('MW-C', 'MW-SA', 'Salima'),
    ('MW-S', 'MW-BA', 'Balaka'),
    ('MW-S', 'MW-BL', 'Blantyre'),
    ('MW-S', 'MW-CK', 'Chikwawa'),
    ('MW-S', 'MW-CR', 'Chiradzulu'),
    ('MW-S', 'MW-MH', 'Machinga'),
    ('MW-S', 'MW-MG', 'Mangochi'),
    ('MW-S', 'MW-MU', 'Mulanje'),
    ('MW-S', 'MW-MW', 'Mwanza'),
    ('MW-S', 'MW-NE', 'Neno'),
    ('MW-S', 'MW-NS', 'Nsanje'),
    ('MW-S', 'MW-PH', 'Phalombe'),
    ('MW-S', 'MW-TH', 'Thyolo'),
    ('MW-S', 'MW-ZO', 'Zomba')
) AS d (region_code, code, name)
JOIN institution.administrative_area r
  ON r.jurisdiction_id = j.jurisdiction_id AND r.area_level = 'region' AND r.code = d.region_code
WHERE j.code = 'MW'
ON CONFLICT (jurisdiction_id, area_level, code) DO NOTHING;

-- ------------------------------------------------------------
-- Republic of Malawi as an organization (no departments hard-coded)
-- ------------------------------------------------------------

INSERT INTO core.entity (entity_kind, legal_name, short_name, jurisdiction_id)
SELECT 'government', 'Government of the Republic of Malawi', 'GoM', j.jurisdiction_id
FROM ref.jurisdiction j
WHERE j.code = 'MW'
  AND NOT EXISTS (
      SELECT 1 FROM core.entity e
      WHERE e.entity_kind = 'government' AND e.legal_name = 'Government of the Republic of Malawi'
  );

COMMIT;
