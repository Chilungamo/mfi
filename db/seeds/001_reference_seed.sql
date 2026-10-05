-- ============================================================
-- AL-MFI-001 v0.1 — Reference seed
-- Idempotent: safe to re-run.
-- ============================================================

BEGIN;

INSERT INTO ref.jurisdiction (code, name) VALUES
    ('MW', 'Republic of Malawi')
ON CONFLICT (code) DO NOTHING;

INSERT INTO ref.currency (currency_code, name, minor_units) VALUES
    ('MWK', 'Malawian Kwacha', 2),
    ('USD', 'United States Dollar', 2),
    ('ZAR', 'South African Rand', 2),
    ('EUR', 'Euro', 2),
    ('GBP', 'Pound Sterling', 2)
ON CONFLICT (currency_code) DO NOTHING;

INSERT INTO ref.unit (unit_code, name, unit_kind, currency_code, scale) VALUES
    ('MWK',      'Malawian Kwacha',               'monetary', 'MWK', 0),
    ('MWK_000',  'Malawian Kwacha (thousands)',   'monetary', 'MWK', 3),
    ('MWK_MN',   'Malawian Kwacha (millions)',    'monetary', 'MWK', 6),
    ('MWK_BN',   'Malawian Kwacha (billions)',    'monetary', 'MWK', 9),
    ('USD',      'US Dollar',                     'monetary', 'USD', 0),
    ('USD_MN',   'US Dollar (millions)',          'monetary', 'USD', 6),
    ('PCT',      'Percent',                       'percent',  NULL,  0),
    ('RATIO',    'Ratio',                         'ratio',    NULL,  0),
    ('COUNT',    'Count',                         'count',    NULL,  0),
    ('SHARES',   'Shares',                        'count',    NULL,  0),
    ('INDEX_PT', 'Index points',                  'index',    NULL,  0)
ON CONFLICT (unit_code) DO NOTHING;

INSERT INTO ref.concept (code, label, data_type, period_type, balance) VALUES
    ('revenue',                 'Revenue',                          'monetary', 'duration', 'credit'),
    ('profit_before_tax',       'Profit before tax',                'monetary', 'duration', 'credit'),
    ('profit_after_tax',        'Profit after tax',                 'monetary', 'duration', 'credit'),
    ('total_assets',            'Total assets',                     'monetary', 'instant',  'debit'),
    ('total_liabilities',       'Total liabilities',                'monetary', 'instant',  'credit'),
    ('total_equity',            'Total equity',                     'monetary', 'instant',  'credit'),
    ('cash_and_equivalents',    'Cash and cash equivalents',        'monetary', 'instant',  'debit'),
    ('net_cash_from_operations','Net cash from operating activities','monetary','duration', 'debit'),
    ('loans_and_advances',      'Loans and advances to customers',  'monetary', 'instant',  'debit'),
    ('customer_deposits',       'Customer deposits',                'monetary', 'instant',  'credit'),
    ('earnings_per_share',      'Earnings per share',               'decimal',  'duration', NULL),
    ('dividend_per_share',      'Dividend per share',               'decimal',  'duration', NULL),
    ('shares_outstanding',      'Shares outstanding',               'integer',  'instant',  NULL),
    ('inflation_rate',          'Inflation rate',                   'percent',  'duration', NULL),
    ('policy_rate',             'Policy rate',                      'percent',  'instant',  NULL),
    ('exchange_rate',           'Exchange rate',                    'decimal',  'instant',  NULL),
    ('gdp_nominal',             'Nominal GDP',                      'monetary', 'duration', NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO ref.relationship_type (relationship_type_code, name, is_directed) VALUES
    ('parent_of',      'Parent of',                     true),
    ('subsidiary_of',  'Subsidiary of',                 true),
    ('associate_of',   'Associate of',                  true),
    ('regulated_by',   'Regulated by',                  true),
    ('supervises',     'Supervises',                    true),
    ('audited_by',     'Audited by',                    true),
    ('listed_on',      'Listed on',                     true),
    ('supplier_to',    'Supplier to',                   true),
    ('lender_to',      'Lender to',                     true),
    ('successor_of',   'Successor of',                  true),
    ('related_party',  'Related party',                 false)
ON CONFLICT (relationship_type_code) DO NOTHING;

INSERT INTO source.source_organization (name, source_kind, website, reliability_tier) VALUES
    ('Reserve Bank of Malawi',           'regulator',          'https://www.rbm.mw',  1),
    ('National Statistical Office',      'statistical_agency', 'https://www.nsomalawi.mw', 1),
    ('Malawi Stock Exchange',            'exchange',           'https://mse.co.mw',   1),
    ('Ministry of Finance',              'government',         NULL,                  1)
ON CONFLICT (name) DO NOTHING;

INSERT INTO market.exchange (mic, name, jurisdiction_id)
SELECT 'XMSW', 'Malawi Stock Exchange', j.jurisdiction_id
FROM ref.jurisdiction j WHERE j.code = 'MW'
ON CONFLICT (mic) DO NOTHING;

COMMIT;
