-- Exemplo: cria UMA política de teste e vincula votações a ela, para você
-- conseguir rodar o score.py de ponta a ponta logo após a ingestão.
--
-- ATENÇÃO: isto é só um exemplo mecânico (casa por texto da votação). Políticas
-- reais são CURADORIA editorial — cada votação deve ser lida e marcada como
-- 'for'/'against' à mão. Ajuste o WHERE e as posturas conforme o tema real.
--
--   psql "$DATABASE_URL" -f db/seed_example_policy.sql

BEGIN;

-- 1) cria a política (tema)
INSERT INTO policy (name, description, provisional)
VALUES ('Exemplo — pauta ambiental',
        'Política de demonstração criada por seed_example_policy.sql. Substitua por curadoria real.',
        TRUE)
ON CONFLICT DO NOTHING;

-- 2) vincula até 10 votações nominais cujo texto menciona o tema.
--    stance='for' assume que votar SIM apoia a pauta — REVISE caso a caso!
WITH pol AS (
  SELECT id FROM policy WHERE name = 'Exemplo — pauta ambiental' LIMIT 1
),
cand AS (
  SELECT id AS division_id
  FROM division
  WHERE is_nominal
    AND (description ILIKE '%ambient%' OR description ILIKE '%clima%'
         OR description ILIKE '%floresta%' OR description ILIKE '%desmatament%')
  ORDER BY occurred_at DESC
  LIMIT 10
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT pol.id, cand.division_id, 'for', 'normal'
FROM pol, cand
ON CONFLICT (policy_id, division_id) DO NOTHING;

COMMIT;

-- Depois:
--   python scoring/score.py            # calcula os scores
--   SELECT * FROM party_agreement;     # ranking por partido (após views_agreement.sql)
