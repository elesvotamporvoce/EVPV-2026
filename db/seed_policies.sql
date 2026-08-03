-- ============================================================================
--  Políticas curadas (trabalho editorial) — versionado para recuperação.
--  Padrão TVFY: políticas ESTREITAS, uma pergunta por política, nome = posição.
--  Referencia votações por (house, external_id), estáveis entre rebuilds.
--  Idempotente: apaga a política de mesmo nome e recria. Depois recalcule os
--  scores (scoring/score.py ou o SQL generalizado).
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
--  Combate à violência contra a mulher
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Combate à violência contra a mulher';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Combate à violência contra a mulher',
    'Reúne as votações sobre proteção de mulheres contra a violência: a inclusão da violência vicária (usar os filhos para atingir a mãe) na Lei Maria da Penha, o monitoramento eletrônico de agressores, a proibição de porte de arma para quem responde por agressão, o atendimento especializado a mulheres indígenas nas delegacias, o combate à violência política de gênero e a criação do Sistema Nacional de Enfrentamento à Violência contra Meninas e Mulheres. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2421056-8','for','normal'),    -- PL 3874/2023 armas p/ agressores
  ('2427395-8','for','normal'),    -- PL 4381/2023 delegacias
  -- PL 5231/2020 removido: trata de discriminacao por agentes publicos em geral,
  -- nao de violencia contra a mulher (e era votacao de comissao com 14 votos).
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
--  Redução das emissões de carbono
--
--  Separada em 29/07/2026 da antiga "Ação climática e conservação", que juntava
--  tres eixos distintos num so score: mitigacao/mercado de carbono, conservacao
--  de biodiversidade e educacao ambiental. Um parlamentar pode apoiar tratado de
--  especies migratorias e rejeitar mercado de carbono sem nenhuma incoerencia.
--  Ver "Conservação da biodiversidade" logo abaixo.
--
--  ATENCAO: a votacao 2238434-80 (PL 528/2020) foi aprovada 429 a 19 (96%).
--  Quase unanime, separa pouco. Ver tarefa "Definir política sobre votações
--  quase unânimes" no to-do.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name IN ('Ação climática e conservação', 'Redução das emissões de carbono');
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Redução das emissões de carbono',
    'Reúne as votações sobre os mecanismos de corte de emissões: o Sistema Brasileiro de Comércio de Emissões, o mercado regulado de carbono criado pela Lei 15.042/2024; e o pacote Combustível do Futuro, que trata de mobilidade de baixo carbono e da captura e estocagem geológica de dióxido de carbono. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('1548579-144','for','normal'),  -- PL 182/2024 economia verde (destaque)
  ('1548579-194','for','strong'),  -- mercado de carbono: aprovacao final do Substitutivo do Senado (Lei 15.042/2024)
  ('2238434-80','for','normal'),   -- Combustivel do Futuro (PL 528/2020): aprovacao principal -- 429 a 19, quase unanime
  ('2238434-100','for','normal')   -- PL 528/2020 biocombustíveis
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Conservação da biodiversidade
--
--  Metade conservacionista da antiga "Ação climática e conservação".
--  O PL 2809/2024 (educacao para reacao a desastres climaticos, 295 a 118) ficou
--  DE FORA: e educacao ambiental, eixo proprio, e sozinho nao sustenta politica.
--  Retomar se surgir mais votacao de educacao ambiental.
--
--  O PL 2225/2024 (direito de criancas e adolescentes a Natureza) e o
--  PL 3899/2012 (producao e consumo sustentaveis) entraram aqui por decisao
--  editorial de 29/07/2026: encaixam frouxamente, mas ampliam a base de 3 para 5.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Conservação da biodiversidade';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Conservação da biodiversidade',
    'Reúne as votações sobre proteção de ecossistemas e espécies: a Lei do Mar, que institui a política de conservação do bioma marinho brasileiro; a adesão ao tratado internacional de conservação de espécies migratórias; a Política Nacional de Estímulo à Produção e ao Consumo Sustentáveis; e o direito de crianças e adolescentes à Natureza. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('604557-191','for','normal'),   -- Lei do Mar (PL 6969/2013): aprovacao do substitutivo
  ('604557-205','for','normal'),   -- PL 6969/2013 Bioma Marinho
  ('2603342-42','for','normal'),   -- MSC 112/2026 especies migratorias
  ('2438687-71','for','normal'),   -- PL 2225/2024 criancas e Natureza
  ('545304-134','for','normal')    -- PL 3899/2012 Producao/Consumo Sustentaveis
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
  ('camara','2194899-103','for','strong'),  -- PEC 24/2019: 1º turno do substitutivo (principal)
  ('camara','2194899-125','for','normal'),  -- PEC 24/2019 educação fora do teto (destaque)
  ('camara','2541109-38','for','strong'),   -- PLP 163/2025: aprovacao principal na Camara
  ('camara','2541109-45','for','normal'),   -- PLP 163/2025 fora dos limites fiscais (destaque)
  ('camara','1198512-250','for','strong'),  -- FUNDEB permanente: 1º turno do substitutivo (principal)
  ('camara','1198512-279','for','normal'),  -- PEC 15/2015 FUNDEB permanente (destaque)
  -- REMOVIDA em 30/07/2026: ('camara','2208007-48','for','normal') -- PEC 96/2019
  --   Votacao da CCJC, nao do plenario: so 52 deputados podiam votar, e os outros
  --   837 entravam como "ausentes" sem nunca ter tido a chance. O score.py agora
  --   ignora automaticamente qualquer votacao fora de PLEN/SF (ver PLENARY_BODIES),
  --   entao mesmo que volte para ca ela nao entra no calculo.
  ('camara','2409076-34','for','normal'),   -- PLP 243/2023 Pé-de-Meia (Câmara)
  ('camara','2465240-36','for','normal'),   -- PL 3118/2024 assistência estudantil
  ('senado','7030','for','strong'),         -- PLP 163/2025 (Senado)
  ('senado','6783','for','normal'),         -- PLP 243/2023 Pé-de-Meia (Senado)
  ('senado','6882','for','normal')          -- PLP 153/2024
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Demarcação de terras indígenas
--
--  30/07/2026: o PL 4497/2024 ("PL da Grilagem") FOI RETIRADO desta politica.
--  Ele trata de ratificacao de registros imobiliarios em faixa de fronteira —
--  titulacao de terra, nao demarcacao indigena — e estava vinculado tambem a
--  politica "Reforma agraria e acesso a terra", com a mesma direcao. Era a unica
--  proposicao servindo duas politicas, e aqui parecia preenchimento. Segue na
--  politica de reforma agraria, onde o eixo encaixa.
--    ('camara','2471177-56','against','normal')
--    ('camara','2471177-102','against','strong')
--
--  Tambem saiu a flag provisional: a politica tem 5 votacoes, todas de marco
--  temporal, e o eixo esta fechado.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Demarcação de terras indígenas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Demarcação de terras indígenas',
    'Defesa dos direitos territoriais dos povos indígenas: CONTRA o Marco Temporal, a tese de que só há direito à terra ocupada em 5 de outubro de 1988. Score alto = defende os direitos indígenas. Cobre as duas casas: PL 490/2007 (Câmara), PL 2903/2023 e PEC 48/2023 (Senado).',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','345311-270','against','strong'),  -- PL 490/2007 Marco Temporal (Câmara)
  ('camara','345311-279','against','normal'),  -- PL 490/2007 destaque
  ('senado','6756','against','strong'),        -- PL 2903/2023 Marco Temporal (Senado, 43x21)
  ('senado','7032','against','strong'),        -- PEC 48/2023 1º turno (52x14)
  ('senado','7033','against','normal')         -- PEC 48/2023 2º turno (52x15)
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Políticas de igualdade racial
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Políticas de igualdade racial';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Políticas de igualdade racial',
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
--  Proteção dos direitos trabalhistas
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Proteção dos direitos trabalhistas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Proteção dos direitos trabalhistas',
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
--  Redução de penas do 8 de Janeiro (política de um projeto só)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Redução de penas do 8 de Janeiro';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Redução de penas do 8 de Janeiro',
    'O projeto ficou conhecido primeiro como PL da Anistia e depois como PL da Dosimetria. A anistia caiu no substitutivo: o texto aprovado não perdoa ninguém, mas reduz penas de quem participou dos atos de 8 de janeiro de 2023. Proíbe somar as penas de golpe e de abolição violenta do Estado Democrático de Direito quando praticadas no mesmo contexto, cria redução de um a dois terços para quem agiu em meio à multidão sem financiar nem liderar, e devolve a progressão de regime a um sexto da pena. Aprovado pela Câmara e pelo Senado, vetado integralmente e promulgado como Lei 15.402/2026 depois de o Congresso derrubar o veto. Score alto = a favor da redução das penas.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2562149-7','for','normal'),   -- urgencia da anistia (311x163, set/2025)
  ('2358548-89','for','strong'),  -- aprovação do substitutivo (291x148)
  ('2358548-81','for','normal'),  -- texto mantido (destaque)
  ('2358548-86','for','normal')   -- texto mantido (destaque)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  ON HOLD: politica de aumento de penas (ex-"Endurecimento das penas")
--
--  Retirada do ar em 29/07/2026 para reanalise. Motivo editorial: o conjunto
--  misturava eixos diferentes e o recorte nao ficou honesto.
--    - PL 3780/2023 (furto e roubo) e crime patrimonial, nao violento.
--    - PL 6749/2016 (agressao a profissionais de saude) e PL 1112/2023
--      (homicidio de agentes de seguranca) seguem a mesma logica: pena maior
--      pela CATEGORIA DA VITIMA, o que e um eixo proprio ("protecao penal
--      reforcada a categorias profissionais"), diferente de "penas maiores".
--    - PL 4149/2004 e sobre ARMAS (porte de uso proibido, disparo, trafico),
--      eixo que provavelmente merece politica propria.
--
--  Votacoes ja mapeadas, para retomar a curadoria:
--    ('264726-144','for','strong'),   -- PL 4149/2004 arma de uso proibido
--    ('2376169-101','for','normal'),  -- PL 3780/2023 furto e roubo
--    ('2121642-105','for','normal'),  -- PL 6749/2016 agressao a prof. de saude
--    ('2351284-38','for','normal')    -- PL 1112/2023 progressao 80% (homicidio
--                                     --   de agente de seguranca)
--  Candidatas nao usadas: PL 5582/2025 (faccoes/crime organizado, 4 votacoes),
--    PL 1637/2019 (medida de seguranca p/ inimputavel), PL 5352/2023 (arma de
--    alto potencial destrutivo), PL 488/2019 (penas p/ pedofilia),
--    PL 2307/2007 (adulteracao de alimentos como crime hediondo).
--
--  Ver tarefa "Reanalisar politica de penas" no to-do.
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
--  Política nacional de cultura
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Política nacional de cultura';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Política nacional de cultura',
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
  ('2471177-56','against','normal'),  -- PL 4497/2024 "PL da Grilagem" (aprovacao na Camara)
  ('2471177-102','against','strong'), -- PL 4497/2024: aprovacao final do Substitutivo do Senado (dez/2025)
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
--  Isenção de impostos para igrejas (PEC 5/2023) — política de um projeto só
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Isenção de impostos para igrejas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Isenção de impostos para igrejas',
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
    'Posição sobre a legalização de cassinos, bingos e outros jogos de azar (PL 442/1991, o "marco dos jogos", aprovado pela Câmara em 2022) e sobre a regulamentação das apostas esportivas online, as bets (PL 3626/2023, sancionado como Lei 14.790/2023). Score alto = a favor da legalização e regulamentação.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('15460-165','for','strong'),   -- aprovação do substitutivo (246x202)
  ('15460-179','for','normal')    -- texto mantido (234x175)
  -- NOTA: o PL 3626/2023 (Bets) foi retirado desta politica: regulamentar apostas
  -- online nao equivale a apoiar a legalizacao de cassinos e bingos, e quem e
  -- contra o jogo pode votar a favor de regular o que ja existe. Candidato a
  -- politica propria ("Regulamentacao das apostas esportivas online").
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

-- ============================================================================
--  "Por que isso importa para você?" — texto prático por política (coluna impact)
-- ---------------------------------------------------------------------------
--  Abastecimento público de medicamentos
--
--  Criada em 30/07/2026. Primeira politica de saude do site — o tema tinha 94
--  proposicoes votadas e nenhuma politica.
--
--  Eixo: o Estado deve garantir o abastecimento de medicamentos e insumos,
--  inclusive passando por cima de licitacao e de patente.
--
--  A direcao de CADA votacao foi conferida na API da Camara, porque as descricoes
--  oficiais ("Mantido o texto", "Rejeitado o Requerimento") nao dizem o que estava
--  em jogo:
--    2252295-130  DTQ 6 (NOVO) pedia suprimir o art. 26 do substitutivo, que
--                 autoriza licitacao exclusiva para Empresa Estrategica de Saude.
--                 SIM = manter o artigo = a favor.
--    947810-85    DTQ 1 (NOVO) pedia suprimir a palavra "publica" (instituicao
--                 publica produtora de hemoderivados, tipo Hemobras).
--                 SIM = manter a palavra = a favor do produtor publico.
--    2252295-110  Requerimento de RETIRADA DE PAUTA, rejeitado 55x212.
--                 SIM = tirar da pauta = obstruir. Por isso stance 'against'.
--
--  FORA por decisao editorial: PL 2158/2023 (venda de medicamento em farmacia
--  dentro de supermercado). Parecia encaixar pelo tema "medicamentos", mas e
--  regulacao de varejo, nao abastecimento — outro eixo.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Abastecimento público de medicamentos';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Abastecimento público de medicamentos',
    'Reúne as votações sobre como o Estado garante remédio e insumo: licitação reservada à indústria instalada no país, compra direta de hemoderivados do produtor público, como a Hemobrás, e o primeiro passo para quebrar a patente do Mounjaro e do Zepbound. Score alto = defende o abastecimento público e a produção nacional.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2252295-120','for','strong'),    -- PL 2583/2020: aprovacao do substitutivo (352x63)
  ('2252295-130','for','normal'),    -- PL 2583/2020: DVS art. 26, licitacao exclusiva mantida (316x110)
  ('2252295-110','against','normal'),-- PL 2583/2020: retirada de pauta rejeitada (55x212) -> SIM = obstruir
  ('2589628-8','for','normal'),      -- PL 424/2015: urgencia (286x111)
  ('947810-85','for','normal'),      -- PL 424/2015: DVS, palavra "publica" mantida (285x106)
  ('2601223-8','for','normal')       -- PL 68/2026: urgencia da quebra de patente (337x19) -> vira weak
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  SAUDE: eixos levantados em 30/07/2026 e NAO transformados em politica.
--  Guardados aqui para nao perder o levantamento. Ver tarefas no to-do.
--
--  (a) Internacao de dependentes quimicos — eixo nitido (coercao e autoridade
--      familiar), mas so 2 votacoes:
--        PL 4183/2024 internacao de menores  — urgencia 317x117 (div 3789)
--        PL 1822/2024 internacao imediata    — requerimento rejeitado 99x277 (div 3774)
--
--  (b) Pesquisa clinica com seres humanos — PL 7082/2017, 5 votacoes entre 70% e
--      75%, otima separacao, mas uma proposicao so e tema tecnico:
--        divs 2314, 2315, 2316, 2317, 2318
--
--  (c) Financiamento da saude — o tema que o publico espera, mas os meritos sao
--      quase unanimes (MPV 1301/2025 aprovada 403x6; PLP 72/2024 aprovado 432x2)
--      e o disputado e requerimento de obstrucao. Alem disso o PLP 163/2025 ja e
--      a base da politica de educacao, e o PLP 18/2021 aponta ao CONTRARIO: ele
--      permite que emendas destinadas a saude paguem o resgate pre-hospitalar dos
--      bombeiros militares, ampliando o que conta como gasto em saude.
-- ---------------------------------------------------------------------------

-- ============================================================================
--  TEXTOS DO QUIZ
--
--  O quiz mostra um gancho curto (quiz_hook) e DUAS POSICOES NOMEADAS PELO
--  CONTEUDO, nunca "a favor" e "contra". Isso resolve a leitura das politicas
--  invertidas: a pessoa escolhe uma posicao concreta, e a curadoria e quem sabe
--  qual delas o Congresso votou.
--
--  CONVENCOES:
--   * side_a e SEMPRE o lado que da score alto. A ordem fixa gera vies de
--     posicao (a primeira opcao e mais escolhida) e isso foi assumido
--     conscientemente em 31/07/2026.
--   * quiz_hook = o impact SEM o fecho dos dois lados. No quiz os dois lados
--     vivem nas opcoes; repetir seria dizer a mesma coisa duas vezes na tela.
--   * teto de referencia de 150 caracteres por nota, flexivel. O que importa
--     mais e os dois lados da MESMA politica ficarem proximos em tamanho, para
--     as caixas de altura igual do quiz nao abrirem buraco.
--   * o impact da pagina e COMPOSTO no fim deste arquivo a partir destas pecas,
--     para quiz e site nunca divergirem.
-- ============================================================================
UPDATE policy SET quiz_hook = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Trata da segurança de mulheres em todo o Brasil: define como casos de violência doméstica e feminicídio são prevenidos, investigados e atendidos.'
 WHEN 'Redução das emissões de carbono' THEN 'Mexe no preço do combustível que você põe no tanque e da energia da sua casa, e define se as empresas que mais poluem pagam pelo que emitem.'
 WHEN 'Mais investimento na educação' THEN 'Define quanto dinheiro chega à escola pública e à universidade federal, e se essa verba fica protegida quando o governo precisa cortar.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Define o que a empresa deve à trabalhadora: mesmo salário do colega homem na mesma função e licença nos dias de menstruação incapacitante.'
 WHEN 'Rigor no licenciamento ambiental' THEN 'O licenciamento é a análise que decide se uma obra pode sair do papel, e o que ela precisa fazer para não poluir o rio, o ar e o bairro ao lado.'
 WHEN 'Demarcação de terras indígenas' THEN 'Decide quem fica com terras em disputa no interior do país: estabelece a regra que define se uma área vira terra indígena ou continua como está.'
 WHEN 'Políticas de igualdade racial' THEN 'Define o quanto o poder público age para reduzir a desigualdade racial: punição por racismo, cota em concurso e partido obrigado a bancar candidatura negra.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Mexe no tempo livre e no bolso de quem tem carteira assinada: quantas horas se trabalha por semana e quanto entra no seu FGTS e no INSS.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Trata do tamanho da pena de quem invadiu e depredou o Congresso, o Planalto e o STF em 8 de janeiro de 2023.'
 ELSE quiz_hook END;

UPDATE policy SET side_a_title = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Proteger desde a denúncia'
 WHEN 'Redução das emissões de carbono' THEN 'Quem polui deve pagar'
 WHEN 'Mais investimento na educação' THEN 'Priorizar a verba da educação'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Direito básico, não benefício'
 WHEN 'Rigor no licenciamento ambiental' THEN 'Melhor demorar do que remediar'
 WHEN 'Demarcação de terras indígenas' THEN 'Tem que considerar quem foi expulso'
 WHEN 'Políticas de igualdade racial' THEN 'A lei deve corrigir a desigualdade'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'A CLT é o piso, não o teto'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Corrigir penas desproporcionais'
 ELSE side_a_title END;

UPDATE policy SET side_a_note = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'o período mais perigoso é logo depois que a mulher denuncia, não depois da sentença'
 WHEN 'Redução das emissões de carbono' THEN 'grandes emissores passam a ter limite e a comprar crédito de quem emite menos'
 WHEN 'Mais investimento na educação' THEN 'escola e universidade dependem de dinheiro garantido e não podem sofrer quando o governo corta gastos'
 WHEN 'Igualdade de gênero no trabalho' THEN 'salário igual por trabalho igual e afastamento em condição de saúde não são favor'
 WHEN 'Rigor no licenciamento ambiental' THEN 'barragens que romperam eram classificadas como de impacto médio antes do desastre'
 WHEN 'Demarcação de terras indígenas' THEN 'comunidade removida à força antes de 1988 não deveria perder o direito por não estar lá naquela data'
 WHEN 'Políticas de igualdade racial' THEN 'séculos de desigualdade não acabam sozinhos; é preciso política que equilibre e abra caminho'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'sem mínimo garantido em lei, a negociação vira imposição de quem tem mais poder'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'mais de quinze anos para quem entrou na multidão sem liderar nem financiar é punição excessiva'
 ELSE side_a_note END;

UPDATE policy SET side_b_title = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Aplicar melhor o que já existe'
 WHEN 'Redução das emissões de carbono' THEN 'Sem custo novo sobre produzir'
 WHEN 'Mais investimento na educação' THEN 'Cautela com gasto obrigatório'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Deixar para a negociação'
 WHEN 'Rigor no licenciamento ambiental' THEN 'A demora também cobra caro'
 WHEN 'Demarcação de terras indígenas' THEN 'Uma data encerra a disputa'
 WHEN 'Políticas de igualdade racial' THEN 'A lei deve ser igual para todos'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Deixar empresa e trabalhador negociarem'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Manter as penas como foram fixadas'
 ELSE side_b_title END;

UPDATE policy SET side_b_note = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'falta delegacia e estrutura, não lei nova; mais regra não muda o atendimento'
 WHEN 'Redução das emissões de carbono' THEN 'a conta do carbono chega no combustível e na energia, e quem paga é o consumidor'
 WHEN 'Mais investimento na educação' THEN 'despesa garantida em lei tira do governo a margem de escolher prioridades a cada ano'
 WHEN 'Igualdade de gênero no trabalho' THEN 'empresa e empregada resolvem melhor caso a caso do que uma regra igual para todas'
 WHEN 'Rigor no licenciamento ambiental' THEN 'obra parada por anos trava saneamento, energia e emprego em região que precisa'
 WHEN 'Demarcação de terras indígenas' THEN 'sem data, qualquer área pode ser reivindicada e ninguém tem segurança sobre o próprio título'
 WHEN 'Políticas de igualdade racial' THEN 'política que classifica por raça oficializa uma divisão que não deveria existir'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'acordo entre as partes se ajusta ao setor e ao porte; regra única, não'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'reduzir pena de ataque às instituições sinaliza que atentar contra a democracia sai barato'
 ELSE side_b_note END;

-- O impact exibido na pagina da politica e derivado das pecas acima.
UPDATE policy SET impact =
  quiz_hook || ' Para quem defende, ' || side_a_note || '; para quem critica, ' || side_b_note || '.'
WHERE quiz_hook IS NOT NULL;
-- ============================================================================
UPDATE policy SET impact = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Trata da segurança de mães, filhas e companheiras: define como casos de violência doméstica e feminicídio são prevenidos, investigados e atendidos. Para quem defende, fecha brechas que custam vidas; para quem critica, restrições aplicadas antes da condenação.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Decide se as empresas são obrigadas a pagar o mesmo salário a homens e mulheres na mesma função. Mexe nos direitos e no contracheque de milhões de trabalhadoras. Para quem defende, é direito básico; para quem critica, é mais custo e obrigação para o empregador.'
 WHEN 'Redução das emissões de carbono' THEN 'Mexe no preço do combustível que você põe no tanque e da energia da sua casa, e define se quem mais polui paga pelo que emite. De um lado, indústria mais moderna e um mercado novo de crédito de carbono; do outro, custo de adaptação que pode chegar ao consumidor.'
 WHEN 'Conservação da biodiversidade' THEN 'Mexe no que pode e no que não pode em áreas de natureza preservada, do bioma marinho às rotas de aves migratórias. De um lado, base para a pesca e o turismo continuarem existindo; do outro, limite à atividade produtiva no litoral e em área sensível.'
 WHEN 'Rigor no licenciamento ambiental' THEN 'O licenciamento é a análise que avalia se uma obra ou fábrica pode poluir rios, ar e comunidades vizinhas. De um lado, flexibilizar diminui burocracias e acelera empreendimentos; do outro, significa menos proteção a quem vive perto deles e menos controle sobre quem paga a conta de um acidente.'
 WHEN 'Mais investimento na educação' THEN 'Define quanto dinheiro chega à escola pública: salário de professor, merenda, vaga em creche e apoio para o aluno de baixa renda. Impacto direto em quem estuda ou tem filhos na rede pública. Para quem defende, é investimento que se paga no futuro; para quem critica, é gasto sem garantia de melhora no aprendizado.'
 WHEN 'Demarcação de terras indígenas' THEN 'Decide quem fica com terras em disputa: os povos indígenas ou os produtores e empresas. Afeta os conflitos no campo, a preservação da floresta e o clima. De um lado, segurança jurídica para quem investe e produz (agronegócio); do outro, o território de comunidades que vivem ali há gerações.'
 WHEN 'Políticas de igualdade racial' THEN 'Define se há reserva de vaga para pessoas negras em concurso público, qual a punição para quem comete racismo e se partido é obrigado a bancar candidatura negra. Para quem defende, corrige desigualdade histórica; para quem critica, separa cidadãos por raça.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Mexe no tempo livre (fim da escala 6x1) e no bolso de quem tem carteira assinada: quantos dias o trabalhador folga por semana e quanto entra no seu FGTS e no INSS. Quem é a favor vê mais direitos garantidos; quem é contra enxerga contratação mais cara para as empresas.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Trata do tamanho da pena de quem invadiu e depredou o Congresso, o Planalto e o STF em 8 de janeiro de 2023. Quem vota a favor da anistia fala em exagero nas condenações; quem vota contra fala na impunidade e possibilidade de criar precedentes para novos ataques às instituições.'
 WHEN 'Política nacional de cultura' THEN 'Decide se shows, cinema, teatro e ponto de cultura da sua cidade têm verba previsível, e se o streaming paga uma contribuição que financia produção brasileira. Para quem defende, volta em emprego e economia; para quem critica, é despesa fixa criada em lei.'
 WHEN 'Isenção de impostos para igrejas' THEN 'Hoje as igrejas não pagam imposto sobre templo e patrimônio; a proposta estende isso para bens e serviços que elas compram. De um lado, menos arrecadação para saúde e educação; do outro, mais recursos para templos e atividades religiosas.'
 WHEN 'Legalização dos jogos de azar' THEN 'Decide se cassino, bingo e jogo do bicho passam a funcionar legalmente. De um lado, emprego, turismo e imposto arrecadado; do outro, risco de vício em jogo e de lavagem de dinheiro.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Define se deputado e senador respondem a processo criminal como qualquer cidadão. Hoje é o STF que decide abrir a ação; pela proposta, seria preciso autorização dos próprios parlamentares, em voto secreto. De um lado, defesa contra perseguição política; do outro, mais dificuldade para punir corrupção e crimes graves.'
 WHEN 'Reforma agrária e acesso à terra' THEN 'Trata do acesso à terra por três caminhos: desapropriar fazenda que descumpre a função social (regra ambiental e trabalhista, por exemplo), assentar família sem terra e regularizar terra pública. Os projetos aprovados dificultam os três. De um lado, segurança jurídica; do outro, reforma agrária travada e facilitação de grilagem.'
 WHEN 'Abastecimento público de medicamentos' THEN 'Mexe no preço e no acesso ao remédio que chega ao posto de saúde. De um lado, produção nacional e quebra de patente que barateiam o medicamento; do outro, menos concorrência e proteção de patente mais fraca.'
 WHEN 'Reforma tributária do consumo' THEN 'Mexe no preço do que você compra e no que sobra no fim do mês: unifica cinco impostos, devolve dinheiro a quem ganha pouco e taxa mais bebida e cigarro. De um lado, menos burocracia para as empresas; do outro, o setor de serviços tende a pagar mais.'
 ELSE impact END;

-- ---------------------------------------------------------------------------
--  Detalhes de cada politica (texto exibido em "Detalhes" na pagina da politica)
--  Reescrito para explicar as votacoes em linguagem simples e citar os apelidos
--  pelos quais as pautas ficaram conhecidas ("PL da Devastacao", "PEC da
--  Blindagem", "marco dos jogos"...). Mantenha sincronizado ao incluir ou
--  remover votacoes de uma politica.
-- ---------------------------------------------------------------------------
UPDATE policy SET description = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Reúne as votações sobre o combate à violência contra a mulher: a inclusão da violência vicária (usar os filhos para atingir a mãe) na Lei Maria da Penha, o monitoramento eletrônico de agressores, a proibição de porte de arma para quem responde por agressão, o atendimento especializado a mulheres indígenas nas delegacias, o combate à violência política de gênero e a criação do Sistema Nacional de Enfrentamento à Violência contra Meninas e Mulheres. Votar SIM apoia a política.'
 WHEN 'Redução das emissões de carbono' THEN 'Reúne as votações sobre os mecanismos de corte de emissões: o Sistema Brasileiro de Comércio de Emissões, o mercado regulado de carbono criado pela Lei 15.042/2024; e o pacote Combustível do Futuro, que trata de mobilidade de baixo carbono e da captura e estocagem geológica de dióxido de carbono. Votar SIM apoia a política.'
 WHEN 'Conservação da biodiversidade' THEN 'Reúne as votações sobre proteção de ecossistemas e espécies: a Lei do Mar, que institui a política de conservação do bioma marinho brasileiro; a adesão ao tratado internacional de conservação de espécies migratórias; a Política Nacional de Estímulo à Produção e ao Consumo Sustentáveis; e o direito de crianças e adolescentes à Natureza. Votar SIM apoia a política.'
 WHEN 'Mais investimento na educação' THEN 'Reúne as votações sobre dinheiro para a educação pública: o FUNDEB permanente na Constituição (PEC 15/2015), a exclusão da educação do teto de gastos (PEC 24/2019) e dos limites do arcabouço fiscal (PLP 163/2025), a execução orçamentária obrigatória, a política de assistência estudantil e o Pé-de-Meia, a poupança que ajuda o aluno de baixa renda a terminar o ensino médio. Votar SIM apoia mais investimento.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Reúne as votações sobre igualdade entre mulheres e homens no trabalho, com destaque para a Lei da Igualdade Salarial (PL 1085/2023), que obriga empresas a pagar o mesmo salário para a mesma função e a publicar relatórios de transparência salarial. Votar SIM apoia a política. Política em crescimento: novas votações serão adicionadas conforme o Congresso votar o tema.'
 WHEN 'Rigor no licenciamento ambiental' THEN 'Reúne as votações que flexibilizam o licenciamento ambiental, a começar pelo PL 2159/2021, apelidado de "PL da Devastação", que cria a licença por autodeclaração, e pela MPV 1308/2025, que instituiu a licença especial para obras prioritárias. Score alto = defende manter as regras rigorosas; score baixo = votou para flexibilizar.'
 WHEN 'Demarcação de terras indígenas' THEN 'Reúne as votações sobre a demarcação de terras indígenas, com destaque para o Marco Temporal, a tese de que só há direito à terra ocupada em 5 de outubro de 1988: aprovado na Câmara (PL 490/2007) e no Senado (PL 2903/2023), e depois inserido na Constituição pela PEC 48/2023. Score alto = defende os direitos territoriais indígenas.'
 WHEN 'Políticas de igualdade racial' THEN 'Reúne as votações sobre igualdade racial: a reserva de 30% das vagas em concursos públicos para pessoas negras, indígenas e quilombolas; a equiparação da injúria racial ao crime de racismo, com pena maior; o feriado nacional da Consciência Negra; a "Lista Suja" do racismo no futebol; e a PEC 9/2023, que perdoou os partidos que descumpriram a cota de financiamento de candidaturas negras (nessa, votar NÃO é que apoia a política). Score alto = apoia a igualdade racial.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Reúne as votações sobre a proteção dos direitos de quem trabalha: a favor da PEC 221/2019, que acaba com a escala 6x1 e reduz a jornada máxima, e contra o Contrato Verde e Amarelo (MPV 905/2019) e sua retomada no PL 5496/2013, que criavam contratos de jovens com FGTS e contribuição ao INSS reduzidos. Score alto = defende os direitos dos trabalhadores.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'O projeto ficou conhecido primeiro como PL da Anistia e depois como PL da Dosimetria. A anistia caiu no substitutivo: o texto aprovado não perdoa ninguém, mas reduz penas de quem participou dos atos de 8 de janeiro de 2023. Proíbe somar as penas de golpe e de abolição violenta do Estado Democrático de Direito quando praticadas no mesmo contexto, cria redução de um a dois terços para quem agiu em meio à multidão sem financiar nem liderar, e devolve a progressão de regime a um sexto da pena. Aprovado pela Câmara e pelo Senado, vetado integralmente e promulgado como Lei 15.402/2026 depois de o Congresso derrubar o veto. Score alto = a favor da redução das penas.'
 WHEN 'Política nacional de cultura' THEN 'Reúne as votações sobre dinheiro público para cultura: tornar permanente a Política Nacional Aldir Blanc (PL 363/2025), que repassa cerca de R$ 15 bilhões a estados e municípios ao longo de cinco anos, e a regulamentação do streaming (PL 8889/2017), que cobra uma contribuição de plataformas como Netflix e Prime Video para financiar o audiovisual brasileiro. Score alto = apoia o financiamento à cultura.'
 WHEN 'Reforma agrária e acesso à terra' THEN 'Reúne as votações sobre terra e reforma agrária: o PL 4357/2023, que proíbe desapropriar imóveis produtivos para fins de reforma agrária; o PL 4497/2024, o "PL da Grilagem", que valida registros sobre terras públicas em faixa de fronteira, inclusive sobre terras indígenas em demarcação; e o PL 709/2023, que endurece a punição a famílias que ocupam terras. Score alto = defende a reforma agrária e o acesso à terra.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Reúne as votações sobre a PEC 3/2021, a "PEC da Blindagem", que exigiria autorização prévia da própria Câmara ou do Senado, em voto secreto, para o STF processar criminalmente um parlamentar. Foi aprovada pela Câmara em setembro de 2025 e, depois de protestos em todo o país, rejeitada pelo Senado. Score alto = a favor da blindagem.'
 WHEN 'Isenção de impostos para igrejas' THEN 'Reúne as votações sobre a PEC 5/2023, que amplia a imunidade tributária das igrejas: hoje elas não pagam impostos sobre templos e patrimônio, e a proposta estende o benefício à compra de bens e serviços usados nas atividades religiosas. Aprovada pela Câmara em dois turnos em maio de 2026. Score alto = a favor da ampliação.'
 WHEN 'Legalização dos jogos de azar' THEN 'Reúne as votações sobre o PL 442/1991, o "marco dos jogos", que legaliza cassinos em resorts, bingos, jogo do bicho e apostas em corridas de cavalo. Foi aprovado pela Câmara em fevereiro de 2022 e segue parado no Senado. Score alto = a favor da legalização.'
 WHEN 'Abastecimento público de medicamentos' THEN 'Reúne as votações sobre como o Estado garante remédio e insumo: licitação reservada à indústria instalada no país, compra direta de hemoderivados do produtor público, como a Hemobrás, e o primeiro passo para quebrar a patente do Mounjaro e do Zepbound. Score alto = defende o abastecimento público e a produção nacional.'
 WHEN 'Reforma tributária do consumo' THEN 'Reúne as votações da reforma tributária do consumo (PEC 45/2019), promulgada como Emenda Constitucional 132/2023: substitui cinco tributos (PIS, Cofins, IPI, ICMS e ISS) por um IVA dual (CBS federal e IBS de estados e municípios), cria o cashback, que devolve imposto a famílias de baixa renda, e o imposto seletivo sobre produtos nocivos à saúde e ao meio ambiente. Inclui os votos das duas casas. Score alto = a favor da reforma.'
 ELSE description END;
