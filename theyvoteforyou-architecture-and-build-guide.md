# They Vote For You — Architecture Breakdown & Build Guide

*Research notes on how [theyvoteforyou.org.au](https://theyvoteforyou.org.au/) is built, layer by layer, followed by steps to build a similar platform with a modern equivalent stack.*

> **Sourcing note.** Everything in the "How it is built" sections below is grounded in the project's public source code and its own documentation: the open-source repo [`openaustralia/theyvoteforyou`](https://github.com/openaustralia/theyvoteforyou) (README + `Gemfile`) and the site's own [API docs](https://theyvoteforyou.org.au/help/data). Where I infer something that isn't stated outright (e.g. the specific web server or cloud host), I flag it as an inference. Version numbers reflect the repo's `main` branch as of July 2026 and may have moved since — verify against the repo if it matters.

---

## 1. What the platform actually is

They Vote For You (TVFY) is a **parliamentary voting-record website**. It takes the raw, hard-to-read record of how members of parliament vote on formal motions ("divisions"), and turns it into something a normal person can search and understand: *"How does my MP vote on the issues I care about?"*

It is a project of the **OpenAustralia Foundation** (a registered Australian charity) and is a modern Rails-based evolution of the pioneering UK **Public Whip** project (originally a ~2003-era PHP app). The same codebase has been reused for the UK and Ukraine, so it's deliberately built to be re-skinnable for different parliaments.

The most important thing to understand before looking at the tech: **the cleverness is in the data model and the scoring, not in flashy frontend engineering.** It's a fairly traditional server-rendered web app. The value is (a) a reliable pipeline that ingests official parliamentary records and (b) an editorial + scoring layer that groups individual votes into human-readable "policies."

### The core domain concepts

| Concept | What it is |
|---|---|
| **Person** | An MP or Senator, with party, electorate/house, offices held. |
| **Division** | A single recorded vote in parliament — the atomic unit. Has ayes/noes, date, house, and a text summary drawn from Hansard (editable by contributors). |
| **Policy** | A human-curated *theme* (e.g. "increasing housing affordability") built by linking together many divisions and tagging each as a "for" or "against" vote, optionally weighted as a **strong** vote. |
| **Agreement score** | For each person × policy, a calculated 0–100 score of how consistently they voted with that policy, turned into plain-English categories like *"voted consistently for."* |
| **Rebellion** | A vote cast against the majority of the person's own party — surfaced as a stat. |

This People / Division / Policy triangle, plus the agreement-scoring math inherited from Public Whip, is the heart of the product.

---

## 2. How it is built — layer by layer

TVFY is a **server-rendered Ruby on Rails monolith** backed by MySQL and Elasticsearch, fed by an offline data-ingestion pipeline. There is no separate SPA frontend — the browser mostly receives HTML rendered on the server.

### Layer A — Data ingestion / ETL pipeline (upstream, offline)

This is the part that makes the site *exist*, and it lives largely **outside** the Rails app.

- Official **Hansard** (the verbatim parliamentary record) is parsed by a separate OpenAustralia tool, [`openaustralia-parser`](https://github.com/openaustralia/openaustralia-parser), into **ParlParse XML** — a format inherited from the UK TheyWorkForYou lineage. The resulting debate XML files (which contain the division/voting data) are published on `data.openaustralia.org.au`.
- The Rails app then **loads that XML** into its own database via **Rake tasks** (`application:load:members`, `application:load:divisions[from,to]`, etc.).
- Inside the app, `mechanize` (HTTP) + `nokogiri` (XML/HTML parsing) are used to download and parse debate content.
- For other countries, the app can ingest the **Popolo** open data standard (`application:load:popolo`), with people/vote data collected by **morph.io** scrapers. This is how the same codebase serves Ukraine.
- **Daily updates** run through a single `application:load:daily` Rake task, triggered by **cron at 09:15**. Cache-rebuilding Rake tasks (`application:cache:*`) recompute derived data after loads.

*Takeaway:* ingestion is a batch/ETL concern, decoupled from request handling. The website reads pre-computed data; it does not scrape parliament live on page load.

### Layer B — Backend application (Ruby on Rails)

The web app itself. Key facts from the `Gemfile`:

- **Ruby on Rails `~> 8.0`** (Ruby version pinned via `.ruby-version`). Language split in the repo is ~68% Ruby, ~17% Haml.
- **MySQL** database via the `mysql2` gem.
- **Authentication:** `devise` (user accounts, sign-up confirmation emails). **Authorization:** `pundit` (policy-based access control). `invisible_captcha` for spam resistance on forms.
- **Background jobs:** `delayed_job_active_record` — long-running work (data loads, cache rebuilds, screenshot generation) runs out-of-band.
- **Editorial / audit:** `paper_trail` versions the contributor-edited content (division summaries, policies), so edits are tracked and reversible. `diffy` renders diffs. `redcarpet` / `marked-rails` / `reverse_markdown` handle Markdown (summaries are stored/edited as Markdown).
- **Admin panel:** `administrate` (a Rails admin framework) at `/admin`.
- **Feature flags:** `flipper` (+ `flipper-ui`, `flipper-active_record`) to roll features out to specific users/groups.
- **Domain/util gems:** `ranker` (ranking), `numbers_and_words`, `htmlentities`, `meta-tags` (SEO/OpenGraph), `selenium-webdriver` (headless screenshots of social-share cards).
- **Monitoring:** `skylight` (performance), `honeybadger` (error tracking).

### Layer C — Data storage & search

- **Primary store:** MySQL (relational — people, divisions, votes, policies, join tables, users).
- **Search:** **Elasticsearch 7**, driven through the **`searchkick`** gem (with `oj` + `faraday-typhoeus` for throughput). Reindex via `rake searchkick:reindex:all`; incremental updates are automatic. This powers the free-text search box and postcode/name lookup.
- **Caching:** **Memcached** via the `dalli` client — used heavily because agreement scores and stats are expensive to compute, so they're precomputed and cached rather than calculated per request.

### Layer D — Frontend / presentation

Deliberately lightweight and server-driven:

- **Server-rendered HTML** via **Haml** templates (Rails views). No React/Vue/Angular SPA.
- **Styling:** **SCSS** compiled through the Rails/**Sprockets** asset pipeline, built on **Bootstrap 3** (`bootstrap-sass ~> 3.3`), with `autoprefixer-rails`, Foundation icons, and a little Font Awesome.
- **JavaScript:** minimal (~1.4% of the repo) — **jQuery** (`jquery-rails`) plus small enhancements (e.g. `bootstrap-select`). Minified with `terser`; `mini_racer` provides a JS runtime at build time.
- Progressive-enhancement philosophy: the site works as plain HTML links and forms; JS is garnish, not the foundation.

### Layer E — Public API

- A **REST API v1** returning **JSON**, built with **`jbuilder`** templates. Endpoints: `/api/v1/people`, `/api/v1/people/:id`, `/api/v1/policies`, `/api/v1/policies/:id`, `/api/v1/divisions`, `/api/v1/divisions/:id`.
- **Per-user API keys** (auto-issued on sign-up); `rack-cors` enables cross-origin browser use.
- A **legacy XML API** (`/feeds/*.xml`) is still maintained for backwards compatibility (used by OpenAustralia.org) but is being phased out.

*This matters:* the same data model is exposed as a product feature ("use our API to remix the data"), reinforcing the open-data mission.

### Layer F — Infrastructure, deploy & ops

- **App server / stack:** Rack 3-based. The `Gemfile` notes a Passenger/Rack-3 compatibility constraint, which *strongly implies* **Phusion Passenger** as the production app server (behind a web server such as nginx/Apache) — this is an **inference**, not stated outright.
- **Deployment:** **Capistrano** for the Australian production site (`cap production deploy`); **Mina** for the Ukrainian deployment. Deploys run as a `deploy` user under `/srv/www/production/current`.
- **Provisioning / config management:** the repo contains **Puppet** manifests (`manifests/`, ~1.2% Puppet) and a `docker-stack/` directory; historically a **Vagrant** VM for local dev. Ansible is referenced via `Procfile.ansible`.
- **Process definition:** `Procfile` / `foreman` for running the web + worker processes.
- **Hosting:** example hostnames in the README (`ip-172-31-…`) point to **AWS EC2** — again an **inference** from the private IP range, not an explicit statement.
- **Analytics:** self-hosted **Plausible**, proxied through the app via `rack-proxy` (privacy-preserving, avoids third-party trackers).
- **CI / quality:** GitHub Actions (`rubyonrails.yml`), RSpec test suite, RuboCop linting, Brakeman security scanning.

### One-paragraph summary of the real stack

> A Ruby on Rails 8 server-rendered monolith (Haml + Bootstrap 3 + jQuery) on MySQL, with Elasticsearch (Searchkick) for search and Memcached for caching the expensive vote-agreement computations. Content is loaded by offline Rake/cron ETL jobs that parse official Hansard XML (ParlParse/Popolo). Contributor edits are audit-tracked with PaperTrail; the whole dataset is re-exposed through a keyed JSON REST API. Deployed with Capistrano to (inferred) AWS/Passenger, with Skylight + Honeybadger monitoring and self-hosted Plausible analytics.

---

## 3. Build a similar platform — modern equivalent stack

Below is how you'd build the *same product* today if you weren't tied to their Ruby/MySQL choices. The domain model and the ETL-then-serve architecture stay the same because they're genuinely the right shape for this problem — only the technology choices are modernized. Treat this as a reference architecture, not a turnkey recipe; verify library/API specifics against current docs before committing.

### 3.0 Recommended modern stack (one option)

| Concern | TVFY (original) | Modern equivalent |
|---|---|---|
| Backend framework | Rails 8 (Ruby) | **Next.js (TypeScript) full-stack**, *or* Django/FastAPI (Python) if you prefer a data-science-friendly backend |
| Database | MySQL | **PostgreSQL** |
| ORM / data layer | ActiveRecord | **Prisma** (TS) or SQLAlchemy/Django ORM (Py) |
| Search | Elasticsearch 7 + Searchkick | **Postgres full-text / `pg_trgm`** to start; **Meilisearch/Typesense** if you outgrow it |
| Cache | Memcached | **Redis** |
| Background jobs / ETL | delayed_job + cron | **A job runner** (e.g. a Python/Node worker) on a scheduler — cron, a cloud scheduler, or a workflow tool like Dagster/Prefect for the pipeline |
| Frontend | Haml + Bootstrap 3 + jQuery | **React/Next.js + Tailwind** (server components keep it mostly server-rendered, matching the original's SEO-friendly approach) |
| Auth | Devise | **Auth.js/Clerk** (TS) or Django auth |
| Admin/editorial | Administrate | Framework admin, or a headless CMS for the editable summaries/policies |
| Deploy | Capistrano + Passenger + AWS | **Docker + a managed platform** (Fly.io / Render / Railway / AWS ECS); CI via GitHub Actions |
| Analytics | self-hosted Plausible | Plausible / Umami (privacy-first, self-hostable) |
| Monitoring | Skylight + Honeybadger | Sentry + OpenTelemetry |

> Whatever you pick, keep the two hard-won ideas: **(1)** a batch ETL pipeline decoupled from the web request path, and **(2)** precomputed & cached agreement scores. Those are what make the site fast and correct.

### 3.1 Step-by-step build plan

**Step 1 — Model the domain first.** Define the core entities before writing any UI: `Person`, `Party`, `Chamber/House`, `Division` (a single recorded vote), `Vote` (one person's aye/no/absent on one division), `Policy` (a theme), and `PolicyDivision` (join table linking a policy to a division, with a `stance` of for/against and a `strength` of normal/strong). Add `User` and a versioned-edit/audit table. This schema *is* the product — get it right early.

**Step 2 — Find and understand your data source.** This is the hardest real-world step, not a technical one. You need an official, machine-readable record of parliamentary votes for your target legislature. Options, roughly in order of preference:
- an official open-data API or bulk download of votes/divisions;
- a standard civic-data format — look at **Popolo** (people/orgs/votes) and the **ParlParse** ecosystem that TVFY uses;
- scraping the official Hansard/journals as a last resort (respect terms of use and rate limits).
Confirm the source is authoritative and complete before building on it. *I can't tell you which source exists for your specific parliament — that requires verifying what your legislature actually publishes.*

**Step 3 — Build the ingestion pipeline (decoupled).** Write ETL jobs that fetch the source, parse it, normalize it into your schema, and upsert into Postgres. Make them **idempotent** (safe to re-run) and **incremental** (a daily job that only pulls new divisions). Keep this completely separate from the web server — a scheduled worker process, exactly as TVFY uses a daily cron Rake task. Store raw source payloads so you can reprocess if your parser changes.

**Step 4 — Implement the agreement-scoring engine.** For each (person, policy), compute how consistently they voted with the policy's stance, weighting "strong" votes more heavily, and map the numeric score to plain-language buckets (e.g. "consistently for" / "mixed" / "consistently against"), plus a "not enough votes" case. **Precompute** these on ingest and cache them (Redis) — do not compute per request. The original derives this math from Public Whip; study that lineage rather than inventing scoring from scratch, and be transparent about the method (it's editorially sensitive).

**Step 5 — Build the read/serve backend + API.** Expose the data through a clean JSON REST (or GraphQL) API: list/detail endpoints for people, divisions, and policies, mirroring TVFY's `/api/v1/...` shape. Add per-user API keys and CORS. Designing the API first (API-first) makes both your own frontend and third-party reuse fall out naturally — and open reuse is part of the mission.

**Step 6 — Build the frontend (server-rendered, SEO-first).** Use Next.js server components (or Django templates) so pages are crawlable and fast — this is a public-interest, search-driven site, so SEO and shareable OpenGraph cards matter more than app-like interactivity. Core pages: home with **postcode/name lookup → your representative**, person profile (voting summary + policy agreements), division detail (summary + who voted how), policy detail, and search results. Keep client JS minimal.

**Step 7 — Add search.** Start simple with Postgres full-text search + trigram matching for name/postcode/keyword lookup; only introduce Meilisearch/Typesense/Elasticsearch if you genuinely outgrow it. (TVFY uses Elasticsearch, but that's arguably heavier than a new project needs on day one.)

**Step 8 — Add the editorial / contribution layer.** A lot of TVFY's value is *human-written* division summaries and curated policies. Build an authenticated admin/editor interface with **version history and diffs** (PaperTrail-equivalent), moderation, and attribution. Decide your editorial governance model early — who can create policies, who approves edits.

**Step 9 — Caching, monitoring, analytics.** Put Redis in front of expensive reads. Add error tracking (Sentry) and performance monitoring (OpenTelemetry). Use a privacy-respecting analytics tool (Plausible/Umami), ideally self-hosted/proxied, consistent with the public-trust nature of the project.

**Step 10 — Package, deploy, automate.** Containerize with Docker; run web and worker as separate processes. Deploy to a managed platform (Fly.io/Render/Railway/ECS). Wire up GitHub Actions for tests, linting, a security scan, and deploy-on-merge. Schedule the daily ingestion job. Add a status/"recent changes" page so users can see the data is fresh.

**Step 11 — Licensing, trust & governance (non-technical but essential).** TVFY's credibility comes from being **open source, open data, non-partisan, and transparent about method**. To build something similar and trustworthy: open your code, document your scoring methodology publicly, publish under a clear data licence, disclose funding, and provide an obvious way to report errors. For a project about holding power to account, this trust layer is as important as the code.

---

## 4. Quick reference — the original stack at a glance

- **Framework:** Ruby on Rails 8
- **DB:** MySQL · **Search:** Elasticsearch 7 (Searchkick) · **Cache:** Memcached (Dalli)
- **Views:** Haml · **CSS:** SCSS + Bootstrap 3 · **JS:** jQuery (minimal)
- **Auth/authz:** Devise + Pundit · **Admin:** Administrate · **Flags:** Flipper
- **Jobs:** delayed_job · **Versioning:** PaperTrail · **Parsing:** Mechanize + Nokogiri
- **API:** JSON REST (jbuilder) + keyed access + legacy XML feeds
- **Ingest:** Rake/cron ETL of ParlParse/Popolo XML from OpenAustralia parser + morph.io scrapers
- **Deploy:** Capistrano/Mina, Puppet, Docker; Passenger + AWS *(inferred)*
- **Ops:** Skylight, Honeybadger, self-hosted Plausible, GitHub Actions CI (RSpec/RuboCop/Brakeman)

---

## 5. Applying this to the Brazilian Congress ("Eles Votam Por Você")

Good news: Brazil is one of the better countries in the world for this, because **both houses publish official, free, no-registration open-data REST APIs** — this is exactly the Step 2 data source that's usually the hard part. The catch is that "the Brazilian Congress" is really **two separate institutions with two separate APIs**, and you'll have to integrate and normalize both.

### 5.1 The two official data sources

**Câmara dos Deputados (lower house, 513 deputados)** — [`dadosabertos.camara.leg.br`](https://dadosabertos.camara.leg.br/)
- A modern **RESTful API** (OpenAPI/Swagger-documented) returning **JSON or XML**, plus **bulk file downloads** in CSV, XLSX, ODS, JSON and XML. Maintained by the Chamber's IT department (DITEC); community support via the [`CamaraDosDeputados/dados-abertos`](https://github.com/CamaraDosDeputados/dados-abertos) GitHub repo.
- Relevant resources (the base is roughly `.../api/v2/` — **verify exact paths in the live Swagger**, as I'm reproducing these from memory/docs, not a live call):
  - `/deputados` — list of deputies, with party, state (UF), photo, status;
  - `/votacoes` — the votes/divisions themselves (id, date, result, body, approval indicator);
  - `/votacoes/{id}/votos` — **individual deputy votes** for a given vote (this is your core join table);
  - `/votacoes/{id}/orientacoes` — **party bench guidance** ("orientações de bancada") for how each party told its members to vote;
  - `/proposicoes` — the bills/propositions a vote relates to.
- Bulk equivalents are published yearly as `votacoes-{ano}`, `votacoesVotos-{ano}`, `votacoesOrientacoes-{ano}`, etc.

**Senado Federal (upper house, 81 senadores)** — [`legis.senado.leg.br/dadosabertos`](https://legis.senado.leg.br/dadosabertos/docs/index.html)
- Also a **REST API** with a Swagger UI. It defaults to **XML**; request **JSON** by appending `.json` to the path or sending an `Accept: application/json` header.
- Relevant endpoints (shape roughly as below — again, confirm against the Swagger before coding):
  - senator list (e.g. `/senador/lista/atual`) and detail (`/senador/{codigo}`);
  - **votes by senator**, e.g. `/senador/{codigo}/votacoes.json`.
- Note the Senate's data model and IDs are organized differently from the Câmara's (it's more senator-centric than vote-centric), which is the main integration friction.

There is **no single unified "Congresso Nacional" API** — you integrate the two separately and merge them behind your own schema. A possible shortcut for cleaned/joined historical data is [Base dos Dados](https://basedosdados.org/) (community-maintained, queryable via BigQuery), but treat it as a convenience layer, not the authoritative source — always be able to fall back to the official APIs.

### 5.2 The one caveat that shapes the whole product

**Only *nominal* votes record how each individual voted.** Brazilian voting comes in two kinds:
- **Votação nominal** — cast electronically, every member's individual vote is recorded. *This is the only data you can score people on.*
- **Votação simbólica** — individual votes are **not** recorded electronically; you only get an aggregate outcome.

This is the direct Brazilian equivalent of TVFY only being able to build policies from recorded divisions. **Your agreement-scoring engine (Step 4) can only use nominal votes**, and you should be explicit to users that symbolic votes aren't reflected — otherwise the coverage looks misleadingly incomplete. Set expectations in the UI ("based on N recorded/nominal votes").

### 5.3 What Brazil gives you for *free* that Australia's TVFY had to compute

The Câmara's **`orientações de bancada`** (official party voting guidance) is a genuine gift. TVFY *calculates* "rebellions" by comparing each MP to the majority of their own party. In Brazil, the party leadership's official orientation is **published as data** for nominal plenary votes — so you can compute a deputy's "loyalty / rebellion" rate by directly comparing their vote to their party's published orientation, which is both simpler and more authoritative. Build this in as a first-class feature; it's very meaningful in Brazil's coalition politics.

### 5.4 Brazil-specific adjustments to the build plan

- **Two-source ingestion:** your ETL (Step 3) needs two adapters — one per house — normalizing different formats/IDs into one `Person`/`Division`/`Vote` schema. Tag each person with `house = camara | senado`.
- **Party & coalition modeling:** Brazil has many parties and frequent party-switching ("troca de partido") mid-term. Model party membership *with time validity*, not as a fixed field, or historical vote analysis will be wrong.
- **State/UF and postcode lookup:** deputies represent states (UF), senators represent states too. The "find my representative" flow maps a user's **UF** (and CEP/postcode) to their deputies + 3 senators. There's no single-member district like Australia — one state has many deputies, so "your representatives" is a *set*.
- **Policies are editorial and political:** the "policy" curation layer (Step 8) is where neutrality matters most in a polarized context. Document methodology publicly, show the underlying votes behind every policy, and keep it non-partisan and auditable (Step 11) — this is what will make or break trust in Brazil.
- **Language & naming:** everything in pt-BR; "division" → "votação", "policy" → "tema"/"política", "MP" → "deputado(a)"/"senador(a)". Your project name "Eles Votam Por Você" already nails the TVFY framing.

### 5.5 Bottom line for Brazil

The architecture in Sections 2–3 transfers almost unchanged. The Brazil-specific work is: **(1)** write two ingestion adapters against the Câmara and Senado open-data APIs, **(2)** restrict scoring to nominal votes, **(3)** exploit the published party orientations for a strong loyalty/rebellion feature, and **(4)** model time-varying party membership and multi-representative-per-state lookup. The data being free and official means you can skip the single hardest part of cloning TVFY.

---

## 6. Verified API shapes + database schema (votes per person *and* per party)

*This section is grounded in **live calls** I made to both APIs on 2026-07-04, not documentation alone. Sample values are real responses. Record-shape notes are verbatim from the JSON.*

### 6.1 Câmara dos Deputados — confirmed endpoints

Base URL: `https://dadosabertos.camara.leg.br/api/v2`. Returns JSON. Supports paging via `pagina` / `itens`, date filters `dataInicio` / `dataFim`, and `ordem` / `ordenarPor`. (Note: I found `itens` is **ignored on the `/votos` and `/orientacoes` sub-resources** — they return the full set — so plan to fetch and process the whole roll-call.)

**(a) The vote itself — `GET /votacoes`** (and `/votacoes/{id}`). Real record:

```json
{
  "id": "2630579-2",
  "data": "2026-06-10",
  "dataHoraRegistro": "2026-06-10T17:48:42",
  "siglaOrgao": "PLP10821",
  "uriEvento": ".../eventos/82394",
  "proposicaoObjeto": "REQ 13/2026 PLP10821",
  "uriProposicaoObjeto": ".../proposicoes/2630579",
  "descricao": "Aprovado o Requerimento, com alteração...",
  "aprovacao": 1
}
```
Note the composite `id` (`{proposicaoId}-{sequência}`) and that `siglaOrgao` tells you the body — `PLEN` for plenary vs committee codes like `CCJC`, `CFT`. **`aprovacao`** is 1/0.

**(b) Votes per PERSON — `GET /votacoes/{id}/votos`.** One record per deputy (a full plenary roll-call is ~500). Real record:

```json
{
  "tipoVoto": "Não",
  "dataRegistroVoto": "2020-12-22T23:35:42",
  "deputado_": {
    "id": 66179,
    "nome": "Norma Ayub",
    "siglaPartido": "DEM",
    "uriPartido": ".../partidos/36769",
    "siglaUf": "ES",
    "idLegislatura": 56,
    "urlFoto": "https://www.camara.leg.br/internet/deputado/bandep/66179.jpg"
  }
}
```
The vote value is `tipoVoto` (`"Sim"`, `"Não"`, plus `"Obstrução"`, `"Abstenção"`, `"Artigo 17"`); the person is nested under `deputado_`.

**(c) Votes per PARTY — `GET /votacoes/{id}/orientacoes`.** This is the **official party/bloc voting instruction** — exactly what you asked about. Real records (from vote `2265603-43`):

```json
[
  {"orientacaoVoto":"Sim","codTipoLideranca":"P","siglaPartidoBloco":"NOVO","codPartidoBloco":37901},
  {"orientacaoVoto":"Não","codTipoLideranca":"P","siglaPartidoBloco":"PT","codPartidoBloco":36844},
  {"orientacaoVoto":"Não","codTipoLideranca":"B","siglaPartidoBloco":"Governo","codPartidoBloco":null},
  {"orientacaoVoto":"Não","codTipoLideranca":"B","siglaPartidoBloco":"Oposição","codPartidoBloco":null}
]
```
Every party gets a row (`codTipoLideranca:"P"`) plus the **cross-party blocs** `Governo`, `Oposição`, `Minoria` (`codTipoLideranca:"B"`). So for each nominal vote you get, for free, the official line of every party — no need to infer it. Empty array (`"dados":[]`) means a symbolic vote with no recorded orientation.

**(d) People — `GET /deputados`** (list) and `/deputados/{id}` (detail with full history). `GET /partidos` gives the party registry (the `codPartidoBloco` above are stable party IDs).

### 6.2 Senado Federal — confirmed endpoints (with a live caveat)

Base URL: `https://legis.senado.leg.br/dadosabertos`. XML by default; add `.json` or `Accept: application/json`.

**✅ Migration RESOLVED (verified against the Senate's OpenAPI spec, version `4.1.3.82`, on 2026-07-04).** The old per-senator endpoint `GET /senador/{codigo}/votacoes` is **deprecated**, along with four other legacy vote endpoints (`/plenario/votacao/nominal/{ano}`, `/plenario/lista/votacao/{dataSessao}`, `/plenario/lista/votacao/{dataInicio}/{dataFim}`, `/materia/votacoes/{codigo}`). **All five point to the same single successor: `GET /dadosabertos/votacao`.** Build against that one.

- **Successor endpoint — `GET /dadosabertos/votacao`** ("Votos Nominais de Parlamentares em Processos Legislativos", *not* deprecated). It's a single flat endpoint filtered entirely by **query parameters** (no `/votacao/{id}` sub-paths): `codigoSessao`, `dataInicio`, `dataFim`, `idProcesso`, `codigoMateria`, `sigla`, `numero`, `ano`, `codigoParlamentar`, `nomeParlamentar`, `siglaVotoParlamentar`, `v` (version). So you page/backfill by `dataInicio`/`dataFim`, filter a bill by `sigla`+`numero`+`ano`, or a senator by `codigoParlamentar`.
- **Deprecation is signalled per-request via HTTP headers**, not in the JSON body: `Deprecation:` (start date), `Sunset:` (full shutdown date), `Link: <successor-url>; rel="successor"`. The spec's example shows `Sunset: Sun, 01 Feb 2026` — treat that as illustrative and read the *actual* header on each deprecated call.
- **Rate limit:** more than ~10 requests/second returns **HTTP 429** — so throttle your ingestion.

The Senado's shape is **inverted and deeply nested** vs the Câmara's — it's senator-centric, at `VotacaoParlamentar.Parlamentar.Votacoes.Votacao[]`. Real record (abridged):

```json
{
  "Materia": {
    "Codigo": "141674",
    "DescricaoIdentificacao": "PL 1282/2020 (Substitutivo-CD)",
    "Sigla": "PL", "Numero": "1282", "Ano": "2020",
    "Ementa": "Institui o Programa Nacional de Apoio às Microempresas... (Pronampe)"
  },
  "SessaoPlenaria": { "SiglaCasaSessao": "SF", "DataSessao": "2020-04-24" },
  "CodigoSessaoVotacao": "6096",
  "IndicadorVotacaoSecreta": "Não",
  "DescricaoResultado": "Rejeitado",
  "SiglaDescricaoVoto": "Não"
}
```
The individual vote value is `SiglaDescricaoVoto`; the bill is the `Materia` sub-object (`Sigla`+`Numero`+`Ano`, plus `Ementa`); the overall outcome is `DescricaoResultado` (distinct from the person's vote).

**Correction to an earlier assumption:** the Senate *does* publish party orientations after all — via `GET /dadosabertos/plenario/votacao/orientacaoBancada/{dataSessao}` (or a `{dataInicio}/{dataFim}` range), which is **not** deprecated. The difference from the Câmara is that you fetch it **by session date**, not by vote id, then join it to the votes of that session. So both houses give you an official party line; the Senate just keys it differently. (The Senate also exposes committee votes separately via `/votacaoComissao/parlamentar/{codigo}`, `/votacaoComissao/materia/{sigla}/{numero}/{ano}`, and `/votacaoComissao/comissao/{siglaComissao}`.)

### 6.3 The three ways to express "per party" (design decision)

Your instinct to store votes per person *and* per party is right — but "per party" means three different things, and a serious platform stores all three:

| Concept | Meaning | Source |
|---|---|---|
| **Party orientation** | The official instruction the party leadership gave ("vote Sim"). | Câmara `/votacoes/{id}/orientacoes` (by vote); Senate `/plenario/votacao/orientacaoBancada/{dataSessao}` (by session date). Plenary only, both houses. |
| **Party actual tally** | How the party's members *actually* voted in aggregate (e.g. 45 Sim / 3 Não / 2 abstain → majority Sim). | **Computed** by grouping the per-person votes by party. |
| **Individual rebellion** | A member who voted against their own party's orientation (or against the party's majority). | **Computed** by comparing (b) person vote vs (a) orientation and/or (c) tally. |

The gold feature — "how loyal / rebellious is this deputy?" — falls out of comparing the person's `tipoVoto` to their party's `orientacaoVoto`. For the Senate (no orientation data) you fall back to comparing each senator to their party's computed majority. Store the aggregate as a materialized table so you're not recomputing per page load (this is the Brazilian analogue of TVFY's cached scores).

### 6.4 Normalized two-house schema

Postgres-flavoured DDL. Designed so Câmara and Senado data land in **one** model, and so per-person, per-party-orientation, and per-party-tally are all first-class. IDs from each house are kept as `external_id` + `house` rather than reused as primary keys.

```sql
-- Reference: parties (stable across both houses; map each house's codes in)
CREATE TABLE party (
  id            SERIAL PRIMARY KEY,
  sigla         TEXT NOT NULL,             -- 'PT', 'PL', 'NOVO'
  name          TEXT,
  camara_cod    INTEGER,                   -- codPartidoBloco from Câmara
  senado_cod    TEXT,                      -- Senate party code (if any)
  active        BOOLEAN DEFAULT TRUE
);

-- People: deputies and senators in one table
CREATE TABLE person (
  id            SERIAL PRIMARY KEY,
  house         TEXT NOT NULL CHECK (house IN ('camara','senado')),
  external_id   TEXT NOT NULL,             -- Câmara deputado.id / Senado Parlamentar.Codigo
  name          TEXT NOT NULL,
  uf            TEXT,                       -- state represented
  photo_url     TEXT,
  active        BOOLEAN DEFAULT TRUE,
  UNIQUE (house, external_id)
);

-- Party membership WITH TIME VALIDITY (Brazilians switch parties mid-term)
CREATE TABLE party_membership (
  id            SERIAL PRIMARY KEY,
  person_id     INTEGER NOT NULL REFERENCES person(id),
  party_id      INTEGER NOT NULL REFERENCES party(id),
  start_date    DATE NOT NULL,
  end_date      DATE                        -- NULL = current
);

-- Bills / propositions
CREATE TABLE proposition (
  id            SERIAL PRIMARY KEY,
  house         TEXT NOT NULL,
  external_id   TEXT,
  sigla         TEXT, numero TEXT, ano TEXT, -- 'PL' 1282 2020
  ementa        TEXT,
  UNIQUE (house, external_id)
);

-- Divisions = a single recorded vote
CREATE TABLE division (
  id            SERIAL PRIMARY KEY,
  house         TEXT NOT NULL,
  external_id   TEXT NOT NULL,             -- Câmara '2265603-43' / Senado CodigoSessaoVotacao
  occurred_at   TIMESTAMP NOT NULL,
  body          TEXT,                       -- siglaOrgao: 'PLEN','CCJC'...
  proposition_id INTEGER REFERENCES proposition(id),
  description   TEXT,                       -- editable summary (Markdown), like TVFY
  result_approved BOOLEAN,                  -- Câmara aprovacao / Senado DescricaoResultado
  is_nominal    BOOLEAN NOT NULL,           -- FALSE = symbolic → no per-person votes
  is_secret     BOOLEAN DEFAULT FALSE,
  UNIQUE (house, external_id)
);

-- (b) VOTES PER PERSON
CREATE TABLE vote (
  id            SERIAL PRIMARY KEY,
  division_id   INTEGER NOT NULL REFERENCES division(id),
  person_id     INTEGER NOT NULL REFERENCES person(id),
  party_id      INTEGER REFERENCES party(id),  -- party AT TIME OF VOTE (snapshot)
  option        TEXT NOT NULL CHECK (option IN
                  ('sim','nao','abstencao','obstrucao','ausente','artigo17')),
  registered_at TIMESTAMP,
  UNIQUE (division_id, person_id)
);

-- (a) VOTES PER PARTY — official orientation (Câmara /orientacoes; also blocs)
CREATE TABLE party_orientation (
  id            SERIAL PRIMARY KEY,
  division_id   INTEGER NOT NULL REFERENCES division(id),
  party_id      INTEGER REFERENCES party(id),   -- NULL when it's a bloc
  bloc_name     TEXT,                            -- 'Governo','Oposição','Minoria' or NULL
  leadership_type TEXT CHECK (leadership_type IN ('P','B')),
  orientation   TEXT CHECK (orientation IN ('sim','nao','liberado','obstrucao', NULL))
);

-- (c) VOTES PER PARTY — computed actual tally (materialized on ingest)
CREATE TABLE party_vote_tally (
  id            SERIAL PRIMARY KEY,
  division_id   INTEGER NOT NULL REFERENCES division(id),
  party_id      INTEGER NOT NULL REFERENCES party(id),
  sim_count     INTEGER DEFAULT 0,
  nao_count     INTEGER DEFAULT 0,
  abstencao_count INTEGER DEFAULT 0,
  ausente_count INTEGER DEFAULT 0,
  majority_option TEXT,                          -- derived
  UNIQUE (division_id, party_id)
);

-- Editorial / scoring layer (as in TVFY)
CREATE TABLE policy (
  id SERIAL PRIMARY KEY, name TEXT, description TEXT, provisional BOOLEAN DEFAULT TRUE
);
CREATE TABLE policy_division (
  policy_id INTEGER REFERENCES policy(id),
  division_id INTEGER REFERENCES division(id),
  stance TEXT CHECK (stance IN ('for','against')),
  strength TEXT CHECK (strength IN ('normal','strong')) DEFAULT 'normal',
  PRIMARY KEY (policy_id, division_id)
);
CREATE TABLE agreement_score (          -- precomputed & cached
  person_id INTEGER REFERENCES person(id),
  policy_id INTEGER REFERENCES policy(id),
  score NUMERIC(5,2),                   -- 0..100
  category TEXT,                        -- 'consistently_for', 'mixed', ...
  n_divisions INTEGER,                  -- so UI can say "based on N votes"
  PRIMARY KEY (person_id, policy_id)
);
```

**Two modelling notes that will save you pain:**
1. Store `vote.party_id` as the party **at the moment of the vote** (a snapshot), not a live FK to the person's current party — otherwise a mid-term party switch silently rewrites voting history. Populate it from `party_membership` by date.
2. `party_orientation.party_id` is nullable because the Câmara mixes real parties with the `Governo`/`Oposição`/`Minoria` blocs in the same feed; keep blocs as `bloc_name` so they don't pollute your party table.

### 6.5 Party-level derived metrics you can now compute

With the above, these all become straightforward queries/materialized views:
- **Party cohesion** — how often a party's members vote together (Rice index over `party_vote_tally`).
- **Party loyalty per member** — % of nominal votes where the person matched their party's orientation.
- **Government vs opposition alignment** — compare each person/party to the `Governo` bloc orientation.
- **Party agreement with a policy** — average member agreement scores grouped by party, so you can show "how each *party* votes on housing," not just each person.

That last one is worth calling out: because you store scores per person and membership over time, you can present the TVFY experience at **both** the individual and the party level — which is exactly the per-person *and* per-party product you're aiming for.

### 6.6 Câmara parameters + the recommended ingestion strategy (resolved)

Two practical findings from testing the live Câmara API and reading its official docs:

**The `/votacoes` list filters are limited — don't rely on `siglaOrgao`.** In live tests, passing `siglaOrgao=PLEN` (or a numeric org id) to `GET /api/v2/votacoes` returned an **empty** result rather than filtering, so treat it as unsupported on that endpoint. The filters that *do* work are the date range (`dataInicio`/`dataFim`), sorting (`ordem`, `ordenarPor`), and paging (`pagina`, `itens`). To restrict to plenary, filter **client-side** on the `siglaOrgao` field (`"PLEN"`) after fetching, or use the bulk files below. On the `/votos` and `/orientacoes` sub-resources, `itens` is ignored — you always get the full set.

**For history, use the bulk download files; use the REST API for the daily delta.** This mirrors how TVFY separates a big initial load from daily cron updates. The Câmara publishes yearly files (formats: `csv`, `xlsx`, `ods`, `json`, `xml`; **updated daily**) at `dadosabertos.camara.leg.br/arquivos/{conjunto}/{formato}/{conjunto}-{ano}.{formato}`:

| File set | What it is | Maps to table |
|---|---|---|
| `votacoes-{ano}` | the votes themselves | `division` |
| `votacoesVotos-{ano}` | **per-person** votes (nominal; some symbolic) | `vote` |
| `votacoesOrientacoes-{ano}` | **per-party** orientations (Plenary only) | `party_orientation` |
| `votacoesObjetos-{ano}` | the proposition each vote was *about* | link `division → proposition` |
| `votacoesProposicoes-{ano}` | propositions *affected* by each vote | secondary bill links |
| `deputados`, `proposicoes-{ano}`, `orgaos` | people, bills, bodies | `person`, `proposition` |

**A data-quality caveat straight from the Câmara's docs:** a vote is formally a decision about *one and only one* proposition (its "objeto"), but **very often the real proposition voted on is not identified** — especially for plenary votes. So `division.proposition_id` will legitimately be null a lot of the time, and `votacoesObjetos` only lists *possible* objects. Plan your UI and your policy-tagging to tolerate votes whose bill link is uncertain; don't assume every vote cleanly maps to a bill.

**Recommended ingestion design:** one-time **backfill** by downloading `votacoes*`/`deputados`/`proposicoes` yearly files into the tables; then a **daily job** that calls the REST API for the last few days (`dataInicio`/`dataFim`), pulling `/votacoes`, then `/votacoes/{id}/votos` and `/votacoes/{id}/orientacoes` per new nominal vote. For the Senate, backfill and update both through `GET /dadosabertos/votacao` by date range, plus `/plenario/votacao/orientacaoBancada/{dataInicio}/{dataFim}` for orientations — throttling under ~10 req/s.

---

### Sources
- [openaustralia/theyvoteforyou — GitHub repo (README + Gemfile)](https://github.com/openaustralia/theyvoteforyou)
- [They Vote For You — API documentation](https://theyvoteforyou.org.au/help/data)
- [They Vote For You — home / about](https://theyvoteforyou.org.au/)
- Referenced upstream projects: [Public Whip](http://www.publicwhip.org.uk/), [OpenAustralia parser](https://github.com/openaustralia/openaustralia-parser), [Popolo standard](http://www.popoloproject.com/)
- Brazil — Câmara dos Deputados: [Dados Abertos portal](https://dadosabertos.camara.leg.br/), [Swagger API](https://dadosabertos.camara.leg.br/swagger/api.html), [GitHub repo](https://github.com/CamaraDosDeputados/dados-abertos), [voting-data announcement](https://www.camara.leg.br/assessoria-de-imprensa/641667-dados-abertos-disponibiliza-informacoes-detalhadas-de-votacoes/)
- Brazil — Senado Federal: [Dados Abertos](https://www12.senado.leg.br/dados-abertos), [Swagger UI](https://legis.senado.leg.br/dadosabertos/api-docs/swagger-ui/index.html), [OpenAPI spec JSON (v4.1.3.82, `/v3/api-docs`)](https://legis.senado.leg.br/dadosabertos/v3/api-docs) — verified endpoints, deprecations and the `/votacao` successor
- Brazil — Câmara bulk files & field tutorials: [Arquivos & tutoriais](https://dadosabertos.camara.leg.br/swagger/api.html?tab=staticfile), [votações data tutorial](https://dadosabertos.camara.leg.br/howtouse/2020-02-07-dados-votacoes.html)
- Brazil — cleaned datasets (convenience): [Base dos Dados](https://basedosdados.org/)
