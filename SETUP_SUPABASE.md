# Setup Supabase + GitHub Actions (sem instalar nada local)

Objetivo: banco no **Supabase**, e a carga + scores rodando no **GitHub Actions**
contra ele. Você não instala Docker, psql nem Python na sua máquina.

## ⚠️ Segurança primeiro

- **Nunca** cole a senha do banco em chat, em issues, ou em arquivos versionados.
- A senha vai só em: **Secret do GitHub** e, se for rodar local, no `.env`
  (que está no `.gitignore`).
- Se a senha já apareceu em algum lugar público, **rode "Reset database password"**
  no painel do Supabase.

## Passo 1 — Pegar a connection string CERTA

No painel do Supabase: **Project → Connect** (ou Settings → Database).

Há dois tipos de string — a escolha importa:

- **Direct connection** (`db.rvcfbklnwglmhoxfexvj.supabase.co:5432`) — foi a que
  você me mandou. Boa para uso local. **Porém** a conexão direta hoje costuma ser
  **só IPv6**, e o runner do GitHub Actions é **IPv4** — então ela pode **não
  conectar** a partir do Actions.
- **Connection pooler** (algo como `...pooler.supabase.com:6543`, "Transaction"
  ou "Session") — é **IPv4** e é a recomendada para GitHub Actions e para apps.

👉 Para o GitHub Actions, **copie a string do POOLER** no painel. Acrescente
`?sslmode=require` se ela ainda não tiver (o Supabase exige SSL).

> Não sei o host/porta exatos do seu pooler (varia por região e o Supabase muda
> isso às vezes) — **copie a string exata do painel**, não monte à mão.

## Passo 2 — Guardar como Secret no GitHub

No repositório: **Settings → Secrets and variables → Actions → New repository
secret**.

- Nome: `DATABASE_URL`
- Valor: a string do **pooler** com a senha real e `?sslmode=require`.

## Passo 3 — Primeira carga (tudo na nuvem)

**Actions → "Ingestão diária — Câmara + Senado" → Run workflow.** Preencha
`start` e `end` (ex.: `2025-01-01` a `2025-03-31` para testar rápido) e rode.

O workflow, nesta ordem:
1. cria o schema e as views (idempotente — pode rodar quantas vezes quiser);
2. ingere Câmara e Senado no período;
3. deriva as filiações partidárias;
4. calcula os agreement scores.

Depois disso, o agendamento diário mantém tudo atualizado sozinho.

## Passo 4 — Conferir os dados

No Supabase: **Table Editor** (veja `division`, `vote`, `party_orientation`,
`agreement_score`) ou **SQL Editor**:

```sql
select house, count(*) from division group by house;
select option, count(*) from vote group by option order by 2 desc;
select count(*) from agreement_score;
```

## Passo 5 (opcional) — Rodar a API contra o Supabase

Na sua máquina (ou num host como Render/Fly), com a **direct connection** no
`.env`:

```bash
pip install -r api/requirements.txt
export DATABASE_URL="postgresql://postgres:SUA_SENHA@db.rvcfbklnwglmhoxfexvj.supabase.co:5432/postgres?sslmode=require"
uvicorn api.main:app --reload   # http://localhost:8000/docs
```

Para a API em produção com muitos acessos, prefira a string do **pooler**.

## Alternativa: aplicar o schema pelo navegador

Se preferir, em vez de deixar o workflow criar o schema, abra o **SQL Editor** do
Supabase e cole o conteúdo de `db/schema.sql` e depois `db/views_agreement.sql`.
É 100% no navegador, sem instalar nada.

## Observações honestas

- Limites do plano grátis do Supabase (conexões, storage, pausa por inatividade)
  **mudam com frequência** — confira no painel/site.
- O detalhe IPv6 (direct) vs IPv4 (pooler) para o GitHub Actions é o tropeço mais
  comum; se o workflow falhar com erro de conexão/timeout, é quase certo que é a
  string direct — troque pela do pooler.
