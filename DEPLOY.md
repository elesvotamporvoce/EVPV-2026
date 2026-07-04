# Deploy / execução

Duas formas de rodar o projeto de ponta a ponta (banco real + acesso à API).

## A) Local com Docker (mais rápido para testar hoje)

Pré-requisito: Docker + Docker Compose.

```bash
cp .env.example .env          # ajuste a senha se quiser

# 1. Sobe o Postgres (o schema.sql é carregado automaticamente na 1ª vez)
docker compose up -d db

# 2. (opcional) valida o parsing sem gravar
docker compose run --rm ingest --start 2025-12-17 --end 2025-12-17 --dry-run

# 3. Carga real
docker compose run --rm ingest --start 2025-12-01 --end 2025-12-18 --plen-only

# 4. Conferir no banco
docker compose exec db psql -U evpv -d evpv -c \
  "SELECT body, count(*) FROM division GROUP BY body ORDER BY 2 DESC LIMIT 10;"
docker compose exec db psql -U evpv -d evpv -c \
  "SELECT option, count(*) FROM vote GROUP BY option ORDER BY 2 DESC;"
```

Notas:
- O `schema.sql` só roda automaticamente quando o volume é criado do zero. Para
  recarregar o schema, use `docker compose down -v` (apaga os dados) ou rode o
  `psql -f db/schema.sql` manualmente — mas o script é idempotente, então
  normalmente não é preciso.
- Para rodar o script SEM docker, aponte `DATABASE_URL` para o Postgres e use
  `python ingest/ingest_camara.py ...` (veja `ingest/README.md`).

## B) Nuvem: Postgres gerenciado + GitHub Actions (job diário)

1. **Crie um Postgres gerenciado** (Neon, Supabase, Railway ou Render). Copie a
   *connection string* (algo como `postgresql://user:pass@host:5432/db`).
2. **Carregue o schema** uma vez:
   ```bash
   psql "sua-connection-string" -f db/schema.sql
   ```
3. **Guarde o segredo no GitHub**: repositório → Settings → Secrets and variables
   → Actions → New repository secret → nome `DATABASE_URL`, valor = a connection
   string.
4. **Pronto.** O workflow `.github/workflows/daily-ingest.yml` roda todo dia às
   14:00 UTC (~11:00 BRT), carregando os últimos 3 dias. Você também pode
   disparar manualmente em Actions → "Ingestão diária — Câmara" → Run workflow,
   informando `start`/`end`.

> Dica: o runner do GitHub Actions tem internet aberta, então a própria carga
> diária roda lá — você não precisa manter servidor.

## Ressalvas honestas

- Os **planos gratuitos e limites** desses serviços mudam com frequência e podem
  ter mudado desde a redação deste guia — confirme no site de cada um.
- As **versões das actions** (`checkout@v4`, `setup-python@v5`) e a imagem
  `postgres:16` são as atuais no momento da escrita; podem ter avançado. Ajuste
  se necessário.
- O horário do cron do GitHub Actions é sempre **UTC** e execuções agendadas
  podem atrasar em horários de pico — não conte com precisão de minutos.
- Antes de produção, rode a carga primeiro num **banco de teste** e confira os
  números.
