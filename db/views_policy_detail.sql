-- View de apoio consumida pelo site:
--   web/app/politicas/[id]/page.tsx  e  web/app/pessoas/[id]/page.tsx
--
-- Estava viva SÓ no Supabase, sem definição versionada — um rebuild a partir do
-- schema.sql derrubava o site. Versionada em 30/07/2026.
--
-- Roda depois do schema.sql:  psql "$DATABASE_URL" -f db/views_policy_detail.sql
--
-- Expõe, além dos dados da votação:
--   effective_strength -- peso REALMENTE usado no score, escrito pelo scoring/score.py.
--                         Vira 'weak' quando a votação é quase unânime. A UI lê esta
--                         coluna, e não `strength`, para não mostrar ★ de voto forte
--                         numa votação que o motor rebaixou.
--   votos_sim/votos_nao/pct_maioria -- a margem apurada, para o site poder dizer ao
--                         usuário POR QUE o peso caiu.
--
-- ATENÇÃO à ordem das colunas: as novas ficam no fim porque CREATE OR REPLACE VIEW
-- não permite inserir coluna no meio (erro 42P16). Para reordenar, é DROP + CREATE.

CREATE OR REPLACE VIEW policy_division_detail WITH (security_invoker = true) AS
SELECT pd.policy_id,
       pd.stance,
       pd.strength,
       d.id AS division_id,
       d.description,
       d.occurred_at,
       d.house,
       d.result_approved,
       pr.sigla AS prop_sigla,
       pr.numero AS prop_numero,
       pr.ano AS prop_ano,
       pr.ementa AS prop_ementa,
       pr.external_id AS prop_external_id,
       COALESCE(pd.effective_strength, pd.strength) AS effective_strength,
       vc.votos_sim,
       vc.votos_nao,
       CASE WHEN COALESCE(vc.votos_sim, 0) + COALESCE(vc.votos_nao, 0) > 0
            THEN ROUND(100.0 * GREATEST(vc.votos_sim, vc.votos_nao)
                       / (vc.votos_sim + vc.votos_nao))
       END AS pct_maioria
  FROM policy_division pd
  JOIN division d ON d.id = pd.division_id
  LEFT JOIN proposition pr ON pr.id = d.proposition_id
  LEFT JOIN LATERAL (
        SELECT COUNT(*) FILTER (WHERE v.option = 'sim') AS votos_sim,
               COUNT(*) FILTER (WHERE v.option = 'nao') AS votos_nao
          FROM vote v WHERE v.division_id = d.id
  ) vc ON TRUE;
