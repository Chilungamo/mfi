-- ============================================================
-- AL-MFI-001 — Schema checks
-- Each query returns zero rows when the database is healthy.
-- ============================================================

-- 1. Required schemas exist.
SELECT 'missing schema: ' || s AS problem
FROM unnest(ARRAY[
    'ref', 'source', 'institution', 'core', 'reporting', 'government',
    'market', 'finance', 'ownership', 'economy', 'analytics'
]) AS s
WHERE NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = s);

-- 2. Appointments that overlap for the same substantive position.
SELECT 'overlapping substantive appointments: ' || a1.appointment_id || ' / ' || a2.appointment_id AS problem
FROM institution.appointment a1
JOIN institution.appointment a2
  ON a1.position_id = a2.position_id
 AND a1.appointment_id < a2.appointment_id
 AND a1.appointment_kind = 'substantive'
 AND a2.appointment_kind = 'substantive'
 AND daterange(a1.start_date, a1.end_date, '[]') && daterange(a2.start_date, a2.end_date, '[]');

-- 3. Verified claims with no supporting evidence.
SELECT 'verified claim without evidence: ' || c.claim_id AS problem
FROM source.claim c
WHERE c.verification_status IN ('verified', 'corroborated')
  AND NOT EXISTS (
      SELECT 1 FROM source.claim_evidence e
      WHERE e.claim_id = c.claim_id AND e.relation = 'corroborates'
  );

-- 4. Facts without any linked observation (broken lineage).
SELECT 'fact without observation: ' || f.fact_id AS problem
FROM core.fact f
WHERE NOT EXISTS (SELECT 1 FROM core.fact_observation fo WHERE fo.fact_id = f.fact_id);

-- 5. Organizational-unit cycles.
WITH RECURSIVE walk (start_id, unit_id, depth) AS (
    SELECT organizational_unit_id, parent_unit_id, 1
    FROM institution.organizational_unit
    WHERE parent_unit_id IS NOT NULL
    UNION ALL
    SELECT w.start_id, ou.parent_unit_id, w.depth + 1
    FROM walk w
    JOIN institution.organizational_unit ou ON ou.organizational_unit_id = w.unit_id
    WHERE ou.parent_unit_id IS NOT NULL AND w.depth < 64
)
SELECT DISTINCT 'organizational unit cycle at: ' || start_id AS problem
FROM walk
WHERE unit_id = start_id;
