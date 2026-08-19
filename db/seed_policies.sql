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
--  Igualdade de gênero no trabalho
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Igualdade de gênero no trabalho';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Igualdade de gênero no trabalho',
    'Igualdade entre mulheres e homens no mundo do trabalho: igualdade salarial obrigatória (PL 1085/2023) e direitos trabalhistas ligados à maternidade e ao cuidado. Votar SIM apoia a política. Política em crescimento: novas votações serão adicionadas.',
    false) RETURNING id
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
--  Recomposta em 04/08/2026 apos auditoria dos objetos de cada votacao
--  (campo descUltimaAberturaVotacao da API da Camara):
--   * saiu 1548579-144 (destaque de dez/2023): esquerda votou NAO por achar
--     o texto fraco (agro fora do mercado) — sinal invertido para o eixo
--   * saiu 2238434-100: supressao tecnica sobre biometano, nao mede clima
--   * entrou 2269745-84 INVERTIDA: destaque do PSOL para tirar "gas natural"
--     do Paten; manter o texto = manter o fossil, logo NAO apoia a politica
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Redução das emissões de carbono';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Redução das emissões de carbono',
    'Reúne as votações sobre o corte de emissões: a aprovação final do mercado regulado de carbono (PL 182/2024, hoje Lei 15.042/2024), o pacote Combustível do Futuro (PL 528/2020) e, invertido, o destaque que manteve o gás natural entre as fontes do programa de transição energética (PL 327/2021). Nessa, votar NÃO apoia a política. Score alto = apoia a redução das emissões.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2238434-80','for','normal'),    -- PL 528/2020 Combustivel do Futuro (merito; 429x19, vira weak)
  ('2269745-84','against','normal'),-- Paten: manter gas natural = contra a politica (225x187)
  ('1548579-126','for','normal'),   -- mercado de carbono: aprovacao na Camara, dez/2023 (299x103) [auditoria 19/08/2026]
  ('1548579-194','for','strong')    -- PL 182/2024 mercado de carbono, texto final do Senado (336x38)
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
--  Flexibilização do licenciamento ambiental
--
--  18/08/2026: DES-INVERTIDA e recomposta. Era "Rigor no licenciamento
--  ambiental", politica invertida com stances 'against'. O que o Congresso
--  votou em 2025 foi a flexibilizacao; nomeando pelo que foi votado, votar
--  SIM apoia a politica e some a explicacao de inversao da pagina.
--  Auditoria via descUltimaAberturaVotacao (API da Camara):
--   * 257161-454 e o MERITO das Emendas do Senado ao PL 2159/2021 (parecer
--     Ze Vitor, ressalvados os destaques); mandou o texto a sancao
--     (Lei 15.190/2025). 267x116.
--   * entraram os 5 destaques nominais de 17/07/2025: cada um decide uma
--     medida distinta, nao e empilhamento.
--   * 2541991-38 e a UNICA votacao nominal da MPV 1308/2025 (Lei 15.300/2025):
--     DVS da Fdr PSOL-REDE contra o art. 6 (rodovias "estrategicas", BR-319);
--     "Mantido o texto", 300x123. O merito da MPV (2541991-29) foi simbolico.
--   * FORA: redacao final 257161-483 (empilharia com o merito), requerimentos
--     procedimentais 257161-442/446/450 (442 e 446 tem sinal invertido, sao
--     obstrucao) e as votacoes de 2021 (outra legislatura).
--   * REMOVIDA a 2324721-94 (PL 1366/2022 silvicultura): estava neste seed
--     mas NAO estava no banco (divergencia detectada em 18/08/2026) e nao
--     pertence ao eixo da lei geral do licenciamento.
--  PENDENTE: votacao dos vetos (VET 29/2025, 27/11/2025, Camara 167x295)
--  nao esta na API da Camara (PDFs SISCON, ver extract_vetos_cn.py na pasta
--  do projeto). Se ingerida, entra como 'against': la SIM = manter o veto.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Flexibilização do licenciamento ambiental';
DELETE FROM policy WHERE name = 'Rigor no licenciamento ambiental';  -- nome antigo
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Flexibilização do licenciamento ambiental',
    'Simplificar o licenciamento ambiental: o PL 2159/2021 (lei geral, com a licença por autodeclaração) e a MPV 1308/2025 (licenciamento especial acelerado). Votar SIM apoia a flexibilização.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('257161-454','for','strong'),   -- PL 2159/2021: merito das Emendas do Senado (267x116)
  ('257161-462','for','normal'),   -- Emenda 1: mineracao de grande porte fora do regime Conama (242x117)
  ('257161-465','for','normal'),   -- Emenda 3: Licenca Ambiental Especial monofasica (232x104)
  ('257161-467','for','normal'),   -- Emenda 4: porte/potencial poluidor pelo ente federativo (234x101)
  ('257161-476','for','normal'),   -- Emenda 18: amplia a LAC, analise por amostragem (221x77)
  ('257161-479','for','normal'),   -- Emenda 28: revoga protecoes da Lei da Mata Atlantica (229x82)
  ('2541991-38','for','strong')    -- MPV 1308/2025: DVS art. 6 mantido (300x123)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Investimento na educação pública
--  (renomeada em 18/08/2026; era "Mais investimento na educação")
--  (sem o SNE/PLP 235, que é governança — candidata a política própria)
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Investimento na educação pública';
DELETE FROM policy WHERE name = 'Mais investimento na educação';  -- nome antigo
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Investimento na educação pública',
    'Mais recursos para a educação pública: FUNDEB permanente, exclusão da educação do teto de gastos/arcabouço fiscal, execução orçamentária obrigatória, assistência estudantil e Pé-de-Meia (permanência no ensino médio). Votar SIM apoia mais investimento.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','2194899-103','for','strong'),  -- PEC 24/2019: 1º turno do substitutivo (principal)
  ('camara','2194899-137','for','normal'),  -- PEC 24/2019: 2º turno (331x163) [auditoria 19/08/2026]
  ('camara','2194899-125','for','normal'),  -- PEC 24/2019 educação fora do teto (destaque)
  ('camara','2541109-38','for','strong'),   -- PLP 163/2025: aprovacao principal na Camara
  ('camara','2541109-45','for','normal'),   -- PLP 163/2025 fora dos limites fiscais (destaque)
  ('camara','2541109-88','for','normal'),   -- PLP 163/2025: Substitutivo do Senado (320x109) [auditoria 19/08/2026]
  ('camara','1198512-250','for','strong'),  -- FUNDEB permanente: 1º turno do substitutivo (principal)
  ('camara','1198512-272','for','normal'),  -- FUNDEB: 2º turno (492x6, vira weak) [auditoria 19/08/2026]
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
--  Marco temporal para terras indígenas (ex-"Demarcação de terras indígenas")
--
--  18/08/2026: DES-INVERTIDA e renomeada. Era politica invertida (stances
--  'against'); nomeando pelo que o Congresso de fato votou, SIM apoia o marco
--  temporal e some a explicacao de inversao da pagina.
--   * SAIU a 345311-279 ("Mantido o texto", 290x142): auditoria via
--     descUltimaAberturaVotacao mostrou que e o DTQ 4 do bloco UNIAO sobre o
--     par. 4 do art. 16 do substitutivo (Uniao retomar terra ja demarcada se
--     os "tracos culturais" da comunidade mudarem). Eixo proprio, nao e marco
--     temporal. Candidata a politica futura.
--   * 19/08/2026: ENTROU a 345311-276 (DTQ 3 PSOL-REDE, DVS do art. 4 do
--     substitutivo, O artigo que define o marco temporal; mantido 288x148).
--     Corrige efeito colateral da remocao da -279: com 1 so votacao na
--     Camara, MIN_ATTENDED=2 deixava TODOS os deputados sem score.
--  30/07/2026: o PL 4497/2024 ("PL da Grilagem") ja havia sido retirado: e
--  titulacao de terra em faixa de fronteira, nao demarcacao indigena. Segue na
--  politica de reforma agraria ('2471177-56' e '2471177-102').
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Marco temporal para terras indígenas';
DELETE FROM policy WHERE name = 'Demarcação de terras indígenas';  -- nome antigo
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Marco temporal para terras indígenas',
    'Instituir o marco temporal: só tem direito à terra indígena quem a ocupava em 5 de outubro de 1988. A FAVOR do PL 490/2007 (Câmara), do PL 2903/2023 e da PEC 48/2023 (Senado). Votar SIM apoia o marco temporal.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','345311-270','for','strong'),  -- PL 490/2007: merito do substitutivo (283x155)
  ('camara','345311-276','for','normal'),  -- DTQ 3 PSOL: art. 4 (o marco temporal) mantido (288x148)
  ('senado','6756','for','strong'),        -- PL 2903/2023: merito (43x21)
  ('senado','7032','for','strong'),        -- PEC 48/2023: 1º turno (52x14)
  ('senado','7033','for','normal')         -- PEC 48/2023: 2º turno (52x15)
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Políticas de igualdade racial
--
--  18/08/2026: revisada. Auditoria via descUltimaAberturaVotacao:
--   * SAIU a PEC 9/2023 ('2352476-149','against','normal'): sinal CRUZADO.
--     A federacao PT-PCdoB-PV e o PSB orientaram SIM (o substitutivo tambem
--     impoe aos partidos financiar candidaturas negras); os NAOs misturam
--     PSOL-REDE (contra a anistia) com NOVO/Oposicao (outros motivos).
--     Voto com os dois polos trocados nao mede o eixo. Os 2 DVS do PSOL
--     (2352476-155 e -171) foram 404x23 e 379x23, quase unanimes, nao entram.
--   * ENTROU a urgencia do PL 1958/2021 ('2462049-9', 272x140): orientacao
--     limpa no eixo (Governo/PT/PSOL/PSB Sim; PL/NOVO/Oposicao Nao).
--   * 2487399-57 conferida: DTQ 1 (NOVO) para suprimir "torcedores" do
--     art. 1 do substitutivo da Lista Suja; manter o texto = alcance maior.
--   * 1301128-43 (injuria racial): unica nominal da proposicao, 358x17
--     (vira weak), legislatura anterior (nov/2021), mantida com esse aviso.
--  Sem inversao: as 5 votacoes sao 'for'.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Políticas de igualdade racial';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Políticas de igualdade racial',
    'Promoção da igualdade racial: cota de 30% em concursos públicos para pretos, pardos, indígenas e quilombolas; equiparação da injúria racial ao crime de racismo; feriado nacional da Consciência Negra; e "Lista Suja" do racismo no futebol. Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2462049-9','for','normal'),    -- PL 1958/2021: urgencia das cotas em concursos (272x140)
  ('2439779-55','for','strong'),   -- PL 1958/2021: substitutivo, cotas 30% (241x94, decisiva)
  ('1301128-43','for','strong'),   -- injuria racial = racismo (358x17, vira weak; nov/2021)
  ('2299903-53','for','normal'),   -- PL 3268/2021: feriado Consciencia Negra (286x121)
  ('2487399-57','for','normal')    -- PL 1069/2025: Lista Suja, DVS "torcedores" mantido (295x120)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Proteção dos direitos trabalhistas
--
--  18/08/2026: revisada e ampliada de 3 para 5 votacoes. Auditoria via
--  descUltimaAberturaVotacao + orientacoes:
--   * ENTROU 575585-99 (DTQ 2 Fdr PT-PCdoB-PV, DVS do art. 441-G do
--     substitutivo do PL 5496: reducao da aliquota patronal previdenciaria).
--     "Mantido o texto" 312x104: SIM = manter o corte = against.
--   * ENTROU 2233802-438 (PEC 221, 2o turno, 461x19): consistencia com as
--     demais PECs do site, que entram com os dois turnos. Vira weak.
--   * 575585-92 conferida: orientacao PT-PCdoB-PV e PSOL-REDE Nao;
--     PL/NOVO/blocos Sim; Governo e Maioria Liberado. Sinal ok.
--   * 2233802-416 (requerimento 372x101) fora: procedimental.
--   * MPV 905 (abr/2020, legislatura anterior): mantido so o merito -65;
--     os destaques de 2020 seriam empilhamento de legislatura antiga.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Proteção dos direitos trabalhistas';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Proteção dos direitos trabalhistas',
    'Defesa e ampliação dos direitos trabalhistas: A FAVOR do fim da escala 6x1 (PEC 221/2019, dois turnos) e CONTRA a redução de FGTS e INSS em contratos de jovens (Contrato Verde e Amarelo, MPV 905/2019, e sua retomada no PL 5496/2013, mérito e destaque). Score alto = defende os direitos dos trabalhadores.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2229308-65','against','strong'),  -- MPV 905/2019: Contrato Verde e Amarelo, merito (322x153, abr/2020)
  ('575585-92','against','strong'),   -- PL 5496/2013: substitutivo do contrato jovem (286x91)
  ('575585-99','against','normal'),   -- PL 5496/2013: DVS art. 441-G, corte da patronal mantido (312x104)
  ('2233802-424','for','strong'),     -- PEC 221/2019: 1o turno, fim da escala 6x1 (472x22, vira weak)
  ('2233802-438','for','normal')      -- PEC 221/2019: 2o turno (461x19, vira weak)
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Redução de penas do 8 de Janeiro (um projeto só, PL 2162/2023, duas casas)
--
--  18/08/2026: revisada e ampliada de 4 para 5 votacoes.
--  Auditoria via descUltimaAberturaVotacao:
--   * -81 e o DTQ 6 (PSB), DVS do art. 112 da LEP (progressao de regime);
--     -86 e o DTQ 4 (Fdr PT-PCdoB-PV), DVS de trecho do mesmo art. 112.
--     "Mantido o texto" = manter o beneficio = for. Sinais conferidos.
--   * ENTROU a votacao do SENADO (7041, 17/12/2025, 48x25, "nos termos do
--     parecer"): senadores nao pontuam (MIN_ATTENDED=2 e e a unica do
--     Senado aqui), mas o voto individual aparece na pagina de cada um.
--   * FORA: 3 DVS do PT de madrugada com quorum desabado (2358548-90 230x34,
--     -93 229x26, -96 231x23: a propria federacao autora teve <40 Naos, o
--     placar nao reflete a disputa real), encerramento de discussao -67
--     (271x124, procedimental), redacao final -98 e requerimentos de
--     obstrucao -51/-55.
--  PENDENTE: a derrubada do veto (Lei 15.402/2026) e sessao conjunta do
--  Congresso e nao esta na API; mesmo caso do VET 29/2025 da P5.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Redução de penas do 8 de Janeiro';
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Redução de penas do 8 de Janeiro',
    'O projeto ficou conhecido primeiro como PL da Anistia e depois como PL da Dosimetria. A anistia caiu no substitutivo: o texto aprovado não perdoa ninguém, mas reduz penas de quem participou dos atos de 8 de janeiro de 2023. Aprovado pela Câmara e pelo Senado, vetado integralmente e promulgado como Lei 15.402/2026 depois de o Congresso derrubar o veto. Score alto = a favor da redução das penas.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('camara','2562149-7','for','normal'),   -- urgencia (311x163, set/2025)
  ('camara','2358548-81','for','normal'),  -- DTQ 6 PSB: art. 112 LEP mantido (218x136)
  ('camara','2358548-86','for','normal'),  -- DTQ 4 PT: trecho do art. 112 mantido (208x121)
  ('camara','2358548-89','for','strong'),  -- substitutivo aprovado (291x148, decisiva)
  ('senado','7041','for','strong')         -- Senado: PL 2162 nos termos do parecer (48x25)
) AS v(house, ext, stance, strength) ON TRUE
JOIN division d ON d.house=v.house AND d.external_id = v.ext;

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
  ('2483495-52','for','strong'),   -- PL 363/2025 Aldir Blanc permanente (278x111, decisiva)
  ('2483495-56','for','normal'),   -- Aldir Blanc: DTQ 1 NOVO, texto mantido (266x113) [auditoria 19/08/2026]
  ('2157806-137','for','normal'),  -- PL 8889/2017 lei do streaming, subemenda (330x118)
  ('2157806-168','for','normal')   -- streaming: Emenda Aglutinativa 1 (325x94) [auditoria 19/08/2026]
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Proteção da propriedade rural (ex-"Distribuição e acesso à terra")
--
--  19/08/2026: DES-INVERTIDA e renomeada (era a ultima politica invertida do
--  site). Mesma regra da P5/P6: nomear pelo que o Congresso de fato votou;
--  as 4 votacoes viram 'for' e SIM passa a apoiar a politica.
--  Auditoria: sinais e orientacoes conferidos (PT/Governo/PSOL orientaram Nao
--  nos meritos; PL/NOVO/Oposicao Sim). Destaques nominais das mesmas
--  proposicoes NAO entraram (decisao D6: empilhamento; reavaliar depois).
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Proteção da propriedade rural';
DELETE FROM policy WHERE name = 'Distribuição e acesso à terra';  -- nome antigo
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Proteção da propriedade rural',
    'Proteção da propriedade rural: A FAVOR de proibir a desapropriação do imóvel produtivo (PL 4357/2023), de punir ocupações de terra (PL 709/2023) e de validar registros antigos em faixa de fronteira (PL 4497/2024, o "PL da Grilagem"). Votar SIM apoia a política.',
    false) RETURNING id
)
INSERT INTO policy_division (policy_id, division_id, stance, strength)
SELECT p.id, d.id, v.stance, v.strength FROM p
JOIN (VALUES
  ('2349493-82','for','normal'),   -- PL 709/2023: pune ocupacoes (336x120, mai/2024)
  ('2471177-56','for','normal'),   -- PL 4497/2024 "PL da Grilagem": aprovacao na Camara (328x100)
  ('2386051-93','for','strong'),   -- PL 4357/2023: proibe desapropriar imovel produtivo (287x113, decisiva)
  ('2471177-102','for','strong')   -- PL 4497/2024: Substitutivo do Senado (310x115, dez/2025)
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
  ('2114626-17','for','normal'),  -- urgencia do marco dos jogos, dez/2021 (293x138) [auditoria 19/08/2026]
  ('15460-165','for','strong'),   -- aprovação do substitutivo (246x202)
  ('15460-179','for','normal')    -- DTQ 14 PCdoB: blindagem tributaria do setor mantida (234x175)
  -- NOTA: o PL 3626/2023 (Bets) foi retirado desta politica: regulamentar apostas
  -- online nao equivale a apoiar a legalizacao de cassinos e bingos, e quem e
  -- contra o jogo pode votar a favor de regular o que ja existe. Candidato a
  -- politica propria ("Regulamentacao das apostas esportivas online").
) AS v(ext, stance, strength) ON TRUE
JOIN division d ON d.house='camara' AND d.external_id = v.ext;

-- ---------------------------------------------------------------------------
--  Unificação dos impostos do consumo (ex-"Reforma tributária do consumo")
--  Renomeada em 19/08/2026 na revisão de textos. PEC 45/2019, as duas casas.
-- ---------------------------------------------------------------------------
DELETE FROM policy WHERE name = 'Unificação dos impostos do consumo';
DELETE FROM policy WHERE name = 'Reforma tributária do consumo';  -- nome antigo
WITH p AS (
  INSERT INTO policy (name, description, provisional) VALUES (
    'Unificação dos impostos do consumo',
    'Posição sobre a reforma tributária do consumo (PEC 45/2019, promulgada como Emenda Constitucional 132/2023): substitui PIS, Cofins, IPI, ICMS e ISS por um imposto em duas partes (CBS e IBS), com cashback para famílias de baixa renda e imposto seletivo. Inclui os votos da Câmara e do Senado. Votar SIM apoia a reforma.',
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
  -- REMOVIDA em 19/08/2026: ('2252295-110','against','normal') retirada de pauta
  --   rejeitada (55x212). Obstrucao procedimental; o site nao conta esse tipo
  --   de votacao em nenhuma outra politica (Governo nem orientou; 267 votantes).
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
 WHEN 'Combate à violência contra a mulher' THEN 'Esta política reúne as votações que aumentaram a proteção da mulher após a denúncia: tornozeleira no agressor, arma proibida para quem responde por agressão e melhor acolhimento na delegacia. Também criou punição específica para quem usa os filhos para ferir a mãe.'
 WHEN 'Redução das emissões de carbono' THEN 'O Congresso criou um limite de poluição para as grandes empresas: quem passa do teto paga, quem polui menos vende crédito. Também incentivou combustíveis mais limpos.'
 WHEN 'Investimento na educação pública' THEN 'Define quanto dinheiro chega à escola pública e à universidade federal, e se essa verba fica protegida quando o governo precisa cortar gastos.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Define o que a empresa deve à trabalhadora: mesmo salário do colega homem na mesma função e licença nos dias de menstruação incapacitante.'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'O licenciamento é a análise que decide se uma obra pode sair do papel, e o que ela precisa fazer para não poluir o rio, o ar e o bairro ao lado.'
 WHEN 'Marco temporal para terras indígenas' THEN 'O marco temporal decide quem tem direito de reivindicar terra indígena: só quem já estava na área em 5 de outubro de 1988, data da nova Constituição.'
 WHEN 'Políticas de igualdade racial' THEN 'Define o quanto o poder público age para reduzir a desigualdade racial: punição por racismo, cota em concurso e partido obrigado a bancar candidatura negra.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Mexe no tempo livre e no bolso de quem tem carteira assinada: quantas horas se trabalha por semana (escala 6x1) e quanto entra no seu FGTS e no INSS.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Trata do tamanho da pena de quem invadiu e depredou o Congresso, o Planalto e o STF em 8 de janeiro de 2023.'
 WHEN 'Proteção da propriedade rural' THEN 'Trata de uma disputa antiga no campo: quem tem muita terra e não a usa direito pode perdê-la, e quem não tem nenhuma pode receber.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Define se deputado e senador respondem a processo criminal como qualquer cidadão, ou se dependem da autorização dos colegas para serem julgados.'
 WHEN 'Política nacional de cultura' THEN 'Decide se shows, cinema, teatro e ponto de cultura da sua cidade têm verba previsível, e se o streaming paga uma contribuição que financia produção brasileira.'
 WHEN 'Isenção de impostos para igrejas' THEN 'Igreja já não paga imposto sobre templo, patrimônio e renda. A proposta estende a isenção para tudo que ela compra.'
 WHEN 'Legalização dos jogos de azar' THEN 'Decide se cassino, bingo e jogo do bicho passam a funcionar dentro da lei, com regra e imposto, em vez de na clandestinidade.'
 WHEN 'Unificação dos impostos do consumo' THEN 'Cinco impostos escondidos no preço de tudo viram um só, com devolução de parte do valor para quem ganha pouco. É a maior mudança de impostos em décadas.'
 WHEN 'Conservação da biodiversidade' THEN 'O peixe do mercado, a água da torneira e o turismo da praia dependem da natureza em pé. Estas votações decidem o quanto ela fica protegida.'
 WHEN 'Abastecimento público de medicamentos' THEN 'Mexe no preço e na falta de remédio no posto: produção nacional, compra direta do produtor público e quebra de patente.'
 ELSE quiz_hook END;

UPDATE policy SET side_a_title = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Concordo com essas medidas'
 WHEN 'Redução das emissões de carbono' THEN 'Quem polui deve pagar'
 WHEN 'Investimento na educação pública' THEN 'Priorizar a verba da educação'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Direito básico, não benefício'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'A demora também cobra caro'
 WHEN 'Marco temporal para terras indígenas' THEN 'Uma data encerra a disputa'
 WHEN 'Políticas de igualdade racial' THEN 'A lei deve corrigir a desigualdade'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Direito não se negocia para baixo'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Corrigir penas desproporcionais'
 WHEN 'Proteção da propriedade rural' THEN 'Quem produz não pode perder a terra'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Político também é perseguido'
 WHEN 'Política nacional de cultura' THEN 'Sem verba fixa, a cultura some do interior'
 WHEN 'Isenção de impostos para igrejas' THEN 'Menos imposto, mais ação social'
 WHEN 'Legalização dos jogos de azar' THEN 'Já existe, melhor regular'
 WHEN 'Unificação dos impostos do consumo' THEN 'Chega de imposto escondido'
 WHEN 'Conservação da biodiversidade' THEN 'Sem conservar não há do que viver'
 WHEN 'Abastecimento público de medicamentos' THEN 'Remédio caro demais é remédio que falta'
 ELSE side_a_title END;

UPDATE policy SET side_a_note = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'acredito que o momento mais perigoso para a mulher é entre a denúncia e a prisão, e ali faltava proteção'
 WHEN 'Redução das emissões de carbono' THEN 'acho que poluir de graça sai caro para todo mundo: o risco é mais seca, enchente e mudança do clima'
 WHEN 'Investimento na educação pública' THEN 'escola e universidade públicas dependem de dinheiro garantido; acredito que mais estudo vira também mais renda, mais saúde e menos violência no futuro'
 WHEN 'Igualdade de gênero no trabalho' THEN 'acredito que salário igual por trabalho igual e afastamento em condição de saúde não são favor'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'acho que obra parada por anos trava saneamento, energia e emprego em região que precisa'
 WHEN 'Marco temporal para terras indígenas' THEN 'acho que com uma data definida cada um sabe o que é seu, e a disputa acaba'
 WHEN 'Políticas de igualdade racial' THEN 'acredito que séculos de desigualdade não acabam sozinhos; é preciso política que equilibre e abra caminho'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'acredito que jornada e aposentadoria são garantias mínimas, não moeda de troca'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'acho que mais de quinze anos para quem entrou na multidão sem liderar nem financiar é punição excessiva'
 WHEN 'Proteção da propriedade rural' THEN 'acredito que propriedade que gera safra e emprego não pode viver sob ameaça de desapropriação'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'acho que o processo pode ser usado só para tirar do caminho quem incomoda'
 WHEN 'Política nacional de cultura' THEN 'acredito que sem repasse garantido só os grandes centros continuam tendo cultura'
 WHEN 'Isenção de impostos para igrejas' THEN 'acho que cada real que a igreja não paga em imposto vira atendimento a quem precisa'
 WHEN 'Legalização dos jogos de azar' THEN 'acho que proibir não acabou com o jogo; só tirou o imposto e a fiscalização'
 WHEN 'Unificação dos impostos do consumo' THEN 'acredito que ver quanto se paga em cada compra é o primeiro passo para cobrar melhor o governo'
 WHEN 'Conservação da biodiversidade' THEN 'acredito que pesca, água e turismo dependem do que ainda está em pé'
 WHEN 'Abastecimento público de medicamentos' THEN 'produzir aqui e quebrar patente derruba o preço para quem depende do SUS'
 ELSE side_a_note END;

UPDATE policy SET side_b_title = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'Qualquer violência deve ser combatida, independente de gênero'
 WHEN 'Redução das emissões de carbono' THEN 'A conta chega no consumidor'
 WHEN 'Investimento na educação pública' THEN 'Gasto protegido por lei aperta todo o resto'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Deixar para a negociação'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'Melhor demorar do que remediar'
 WHEN 'Marco temporal para terras indígenas' THEN 'Tem que considerar quem foi expulso'
 WHEN 'Políticas de igualdade racial' THEN 'A lei deve ser igual para todos'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Deixar empresa e trabalhador negociarem'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'O recado importa mais que o desconto'
 WHEN 'Proteção da propriedade rural' THEN 'Terra tem que cumprir função social'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Político não pode ter regra própria'
 WHEN 'Política nacional de cultura' THEN 'Cultura se financia com público'
 WHEN 'Isenção de impostos para igrejas' THEN 'Quem não paga joga a conta no resto'
 WHEN 'Legalização dos jogos de azar' THEN 'Legalizar é facilitar o vício'
 WHEN 'Unificação dos impostos do consumo' THEN 'Alguém vai pagar a diferença'
 WHEN 'Conservação da biodiversidade' THEN 'Regra demais trava quem produz'
 WHEN 'Abastecimento público de medicamentos' THEN 'Sem patente ninguém pesquisa'
 ELSE side_b_title END;

UPDATE policy SET side_b_note = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'acho que não deveria haver medida extra para um gênero e não para o outro'
 WHEN 'Redução das emissões de carbono' THEN 'acredito que o custo do carbono entra no preço do combustível, da energia e do frete'
 WHEN 'Investimento na educação pública' THEN 'acho que o governo eleito deve poder decidir onde o dinheiro é mais necessário'
 WHEN 'Igualdade de gênero no trabalho' THEN 'acho que empresa e empregada resolvem melhor caso a caso do que uma regra igual para todas'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'acredito que as barragens que romperam em Mariana e Brumadinho eram de impacto médio, e são elas que agora têm menos análise'
 WHEN 'Marco temporal para terras indígenas' THEN 'acredito que comunidade removida à força antes de 1988 não deveria perder o direito por não estar lá naquela data'
 WHEN 'Políticas de igualdade racial' THEN 'acho que política que classifica por raça oficializa uma divisão que não deveria existir'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'acredito que acordo entre as partes se ajusta ao setor e ao porte; regra única, não'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'acho que reduzir pena de ataque às instituições sinaliza que agir contra a democracia sai barato'
 WHEN 'Proteção da propriedade rural' THEN 'acho que fazenda que desmata ilegalmente ou usa trabalho escravo deveria poder virar assentamento'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'acredito que quem cometeu crime deve responder como qualquer pessoa'
 WHEN 'Política nacional de cultura' THEN 'acho que show, filme e festival devem viver de ingresso pago e patrocínio, não de imposto'
 WHEN 'Isenção de impostos para igrejas' THEN 'acredito que o imposto que a igreja deixa de pagar aparece no preço que todo mundo paga'
 WHEN 'Legalização dos jogos de azar' THEN 'acredito que quanto mais fácil apostar, mais gente se endivida e mais dinheiro sujo circula'
 WHEN 'Unificação dos impostos do consumo' THEN 'acredito que o setor de serviços vai subir os preços, e é o consumidor que paga a conta'
 WHEN 'Conservação da biodiversidade' THEN 'acho que mais restrição no litoral e em área sensível atinge quem vive de produzir ali'
 WHEN 'Abastecimento público de medicamentos' THEN 'enfraquecer a patente afugenta o investimento que cria o remédio novo'
 ELSE side_b_note END;

-- ============================================================================
-- Texto exibido em "Por que isso importa para voce?" na PAGINA da politica.
-- E independente do quiz_hook, que e o texto curto do QUIZ: o da pagina explica
-- mais (cerca de 100 palavras) e fecha apresentando os dois lados. Nao derive um
-- do outro; se mudar um, revise o outro.
UPDATE policy SET impact = CASE name
 WHEN 'Combate à violência contra a mulher' THEN 'A maior parte da violência contra a mulher acontece dentro de casa, e o agressor quase sempre é conhecido. Estas votações tratam do que o Estado faz depois da denúncia: tornozeleira e arma proibida para quem responde por agressão, violência vicária na Lei Maria da Penha, atendimento à mulher indígena na delegacia e um sistema nacional com recursos. Nada cria crime novo: muda a chance de a proteção chegar antes do pior.
Para quem defende, o período mais perigoso é logo após a denúncia; para quem critica, a lei deveria valer igual para qualquer agressor.'
 WHEN 'Redução das emissões de carbono' THEN 'Toda atividade que queima combustível ou derruba floresta solta gás de efeito estufa, e estas votações decidem se isso passa a ter preço. O mecanismo central é o mercado de carbono: quem emite acima do limite compra crédito de quem emite menos, e poluir vira custo. O outro pacote incentiva combustíveis mais limpos: diesel verde, aviação e captura de carbono.
Para quem defende, poluir de graça sai caro para todos: mais seca, enchente e mudança do clima; para quem critica, esse custo cai no combustível, na energia e no frete.'
 WHEN 'Investimento na educação pública' THEN 'Essas votações protegeram o dinheiro da educação: o Fundeb (professor e merenda) virou permanente, universidades saíram do teto de gastos, e foi criada uma poupança para o aluno pobre terminar os estudos.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'Mulheres e homens que fazem o mesmo trabalho nem sempre recebem o mesmo salário. Estas votações tratam de duas obrigações que a lei pode impor à empresa: pagar igual por função igual, com transparência salarial, e dar três dias de licença por mês a quem comprove sintomas graves de menstruação. Para quem defende, salário igual e afastamento por saúde não são favor; para quem critica, empresa e empregada resolvem melhor caso a caso.'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'Licenciamento é a análise que decide se uma obra pode sair do papel e o que ela precisa fazer para não poluir o rio, o ar e o bairro ao lado. Esta política simplificou essa análise: criou a licença por autodeclaração, em que o empreendedor diz que cumpre as exigências, tirou regras mais duras de mineração de grande porte e abriu um caminho acelerado para obras estratégicas. Quem votou a favor diz que obra parada também cobra um preço; quem votou contra lembra que as barragens de Mariana e Brumadinho não eram classificadas como de grande impacto.'
 WHEN 'Marco temporal para terras indígenas' THEN 'A Constituição garante aos indígenas as terras que ocupam tradicionalmente, mas a disputa é sobre o que “tradicionalmente” quer dizer. O marco temporal fixa uma data: só teria direito quem estivesse na terra em 5 de outubro de 1988. Para quem defende, uma data acaba com a insegurança sobre quem tem direito a quê; para quem critica, ignora que muitas comunidades foram expulsas à força antes de 1988.'
 WHEN 'Políticas de igualdade racial' THEN 'Esta política reúne decisões sobre desigualdade racial: injúria racial punida como crime de racismo, 30% das vagas de concursos federais reservadas a pessoas negras, indígenas e quilombolas, o 20 de novembro como feriado nacional e a lista suja de clubes punidos por racismo no futebol. Para quem defende, séculos de desigualdade racial não se corrigem sozinhos; para quem critica, lei que classifica por raça oficializa uma divisão que não deveria existir.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'Carteira assinada é o piso de direitos que não depende de negociação, e estas votações mexem nesse piso. De um lado, a redução da jornada máxima na Constituição, ligada ao fim da escala 6x1. Do outro, contratos para jovens com FGTS e INSS reduzidos: custam menos ao empregador, mas rendem menos fundo de garantia e aposentadoria. Por isso apoiar é votar SIM na jornada e NÃO nos contratos.
Para quem defende, sem mínimo em lei a negociação vira imposição; para quem critica, acordo entre as partes se ajusta melhor a cada setor.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'Em 8 de janeiro de 2023, milhares de pessoas invadiram e depredaram as sedes dos três poderes, e centenas foram condenadas. O projeto nasceu como anistia e mudou no caminho: o texto aprovado não perdoa ninguém, mas reduz penas, proibindo somar as condenações por golpe e por abolição do Estado Democrático e cortando de um a dois terços a pena de quem não liderou nem financiou.
Para quem defende, mais de quinze anos para quem só entrou na multidão é excessivo; para quem critica, reduzir pena de ataque às instituições sinaliza que atentar contra a democracia sai barato.'
 WHEN 'Política nacional de cultura' THEN 'Os shows da sua cidade, o cinema nacional e os festivais do seu bairro dependem de verba pública para existir. Parte das votações tornou permanente o repasse federal da cultura a estados e municípios; parte obrigou o streaming a contribuir para o cinema brasileiro.
Quem defende diz que verba previsível leva cultura para além dos grandes centros; quem critica diz que despesa fixada em lei tira espaço de outras prioridades.'
 WHEN 'Proteção da propriedade rural' THEN 'Pela Constituição, terra mal usada pode ser desapropriada para reforma agrária. O Congresso apertou essa porta: se a fazenda produz, ninguém tira; se tem crime ambiental ou trabalho escravo, só vale depois de condenação final na Justiça; quem ocupa terra perde direitos; e registros antigos de terra pública ficam valendo.
Um lado diz que quem produz não pode viver com medo de perder a terra; o outro, que a reforma agrária ficou sem caminho e a grilagem foi premiada.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'Hoje é o Supremo que decide se abre processo criminal contra deputado ou senador, sem pedir licença a ninguém. A PEC 3/2021 mudava isso: o processo só começaria se a própria Câmara ou o próprio Senado autorizasse, em votação secreta. A Câmara aprovou em setembro de 2025; depois de protestos pelo país, o Senado rejeitou.
Para quem defende, o processo pode ser usado para tirar do caminho quem incomoda; para quem critica, quem cometeu crime responde como qualquer pessoa.'
 WHEN 'Isenção de impostos para igrejas' THEN 'Igreja não paga imposto sobre o templo, o patrimônio e a renda: isso já é assim desde sempre. A PEC 5/2023 amplia: tira também o imposto de tudo que a igreja compra, da cadeira à obra, incluindo creches, comunidades terapêuticas e seminários ligados a ela. Esse imposto não desaparece: o que a igreja deixa de pagar acaba na conta dos outros.
Um lado diz que a igreja cuida de quem o Estado esquece; o outro, que isenção de um grupo encarece a vida de todos.'
 WHEN 'Legalização dos jogos de azar' THEN 'Cassino, bingo e jogo do bicho são proibidos desde os anos 1940, mas nunca deixaram de existir: seguem na clandestinidade, sem imposto e sem fiscalização. O PL 442/1991 traz a atividade para dentro da lei, com regras e tributos. A Câmara aprovou em 2022, pela margem mais apertada de todo o site; o projeto está parado no Senado desde então.
Para quem defende, regulado, o jogo gera emprego, turismo e imposto; para quem critica, legalizar amplia o vício e abre porta para lavagem de dinheiro.'
 WHEN 'Unificação dos impostos do consumo' THEN 'O imposto que você paga está escondido no preço de cada compra, espalhado em cinco tributos com regras diferentes. A reforma junta tudo num imposto só, devolve parte do valor para famílias de baixa renda e cobra mais de produtos que fazem mal, como bebida e cigarro.
Um lado diz que ficou mais simples e transparente; o outro, que serviços vão encarecer e ninguém sabe ainda o tamanho final da conta.'
 WHEN 'Conservação da biodiversidade' THEN 'Biodiversidade parece assunto distante, mas é o peixe no mercado, a água da cidade, o inseto que poliniza a lavoura e o turismo do litoral. Estas votações protegem ecossistemas: a principal é a Lei do Mar, primeira política nacional para a costa brasileira; há também o acordo de espécies migratórias, o consumo sustentável e o direito das crianças ao contato com a natureza.
Para quem defende, sem conservar não há pesca, água nem turismo amanhã; para quem critica, regra demais em área sensível trava quem produz.'
 WHEN 'Abastecimento público de medicamentos' THEN 'Remédio que falta no posto quase sempre tem uma causa distante: o país não produz, a compra trava na burocracia ou a patente segura o preço lá em cima. O Congresso atacou as três frentes: incentivo à fábrica nacional, compra direta do produtor público e o primeiro passo para quebrar a patente do Mounjaro e do Zepbound.
Para quem defende, produção nacional e quebra de patente barateiam o remédio; para quem critica, enfraquecer a patente afugenta a pesquisa que cria o remédio novo.'
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
Duas foram votações de destaque, quando o plenário decide se mantém um trecho do texto: o PL 2942/2024, que determina o monitoramento eletrônico de agressores, e o PL 3880/2024, que inclui a violência vicária (usar os filhos para atingir a mãe) entre as formas de violência doméstica da Lei Maria da Penha.
A sexta é o PLP 41/2026, que cria o Sistema Nacional de Enfrentamento da Violência contra Meninas e Mulheres e destina recursos ao combate ao feminicídio. Foi aprovado por 470 a 1.
Duas dessas votações entram com peso reduzido por terem sido quase unânimes: o PLP 41/2026 e o PL 2942/2024, aprovado por 408 a 13. Quando quase todo mundo vota igual, o voto distingue pouco um parlamentar do outro.'
 WHEN 'Redução das emissões de carbono' THEN 'São quatro votações, todas na Câmara, e a direção muda numa delas.
Duas são do mercado regulado de carbono (PL 2148/2015, aprovado como PL 182/2024 e hoje Lei 15.042/2024), que fixa limites de emissão para grandes emissores e permite vender o excedente a quem emite menos: a aprovação do texto pela Câmara em dezembro de 2023, por 299 a 103, e a votação do texto vindo do Senado em novembro de 2024, por 336 a 38, que é a decisiva desta política.
A terceira é do PL 528/2020, o pacote Combustível do Futuro: diesel verde, combustível sustentável de aviação e captura de carbono. Foi quase unânime, 429 a 19, e por isso entra com peso reduzido.
A quarta é invertida: o destaque do PSOL que tentou tirar o gás natural do programa de transição energética (Paten, PL 327/2021). O plenário manteve o gás natural por 225 a 187, e aqui apoiar a política é votar NÃO.'
 WHEN 'Investimento na educação pública' THEN 'É a política com mais votações: quatorze, sendo onze na Câmara e três no Senado. Votar SIM apoia mais investimento em todas.
A PEC 15/2015 tornou o Fundeb permanente na Constituição; antes ele tinha prazo e precisava ser renovado. Entram os dois turnos, de julho de 2020, e um destaque. A PEC 24/2019 excluiu as despesas das instituições federais de ensino dos limites de gasto primário, também com dois turnos e um destaque, em dezembro de 2022.
O PLP 243/2023 criou o programa que deu origem ao Pé-de-Meia e foi votado nas duas casas. O PLP 153/2024, no Senado, tratou da transferência de saldos do Fundo Nacional de Desenvolvimento da Educação para estados e municípios. O PL 3118/2024 incluiu a assistência estudantil entre as prioridades do Fundo Social.
O PLP 163/2025 é o mais recente e o mais disputado: exclui despesas com educação e saúde dos limites do arcabouço fiscal. Entram a aprovação na Câmara por 296 a 145, um destaque, a votação do texto que voltou do Senado, por 320 a 109, e a aprovação no Senado por 47 a 16.
Quatro votações entram com peso reduzido por quase-unanimidade: os dois turnos da PEC 15/2015, aprovados por 499 a 7 e 492 a 6, e as duas do Senado que passaram sem nenhum voto contrário.'
 WHEN 'Igualdade de gênero no trabalho' THEN 'São duas votações, ambas na Câmara. Votar SIM apoia a política.
O PL 1085/2023 é a Lei da Igualdade Salarial: obriga a pagar o mesmo salário a mulheres e homens na mesma função e cria a obrigação de publicar relatórios de transparência salarial. Foi aprovado por 325 a 36 e é a votação decisiva desta política. Virou a Lei 14.611/2023, declarada constitucional por unanimidade pelo STF em maio de 2026.
A segunda é o requerimento de urgência do PL 1249/2022, que garante três dias consecutivos de licença por mês às trabalhadoras que comprovem sintomas graves associados ao fluxo menstrual. Urgência decide se a matéria vai direto ao plenário: mede disposição de pautar, não posição sobre o conteúdo. No dia seguinte a Câmara aprovou o substitutivo, que reduziu a licença para até dois dias mediante laudo médico, mas essa votação foi simbólica e por isso não entra aqui.
Com só duas votações, esta política segue marcada como provisória. Ela está publicada e pontuada, mas com base estreita.'
 WHEN 'Flexibilização do licenciamento ambiental' THEN 'São sete votações, todas na Câmara. Votar SIM apoia a política.
Seis são do PL 2159/2021, que reescreveu a lei geral do licenciamento e ficou conhecido como PL da Devastação. A votação de mérito, que mandou o texto à sanção, foi aprovada por 267 a 116 e entra com peso forte. As outras cinco são destaques sobre emendas do Senado, cada uma decidindo uma coisa diferente: tirar a mineração de grande porte do regime do Conama, criar a licença ambiental especial de rito único, deixar o ente federativo definir porte e potencial poluidor, ampliar o autolicenciamento com conferência por amostragem, e revogar exigências da Lei da Mata Atlântica.
A sétima é da MPV 1308/2025, que criou o licenciamento especial para empreendimentos estratégicos. A votação registrada é o destaque em que o plenário decidiu manter o artigo sobre obras de rodovia. Foi a única votação nominal daquela medida provisória, porque o mérito foi aprovado de forma simbólica.
Ficaram de fora a redação final e os requerimentos de procedimento, que não decidem o conteúdo, e as votações de 2021, da legislatura anterior.
O PL 2159/2021 virou a Lei 15.190/2025 e a MPV 1308/2025 virou a Lei 15.300/2025. Em novembro de 2025 o Congresso derrubou a maior parte dos vetos que o governo tinha posto no texto; essa votação ainda não está no site.'
 WHEN 'Marco temporal para terras indígenas' THEN 'São cinco votações: duas na Câmara e três no Senado. Votar SIM apoia o marco temporal.
O PL 490/2007 regulamenta o artigo 231 da Constituição, que trata das terras indígenas, e fixa o marco temporal. A Câmara aprovou o substitutivo em maio de 2023 por 283 a 155, a votação decisiva desta política, e em seguida manteve, por 288 a 148, o artigo que define o próprio marco temporal, contra um destaque que queria suprimi-lo.
No Senado, a mesma tese tramitou como PL 2903/2023 e foi aprovada em setembro de 2023 por 43 a 21, poucos dias depois de o Supremo Tribunal Federal rejeitar essa mesma tese em julgamento.
A resposta do Congresso foi a PEC 48/2023, que escreve o marco temporal direto na Constituição, e não mais em lei ordinária. O Senado aprovou os dois turnos em dezembro de 2025.
Ficou de fora um destaque da Câmara sobre outro trecho do mesmo substitutivo, que permite à União retomar terra indígena já demarcada se os “traços culturais” da comunidade mudarem com o tempo: é um mecanismo diferente do marco temporal, tratado à parte.
Nenhuma das cinco votações foi quase unânime: as maiorias ficaram entre 65% e 79%.'
 WHEN 'Políticas de igualdade racial' THEN 'São cinco votações, todas na Câmara. Votar SIM apoia a política.
O PL 1958/2021 reserva 30% das vagas em concursos públicos federais a pessoas pretas, pardas, indígenas e quilombolas. Aparece duas vezes: no requerimento de urgência, aprovado por 272 a 140, e na aprovação do substitutivo, por 241 a 94, que é a votação decisiva desta política.
O PL 4566/2021 equiparou a injúria racial ao crime de racismo, com pena maior. Foi aprovado por 358 a 17: quase unânime, e por isso entra com peso reduzido. É a votação mais antiga do conjunto, de novembro de 2021, da legislatura anterior.
O PL 3268/2021 declarou o 20 de novembro, Dia de Zumbi e da Consciência Negra, feriado nacional. Foi aprovado por 286 a 121.
O PL 1069/2025 cria a “Lista Suja do Racismo no Futebol”, cadastro de clubes e entidades punidos por racismo. A votação registrada é o destaque que manteve os torcedores no alcance do cadastro, por 295 a 120; o mérito foi aprovado de forma simbólica.
A PEC 9/2023, que mudou as sanções aos partidos que não aplicaram o mínimo em candidaturas negras, saiu da política: a federação PT-PCdoB-PV e o PSOL votaram em lados opostos, e uma votação com os dois polos trocados não mede este eixo.'
 WHEN 'Proteção dos direitos trabalhistas' THEN 'São cinco votações, todas na Câmara, e a direção muda conforme a proposta.
A MPV 905/2019 criou o Contrato de Trabalho Verde e Amarelo, com FGTS e contribuição previdenciária reduzidos para jovens sem vínculo anterior. Foi aprovada por 322 a 153 em abril de 2020, na legislatura anterior. O PL 5496/2013 retomou a mesma ideia em 2023, com contrato por prazo determinado para jovens de 16 a 24 anos: aparece no mérito, aprovado por 286 a 91, e no destaque que manteve o corte da contribuição previdenciária patronal, por 312 a 104. Nessas três, apoiar os direitos trabalhistas é votar NÃO.
A PEC 221/2019 vai na direção oposta: reduz a jornada máxima prevista na Constituição, de 44 para 36 horas semanais ao longo de dez anos. É a proposta associada ao fim da escala 6x1, e nela apoiar é votar SIM. A Câmara aprovou os dois turnos em 27 de maio de 2026: 472 a 22 e 461 a 19.
Justamente por serem quase unânimes, as duas votações da PEC entram com peso reduzido: com mais de 95% dos votos de um lado, elas distinguem pouco um parlamentar do outro.'
 WHEN 'Redução de penas do 8 de Janeiro' THEN 'São cinco votações: quatro na Câmara e uma no Senado, todas sobre o PL 2162/2023. Votar SIM apoia a redução das penas.
A primeira, em setembro de 2025, foi o requerimento de urgência na Câmara, que mandou o texto direto ao plenário, aprovado por 311 a 163. As três seguintes ocorreram na madrugada de 10 de dezembro de 2025: dois destaques que mantiveram no texto as novas regras de execução penal, por 218 a 136 e 208 a 121, e a votação do mérito, que aprovou o substitutivo por 291 a 148.
No Senado, o projeto foi aprovado em 17 de dezembro de 2025, por 48 a 25. Como é a única votação do Senado nesta política e são precisas ao menos duas para pontuar, os senadores não recebem índice, mas o voto de cada um fica registrado na sua página.
O projeto ficou conhecido primeiro como PL da Anistia e depois como PL da Dosimetria: a anistia caiu no substitutivo, e o texto aprovado passou a apenas reduzir penas. Foi vetado integralmente pela Presidência e promulgado como Lei 15.402/2026 quando o Congresso derrubou o veto; a votação da derrubada é de sessão conjunta e não está na base.
Ficaram de fora três destaques votados de madrugada com o plenário esvaziado, cujos placares não refletem a disputa real, além da redação final e dos requerimentos de procedimento.
Nenhuma das cinco votações foi quase unânime: as maiorias ficaram entre 62% e 66%.'
 WHEN 'Política nacional de cultura' THEN 'São quatro votações, todas na Câmara. Votar SIM apoia a política.
Duas são do PL 363/2025, que torna permanente o repasse da Política Nacional Aldir Blanc de Fomento à Cultura a estados e municípios: a aprovação do substitutivo, por 278 a 111, que é a votação decisiva desta política, e o destaque que manteve o texto contra uma supressão pedida pelo NOVO, por 266 a 113.
As outras duas são do PL 8889/2017, que regulamenta o streaming e cria a contribuição destinada ao financiamento do audiovisual brasileiro: a aprovação da subemenda substitutiva, por 330 a 118, e a emenda aglutinativa que fechou o texto, por 325 a 94.
Nenhuma das quatro foi quase unânime.'
 WHEN 'Proteção da propriedade rural' THEN 'São quatro votações, todas na Câmara. Votar SIM apoia a política.
O PL 4357/2023 é a votação de maior peso: proíbe desapropriar o imóvel produtivo para reforma agrária e exige condenação criminal definitiva nos casos de crime ambiental ou trabalhista. Foi aprovado em novembro de 2025, por 287 a 113.
O PL 709/2023 pune quem ocupa ou invade propriedades: quem participa de ocupação fica impedido de ser beneficiário da reforma agrária. Foi aprovado em maio de 2024, por 336 a 120.
O PL 4497/2024, que ficou conhecido como PL da Grilagem, valida registros antigos sobre terras públicas em faixa de fronteira, os 150 quilômetros ao longo das fronteiras do país. Aparece duas vezes: na aprovação pela Câmara, em junho de 2025, por 328 a 100, e na aprovação do texto que voltou do Senado, em dezembro de 2025, por 310 a 115.
Nenhuma das quatro votações foi quase unânime: as maiorias ficaram entre 72% e 77%.'
 WHEN 'Blindagem de parlamentares (PEC da Blindagem)' THEN 'São três votações, todas na Câmara e todas sobre a PEC 3/2021. Votar SIM apoia a blindagem.
Como toda proposta de emenda à Constituição, ela precisa passar em dois turnos. O primeiro turno, em 16 de setembro de 2025, aprovou o substitutivo por 353 a 134 e é a votação decisiva. O segundo turno, no mesmo dia, confirmou por 344 a 133. No dia seguinte, o plenário aprovou ainda uma emenda aglutinativa, por 314 a 168.
A PEC altera os artigos 14, 27, 53, 102 e 105 da Constituição, ou seja, alcança também as regras aplicáveis a deputados estaduais e a competência do Supremo Tribunal Federal e do Superior Tribunal de Justiça.
Depois de aprovada na Câmara, a proposta foi rejeitada pelo Senado. Como não há votação nominal do Senado nesta base para essa matéria, nenhum senador recebe índice nesta política.'
 WHEN 'Isenção de impostos para igrejas' THEN 'São duas votações, ambas na Câmara e ambas em 28 de maio de 2026. Votar SIM apoia a ampliação.
A PEC 5/2023 acrescenta um parágrafo ao artigo 150 da Constituição, que trata das imunidades tributárias. O primeiro signatário é o deputado Marcelo Crivella; o texto aprovado é do relator Fernando Máximo.
Por ser emenda constitucional, precisou de dois turnos: 385 a 93 no primeiro, que é a votação decisiva, e 368 a 96 no segundo.
A imunidade ampliada não passa a valer sozinha: depende de lei complementar que defina critérios de habilitação uniformes em todo o país.
Depois da Câmara, a proposta foi enviada ao Senado, onde ainda não foi votada. Por isso nenhum senador recebe índice nesta política.'
 WHEN 'Legalização dos jogos de azar' THEN 'São três votações, todas na Câmara e da legislatura anterior. Votar SIM apoia a legalização.
O PL 442/1991 nasceu tratando do jogo do bicho e cresceu até virar o chamado “marco dos jogos”: legaliza cassinos, bingos e outros jogos, revogando a proibição em vigor desde os anos 1940. A urgência foi aprovada em dezembro de 2021, por 293 a 138. O mérito, em 24 de fevereiro de 2022, é a votação mais apertada de todo o conjunto de políticas do site: 246 a 202, ou 55% de maioria.
A terceira é o destaque que manteve, por 234 a 175, o trecho que impede a cobrança de outros tributos sobre o setor além dos criados pelo próprio projeto. Ele decide o regime tributário da atividade legalizada, não a legalização em si, mas o padrão de votos espelhou o do mérito e por isso foi mantido na política.
O projeto está no Senado desde 2022 e não foi votado lá. Nenhum senador recebe índice nesta política, e o índice dos deputados reflete posições tomadas há mais de quatro anos, na legislatura anterior.'
 WHEN 'Unificação dos impostos do consumo' THEN 'São quatro votações, duas na Câmara e duas no Senado: é uma das quatro políticas do site com votos das duas casas. Votar SIM apoia a reforma.
Por ser emenda constitucional, a PEC 45/2019 precisou de dois turnos em cada casa. Na Câmara, em julho de 2023: 382 a 118 no primeiro turno, que é a votação decisiva, e 375 a 113 no segundo. No Senado, em novembro de 2023: 53 a 24 nos dois turnos.
O texto substitui PIS, Cofins, IPI, ICMS e ISS por um imposto em duas partes, a CBS federal e o IBS de estados e municípios, cria o cashback para famílias de baixa renda e o imposto seletivo sobre produtos nocivos à saúde e ao meio ambiente.
Foi promulgada como Emenda Constitucional 132/2023. As regras concretas vêm por leis complementares posteriores, que não fazem parte desta política.'
 WHEN 'Conservação da biodiversidade' THEN 'São cinco votações, todas na Câmara. Votar SIM apoia a política.
O PL 6969/2013 institui a Política Nacional para a Conservação e o Uso Sustentável do Bioma Marinho Brasileiro, a Lei do Mar. Aparece duas vezes: na aprovação do texto, por 378 a 66, e num destaque logo em seguida.
O PL 2225/2024 estabelece diretrizes para o direito de crianças e adolescentes à natureza e altera o Estatuto da Criança e do Adolescente, o Estatuto da Cidade e a Política Nacional do Meio Ambiente.
O PL 3899/2012 institui a Política Nacional de Estímulo à Produção e ao Consumo Sustentáveis.
A MSC 112/2026 levou ao Congresso o acordo firmado na 15ª Conferência das Partes da Convenção sobre Espécies Migratórias, assinado em Nairóbi em dezembro de 2025.
As cinco entram com peso normal: nenhuma foi marcada como decisiva na curadoria e nenhuma foi quase unânime.'
 WHEN 'Abastecimento público de medicamentos' THEN 'São cinco votações, todas na Câmara. Votar SIM apoia a política.
Duas são do PL 2583/2020, que institui a Estratégia Nacional de Saúde para incentivar a produção nacional de insumos, medicamentos e materiais: a aprovação do mérito, por 352 a 63, e o destaque que manteve a licitação exclusiva para a Empresa Estratégica de Saúde, por 316 a 110.
O PL 424/2015 permite dispensa de licitação para a compra de hemoderivados pelo SUS, o que viabiliza a compra direta de produtores públicos como a Hemobrás. Aparece duas vezes: no requerimento de urgência, aprovado por 286 a 111, e no destaque que manteve a palavra “pública”, por 285 a 106.
O PL 68/2026 declara de interesse público os medicamentos Mounjaro e Zepbound, para os fins do artigo 71 da Lei de Propriedade Industrial, o dispositivo que permite o licenciamento compulsório de patente. Seu requerimento de urgência foi aprovado por 337 a 19, 94,7% de maioria, pouco abaixo do limiar de 95%, e por isso manteve o peso normal.
Um requerimento de retirada de pauta rejeitado, que já esteve nesta política, saiu na revisão de agosto de 2026: é obstrução procedimental, e o site não conta esse tipo de votação em nenhuma outra política.'
 ELSE description END;
