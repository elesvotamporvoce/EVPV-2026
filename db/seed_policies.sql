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
--  Distribuição e acesso à terra
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Distribuição e acesso à terra';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Distribuição e acesso à terra',
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
 WHEN 'Mais investimento na educação' THEN 'Define quanto dinheiro chega à escola pública e à universidade federal, e se essa verba fica protegida quando o governo precisa cortar gastos.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Define o que a empresa deve à trabalhadora: mesmo salário do colega homem na mesma função e licença nos dias de menstruação incapacitante.'
 WHEN 'Rigor no licenciamento ambiental' THEN 'O licenciamento é a análise que decide se uma obra pode sair do papel, e o que ela precisa fazer para não poluir o rio, o ar e o bairro ao lado.'
 WHEN 'Demarcação de terras indígenas' THEN 'Decide quem fica com terras em disputa no interior do país: estabelece a regra que define se uma área vira terra indígena ou continua como está.'
 WHEN 'Políticas de igualdade racial' THEN 'Define o quanto o poder público age para reduzir a desigualdade racial: punição por racismo, cota em concurso e partido obrigado a bancar candidatura negra.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Mexe no tempo livre e no bolso de quem tem carteira assinada: quantas horas se trabalha por semana e quanto entra no seu FGTS e no INSS.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Trata do tamanho da pena de quem invadiu e depredou o Congresso, o Planalto e o STF em 8 de janeiro de 2023.'
 WHEN 'Distribuição e acesso à terra' THEN 'Trata de uma disputa antiga no campo: quem tem muita terra e não a usa direito pode perdê-la, e quem não tem nenhuma pode receber.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Define se deputado e senador respondem a processo criminal como qualquer cidadão, ou se dependem da autorização dos colegas para serem julgados.'
 WHEN 'Política nacional de cultura' THEN 'Decide se shows, cinema, teatro e ponto de cultura da sua cidade têm verba previsível, e se o streaming paga uma contribuição que financia produção brasileira.'
 WHEN 'Isenção de impostos para igrejas' THEN 'Igreja já não paga imposto sobre templo, patrimônio e renda. A proposta estende a isenção para tudo que ela compra.'
 WHEN 'Legalização dos jogos de azar' THEN 'Decide se cassino, bingo e jogo do bicho passam a funcionar dentro da lei, com regra e imposto, em vez de na clandestinidade.'
 WHEN 'Reforma tributária do consumo' THEN 'Muda o imposto embutido no preço de tudo que você compra: cinco tributos viram um só, e quem ganha pouco recebe parte de volta.'
 WHEN 'Conservação da biodiversidade' THEN 'Define o que pode e o que não pode em área de natureza protegida, do bioma marinho às rotas de aves migratórias.'
 WHEN 'Abastecimento público de medicamentos' THEN 'Mexe no preço e na falta de remédio no posto: produção nacional, compra direta do produtor público e quebra de patente.'
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
 WHEN 'Distribuição e acesso à terra' THEN 'Terra tem que cumprir função social'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Político também é perseguido'
 WHEN 'Política nacional de cultura' THEN 'Cultura precisa de verba previsível'
 WHEN 'Isenção de impostos para igrejas' THEN 'Igreja faz o que o Estado não faz'
 WHEN 'Legalização dos jogos de azar' THEN 'Já existe, melhor regular'
 WHEN 'Reforma tributária do consumo' THEN 'Um imposto só é mais simples'
 WHEN 'Conservação da biodiversidade' THEN 'Sem conservar não há do que viver'
 WHEN 'Abastecimento público de medicamentos' THEN 'Remédio caro demais é remédio que falta'
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
 WHEN 'Distribuição e acesso à terra' THEN 'fazenda que desmata ilegalmente ou usa trabalho escravo deveria poder ser desapropriada e virar assentamento'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'o processo pode ser usado só para tirar do caminho quem incomoda'
 WHEN 'Política nacional de cultura' THEN 'repasse garantido em lei chega a quase todos os municípios, não só aos grandes centros'
 WHEN 'Isenção de impostos para igrejas' THEN 'creche, asilo e comunidade terapêutica atendem gente que o poder público não alcança'
 WHEN 'Legalização dos jogos de azar' THEN 'proibir não acabou com o jogo; só tirou o imposto e a fiscalização'
 WHEN 'Reforma tributária do consumo' THEN 'cinco tributos com regras diferentes viram um, e dá para ver quanto se paga em cada compra'
 WHEN 'Conservação da biodiversidade' THEN 'pesca, água e turismo dependem do que ainda está em pé'
 WHEN 'Abastecimento público de medicamentos' THEN 'produzir aqui e quebrar patente derruba o preço para quem depende do SUS'
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
 WHEN 'Distribuição e acesso à terra' THEN 'Quem produz não pode perder a terra'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Político não pode ter regra própria'
 WHEN 'Política nacional de cultura' THEN 'Despesa carimbada engessa o orçamento'
 WHEN 'Isenção de impostos para igrejas' THEN 'Quem não paga joga a conta no resto'
 WHEN 'Legalização dos jogos de azar' THEN 'Legalizar é facilitar o vício'
 WHEN 'Reforma tributária do consumo' THEN 'Alguém vai pagar a diferença'
 WHEN 'Conservação da biodiversidade' THEN 'Regra demais trava quem produz'
 WHEN 'Abastecimento público de medicamentos' THEN 'Sem patente ninguém pesquisa'
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
 WHEN 'Distribuição e acesso à terra' THEN 'propriedade que gera safra e emprego não deveria viver sob risco de desapropriação'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'se cometeu crime, responde como qualquer pessoa'
 WHEN 'Política nacional de cultura' THEN 'dinheiro fixado em lei disputa espaço com saúde, segurança e educação a cada ano'
 WHEN 'Isenção de impostos para igrejas' THEN 'cada isenção nova empurra para cima a alíquota que todo mundo paga no mercado'
 WHEN 'Legalização dos jogos de azar' THEN 'quanto mais fácil apostar, mais gente se endivida e mais dinheiro sujo circula'
 WHEN 'Reforma tributária do consumo' THEN 'o setor de serviços tende a pagar mais, e a alíquota final ainda não está fechada'
 WHEN 'Conservação da biodiversidade' THEN 'mais restrição no litoral e em área sensível atinge quem vive de produzir ali'
 WHEN 'Abastecimento público de medicamentos' THEN 'enfraquecer a patente afugenta o investimento que cria o remédio novo'
 ELSE side_b_note END;

-- ============================================================================
-- Texto exibido em "Por que isso importa para voce?" na PAGINA da politica.
-- E independente do quiz_hook, que e o texto curto do QUIZ: o da pagina explica
-- mais (cerca de 100 palavras) e fecha apresentando os dois lados. Nao derive um
-- do outro; se mudar um, revise o outro.
UPDATE policy SET impact = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'A maior parte da violência contra a mulher acontece dentro de casa, e o agressor quase sempre é conhecido. Estas votações tratam do que o Estado faz depois da denúncia: tornozeleira no agressor, arma proibida para quem responde por agressão, violência vicária reconhecida na Lei Maria da Penha, atendimento à mulher indígena na delegacia e um sistema nacional com recursos garantidos.
Nada disso cria crime novo. Muda a chance de a proteção chegar antes do pior.
Para quem defende, o período mais perigoso é logo depois que a mulher denuncia, não depois da sentença; para quem critica, falta delegacia e estrutura, não lei nova.'
 WHEN 'Redução das emissões de carbono' THEN 'Toda atividade que queima combustível ou derruba floresta solta gás de efeito estufa. Estas votações decidem se isso passa a ter preço.
O mecanismo principal é o mercado de carbono: quem emite acima de um limite compra crédito de quem emite menos. Poluir deixa de ser de graça e vira custo, que pode chegar ao preço final. O outro pacote trata de combustível: diesel verde, aviação e captura de carbono.
Para quem defende, grandes emissores passam a ter limite e a comprar crédito de quem emite menos; para quem critica, a conta do carbono chega no combustível e na energia, e quem paga é o consumidor.'
 WHEN 'Mais investimento na educação' THEN 'O dinheiro da educação depende de regras que dizem quanto o governo é obrigado a gastar e o que pode ser cortado quando o caixa aperta.
Estas votações mexeram nessas regras: o Fundeb virou permanente na Constituição, universidades e institutos federais saíram do teto de gastos, e foram criados a assistência estudantil e o Pé-de-Meia. O efeito aparece na creche, no salário do professor e na chance de um adolescente terminar a escola.
Para quem defende, escola e universidade dependem de dinheiro garantido; para quem critica, despesa garantida em lei tira do governo a margem de escolher prioridades a cada ano.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Mulheres e homens que fazem o mesmo trabalho nem sempre recebem o mesmo salário. Estas votações tratam de duas obrigações que a lei pode impor à empresa: pagar igual por função igual e publicar quanto paga a cada um, e dar três dias de licença por mês a quem comprove sintomas graves ligados à menstruação.
São só duas votações, então uma única ausência já desloca bastante o resultado individual.
Para quem defende, salário igual por trabalho igual e afastamento em condição de saúde não são favor; para quem critica, empresa e empregada resolvem melhor caso a caso do que uma regra igual para todas.'
 WHEN 'Rigor no licenciamento ambiental' THEN 'Licenciamento é a análise que decide se uma obra pode sair do papel, e o que ela precisa fazer para não poluir o rio, o ar e o bairro ao lado.
As duas votações aqui afrouxam essa análise: uma cria a licença por autodeclaração, em que o próprio empreendedor diz que cumpre as exigências; a outra cria um rito acelerado para obras estratégicas. Como as propostas flexibilizam, aqui apoiar a política é votar NÃO.
Para quem defende, barragens que romperam eram classificadas como de impacto médio antes do desastre; para quem critica, obra parada por anos trava saneamento, energia e emprego.'
 WHEN 'Demarcação de terras indígenas' THEN 'A Constituição garante aos indígenas as terras que ocupam tradicionalmente. A disputa é sobre o que “tradicionalmente” quer dizer.
A tese em jogo é o marco temporal: só teria direito à terra quem estivesse nela em 5 de outubro de 1988. O Congresso aprovou essa tese por lei e depois a escreveu na Constituição. Como as propostas caminham contra a demarcação, aqui apoiar a política é votar NÃO.
Para quem defende, comunidade removida à força antes de 1988 não deveria perder o direito por não estar lá naquela data; para quem critica, sem data qualquer área pode ser reivindicada e ninguém tem segurança sobre o próprio título.'
 WHEN 'Políticas de igualdade racial' THEN 'Esta política reúne cinco decisões sobre desigualdade racial: injúria racial tratada como crime de racismo, cadastro de clubes de futebol punidos, 30% das vagas em concursos federais reservadas a pessoas negras, indígenas e quilombolas, e o 20 de novembro como feriado nacional.
A quinta funciona ao contrário: a PEC 9/2023 afrouxou a punição a partidos que não bancaram candidaturas negras. Nessa, apoiar é votar NÃO.
Para quem defende, séculos de desigualdade não acabam sozinhos e é preciso política que equilibre e abra caminho; para quem critica, política que classifica por raça oficializa uma divisão que não deveria existir.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Carteira assinada significa ter direitos garantidos por lei, que não dependem de negociação. Estas votações tratam de quanto esse piso vale.
De um lado, a redução da jornada máxima na Constituição, proposta associada ao fim da escala 6x1. Do outro, contratos com FGTS e INSS reduzidos para jovens: custam menos ao empregador, mas o trabalhador acumula menos fundo de garantia e menos tempo de aposentadoria. Por isso apoiar é votar SIM na jornada e NÃO nos contratos.
Para quem defende, sem mínimo garantido em lei a negociação vira imposição de quem tem mais poder; para quem critica, acordo entre as partes se ajusta ao setor e ao porte.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Em 8 de janeiro de 2023, milhares de pessoas invadiram e depredaram as sedes dos três poderes. Centenas foram condenadas.
O projeto nasceu como anistia e mudou no caminho: o texto aprovado não perdoa ninguém, reduz penas. Proíbe somar as condenações por golpe e por abolição do Estado Democrático quando ocorrem no mesmo episódio, e corta de um a dois terços a pena de quem participou sem liderar nem financiar.
Para quem defende, mais de quinze anos para quem entrou na multidão sem liderar nem financiar é punição excessiva; para quem critica, reduzir pena de ataque às instituições sinaliza que atentar contra a democracia sai barato.'
 WHEN 'Política nacional de cultura' THEN 'Boa parte da cultura fora dos grandes centros depende de dinheiro público: o festival da cidade, o grupo de teatro, o ponto de cultura.
Uma votação torna permanente a Política Aldir Blanc, que repassa recursos federais a estados e municípios — permanente quer dizer que o município pequeno consegue planejar, em vez de depender de edital que aparece ou não. A outra faz o streaming pagar uma contribuição para financiar produção brasileira.
Para quem defende, repasse garantido em lei chega a quase todos os municípios, não só aos grandes centros; para quem critica, dinheiro fixado em lei disputa espaço com saúde, segurança e educação a cada ano.'
 WHEN 'Distribuição e acesso à terra' THEN 'A Constituição diz que a propriedade precisa cumprir função social. Quando não cumpre, pode ser desapropriada e destinada a famílias sem terra.
As quatro votações aqui estreitam esse caminho: uma proíbe desapropriar imóvel produtivo, outra pune quem ocupa propriedade, e duas validam registros sobre terras públicas em faixa de fronteira. Como as propostas caminham contra o acesso à terra, aqui apoiar a política é votar NÃO.
Para quem defende, fazenda que desmata ilegalmente ou usa trabalho escravo deveria poder ser desapropriada e virar assentamento; para quem critica, propriedade que gera safra e emprego não deveria viver sob risco de desapropriação.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Hoje é o Supremo que decide se abre processo criminal contra um deputado ou senador, sem pedir licença a ninguém.
A PEC 3/2021 muda isso: o processo só começaria com autorização da própria Câmara ou do próprio Senado, em votação secreta. Na prática, o acusado passa a depender do voto dos colegas para ser julgado. A Câmara aprovou em setembro de 2025; depois de protestos pelo país, o Senado rejeitou.
Para quem defende, o processo pode ser usado só para tirar do caminho quem incomoda; para quem critica, se cometeu crime, responde como qualquer pessoa.'
 WHEN 'Isenção de impostos para igrejas' THEN 'Igrejas já não pagam imposto sobre o templo, o patrimônio e a renda. A PEC 5/2023 estende essa isenção ao consumo: os tributos embutidos em tudo que elas compram, de cadeira e microfone a obra e serviço. Alcança também creches, comunidades terapêuticas, seminários e conventos ligados a elas.
O imposto não desaparece, muda de lugar: o que um grupo deixa de pagar tende a aparecer na alíquota que os outros pagam.
Para quem defende, o dinheiro doado pelo fiel já foi tributado uma vez e a igreja sustenta creche e asilo que o poder público não alcança; para quem critica, cada isenção nova empurra para cima a alíquota de todo mundo.'
 WHEN 'Legalização dos jogos de azar' THEN 'Cassino, bingo e jogo do bicho são proibidos desde os anos 1940, mas continuam existindo na clandestinidade, sem imposto e sem fiscalização. O PL 442/1991 traz essa atividade para dentro da lei, com regras de funcionamento e cobrança de tributos.
Nada mudou na prática: a Câmara aprovou em 2022, por margem apertada, e o projeto está parado no Senado desde então.
Para quem defende, a atividade já existe e, regulada, gera emprego, turismo e imposto; para quem critica, legalizar amplia o vício e abre porta para a lavagem de dinheiro.'
 WHEN 'Reforma tributária do consumo' THEN 'Quase tudo que você compra tem imposto no preço. Até 2023 esse imposto vinha de cinco tributos diferentes, cada um com regra própria.
A PEC 45/2019 substitui os cinco por um imposto em duas partes, uma federal e outra de estados e municípios. Cria também o cashback, que devolve parte do imposto a famílias de baixa renda, e cobra mais de bebida e cigarro. Produtos tendem a ficar relativamente mais baratos; serviços, mais caros.
Para quem defende, cinco impostos viram um só e a cobrança fica mais simples e visível; para quem critica, o setor de serviços tende a pagar mais e a alíquota final ainda não está fechada.'
 WHEN 'Conservação da biodiversidade' THEN 'Biodiversidade parece assunto distante, mas sustenta o peixe que chega ao mercado, a água da cidade, o inseto que poliniza a lavoura e o turismo que emprega no litoral.
As cinco votações protegem ecossistemas e espécies. A principal é a Lei do Mar, primeira política nacional para o bioma marinho brasileiro. Há também um acordo sobre espécies migratórias, uma política de produção e consumo sustentáveis, e o direito de crianças ao contato com a natureza.
Para quem defende, sem conservar não há pesca, água nem turismo no futuro; para quem critica, mais regra em área sensível trava atividade produtiva em regiões que dependem dela.'
 WHEN 'Abastecimento público de medicamentos' THEN 'Quando falta remédio no posto, a causa costuma estar longe do balcão: no preço do fabricante, na dependência de um fornecedor no exterior, ou numa regra de compra que trava o SUS.
Estas votações tratam disso: incentivo à indústria instalada no país, compra de hemoderivados direto do produtor público, e a declaração de interesse público do Mounjaro e do Zepbound, passo previsto em lei antes de quebrar a patente.
Para quem defende, produção nacional e quebra de patente barateiam o remédio e reduzem a dependência do exterior; para quem critica, enfraquecer a patente afugenta investimento em pesquisa.'
 ELSE impact END;


-- ---------------------------------------------------------------------------
--  Detalhes de cada politica (texto exibido em "Detalhes" na pagina da politica)
--  Reescrito para explicar as votacoes em linguagem simples e citar os apelidos
--  pelos quais as pautas ficaram conhecidas ("PL da Devastacao", "PEC da
--  Blindagem", "marco dos jogos"...). Mantenha sincronizado ao incluir ou
--  remover votacoes de uma politica.
-- ---------------------------------------------------------------------------
-- Texto de "Detalhes" na pagina da politica: explica as votacoes em linguagem
-- simples, dizendo o que cada projeto faz antes de citar o numero, e por que uma
-- votacao entrou com peso reduzido ou por que a politica e invertida.
-- Mantenha sincronizado ao incluir ou remover votacoes de uma politica.
UPDATE policy SET description = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'São seis votações, todas na Câmara dos Deputados. Votar SIM apoia a política em todas elas.
Três decidiram a pressa, não o conteúdo: os requerimentos de urgência do PL 3874/2023, que proíbe compra e porte de arma para quem responde por agressão contra mulher; do PL 4381/2023, sobre o atendimento a mulheres indígenas nas delegacias; e do PL 68/2025, sobre violência política de gênero. Urgência é o voto que manda a matéria direto ao plenário, sem passar pelas comissões.
Duas foram votações de destaque, quando o plenário decide se mantém um trecho do texto: o PL 2942/2024, que determina o monitoramento eletrônico de agressores, e o PL 3880/2024, que inclui a violência vicária — usar os filhos para atingir a mãe — entre as formas de violência doméstica da Lei Maria da Penha.
A sexta é o PLP 41/2026, que cria o Sistema Nacional de Enfrentamento da Violência contra Meninas e Mulheres e destina recursos ao combate ao feminicídio. Foi aprovado por 470 a 1.
Duas dessas votações entram com peso reduzido por terem sido quase unânimes: o PLP 41/2026 e o PL 2942/2024, aprovado por 408 a 13. Quando quase todo mundo vota igual, o voto distingue pouco um parlamentar do outro.'
 WHEN 'Redução das emissões de carbono' THEN 'São quatro votações, todas na Câmara. Votar SIM apoia a política.
Duas são do PL 182/2024, que instituiu o Sistema Brasileiro de Comércio de Emissões de Gases de Efeito Estufa, o mercado regulado de carbono, hoje Lei 15.042/2024. Ele fixa limites de emissão para grandes emissores e permite que quem fica abaixo do limite venda o excedente a quem passa. A votação de novembro de 2024, que aprovou o texto vindo do Senado, é a decisiva desta política.
As outras duas são do PL 528/2020, o pacote Combustível do Futuro: mobilidade de baixo carbono, programa nacional de combustível sustentável de aviação, programa de diesel verde e captura e estocagem geológica de dióxido de carbono.
Uma das votações do PL 528/2020 foi quase unânime, 429 a 19, e por isso entra com peso reduzido.'
 WHEN 'Mais investimento na educação' THEN 'É a política com mais votações: onze, sendo oito na Câmara e três no Senado. Votar SIM apoia mais investimento em todas.
A PEC 15/2015 tornou o Fundeb permanente na Constituição; antes ele tinha prazo e precisava ser renovado. A PEC 24/2019 excluiu as despesas das instituições federais de ensino dos limites de gasto primário.
O PLP 243/2023 criou o programa de incentivo à permanência no ensino médio, que deu origem ao Pé-de-Meia, e foi votado nas duas casas. O PLP 153/2024, no Senado, tratou da transferência de saldos do Fundo Nacional de Desenvolvimento da Educação para estados e municípios. O PL 3118/2024 incluiu a assistência estudantil entre as prioridades do Fundo Social.
O PLP 163/2025 é o mais recente e o mais disputado: exclui despesas com educação e saúde dos limites do arcabouço fiscal. Foi aprovado na Câmara por 296 a 145 e no Senado por 47 a 16.
Três votações entram com peso reduzido por quase-unanimidade: o primeiro turno da PEC 15/2015, aprovado por 499 a 7, e as duas do Senado que passaram sem nenhum voto contrário.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'São duas votações, ambas na Câmara. Votar SIM apoia a política.
O PL 1085/2023 é a Lei da Igualdade Salarial: obriga a pagar o mesmo salário a mulheres e homens na mesma função e cria a obrigação de publicar relatórios de transparência salarial. Foi aprovado por 325 a 36 e é a votação decisiva desta política.
A segunda é o requerimento de urgência do PL 1249/2022, que garante três dias consecutivos de licença por mês às trabalhadoras que comprovem sintomas graves associados ao fluxo menstrual. Urgência decide se a matéria vai direto ao plenário: mede disposição de pautar, não posição sobre o conteúdo.
Com só duas votações, esta política segue marcada como provisória. Ela está publicada e pontuada, mas com base estreita.'
 WHEN 'Rigor no licenciamento ambiental' THEN 'São duas votações, ambas na Câmara, e esta é uma política invertida: votar NÃO é que apoia o rigor no licenciamento, porque as duas propostas em pauta afrouxam as regras. As duas foram aprovadas.
O PL 2159/2021 ficou conhecido como “PL da Devastação”. Ele reescreve a lei geral do licenciamento, regulamentando o artigo 225 da Constituição, e cria a licença por autodeclaração, em que o empreendedor declara que atende às condições e recebe a licença sem análise prévia do órgão ambiental. Foi aprovado por 267 a 116.
A MPV 1308/2025 institui o licenciamento ambiental especial, um rito mais rápido para empreendimentos classificados como estratégicos. A votação registrada é de destaque, quando o plenário decide manter um trecho do texto.
As duas entram com peso forte por decidirem o mérito da matéria. Com apenas duas votações, a base é estreita: uma ausência pesa muito no índice individual.'
 WHEN 'Demarcação de terras indígenas' THEN 'São cinco votações, duas na Câmara e três no Senado, e esta é uma política invertida: votar NÃO é que apoia os direitos territoriais indígenas, porque todas as propostas instituem o marco temporal.
O PL 490/2007 foi o primeiro. Regulamenta o artigo 231 da Constituição, que trata das terras indígenas, e fixa o marco temporal. A Câmara o aprovou em maio de 2023 por 283 a 155.
No Senado, a mesma matéria tramitou como PL 2903/2023 e foi aprovada em setembro de 2023 por 43 a 21. Pouco antes, o Supremo Tribunal Federal havia rejeitado a tese do marco temporal.
A resposta do Congresso foi a PEC 48/2023, que escreve o marco temporal diretamente na Constituição, e não mais em lei ordinária. O Senado a aprovou nos dois turnos em dezembro de 2025.
Nenhuma das cinco votações foi quase unânime: todas separam bem os parlamentares, com maiorias entre 65% e 79%.'
 WHEN 'Políticas de igualdade racial' THEN 'São cinco votações, todas na Câmara. Em quatro delas votar SIM apoia a política; em uma, votar NÃO.
O PL 4566/2021 equiparou a injúria racial ao crime de racismo, com pena maior, e previu suspensão de direitos quando o racismo ocorre em atividade esportiva. Foi aprovado por 358 a 17: quase unânime, e por isso entra com peso reduzido.
O PL 3268/2021 declarou o 20 de novembro feriado nacional de Zumbi e da Consciência Negra. O PL 1958/2021 reservou 30% das vagas em concursos públicos federais a pessoas pretas, pardas, indígenas e quilombolas, e é a votação decisiva desta política. O PL 1069/2025 cria a “Lista Suja do Racismo no Futebol”, cadastro de clubes e entidades punidos por racismo.
A exceção é a PEC 9/2023, que mudou as sanções aos partidos que não aplicaram o mínimo de recursos em candidaturas negras. Como ela caminha contra a política, aqui apoiar é votar NÃO. A Câmara a aprovou em primeiro turno por 344 a 89.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'São três votações, todas na Câmara, e a direção muda conforme a proposta.
A MPV 905/2019 criou o Contrato de Trabalho Verde e Amarelo, com FGTS e contribuição previdenciária reduzidos para jovens sem vínculo anterior. O PL 5496/2013 retomou a mesma ideia, com contrato por prazo determinado para jovens de 16 a 24 anos sem emprego anterior. Nas duas, apoiar os direitos trabalhistas é votar NÃO, e as duas foram aprovadas.
A PEC 221/2019 vai na direção oposta: reduz a jornada máxima prevista na Constituição. Pela ementa original, de 44 para 36 horas semanais ao longo de dez anos. É a proposta associada ao fim da escala 6x1, e nela apoiar é votar SIM. A Câmara aprovou o primeiro turno em maio de 2026 por 472 a 22.
Justamente por ser quase unânime, essa votação entra com peso reduzido: com 96% dos votos de um lado, ela distingue pouco um parlamentar do outro.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'São quatro votações, todas na Câmara e todas sobre o mesmo projeto, o PL 2162/2023. Votar SIM apoia a redução das penas.
A primeira, em setembro de 2025, foi o requerimento de urgência, que mandou o texto direto ao plenário. As três seguintes ocorreram na madrugada de 10 de dezembro de 2025: dois destaques e a votação do mérito, aprovada por 291 a 148.
O projeto ficou conhecido primeiro como PL da Anistia e depois como PL da Dosimetria. A ementa original concedia anistia aos participantes de manifestações políticas desde outubro de 2022; a anistia caiu no substitutivo, e o texto aprovado passou a apenas reduzir penas.
Depois da Câmara, o projeto foi aprovado pelo Senado, vetado integralmente pela Presidência e promulgado como Lei 15.402/2026 quando o Congresso derrubou o veto. Esta política reúne apenas as votações da Câmara.
Nenhuma das quatro foi quase unânime: as maiorias ficaram entre 62% e 66%.'
 WHEN 'Política nacional de cultura' THEN 'São duas votações, ambas na Câmara. Votar SIM apoia a política.
O PL 363/2025 altera a lei que instituiu a Política Nacional Aldir Blanc de Fomento à Cultura, tornando permanente o repasse de recursos federais a estados e municípios. É a votação decisiva desta política, aprovada por 278 a 111.
O PL 8889/2017 regulamenta a provisão de conteúdo audiovisual por demanda, o streaming. Cria obrigações para as plataformas que operam no país, incluindo contribuição destinada ao financiamento do audiovisual brasileiro. Foi aprovado por 330 a 118.
A base é estreita, com apenas duas votações, mas as duas decidiram o mérito da matéria e nenhuma foi quase unânime.'
 WHEN 'Distribuição e acesso à terra' THEN 'São quatro votações, todas na Câmara, e esta é uma política invertida: votar NÃO é que apoia a distribuição e o acesso à terra, porque as quatro propostas caminham no sentido oposto. Todas foram aprovadas.
O PL 709/2023 altera a Lei 8.629/1993, a lei da reforma agrária, para criar impedimentos a quem ocupa ou invade propriedades.
O PL 4357/2023 altera o artigo 2º da mesma lei, que define o que pode ser desapropriado, para proteger o imóvel produtivo da desapropriação por interesse social. É a votação de maior peso desta política.
O PL 4497/2024 aparece duas vezes: na aprovação pela Câmara, em junho de 2025, e na aprovação do texto que voltou do Senado, em dezembro de 2025. Ele ratifica registros imobiliários decorrentes de alienações e concessões de terras públicas em faixa de fronteira, e ficou conhecido como “PL da Grilagem”.
Nenhuma das quatro foi quase unânime: as maiorias ficaram entre 72% e 77%.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'São três votações, todas na Câmara e todas sobre a PEC 3/2021. Votar SIM apoia a blindagem.
Como toda proposta de emenda à Constituição, ela precisa passar em dois turnos. O primeiro turno, em 16 de setembro de 2025, aprovou o substitutivo por 353 a 134 e é a votação decisiva. O segundo turno, no mesmo dia, confirmou por 344 a 133. No dia seguinte, o plenário aprovou ainda uma emenda aglutinativa, por 314 a 168.
A PEC altera os artigos 14, 27, 53, 102 e 105 da Constituição, ou seja, alcança também as regras aplicáveis a deputados estaduais e a competência do Supremo Tribunal Federal e do Superior Tribunal de Justiça.
Depois de aprovada na Câmara, a proposta foi rejeitada pelo Senado. Como não há votação nominal do Senado nesta base para essa matéria, nenhum senador recebe índice nesta política.'
 WHEN 'Isenção de impostos para igrejas' THEN 'São duas votações, ambas na Câmara e ambas em 28 de maio de 2026. Votar SIM apoia a ampliação.
A PEC 5/2023 acrescenta um parágrafo ao artigo 150 da Constituição, que trata das imunidades tributárias. O primeiro signatário é o deputado Marcelo Crivella; o texto aprovado é do relator Fernando Máximo.
Por ser emenda constitucional, precisou de dois turnos: 385 a 93 no primeiro, que é a votação decisiva, e 368 a 96 no segundo.
A imunidade ampliada não passa a valer sozinha: depende de lei complementar que defina critérios de habilitação uniformes em todo o país.
Depois da Câmara, a proposta foi enviada ao Senado, onde ainda não foi votada. Por isso nenhum senador recebe índice nesta política.'
 WHEN 'Legalização dos jogos de azar' THEN 'São duas votações, ambas na Câmara e ambas em 24 de fevereiro de 2022. Votar SIM apoia a legalização.
O PL 442/1991 nasceu tratando apenas do jogo do bicho e cresceu até virar o chamado “marco dos jogos”. O texto aprovado dispõe sobre a exploração de jogos e apostas em todo o território nacional, revoga o Decreto-Lei 9.215/1946, que proibiu os cassinos, e dispositivos do Decreto-Lei 3.688/1941, a Lei das Contravenções Penais.
A votação do mérito foi a mais apertada de todo o conjunto de políticas do site: 246 a 202, ou 55% de maioria. Logo depois, um destaque foi decidido por 234 a 175.
O projeto está no Senado desde 2022 e não foi votado lá. Por isso nenhum senador recebe índice nesta política, e o índice dos deputados reflete uma posição tomada há mais de quatro anos, numa legislatura anterior.'
 WHEN 'Reforma tributária do consumo' THEN 'São quatro votações, duas na Câmara e duas no Senado. É uma das três políticas do site com votos das duas casas. Votar SIM apoia a reforma.
Por ser emenda constitucional, a PEC 45/2019 precisou de dois turnos em cada casa. Na Câmara, em julho de 2023: 382 a 118 no primeiro turno, que é a votação decisiva, e 375 a 113 no segundo. No Senado, em novembro de 2023: 53 a 24 nos dois turnos.
O texto substitui PIS, Cofins, IPI, ICMS e ISS por um IVA dual — a CBS federal e o IBS de estados e municípios —, cria o cashback para famílias de baixa renda e o imposto seletivo sobre produtos nocivos à saúde e ao meio ambiente.
Foi promulgada como Emenda Constitucional 132/2023. As regras concretas vêm por leis complementares posteriores, que não fazem parte desta política.'
 WHEN 'Conservação da biodiversidade' THEN 'São cinco votações, todas na Câmara. Votar SIM apoia a política.
O PL 6969/2013 institui a Política Nacional para a Conservação e o Uso Sustentável do Bioma Marinho Brasileiro, a Lei do Mar. Aparece duas vezes: na aprovação do texto, por 378 a 66, e num destaque logo em seguida.
O PL 2225/2024 estabelece diretrizes para o direito de crianças e adolescentes à natureza e altera o Estatuto da Criança e do Adolescente, o Estatuto da Cidade e a Política Nacional do Meio Ambiente.
O PL 3899/2012 institui a Política Nacional de Estímulo à Produção e ao Consumo Sustentáveis.
A MSC 112/2026 levou ao Congresso o acordo firmado na 15ª Conferência das Partes da Convenção sobre Espécies Migratórias, assinado em Nairóbi em dezembro de 2025.
As cinco entram com peso normal: nenhuma foi marcada como decisiva na curadoria e nenhuma foi quase unânime.'
 WHEN 'Abastecimento público de medicamentos' THEN 'São seis votações, todas na Câmara. Em cinco delas votar SIM apoia a política; em uma, votar NÃO.
Três são do PL 2583/2020, que institui a Estratégia Nacional de Saúde para incentivar a produção nacional de insumos, medicamentos e materiais. A primeira é um requerimento rejeitado por 55 a 212, e nessa apoiar a política era votar NÃO. Em seguida vieram a aprovação do mérito, por 352 a 63, e um destaque.
O PL 424/2015 permite dispensa de licitação para a compra de hemoderivados pelo SUS, o que viabiliza a compra direta de produtores públicos como a Hemobrás. Aparece duas vezes: no requerimento de urgência e num destaque posterior.
O PL 68/2026 declara de interesse público os medicamentos Mounjaro e Zepbound, para os fins do artigo 71 da Lei de Propriedade Industrial, o dispositivo que permite o licenciamento compulsório de patente. Seu requerimento de urgência foi aprovado por 337 a 19 — 94,7% de maioria, pouco abaixo do limiar de 95%, e por isso a votação manteve o peso normal.'
 ELSE description END;
