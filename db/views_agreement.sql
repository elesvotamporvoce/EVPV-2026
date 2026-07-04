-- Agregação do agreement score POR PARTIDO (usa a filiação ATUAL de cada pessoa).
-- Roda depois do schema e do score.py:  psql "$DATABASE_URL" -f db/views_agreement.sql

CREATE OR REPLACE VIEW party_agreement AS
SELECT
    pm.party_id,
    p.sigla                         AS party_sigla,
    a.policy_id,
    ROUND(AVG(a.score), 2)          AS avg_score,
    COUNT(*)                        AS n_people
FROM agreement_score a
JOIN party_membership pm
  ON pm.person_id = a.person_id
 AND pm.end_date IS NULL            -- filiação atual
JOIN party p ON p.id = pm.party_id
WHERE a.category <> 'not_enough'
GROUP BY pm.party_id, p.sigla, a.policy_id;

-- Exemplo de consulta:
--   SELECT party_sigla, avg_score, n_people
--   FROM party_agreement WHERE policy_id = 1 ORDER BY avg_score DESC;
