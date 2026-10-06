# Architecture Decision Records

Short records of decisions that are expensive to reverse. Each states the context, the decision
and its consequences. A decision is changed by adding a new ADR that supersedes the old one,
never by editing history.

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-merge-implementation-guide.md) | Merge the Malawi Markets Data implementation guide into AL-MFI-001 | Accepted |
| [0002](0002-canonical-concepts-above-taxonomies.md) | Canonical concepts stay above taxonomies | Accepted |
| [0003](0003-uuid-keys.md) | Keep UUID primary keys | Accepted |
| [0004](0004-layout-tooling-migrations.md) | Keep `app/`, adopt uv and Python 3.12, keep `init_db.py` | Accepted |
| [0005](0005-forward-only-migrations.md) | Forward-only numbered migrations | Accepted |
| [0006](0006-append-only-facts.md) | Append-only facts enforced in the database | Accepted |
