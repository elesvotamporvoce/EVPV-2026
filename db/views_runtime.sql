-- Views de leitura consumidas pelo site (web/) e pelo quiz.
-- Estavam vivas SÓ no Supabase, sem definição versionada — um rebuild a partir
-- do schema.sql derrubava praticamente todas as páginas. Versionadas em
-- 04/08/2026, extraídas do banco com pg_get_viewdef.
--
-- Roda depois do schema.sql:  psql "$DATABASE_URL" -f db/views_runtime.sql
-- (party_agreement vem de views_agreement.sql e policy_division_detail de
--  views_policy_detail.sql; rode os três.)
--
-- Todas com security_invoker: a view lê com as permissões de quem consulta,
-- então o RLS das tabelas continua valendo.

-- Voto a voto de uma votação, com quem votou e por qual partido.
CREATE OR REPLACE VIEW division_vote WITH (security_invoker = true) AS
SELECT v.division_id,
       v.option,
       pe.id AS person_id,
       pe.name,
       pe.uf,
       pe.photo_url,
       pe.house,
       pa.sigla AS party_sigla
  FROM vote v
  JOIN person pe ON pe.id = v.person_id
  LEFT JOIN party pa ON pa.id = v.party_id;

-- party_agreement (views_agreement.sql) + nome da política.
CREATE OR REPLACE VIEW party_policy_agreement WITH (security_invoker = true) AS
SELECT pa.party_id,
       pa.party_sigla,
       pa.policy_id,
       pol.name AS policy_name,
       pa.avg_score,
       pa.n_people
  FROM party_agreement pa
  JOIN policy pol ON pol.id = pa.policy_id;

-- Diretório de parlamentares com o partido ATUAL (filiação sem end_date).
CREATE OR REPLACE VIEW person_directory WITH (security_invoker = true) AS
SELECT p.id,
       p.house,
       p.name,
       p.uf,
       p.photo_url,
       p.active,
       pa.id AS party_id,
       pa.sigla AS party_sigla,
       p.mandate_status,
       p.mandate_detail
  FROM person p
  LEFT JOIN party_membership pm ON pm.person_id = p.id AND pm.end_date IS NULL
  LEFT JOIN party pa ON pa.id = pm.party_id;

-- Participação: votos dados vs sessões em que PODIA votar. O CASE alinha o
-- início do mandato ao começo da legislatura (fev/2019 e fev/2023), para não
-- contar contra o parlamentar as sessões anteriores à posse; licenciados e
-- ex-mandatos param de contar depois do último voto.
CREATE OR REPLACE VIEW person_participation WITH (security_invoker = true) AS
SELECT p.id AS person_id,
       p.house,
       s.first_vote,
       s.n_votes,
       ( SELECT count(*) AS count
           FROM division d2
          WHERE d2.is_nominal AND d2.house = p.house AND d2.occurred_at >=
                CASE
                    WHEN s.first_vote >= '2019-02-01 00:00:00+00'::timestamptz
                         AND s.first_vote < '2019-05-01 00:00:00+00'::timestamptz
                      THEN '2019-02-01 00:00:00+00'::timestamptz
                    WHEN s.first_vote >= '2023-02-01 00:00:00+00'::timestamptz
                         AND s.first_vote < '2023-05-01 00:00:00+00'::timestamptz
                      THEN '2023-02-01 00:00:00+00'::timestamptz
                    ELSE s.first_vote::timestamptz
                END
            AND ((COALESCE(p.mandate_status, '') <> ALL (ARRAY['fora'::text, 'licenciado'::text]))
                 OR d2.occurred_at <= s.last_vote)
       ) AS eligible,
       s.last_vote
  FROM person p
  CROSS JOIN LATERAL (
        SELECT min(d.occurred_at) AS first_vote,
               max(d.occurred_at) AS last_vote,
               count(*) FILTER (WHERE v.option <> 'ausente') AS n_votes
          FROM vote v
          JOIN division d ON d.id = v.division_id AND d.is_nominal
         WHERE v.person_id = p.id
  ) s;

-- Score por (pessoa, política) com o nome da política.
CREATE OR REPLACE VIEW person_policy_score WITH (security_invoker = true) AS
SELECT a.person_id,
       a.policy_id,
       pol.name AS policy_name,
       a.score,
       a.category,
       a.n_divisions
  FROM agreement_score a
  JOIN policy pol ON pol.id = a.policy_id;

-- Contadores simples de votos por pessoa.
CREATE OR REPLACE VIEW person_stats WITH (security_invoker = true) AS
SELECT person_id,
       count(*) AS n_votes,
       count(*) FILTER (WHERE option = ANY (ARRAY['sim'::text, 'nao'::text])) AS n_attended,
       count(*) FILTER (WHERE option = 'sim') AS n_sim,
       count(*) FILTER (WHERE option = 'nao') AS n_nao,
       count(*) FILTER (WHERE option <> ALL (ARRAY['sim'::text, 'nao'::text])) AS n_absent
  FROM vote v
 GROUP BY person_id;

-- Votos de uma pessoa com os dados da votação.
CREATE OR REPLACE VIEW person_vote WITH (security_invoker = true) AS
SELECT v.person_id,
       v.option,
       d.id AS division_id,
       d.description,
       d.occurred_at,
       d.house,
       d.result_approved
  FROM vote v
  JOIN division d ON d.id = v.division_id;

-- Quantos parlamentares têm posição atribuída em cada política.
CREATE OR REPLACE VIEW policy_participation WITH (security_invoker = true) AS
SELECT policy_id,
       count(*) FILTER (WHERE category <> 'not_enough') AS n_scored
  FROM agreement_score
 GROUP BY policy_id;

-- Score por (pessoa, política) já com nome, foto, UF e partido — a view mais
-- usada pelo site (rankings, perfis e o resultado do quiz).
CREATE OR REPLACE VIEW score_named WITH (security_invoker = true) AS
SELECT a.person_id,
       a.policy_id,
       a.score,
       a.category,
       a.n_divisions,
       pol.name AS policy_name,
       pe.name AS person_name,
       pe.uf,
       pe.house,
       pe.photo_url,
       dir.party_sigla
  FROM agreement_score a
  JOIN policy pol ON pol.id = a.policy_id
  JOIN person pe ON pe.id = a.person_id
  LEFT JOIN person_directory dir ON dir.id = a.person_id;
