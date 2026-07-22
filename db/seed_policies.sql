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

-- ---------------------------------------------------------------------------
--  Direitos dos povos indígenas (provisória — por ora, o Marco Temporal)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Direitos dos povos indígenas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Direitos dos povos indígenas',
    'Defesa dos direitos territoriais dos povos indígenas: CONTRA o Marco Temporal (PL 490/2007, que restringe a demarcação de terras às ocupadas em 5/10/1988). Score alto = defende os direitos indígenas. Cobre as duas casas: PL 490/2007 (Câmara), PL 2903/2023 e PEC 48/2023 (Senado) e PL 4497/2024 (registros sobre terras em demarcação, vetado).',
    true) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','345311-270','against','strong'),  -- PL 490/2007 Marco Temporal (Câmara)
  ('camara','345311-279','against','normal'),  -- PL 490/2007 destaque
  ('camara','2471177-56','against','normal'),  -- PL 4497/2024 registros s/ demarcação
  ('senado','6756','against','strong'),        -- PL 2903/2023 Marco Temporal (Senado, 43x21)
  ('senado','7032','against','strong'),        -- PEC 48/2023 1º turno (52x14)
  ('senado','7033','against','normal')         -- PEC 48/2023 2º turno (52x15)
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Igualdade racial
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Igualdade racial';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Igualdade racial',
    'Promoção da igualdade racial: cota de 30% em concursos públicos para pretos, pardos, indígenas e quilombolas; equiparação da injúria racial ao crime de racismo; feriado nacional da Consciência Negra; "Lista Suja" do racismo no futebol; e CONTRA a anistia aos partidos que descumpriram as cotas de financiamento de candidaturas negras (PEC 9/2023). Score alto = apoia a igualdade racial.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2439779-55','for','strong'),
  ('1301128-43','for','strong'),
  ('2299903-53','for','normal'),
  ('2487399-57','for','normal'),
  ('2352476-149','against','normal')
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Direitos dos trabalhadores
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Direitos dos trabalhadores';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Direitos dos trabalhadores',
    'Defesa e ampliação dos direitos trabalhistas: A FAVOR do fim da escala 6x1 com jornada máxima de 40h (PEC 221/2019) e CONTRA a redução de FGTS e INSS em contratos de jovens (Contrato Verde e Amarelo, MPV 905/2019, e sua retomada no PL 5496/2013). Score alto = defende os direitos dos trabalhadores.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2233802-424','for','strong'),
  ('575585-92','against','strong'),
  ('2229308-65','against','strong')
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Anistia e redução de penas do 8 de Janeiro (política de um projeto só)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Anistia e redução de penas do 8 de Janeiro';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Anistia e redução de penas do 8 de Janeiro',
    'Posição sobre o PL 2162/2023 ("PL da Dosimetria"): concede anistia a participantes das manifestações de motivação política de 2022-2023 e reduz as penas dos condenados pelos atos de 8 de janeiro. Vetado pelo presidente; o veto foi derrubado pelo Congresso. Score alto = a favor da anistia e da redução de penas.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2358548-89','for','strong'),  -- aprovação do substitutivo (291x148)
  ('2358548-81','for','normal'),  -- texto mantido (destaque)
  ('2358548-86','for','normal')   -- texto mantido (destaque)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Endurecimento das penas
--  (excluído de propósito: PL 6240/2013, desaparecimento forçado — criminalização
--   puxada por direitos humanos, eixo diferente; PL 4333/2025, ementa processual vaga)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Endurecimento das penas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Endurecimento das penas',
    'Penas mais duras e cumprimento mais rigoroso: aumento das penas para porte ilegal de arma de uso proibido (PL 4149/2004), para furto e roubo (PL 3780/2023) e para lesão corporal (PL 6749/2016), além da exigência de 80% de cumprimento da pena para progressão de regime (PL 1112/2023). Score alto = apoia o endurecimento penal.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('264726-144','for','strong'),   -- PL 4149/2004 porte de arma proibida
  ('2376169-101','for','normal'),  -- PL 3780/2023 furto e roubo
  ('2121642-105','for','normal'),  -- PL 6749/2016 lesão corporal
  ('2351284-38','for','normal')    -- PL 1112/2023 progressão 80%
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Financiamento à cultura
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Financiamento à cultura';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Financiamento à cultura',
    'Fomento público à cultura: tornar permanente a Política Nacional Aldir Blanc (PL 363/2025, R$ 15 bilhões para o setor) e regulamentar o streaming (PL 8889/2017) com contribuição para o audiovisual nacional. Score alto = apoia o financiamento à cultura.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2483495-52','for','strong'),   -- PL 363/2025 Aldir Blanc permanente
  ('2157806-137','for','normal')   -- PL 8889/2017 lei do streaming (CAvD)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Reforma agrária e acesso à terra
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Reforma agrária e acesso à terra';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Reforma agrária e acesso à terra',
    'Defesa da reforma agrária e do acesso à terra: CONTRA a proibição de desapropriar terras produtivas (PL 4357/2023), CONTRA a regularização de registros sobre terras públicas em faixa de fronteira, inclusive sobrepostos a terras indígenas em demarcação (PL 4497/2024, o "PL da Grilagem", vetado), e CONTRA a punição de famílias que ocupam terras (PL 709/2023). Score alto = defende a reforma agrária.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2386051-93','against','strong'),  -- PL 4357/2023 proibe desapropriar terra produtiva
  ('2471177-56','against','strong'),  -- PL 4497/2024 "PL da Grilagem" (vetado)
  ('2349493-82','against','normal')   -- PL 709/2023 pune ocupacoes
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Blindagem de parlamentares (PEC da Blindagem) — política de um projeto só
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Blindagem de parlamentares (PEC da Blindagem)';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Blindagem de parlamentares (PEC da Blindagem)',
    'Posição sobre a PEC 3/2021 ("PEC da Blindagem"): exige autorização prévia da própria Casa Legislativa para o STF processar criminalmente parlamentares, com votação secreta. Aprovada pela Câmara em setembro de 2025; após protestos em todo o país, foi rejeitada pelo Senado. Score alto = a favor da blindagem.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2270800-135','for','strong'),  -- 1º turno (353x134)
  ('2270800-160','for','normal'),  -- 2º turno (344x133)
  ('2270800-175','for','normal')   -- emenda do voto secreto (314x168)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Imunidade tributária das igrejas (PEC 5/2023) — política de um projeto só
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Imunidade tributária das igrejas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Imunidade tributária das igrejas',
    'Posição sobre a PEC 5/2023: amplia a imunidade tributária de templos e entidades religiosas para a aquisição de bens e serviços necessários às suas atividades. Aprovada pela Câmara em dois turnos em maio de 2026. Score alto = a favor da ampliação da imunidade.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2351506-104','for','strong'),  -- 1º turno (385x93)
  ('2351506-122','for','normal')   -- 2º turno (368x96)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Legalização dos jogos de azar (PL 442/1991)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Legalização dos jogos de azar';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Legalização dos jogos de azar',
    'Posição sobre a legalização de cassinos, bingos e outros jogos de azar (PL 442/1991, o "marco dos jogos", aprovado pela Câmara em 2022 e parado no Senado). Score alto = a favor da legalização.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('15460-165','for','strong'),   -- aprovação do substitutivo (246x202)
  ('15460-179','for','normal')    -- texto mantido (234x175)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Reforma tributária do consumo (PEC 45/2019 — as duas casas)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Reforma tributária do consumo';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Reforma tributária do consumo',
    'Posição sobre a reforma tributária do consumo (PEC 45/2019, promulgada como Emenda Constitucional 132/2023): substitui PIS, Cofins, IPI, ICMS e ISS pelo IVA dual (CBS e IBS), com cashback para famílias de baixa renda e imposto seletivo. Inclui os votos da Câmara e do Senado. Score alto = a favor da reforma.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','2196833-326','for','strong'),  -- 1º turno Câmara (382x118)
  ('camara','2196833-373','for','normal'),  -- 2º turno Câmara (375x113)
  ('senado','6777','for','strong'),         -- PEC no Senado (53x24)
  ('senado','6773','for','normal')          -- substitutivo no Senado (53x24)
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

COMMIT;
