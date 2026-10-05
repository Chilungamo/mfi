"""Apply migrations, seeds and schema checks to the configured database, in order.

Usage: python scripts/init_db.py [--skip-seeds] [--skip-checks]
"""

import argparse
import sys
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS = ROOT / "db" / "migrations"
SEEDS = ROOT / "db" / "seeds"
CHECKS = ROOT / "db" / "checks"


def _dsn() -> str:
    sys.path.insert(0, str(ROOT))
    from app.config import get_settings

    # psycopg expects a libpq URL, not a SQLAlchemy dialect URL.
    return get_settings().database_url.replace("postgresql+psycopg://", "postgresql://", 1)


def sql_files(directory: Path) -> list[Path]:
    return sorted(directory.glob("*.sql"))


def apply(conn: psycopg.Connection, path: Path) -> None:
    print(f"  applying {path.relative_to(ROOT)}")
    conn.execute(path.read_text(encoding="utf-8"))  # type: ignore[arg-type]


def run_checks(conn: psycopg.Connection) -> int:
    problems = 0
    for path in sql_files(CHECKS):
        for statement in _split_statements(path.read_text(encoding="utf-8")):
            for (problem,) in conn.execute(statement).fetchall():  # type: ignore[arg-type]
                print(f"  CHECK FAILED: {problem}")
                problems += 1
    return problems


def _split_statements(sql: str) -> list[str]:
    lines = [line for line in sql.splitlines() if not line.lstrip().startswith("--")]
    return [stmt.strip() for stmt in "\n".join(lines).split(";") if stmt.strip()]


def ensure_migration_table(conn: psycopg.Connection) -> set[str]:
    conn.execute(
        "CREATE TABLE IF NOT EXISTS public.schema_migration ("
        " filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"
    )
    return {row[0] for row in conn.execute("SELECT filename FROM public.schema_migration")}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-seeds", action="store_true")
    parser.add_argument("--skip-checks", action="store_true")
    args = parser.parse_args(argv)

    with psycopg.connect(_dsn(), autocommit=True) as conn:
        applied = ensure_migration_table(conn)
        print("Migrations:")
        for path in sql_files(MIGRATIONS):
            if path.name in applied:
                print(f"  skip {path.name} (already applied)")
                continue
            apply(conn, path)
            conn.execute("INSERT INTO public.schema_migration (filename) VALUES (%s)", (path.name,))

        if not args.skip_seeds:
            print("Seeds:")
            for path in sql_files(SEEDS):
                apply(conn, path)

        if not args.skip_checks:
            print("Checks:")
            problems = run_checks(conn)
            if problems:
                print(f"{problems} check(s) failed")
                return 1
            print("  all checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
