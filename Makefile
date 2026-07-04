# Eles Votam Por Você — comandos reprodutíveis
# Requer DATABASE_URL, ex.:
#   export DATABASE_URL="postgresql://evpv:evpv@localhost:5432/evpv"
#
# Sobrescreva o período:  make load START=2025-01-01 END=2025-06-30

START ?= 2025-01-01
END   ?= 2025-12-31

.PHONY: help schema load load-camara load-senado derive seed score api test verify

help:
	@echo "Alvos: schema | load | score | api | test | verify"
	@echo "  schema  - cria tabelas e views"
	@echo "  load    - ingestão das duas casas + deriva filiações ($(START)..$(END))"
	@echo "  score   - calcula agreement scores"
	@echo "  api     - sobe a API (http://localhost:8000/docs)"
	@echo "  test    - testes sem banco (score self-test + api)"
	@echo "  verify  - checagem end-to-end contra Postgres real"

schema:
	psql "$(DATABASE_URL)" -f db/schema.sql
	psql "$(DATABASE_URL)" -f db/views_agreement.sql

load-camara:
	python ingest/ingest_camara.py --start $(START) --end $(END) --plen-only

load-senado:
	python ingest/ingest_senado.py --start $(START) --end $(END)

derive:
	psql "$(DATABASE_URL)" -f db/derive_memberships.sql

load: load-camara load-senado derive

seed:
	psql "$(DATABASE_URL)" -f db/seed_example_policy.sql

score:
	python scoring/score.py

api:
	uvicorn api.main:app --reload

test:
	python scoring/score.py --self-test
	python -m api.test_api

verify:
	bash scripts/verify_pipeline.sh
