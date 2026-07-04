# Ingestão — Câmara dos Deputados

Primeiro pedaço executável do projeto: carrega votações da Câmara (voto por
pessoa + orientação por partido) no schema Postgres unificado.

## 1. Subir o banco

```bash
createdb evpv
psql "postgresql://user:pass@localhost:5432/evpv" -f ../db/schema.sql
```

## 2. Instalar dependências

```bash
pip install -r requirements.txt
```

## 3. Testar o parsing sem banco (recomendado antes da 1ª carga)

```bash
python ingest_camara.py --start 2025-12-17 --end 2025-12-17 --limit 5 --dry-run
```

## 4. Carga real

```bash
export DATABASE_URL="postgresql://user:pass@localhost:5432/evpv"

# período completo:
python ingest_camara.py --start 2025-12-01 --end 2025-12-18

# só Plenário (votos nominais + orientação de bancada):
python ingest_camara.py --start 2025-12-01 --end 2025-12-18 --plen-only
```

Para o job diário, agende algo como
`python ingest_camara.py --start $(date -d '2 days ago' +%F) --end $(date +%F)`.

## O que ele grava

| Tabela | Conteúdo |
|---|---|
| `division` | a votação (data, órgão, resultado, nominal?) |
| `vote` | voto de cada deputado (com o partido **no momento do voto**) |
| `party_orientation` | orientação oficial de cada partido/bloco (Plenário) |
| `party_vote_tally` | placar agregado por partido (materializado) |
| `person`, `party`, `proposition` | dados de referência (upsert) |

## Notas / limitações

- **Idempotente**: rodar de novo o mesmo período não duplica (usa `ON CONFLICT`).
- **nominal vs simbólica**: a API não traz um flag direto; usamos a heurística
  "tem voto individual registrado ⇒ nominal". Revisar se precisar de rigor.
- **Proposição às vezes nula**: por decisão da própria Câmara, muitas votações
  não identificam a proposição votada — `division.proposition_id` pode ficar nulo.
- **Rate limit**: há `throttle` embutido; aumente se tomar HTTP 429.
## Senado (`ingest_senado.py`)

Mesma ideia, usando o endpoint **moderno** `GET /dadosabertos/votacao` (os antigos
por-senador estão depreciados e apontam para ele). Pede por janelas mensais.

```bash
python ingest_senado.py --start 2024-01-01 --end 2024-12-31 --dry-run
python ingest_senado.py --start 2024-01-01 --end 2024-12-31   # com DATABASE_URL
```

Diferenças em relação à Câmara:
- A resposta é uma **lista camelCase**; o voto vem em `siglaVotoParlamentar`.
- `/votacao` já traz **só votos nominais** (por isso `is_nominal=TRUE` sempre).
- **Orientação de bancada** do Senado (`/plenario/votacao/orientacaoBancada/{data}`)
  ainda **não** é ingerida: o endpoint existe e não está depreciado, mas retornou
  vazio na data amostrada e o formato precisa ser confirmado numa data populada.
  Por enquanto a posição do partido no Senado vem do **placar agregado**
  (`party_vote_tally`). Implementar a orientação é o próximo incremento.
- Códigos de voto do Senado além de Sim/Não/Abstenção (ex.: `AP`, `NCom`,
  `Presidente (art. 51 RISF)`) são mapeados para `ausente`/`outro` — revisar a
  lista `ABSENCE_CODES` se precisar de precisão.

## Estado de verificação

- `ingest_camara.py`: sintaxe OK; funções de normalização/placar testadas
  contra **dados reais** da API (mapeamento de voto, blocos, placar por partido).
- `../db/schema.sql`: sintaxe Postgres validada pelo parser oficial (libpg_query).
- As chamadas HTTP ao vivo foram confirmadas via inspeção direta dos endpoints,
  mas não foram exercidas de ponta a ponta contra um Postgres real ainda —
  faça a primeira carga num banco de teste antes de produção.
