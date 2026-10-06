# ADR 0002 — Canonical concepts stay above taxonomies

**Status:** Accepted · 2026-10-06

## Context

The guide loads `ifrs-full:*` concepts directly as the platform's concepts and adds Malawi
extensions (`mw-co`, `mw-ps`, `mw-stat`) beside them. AL-MFI-001's founding principle is that a
canonical concept (e.g. `revenue`) sits *above* IFRS, IPSAS, GFS and Malawi public-sector
profiles, because councils, ministries and companies report the same economic idea under
different taxonomies and bases.

## Decision

* `ref.concept` remains the canonical ontology.
* IFRS, GFS and `mw-*` concepts are `ref.taxonomy_concept` rows under a versioned
  `ref.taxonomy_version`; a new IFRS release is a new version, never an overwrite.
* Calculation relationships (parent total, weighted children) are stored per taxonomy version
  in a new `ref.taxonomy_relationship` table — the tree the guide's `calc_consistency` test walks.
* `ref.concept_mapping` links taxonomy concepts to canonical concepts and, via the guide's rule,
  **only `exact` mappings may be summed automatically**.
* Reported facts keep the taxonomy concept they were tagged with, so nothing is lost if a
  canonical mapping is later revised.

## Consequences

* One extra join (taxonomy concept → canonical concept) in marts; dbt staging models absorb it.
* Cross-taxonomy views (a council in GFS terms, a company in IFRS terms, both under `revenue`)
  come for free, which is the main analytical goal of AL-MFI.
