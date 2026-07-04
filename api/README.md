# API REST (FastAPI)

Expõe os dados para o site e para terceiros. Documentação automática (Swagger)
em `/docs` e OpenAPI em `/openapi.json`.

## Rodar

```bash
pip install -r api/requirements.txt
export DATABASE_URL="postgresql://user:pass@localhost:5432/evpv"
uvicorn api.main:app --reload
# abra http://localhost:8000/docs
```

Ou via Docker (junto do banco):

```bash
docker compose up -d db api
# http://localhost:8000/docs
```

## Endpoints (v1)

| Método | Rota | O que retorna |
|---|---|---|
| GET | `/api/v1/people` | lista de parlamentares (filtros: `house`, `uf`, `party`) |
| GET | `/api/v1/people/{id}` | detalhe + votos, rebeliões e comparação com políticas |
| GET | `/api/v1/divisions` | lista de votações (filtros: `house`, `start_date`, `end_date`) |
| GET | `/api/v1/divisions/{id}` | votação + votos por pessoa, orientações e placar por partido |
| GET | `/api/v1/policies` | lista de políticas/temas |
| GET | `/api/v1/policies/{id}` | política + concordância de cada pessoa |
| GET | `/api/v1/parties` | lista de partidos |
| GET | `/api/v1/parties/{id}` | partido + concordância média por política |
| GET | `/api/v1/representatives?uf=SP` | "encontre seus representantes": deputados + senadores do estado |

## Chave de API (opcional)

Se a env `API_KEYS` estiver definida (lista separada por vírgula), a API passa a
exigir o header `X-API-Key`. Sem essa env, fica aberta (bom para dev; dados são
públicos de qualquer forma).

## Testes

```bash
pip install fastapi httpx
python -m api.test_api      # substitui o banco por fixtures; testa rotas e serialização
```

## Notas de implementação

- **Partido atual**: enquanto `party_membership` não for curado, é derivado do
  voto mais recente da pessoa (lateral join em `db.py`). Para a view
  `party_agreement`/`policy_people` funcionarem por partido, popule
  `party_membership` (ex.: `db/derive_memberships.sql`, a criar) ou ajuste as
  queries.
- Toda a fala com o banco fica em `api/db.py` (um único ponto), o que mantém as
  rotas finas e testáveis.
- **Verificação**: as rotas, a serialização (Pydantic) e a chave de API foram
  testadas com banco mockado. As queries SQL em si ainda **não** foram rodadas
  contra um Postgres real neste ambiente — valide na primeira carga.
