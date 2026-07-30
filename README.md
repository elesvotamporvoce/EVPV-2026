# Eles Votam Por Você

Site que mostra **como cada deputado e senador brasileiro votou**, organizado por
tema, a partir dos dados abertos oficiais da Câmara e do Senado.

Para cada política (ex.: "Mais investimento na educação") o site calcula o quanto
cada parlamentar votou de acordo com ela e traduz num rótulo simples — "Sempre a
favor", "Às vezes", "Quase sempre contra". Ninguém opina: os votos decidem. O
trabalho editorial se limita a escolher quais votações entram em cada política e
qual voto conta como apoio, e essas escolhas ficam publicadas no site.

Inspirado no [TheyVoteForYou](https://theyvoteforyou.org.au) australiano.

---

## Como rodar o site na sua máquina

Você precisa do **Node.js 20 ou superior** ([nodejs.org](https://nodejs.org),
versão LTS).

```bash
cd web
npm install          # só na primeira vez, demora alguns minutos
npm run dev
```

Abra <http://localhost:3000>.

O site lê o banco de produção no Supabase, então **não é preciso rodar banco
local** para mexer na interface. As credenciais ficam em `web/.env.local` — copie
de `web/.env.example` se ainda não existir. São chaves públicas de leitura; o RLS
do banco garante que ninguém escreve por elas.

### No Windows, se o PowerShell reclamar

```
npm : File ...\npm.ps1 cannot be loaded because running scripts is disabled
```

Use `npm.cmd` em vez de `npm` (`npm.cmd install`, `npm.cmd run dev`). É o mesmo
programa, na versão batch, que não passa pela política de execução do Windows.

---

## Estrutura

| Pasta | O que é |
|---|---|
| `web/` | Site em Next.js (App Router) + Tailwind. Lê o Supabase direto. |
| `db/` | Schema, views e o seed curado das políticas. |
| `ingest/` | Scripts Python que baixam votações das APIs oficiais. |
| `scoring/` | `score.py`, o motor que calcula o alinhamento de cada parlamentar. |
| `api/` | API REST em FastAPI (opcional — o site não depende dela). |
| `scripts/` | Utilitários: aplicar SQL, verificar integridade. |
| `.github/workflows/` | Cargas automáticas diárias e semanais. |

Ordem de aplicação do SQL — **as três são necessárias**, o site quebra sem a
terceira:

```bash
python scripts/apply_sql.py db/schema.sql db/views_agreement.sql db/views_policy_detail.sql
```

Detalhes de configuração do banco em [SETUP_SUPABASE.md](SETUP_SUPABASE.md).

---

## Como os dados chegam

```
APIs oficiais  ->  ingest/  ->  Postgres (Supabase)  ->  scoring/score.py  ->  web/
```

1. `ingest/ingest_camara.py` e `ingest/ingest_senado.py` baixam votações nominais
   e o voto individual de cada parlamentar.
2. `db/seed_policies.sql` vincula votações a políticas — é aqui que vive a
   curadoria, com o raciocínio em comentários, inclusive das decisões de deixar
   algo de fora.
3. `scoring/score.py` calcula os scores e grava em `agreement_score`.
4. O site lê o resultado.

O workflow **Ingestão diária** roda todo dia às 14:00 UTC: pega os últimos 3 dias,
deriva filiações partidárias e recalcula todos os scores.

Para rodar por fora, com `DATABASE_URL` apontando para o banco:

```bash
pip install -r ingest/requirements.txt
python ingest/ingest_camara.py --start 2026-07-01 --end 2026-07-30
python scoring/score.py                  # todas as políticas
python scoring/score.py --policy 3       # só uma
python scoring/score.py --self-test      # testa a lógica sem tocar no banco
```

---

## A metodologia, em resumo

As constantes estão todas no topo de `scoring/score.py`, explícitas e ajustáveis.
Mudar lá muda a metodologia — e aí precisa mudar a documentação junto.

**Peso de cada votação.** Um voto normal pesa 10; um voto em matéria decisiva,
marcado pela curadoria, pesa 25.

**Ausência não é discordância.** Quem não vota entra com 20% do peso e valor
neutro, para não ser tratado como se tivesse votado contra.

**Duas regras automáticas**, aplicadas pelo motor a partir dos dados apurados, sem
depender de a curadoria lembrar delas:

- *Votação quase unânime pesa menos.* Se 95% ou mais dos votos foram para o mesmo
  lado, o peso cai para 4. Uma votação 470 a 1 quase não distingue parlamentares.
  Ela não é descartada, porque diz muito sobre a minoria que votou contra a
  corrente. Veja `LOPSIDED_THRESHOLD`.
- *Só plenário conta.* Votações de comissão são ignoradas: só os membros podem
  votar, e os demais apareceriam como ausentes sem nunca ter tido a chance de se
  posicionar. Veja `PLENARY_BODIES`.

**Menos de 2 votos decisivos** vira "Sem votos suficientes" em vez de um número
que não se sustenta.

O peso realmente usado fica gravado em `policy_division.effective_strength`, e é
essa coluna que o site exibe — assim o selo mostrado nunca divergir do cálculo.

---

## Curando uma política

A regra que aprendemos errando: **defina o eixo antes de procurar votações.**

Se você parte das votações encontradas e depois pergunta "o que isso tem em
comum?", o eixo sai borrado. Foi assim que uma política de penas juntou furto,
agressão a profissional de saúde e porte de arma no mesmo score — três eixos
diferentes, e um parlamentar podia ser a favor de um e contra outro sem nenhuma
incoerência.

O teste: **a frase permite que alguém seja a favor ou contra ela?** Se o nome
precisa de um "e" para caber tudo, provavelmente são duas políticas.

Depois disso, edite `db/seed_policies.sql` e rode `python scoring/score.py`.

---

## Verificando

```bash
python scoring/score.py --self-test    # lógica do score, sem banco
python scripts/check_integrity.py      # consistência dos dados
bash scripts/verify_pipeline.sh        # ponta a ponta (precisa de DATABASE_URL)
```

---

## Fontes

- [Dados Abertos da Câmara dos Deputados](https://dadosabertos.camara.leg.br/)
- [Dados Abertos do Senado Federal](https://legis.senado.leg.br/dadosabertos/)

Os dados são públicos e oficiais. Onde há divergência entre o que mostramos e a
fonte, a fonte manda — cada votação no site tem link para o projeto na íntegra.
