# Motor de agreement score

Transforma votos brutos em "votou consistentemente a favor de X" — por pessoa
e (via view) por partido. É a peça central, no espírito do TheyVoteForYou.

## Ordem de execução

```bash
# 1. schema + view (uma vez)
psql "$DATABASE_URL" -f db/schema.sql
psql "$DATABASE_URL" -f db/views_agreement.sql

# 2. carregar dados (ver ingest/)
python ingest/ingest_camara.py --start 2025-01-01 --end 2025-12-31 --plen-only
python ingest/ingest_senado.py --start 2025-01-01 --end 2025-12-31

# 3. criar uma política (curadoria real; ou o seed de exemplo)
psql "$DATABASE_URL" -f db/seed_example_policy.sql

# 4. calcular os scores
python scoring/score.py

# 5. consultar
#   por pessoa:
psql "$DATABASE_URL" -c "SELECT person_id, score, category FROM agreement_score WHERE policy_id=1 ORDER BY score DESC LIMIT 20;"
#   por partido:
psql "$DATABASE_URL" -c "SELECT party_sigla, avg_score, n_people FROM party_agreement WHERE policy_id=1 ORDER BY avg_score DESC;"
```

Sem banco, dá para validar a lógica pura:

```bash
python scoring/score.py --self-test
```

## Como o score é calculado

Para cada votação da política:
- a política define a **postura** (`stance`): `for` = votar SIM apoia; `against`
  = votar NÃO apoia.
- a votação é `normal` ou `strong` (voto forte pesa mais).
- votos decisivos são só **sim/não**; abstenção, obstrução e ausência entram com
  peso reduzido e valor neutro.

`score = 100 × (soma ponderada de concordâncias) / (soma ponderada do possível)`,
mapeado para 8 categorias (de "consistentemente a favor" a "consistentemente
contra", mais "sem dados suficientes").

## Metodologia — nota honesta

Os pesos e limiares são **nossos, explícitos e ajustáveis** (constantes no topo
do `score.py`): `WEIGHT`, `ABSENCE_FACTOR`, `ABSENCE_CREDIT`, `MIN_ATTENDED` e os
cortes de categoria. A abordagem é **inspirada** no Public Whip/TVFY, mas **não é
uma réplica bit-a-bit** do algoritmo deles. Para paridade exata com o
TheyVoteForYou, é preciso portar e conferir a implementação open-source deles.
O importante para a confiança do projeto: a metodologia é transparente e
auditável — documente-a publicamente e mostre as votações por trás de cada score.

## Verificação

`score.py --self-test` roda asserções da lógica pura (100%→consistentemente a
favor, 0%→contra, 50%→mistura, domínio do voto forte, diluição por ausência,
`not_enough` com poucos votos). A parte de banco usa UPSERT idempotente.
