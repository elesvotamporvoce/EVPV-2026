-- ============================================================================
--  Políticas curadas (trabalho editorial) — versionado para recuperação.
--  Padrão TVFY: políticas ESTREITAS, uma pergunta por política, nome = posição.
--  Referencia votações por (house, external_id), estáveis entre rebuilds.
--  Idempotente: apaga a política de mesmo nome e recria. Depois recalcule os
--  scores (scoring/score.py ou o SQL generalizado).
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
--  Proteção das mulheres contra a violência
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Proteção das mulheres contra a violência';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Proteção das mulheres contra a violência',
    'Proteção das mulheres contra a violência: Lei Maria da Penha, tipificação da violência vicária, monitoramento eletrônico de agressores, atendimento especializado nas delegacias, proibição de armas para agressores, combate à violência política de gênero e o Sistema Nacional de Enfrentamento. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2421056-8','for','normal'),    -- PL 3874/2023 armas p/ agressores
  ('2427395-8','for','normal'),    -- PL 4381/2023 delegacias
  ('2267839-92','for','normal'),   -- PL 5231/2020 discriminação por agentes
  ('2449741-72','for','normal'),   -- PL 2942/2024 monitoramento eletrônico
  ('2462009-79','for','strong'),   -- PL 3880/2024 violência vicária (M. Penha)
  ('2626432-8','for','normal'),    -- PL 68/2025 violência política de gênero
  ('2606313-36','for','strong')    -- PLP 41/2026 Sistema Nacional
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Igualdade de gênero no trabalho (provisória — em crescimento)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Igualdade de gênero no trabalho';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Igualdade de gênero no trabalho',
    'Igualdade entre mulheres e homens no mundo do trabalho: igualdade salarial obrigatória (PL 1085/2023) e direitos trabalhistas ligados à maternidade e ao cuidado. Votar SIM apoia a política. Política em crescimento: novas votações serão adicionadas.',
    true) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2351179-51','for','strong'),   -- PL 1085/2023 igualdade salarial
  ('2574143-8','for','normal')     -- PL 1249/2022 licença CLT
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Ação climática e conservação
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Ação climática e conservação';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Ação climática e conservação',
    'Políticas de clima e conservação da natureza: economia de baixo carbono, biocombustíveis, bioma marinho, produção e consumo sustentáveis, educação para desastres climáticos, direito das crianças à Natureza e tratados de conservação. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('1548579-144','for','normal'),  -- PL 182/2024 economia verde
  ('2238434-100','for','normal'),  -- PL 528/2020 biocombustíveis
  ('2438467-47','for','normal'),   -- PL 2215/2024 Dia da Ação Climática
  ('604557-205','for','normal'),   -- PL 6969/2013 Bioma Marinho
  ('2438687-71','for','normal'),   -- PL 2225/2024 crianças e Natureza
  ('545304-134','for','normal'),   -- PL 3899/2012 Producao/Consumo Sustentáveis
  ('2448069-50','for','normal'),   -- PL 2809/2024 educação p/ desastres
  ('2603342-42','for','normal')    -- MSC 112/2026 espécies migratórias
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Rigor no licenciamento ambiental
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Rigor no licenciamento ambiental';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Rigor no licenciamento ambiental',
    'Manter regras rigorosas de licenciamento ambiental: CONTRA o PL 2159/2021 ("PL da Devastação"), a MPV 1308/2025 (licenciamento especial) e a exclusão de atividades do licenciamento. Score alto = defende o rigor do licenciamento.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2324721-94','against','normal'),  -- PL 1366/2022 silvicultura
  ('257161-454','against','strong'),  -- PL 2159/2021 "PL da Devastação"
  ('2541991-38','against','strong')   -- MPV 1308/2025 licenciamento especial
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Mais investimento na educação
--  (sem o SNE/PLP 235, que é governança — candidata a política própria)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Mais investimento na educação';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Mais investimento na educação',
    'Mais recursos para a educação pública: FUNDEB permanente, exclusão da educação do teto de gastos/arcabouço fiscal, execução orçamentária obrigatória, assistência estudantil e Pé-de-Meia (permanência no ensino médio). Votar SIM apoia mais investimento.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','2194899-125','for','strong'),  -- PEC 24/2019 educação fora do teto
  ('camara','2541109-45','for','strong'),   -- PLP 163/2025 fora dos limites fiscais
  ('camara','1198512-279','for','normal'),  -- PEC 15/2015 FUNDEB permanente
  ('camara','2208007-48','for','normal'),   -- PEC 96/2019 execução obrigatória
  ('camara','2409076-34','for','normal'),   -- PLP 243/2023 Pé-de-Meia (Câmara)
  ('camara','2465240-36','for','normal'),   -- PL 3118/2024 assistência estudantil
  ('senado','7030','for','strong'),         -- PLP 163/2025 (Senado)
  ('senado','6783','for','normal'),         -- PLP 243/2023 Pé-de-Meia (Senado)
  ('senado','6882','for','normal')          -- PLP 153/2024
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

COMMIT;
