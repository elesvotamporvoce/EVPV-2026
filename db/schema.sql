-- ============================================================================
--  Eles Votam Por Você — Postgres schema
--  Modelo unificado para Câmara dos Deputados + Senado Federal.
--  Suporta: voto por PESSOA, orientação por PARTIDO, placar agregado por
--  partido, filiação partidária com validade no tempo, e a camada editorial
--  (políticas/temas + agreement scores) no estilo TheyVoteForYou.
--
--  Rode com:  psql "$DATABASE_URL" -f db/schema.sql
--  Idempotente: usa IF NOT EXISTS onde possível.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
--  Referência: partidos (estáveis entre as duas casas)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS party (
  id          SERIAL PRIMARY KEY,
  sigla       TEXT NOT NULL UNIQUE,          -- 'PT', 'PL', 'NOVO'
  name        TEXT,
  camara_cod  INTEGER,                       -- codPartidoBloco (Câmara)
  senado_cod  TEXT,                          -- código do partido no Senado
  active      BOOLEAN NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
--  Pessoas: deputados e senadores na mesma tabela
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS person (
  id           SERIAL PRIMARY KEY,
  house        TEXT NOT NULL CHECK (house IN ('camara','senado')),
  external_id  TEXT NOT NULL,                -- deputado.id / Parlamentar.Codigo
  name         TEXT NOT NULL,
  uf           TEXT,                          -- estado representado
  photo_url    TEXT,
  email        TEXT,
  active       BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (house, external_id)
);

-- ---------------------------------------------------------------------------
--  Filiação partidária COM VALIDADE NO TEMPO (troca de partido é comum)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS party_membership (
  id          SERIAL PRIMARY KEY,
  person_id   INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  party_id    INTEGER NOT NULL REFERENCES party(id),
  start_date  DATE,
  end_date    DATE                            -- NULL = filiação atual
);
CREATE INDEX IF NOT EXISTS idx_membership_person ON party_membership(person_id);

-- ---------------------------------------------------------------------------
--  Proposições / matérias (projetos de lei etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS proposition (
  id           SERIAL PRIMARY KEY,
  house        TEXT NOT NULL CHECK (house IN ('camara','senado')),
  external_id  TEXT,                          -- id/URI da proposição/matéria
  sigla        TEXT,                          -- 'PL', 'PEC', 'PLP'
  numero       TEXT,
  ano          TEXT,
  ementa       TEXT,
  raw_label    TEXT,                          -- rótulo bruto (ex.: 'REQ 13/2026 PLP10821')
  UNIQUE (house, external_id)
);

-- ---------------------------------------------------------------------------
--  Votações (divisions) = uma votação registrada
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS division (
  id              SERIAL PRIMARY KEY,
  house           TEXT NOT NULL CHECK (house IN ('camara','senado')),
  external_id     TEXT NOT NULL,             -- Câmara '2265603-43' / Senado codigoSessaoVotacao
  occurred_at     TIMESTAMP,
  body            TEXT,                       -- siglaOrgao: 'PLEN', 'CCJC'...
  proposition_id  INTEGER REFERENCES proposition(id),
  description     TEXT,                       -- resumo (editável, Markdown) — como no TVFY
  result_approved BOOLEAN,                    -- Câmara aprovacao / Senado DescricaoResultado
  is_nominal      BOOLEAN NOT NULL DEFAULT FALSE, -- FALSE = simbólica (sem voto individual)
  is_secret       BOOLEAN NOT NULL DEFAULT FALSE,
  ingested_at     TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (house, external_id)
);
CREATE INDEX IF NOT EXISTS idx_division_date ON division(occurred_at);
CREATE INDEX IF NOT EXISTS idx_division_body ON division(body);

-- ---------------------------------------------------------------------------
--  (b) VOTO POR PESSOA
--  party_id = partido NO MOMENTO DO VOTO (snapshot), não o partido atual.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vote (
  id            SERIAL PRIMARY KEY,
  division_id   INTEGER NOT NULL REFERENCES division(id) ON DELETE CASCADE,
  person_id     INTEGER NOT NULL REFERENCES person(id),
  party_id      INTEGER REFERENCES party(id),
  option        TEXT NOT NULL CHECK (option IN
                  ('sim','nao','abstencao','obstrucao','ausente','artigo17','outro')),
  registered_at TIMESTAMP,
  UNIQUE (division_id, person_id)
);
CREATE INDEX IF NOT EXISTS idx_vote_person ON vote(person_id);
CREATE INDEX IF NOT EXISTS idx_vote_division ON vote(division_id);

-- ---------------------------------------------------------------------------
--  (a) ORIENTAÇÃO POR PARTIDO / BLOCO (linha oficial da liderança)
--  party_id nulo quando é bloco (Governo/Oposição/Minoria/Maioria).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS party_orientation (
  id              SERIAL PRIMARY KEY,
  division_id     INTEGER NOT NULL REFERENCES division(id) ON DELETE CASCADE,
  party_id        INTEGER REFERENCES party(id),
  bloc_name       TEXT,                       -- 'Governo','Oposição','Minoria','Maioria' ou NULL
  leadership_type TEXT CHECK (leadership_type IN ('P','B')),  -- Partido / Bloco
  orientation     TEXT CHECK (orientation IN
                    ('sim','nao','liberado','obstrucao','outro')),
  UNIQUE (division_id, party_id, bloc_name)
);
CREATE INDEX IF NOT EXISTS idx_orientation_division ON party_orientation(division_id);

-- ---------------------------------------------------------------------------
--  (c) PLACAR AGREGADO POR PARTIDO (materializado na ingestão)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS party_vote_tally (
  id              SERIAL PRIMARY KEY,
  division_id     INTEGER NOT NULL REFERENCES division(id) ON DELETE CASCADE,
  party_id        INTEGER NOT NULL REFERENCES party(id),
  sim_count       INTEGER NOT NULL DEFAULT 0,
  nao_count       INTEGER NOT NULL DEFAULT 0,
  abstencao_count INTEGER NOT NULL DEFAULT 0,
  obstrucao_count INTEGER NOT NULL DEFAULT 0,
  ausente_count   INTEGER NOT NULL DEFAULT 0,
  majority_option TEXT,                       -- opção majoritária derivada
  UNIQUE (division_id, party_id)
);

-- ---------------------------------------------------------------------------
--  Camada editorial + pontuação (estilo TheyVoteForYou)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS policy (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  description  TEXT,
  provisional  BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS policy_division (
  policy_id    INTEGER NOT NULL REFERENCES policy(id) ON DELETE CASCADE,
  division_id  INTEGER NOT NULL REFERENCES division(id) ON DELETE CASCADE,
  stance       TEXT NOT NULL CHECK (stance IN ('for','against')),
  strength     TEXT NOT NULL CHECK (strength IN ('normal','strong')) DEFAULT 'normal',
  PRIMARY KEY (policy_id, division_id)
);

CREATE TABLE IF NOT EXISTS agreement_score (   -- pré-calculado e cacheado
  person_id    INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  policy_id    INTEGER NOT NULL REFERENCES policy(id) ON DELETE CASCADE,
  score        NUMERIC(5,2),                  -- 0..100
  category     TEXT,                          -- 'consistently_for', 'mixed', ...
  n_divisions  INTEGER,                       -- para a UI dizer "com base em N votos"
  computed_at  TIMESTAMP NOT NULL DEFAULT now(),
  PRIMARY KEY (person_id, policy_id)
);

COMMIT;
