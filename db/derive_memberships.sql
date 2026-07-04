-- Deriva a filiação ATUAL de cada pessoa a partir do partido do voto mais recente.
-- Preenche party_membership, do qual dependem a view party_agreement e a
-- comparação por partido nas políticas.
--
-- Idempotente: recria as filiações "atuais" (end_date IS NULL). Se um dia você
-- passar a CURAR filiações e histórico à mão, troque esta estratégia derivada.
--
--   psql "$DATABASE_URL" -f db/derive_memberships.sql

BEGIN;

DELETE FROM party_membership WHERE end_date IS NULL;

INSERT INTO party_membership (person_id, party_id, start_date, end_date)
SELECT DISTINCT ON (v.person_id)
       v.person_id, v.party_id, NULL::date, NULL::date
FROM vote v
JOIN division d ON d.id = v.division_id
WHERE v.party_id IS NOT NULL
ORDER BY v.person_id, d.occurred_at DESC NULLS LAST;

COMMIT;
