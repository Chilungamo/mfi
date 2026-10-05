.PHONY: install db-up db-down db-init api test lint typecheck check

install:
	python -m pip install -e '.[dev,ingestion]'

db-up:
	docker compose up -d postgres

db-down:
	docker compose down

db-init:
	python scripts/init_db.py

api:
	uvicorn app.main:app --reload

test:
	pytest

lint:
	ruff check .

format:
	ruff format .

typecheck:
	pyright

check: lint typecheck test
