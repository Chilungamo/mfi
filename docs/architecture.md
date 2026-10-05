# AL-MFI-001 v0.2 — Architecture

## Modular monolith

One PostgreSQL database, one Python service. Modules are PostgreSQL schemas; the SQL migrations
under `db/migrations/` are the schema source of truth.

| Schema        | Responsibility                                                              |
|---------------|-----------------------------------------------------------------------------|
| `ref`         | Jurisdictions, currencies, units, sectors, canonical concepts, frameworks, taxonomies, dimensions |
| `source`      | Source organizations, documents, versions, locations, claims, claim evidence |
| `institution` | Administrative areas, organizational units, people, positions, appointments  |
| `core`        | Entities, identifiers, aliases, relationships, periods, observations, facts  |
| `reporting`   | Reporting entities, filings, contexts, filing dimensions, filing facts (XBRL)|
| `government`  | Programs, funds, revenues, expenditures, transfers, projects, procurement    |
| `market`      | Exchanges, securities, listings, market observations                        |
| `finance`     | Financial statements and line items                                         |
| `ownership`   | Ownership positions                                                         |
| `economy`     | Macroeconomic indicators and observations                                   |
| `analytics`   | Features, inferences, indexes, insights                                     |

## Lineage

```text
SOURCE → DOCUMENT → OBSERVATION → FACT → FEATURE → INFERENCE → INDEX → INSIGHT
```

* `source.document_location` pins every observation, claim, appointment and relationship to a
  page/table/excerpt of an exact `source.document_version` (content-hashed).
* `core.observation` is what a source *said*. `core.fact` is what AL-MFI has *validated*, linked
  back to its observations through `core.fact_observation`.
* `source.claim` holds statements (e.g. from newspapers) that are evidence, not truth.
  `source.claim_evidence` records corroboration/contradiction against other claims, facts or
  official documents.

## Subjects of observations and facts

From v0.2 an observation/fact must anchor to at least one of:

* `entity_id` — a legal entity (company, government, council, SOE…)
* `organizational_unit_id` — a ministry, department, office within an entity
* `administrative_area_id` — a region, district, city…

This is enforced by a `CHECK` constraint.

## Canonical concepts vs. taxonomies

`ref.concept` is the canonical ontology. Taxonomy concepts (`ref.taxonomy_concept`) belong to a
specific `ref.taxonomy_version` and are linked to canonical concepts by `ref.concept_mapping`,
which may be scoped by jurisdiction, entity kind and dimensional context. XBRL filings are kept
verbatim in `reporting.filing_fact` (including unresolved QNames) and optionally linked to the
`core.observation` they produce.

## Temporal institutions

Positions are stable offices; appointments are time-bounded tenures of a person in a position.
`institution.position_holders_on(date)` answers "who held which office on date X".
