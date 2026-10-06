.PHONY: install services-up services-down db-init api test test-integration lint format typecheck check

install:
	uv sync --extra dev

services-up:
	docker compose up -d

services-down:
	docker compose down

db-init:
	uv run python scripts/init_db.py

api:
	uv run uvicorn app.main:app --reload

test:
	uv run pytest

# Needs an empty, disposable database, e.g.
# AL_MFI_TEST_DATABASE_URL=postgresql://al_mfi:al_mfi@localhost:5432/al_mfi_test
test-integration:
	uv run pytest tests/integration

lint:
	uv run ruff check .
	uv run ruff format --check .

format:
	uv run ruff format .

typecheck:
	uv run pyright

check: lint typecheck test
