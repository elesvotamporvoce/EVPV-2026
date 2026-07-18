-- ============================================================================
--  Políticas curadas (trabalho editorial) — versionado para recuperação.
--  Recria as políticas e seus vínculos referenciando as votações por
--  (house, external_id), que são estáveis mesmo se o banco for reconstruído.
--
--  Idempotente: apaga a política de mesmo nome (cascata remove vínculos e
--  scores antigos) e recria. Depois, recalcule os scores (scoring/score.py).
--
--    psql "$DATABASE_URL" -f db/seed_policies.sql
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
--  Política: Direitos e proteção das mulheres
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Direitos e proteção das mulheres';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Direitos e proteção das mulheres',
    'Proteção das mulheres contra a violência (Lei Maria da Penha, feminicídio, monitoramento de agressores) e igualdade de direitos (salário, não discriminação de gênero), além da priorização de projetos pró-mulher. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength
FROM p
JOIN (VALUES
  ('2351179-51','for','strong'),
  ('2421056-8','for','normal'),
  ('2427395-8','for','normal'),
  ('2267839-92','for','normal'),
  ('2574143-8','for','normal'),
  ('2449741-72','for','normal'),
  ('2462009-79','for','strong'),
  ('2626432-8','for','normal'),
  ('2606313-36','for','strong')
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Política: Proteção ao meio ambiente
--  (flexibilizações do licenciamento = CONTRA; políticas de clima/conservação = A FAVOR)
--
--  Curadoria feita com a classificação temática OFICIAL da Câmara (tema 48,
--  "Meio Ambiente e Desenvolvimento Sustentável"), filtrando votações de mérito
--  e DIVISIVAS (minoria >= 15%). Votações deixadas de fora de propósito:
--    - emendas do Senado ao PL 2159/2021: algumas SUAVIZARAM o texto, então a
--      direção não é atribuível sem ler cada uma;
--    - PL 347/2003 (ementa genérica, voto em emenda de teor desconhecido);
--    - PL 914/2024 (Mover): pauta verde embolada com a taxa de importação;
--    - destaques supressivos sem saber qual dispositivo era o alvo.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Proteção ao meio ambiente';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Proteção ao meio ambiente',
    'Rigor na proteção ambiental: CONTRA a flexibilização do licenciamento (PL 2159/2021 "PL da Devastação", MPV 1308/2025) e A FAVOR de políticas de clima e conservação (produção e consumo sustentáveis, bioma marinho, espécies migratórias, educação para desastres climáticos, direito das crianças à Natureza). Score alto = defende o meio ambiente.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength
FROM p
JOIN (VALUES
  -- A FAVOR: clima e conservação
  ('1548579-144','for','normal'),      -- PL 182/2024
  ('2238434-100','for','normal'),      -- PL 528/2020
  ('2438467-47','for','normal'),       -- PL 2215/2024 - Dia Nacional da Ação Climática
  ('604557-205','for','normal'),       -- PL 6969/2013 - Bioma Marinho (PNCMar)
  ('2438687-71','for','normal'),       -- PL 2225/2024 - direito das crianças à Natureza
  ('545304-134','for','normal'),       -- PL 3899/2012 - Produção e Consumo Sustentáveis
  ('2448069-50','for','normal'),       -- PL 2809/2024 - educação p/ desastres climáticos
  ('2603342-42','for','normal'),       -- MSC 112/2026 - tratado espécies migratórias
  -- CONTRA: flexibilização
  ('2324721-94','against','normal'),   -- PL 1366/2022
  ('257161-454','against','strong'),   -- PL 2159/2021 - "PL da Devastação"
  ('2541991-38','against','strong')    -- MPV 1308/2025 - licenciamento especial
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

COMMIT;

-- Após rodar: recalcule os scores com  python scoring/score.py
