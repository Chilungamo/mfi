# AL-MFI-001 — Canonical Malawi Financial & Economic Intelligence Data Model

**Version:** 0.2  
**Status:** Architecture foundation — revised and extended  
**Architecture:** PostgreSQL-first, modular, provenance-preserving, institution-aware, XBRL-ready  
**Lineage:** `SOURCE → DOCUMENT → OBSERVATION → FACT → FEATURE → INFERENCE → INDEX → INSIGHT`

AL-MFI-001 is the canonical data-model foundation for the Malawi Financial & Economic Intelligence Infrastructure.

## What changed in v0.2

Version 0.2 keeps the v0.1 financial-data core and adds the structures needed to represent Malawi as an interconnected economic and institutional system:

1. **Central government, ministries, departments and agencies** can be represented as organizations and organizational units.
2. **Local government and district-level information** can be represented through administrative areas and organizational units.
3. **Officials and decision-makers** are first-class people with time-bounded positions and appointments.
4. **Institutional claims** can be extracted from newspapers and other documents without automatically treating them as verified facts.
5. **Reporting frameworks and taxonomy versions** are first-class reference data.
6. **XBRL concepts, mappings, dimensions, members, filings and contexts** are modeled from inception.
7. **Government finance** has explicit structures for programs, funds, revenues, expenditures, transfers, projects and procurement events.
8. Generic observations/facts can now be attached to an **organizational unit** and/or **administrative area**, not only to a legal entity.

## Core architectural principle

The platform is **not** a database of financial statements. It is a structured representation of Malawi's economic institutions and the information they produce.

The central abstraction is:

```text
CANONICAL ECONOMIC CONCEPT
        │
        ├── IFRS / IFRS for SMEs
        ├── IPSAS
        ├── Malawi public-sector profile
        ├── Malawi local-government profile
        └── future jurisdictional / regulatory taxonomies
                    │
                    ▼
              XBRL / digital filing
```

The canonical ontology therefore sits **above** any one accounting or regulatory taxonomy.

## Layers

### `ref`
Reference and semantic registry:
- jurisdictions
- currencies
- units
- sectors
- canonical concepts
- relationship types
- reporting frameworks
- taxonomies and taxonomy versions
- taxonomy concepts and mappings
- dimensions and dimension members

### `source`
Evidence and institutional knowledge:
- source organizations
- documents
- document versions
- document locations
- claims
- claim-to-claim evidence relationships

A newspaper article is a source document. A statement in that article becomes a claim. The claim can later be corroborated, contradicted or verified against official evidence.

### `institution`
Institutional structure:
- administrative areas
- organizational units
- people
- positions
- appointments
- institutional relationships

This supports temporal questions such as:

> Who was District Commissioner for District X on 15 March 2025?

and:

> Which ministry/department did that office belong to at that time?

### `core`
Canonical economic facts:
- entities
- identifiers
- aliases
- relationships
- periods
- observations
- validated facts

Observations/facts can now carry organizational-unit and administrative-area dimensions.

### `reporting`
Digital reporting and XBRL ingestion:
- reporting entities
- filings
- filing contexts
- filing facts
- filing dimensions

The model is designed so an XBRL filing can be preserved while still mapping its reported concepts into AL-MFI's canonical concept layer.

### `government`
Public-finance and public-project structures:
- programs
- funds
- revenues
- expenditures
- transfers
- projects
- procurement events

### `market`
- exchanges
- securities
- listings
- market observations

### `finance`
- financial statements
- financial line items

### `ownership`
- ownership positions

### `economy`
- macroeconomic indicators
- indicator observations

### `analytics`
- features
- inferences
- indexes
- insights

## XBRL design decision

XBRL is modeled from the beginning, but AL-MFI does **not** make IFRS or any other taxonomy the canonical database ontology.

A canonical concept such as `revenue` can map to different taxonomy concepts depending on:

- reporting framework
- taxonomy
- taxonomy version
- reporting jurisdiction
- entity type
- dimensional context

This is important because IFRS itself uses formal taxonomy architecture, including concepts, dimensions/axes, members, tables/hypercubes and versioned entry points. citeturn0search1turn0search3

The same design principle is useful for government reporting. GASB's current digital-reporting project is explicitly considering how government GAAP requirements, optionality, entity-specific line items and basis of accounting should be represented in a digital taxonomy. AL-MFI adopts that general architectural lesson without copying GASB's taxonomy. citeturn0search0

## Malawi public-sector design

The schema deliberately does not assume that central government and local government are identical reporting entities. It supports:

```text
Republic of Malawi
├── Central Government
│   ├── Ministries
│   ├── Departments
│   ├── Agencies
│   └── Constitutional / statutory bodies
│
├── Local Government
│   ├── District Councils
│   ├── City Councils
│   ├── Municipal Councils
│   └── other local authorities
│
└── State-owned / public-interest entities
```

Administrative geography is separate from organizational structure. This prevents a district, a district council and a government department located in that district from being incorrectly treated as the same kind of object.

Malawi's public-sector reporting context is also modeled separately from private-sector IFRS reporting. Current official material indicates Malawi's government has been moving toward accrual-based IPSAS, while local authorities have been moving toward full IPSAS accrual reporting. citeturn0search14

## Officials and influence

The model stores **formal roles and evidence**, not an arbitrary permanent list of “influential people.”

Influence can later be derived from:

- office held
- decision-making authority
- institutional relationships
- appointment history
- procurement relationships
- ownership relationships
- board positions
- policy/regulatory roles
- repeated source evidence

This makes influence a researchable feature rather than an ungrounded label.

## Newspaper corpus

The source layer is intentionally broad enough for:

- Daily Times
- The Nation
- government releases
- gazettes
- parliamentary documents
- annual reports
- audit reports
- regulatory notices
- company filings
- statistical releases
- other licensed or public sources

However, **news content is evidence, not automatically truth**. A newspaper statement should normally flow through:

```text
ARTICLE
  ↓
CLAIM
  ↓
CORROBORATION / CONTRADICTION
  ↓
VERIFIED FACT (where evidence supports it)
```

This allows the future corpus/search system to become institutional knowledge without contaminating the canonical fact layer with unverified reporting.

## Installation

Apply the original model first, then the v0.2 extension:

```bash
createdb malawi_finintel
psql "$DATABASE_URL" -f db/migrations/001_al_mfi_001_canonical_model.sql
psql "$DATABASE_URL" -f db/migrations/002_al_mfi_001_v02_extensions.sql
psql "$DATABASE_URL" -f db/seeds/001_reference_seed.sql
psql "$DATABASE_URL" -f db/seeds/002_v02_reference_seed.sql
```

## What v0.2 deliberately does NOT do

- It does not copy proprietary IFRS taxonomy packages into the repository.
- It does not claim that Malawi already has a national XBRL taxonomy where that has not been verified.
- It does not automatically classify people as “influential.”
- It does not turn newspaper claims into facts without verification.
- It does not create a separate database for government.
- It does not require a graph database.
- It does not hard-code Malawi-specific government departments into the schema.

## Next vertical slice

The next implementation should be a **real Malawi institutional-data slice**, not another abstract schema exercise:

```text
Official government / annual report / audit source
        ↓
source.document + provenance
        ↓
organization + organizational unit + district/area
        ↓
observation / claim
        ↓
canonical concept / reporting framework
        ↓
validated fact
        ↓
API
        ↓
research-facing company / institution / district view
```

The first production-quality data should prove that one source can simultaneously contribute financial, institutional, geographic and temporal information.

## Repository scaffold v0.2

The v0.2 implementation repository is organized as a modular monolith:

```text
app/          FastAPI + application services + ingestion contracts
db/           PostgreSQL migrations, seeds and schema checks
tests/        unit/integration test suites
docs/         architecture and operational documentation
scripts/      local database/bootstrap commands
config/       environment/configuration space
```

The canonical SQL migrations remain the schema source of truth. The Python layer deliberately does
not duplicate every database table as ORM models yet; this keeps the infrastructure model explicit
until real application workflows justify richer domain models.
