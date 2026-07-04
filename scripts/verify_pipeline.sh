#!/usr/bin/env bash
# Verificação END-TO-END contra um Postgres REAL:
# prova a cadeia schema -> ingestão (2 casas) -> filiações -> política -> scores.
#
# Requer: DATABASE_URL apontando para um Postgres acessível, e as deps Python
#         (pip install -r ingest/requirements.txt).
# Use um intervalo pequeno para rodar rápido.
#
#   export DATABASE_URL="postgresql://evpv:evpv@localhost:5432/evpv"
#   bash scripts/verify_pipeline.sh
#   # ou com datas próprias:  START=2025-03-01 END=2025-03-15 bash scripts/verify_pipeline.sh

set -euo pipefail
: "${DATABASE_URL:?defina DATABASE_URL antes de rodar}"
START="${START:-2025-03-01}"
END="${END:-2025-03-15}"

echo "==> 1/7 schema + views"
psql "$DATABASE_URL" -q -f db/schema.sql
psql "$DATABASE_URL" -q -f db/views_agreement.sql

echo "==> 2/7 ingestão Câmara ($START..$END, plenário)"
python ingest/ingest_camara.py --start "$START" --end "$END" --plen-only

echo "==> 3/7 ingestão Senado ($START..$END)"
python ingest/ingest_senado.py --start "$START" --end "$END"

echo "==> 4/7 derivar filiações partidárias"
psql "$DATABASE_URL" -q -f db/derive_memberships.sql

echo "==> 5/7 política de exemplo"
psql "$DATABASE_URL" -q -f db/seed_example_policy.sql

echo "==> 6/7 calcular agreement scores"
python scoring/score.py

echo "==> 7/7 sanidade (as contagens devem ser > 0 onde houver dados no período)"
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
\echo -- divisões por casa:
SELECT house, count(*) AS divisoes FROM division GROUP BY house;
\echo -- votos por opção:
SELECT option, count(*) AS votos FROM vote GROUP BY option ORDER BY 2 DESC;
\echo -- orientações de partido registradas:
SELECT count(*) AS orientacoes FROM party_orientation;
\echo -- pessoas com filiação atual:
SELECT count(*) AS filiacoes_atuais FROM party_membership WHERE end_date IS NULL;
\echo -- scores gravados:
SELECT count(*) AS scores FROM agreement_score;
SQL

echo ""
echo "OK - a cadeia completa rodou contra o banco. Suba a API para conferir:"
echo "     uvicorn api.main:app --reload   ->  http://localhost:8000/docs"
