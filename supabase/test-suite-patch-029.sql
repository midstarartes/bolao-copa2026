-- ════════════════════════════════════════════════════════════════════════
-- TEST SUITE — patch-029: Pontuação, Buffs, Ranking e Coin-bet
--
-- COMPLETAMENTE SEGURO:
--   Executa dentro de BEGIN / ROLLBACK — tudo é desfeito no final.
--   Nenhum usuário real, palpite, buff ou ranking é afetado.
--
-- COMO USAR:
--   1. Cole este arquivo inteiro no Supabase SQL Editor
--   2. Clique em "Run"
--   3. Veja os resultados de cada bloco (todos devem mostrar apenas "true")
--   4. O ROLLBACK ao final descarta tudo automaticamente
--
-- CENÁRIO DE TESTE:
--   4 partidas: 2x grupos, 1x oitavas, 1x semi final
--   4 players: Alpha (acerta tudo), Beta (resultado), Gamma (usa buffs), Delta (alvo dos buffs)
--
--   BUFFS testados:
--     draw-protected    → Gamma no GRP_02 (apostou vencedor, empatou → 0 pts)
--     palpite-duplo     → Gamma no R16_01 (×2 nos pontos)
--     zerar-adversario  → Gamma zera Delta no GRP_01
--     meia-adversario   → Gamma divide Delta no R16_01
--     coin-bet          → Beta no SEMI_01 (resultado → 2 moedas)
--
-- PONTUAÇÃO ESPERADA (SEM BÔNUS):
--   1° DEMO_Alpha  7.0 pts  4 exatos  100% aproveit
--   2° DEMO_Gamma  4.5 pts  2 exatos   34% aproveit  ← mesmos pts que Beta, mais exatos
--   3° DEMO_Beta   4.5 pts  1 exato    64% aproveit
--   4° DEMO_Delta  1.5 pts  2 exatos  100% aproveit
-- ════════════════════════════════════════════════════════════════════════

BEGIN;


-- ────────────────────────────────────────────────────────────────────────
-- 0. INSERIR DADOS DE TESTE
-- ────────────────────────────────────────────────────────────────────────

-- Usuários de teste (criados em jan/2026 para ficarem antes das partidas)
INSERT INTO public.app_users
  (id, nickname, real_name, password_hash, coins, is_admin, is_blocked, created_at)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001'::uuid,
   'DEMO_Alpha', 'Alpha Test', 'x', 100, false, false, '2026-01-01 00:00:00+00'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002'::uuid,
   'DEMO_Beta',  'Beta Test',  'x', 100, false, false, '2026-01-01 00:00:00+00'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003'::uuid,
   'DEMO_Gamma', 'Gamma Test', 'x', 100, false, false, '2026-01-01 00:00:00+00'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004'::uuid,
   'DEMO_Delta', 'Delta Test', 'x', 100, false, false, '2026-01-01 00:00:00+00');

-- Sessão para Beta (necessária para o teste de coin-bet settle)
INSERT INTO public.app_sessions (token, user_id, expires_at)
VALUES (
  'ffffffff-ffff-ffff-ffff-000000000002'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000002'::uuid,
  now() + interval '1 day'
);

-- Partidas de teste (já encerradas, starts_at em março/2026 > created_at jan/2026)
INSERT INTO public.matches
  (id, match_number, phase, phase_label, home_team, away_team,
   starts_at, status, score_home, score_away, winner_team)
VALUES
  -- Grupos (mata-mata_type = 'group')
  ('TEST_GRP_01', 99,  'group',       'FASE DE GRUPOS',   'Brasil', 'Argentina',
   '2026-03-01 12:00:00+00', 'completed', 2, 1, null),

  ('TEST_GRP_02', 100, 'group',       'FASE DE GRUPOS',   'França',  'Alemanha',
   '2026-03-01 15:00:00+00', 'completed', 1, 1, null),

  -- Oitavas de final (knockout_initial)
  ('TEST_R16_01', 101, 'round_of_16', 'OITAVAS DE FINAL', 'Brasil', 'Argentina',
   '2026-03-02 12:00:00+00', 'completed', 2, 0, 'Brasil'),

  -- Semi Final (knockout_decisive)
  ('TEST_SEMI_01',102, 'semifinal',   'SEMI FINAL',       'Brasil', 'França',
   '2026-03-03 12:00:00+00', 'completed', 1, 0, 'Brasil');

-- ── Palpites de Alpha (acerta tudo exato) ────────────────────────────
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_GRP_01',  2, 1, null),        -- exato grupos
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_GRP_02',  1, 1, null),        -- exato grupos (empate)
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_R16_01',  2, 0, 'Brasil'),    -- exato oitavas
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_SEMI_01', 1, 0, 'Brasil');    -- exato semi

-- ── Palpites de Beta (resultado na maioria) ───────────────────────────
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_GRP_01',  3, 1, null),        -- resultado grupos (+0.5)
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_GRP_02',  1, 1, null),        -- exato grupos (+1.0)
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_R16_01',  1, 0, 'Brasil'),    -- resultado oitavas (+1.0)
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_SEMI_01', 3, 0, 'Brasil');    -- resultado semi (+2.0)

-- ── Palpites de Gamma (usa buffs) ────────────────────────────────────
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_01',  2, 1, null),        -- exato (+1.0)
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_02',  2, 0, null),        -- apostou França, jogo empatou → draw-protected → 0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_R16_01',  2, 0, 'Brasil'),    -- exato + palpite-duplo → +4.0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_SEMI_01', 0, 1, 'França');    -- errou semi (-0.5)

-- ── Palpites de Delta (alvo dos buffs de Gamma, sem palpite no semi) ──
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004', 'TEST_GRP_01',  2, 1, null),        -- exato → mas Gamma zerou Delta → 0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004', 'TEST_GRP_02',  1, 1, null),        -- exato sem buff → +1.0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004', 'TEST_R16_01',  2, 0, 'Brasil');    -- exato → mas Gamma aplicou meia → +1.0
  -- TEST_SEMI_01: SEM palpite → ausência knockout_decisive → -0.5

-- ── Buffs de Gamma ────────────────────────────────────────────────────
INSERT INTO public.match_buffs (user_id, match_id, buff_id, target_nickname)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_02', 'draw-protected',   null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_01', 'zerar-adversario', 'DEMO_Delta'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_R16_01', 'palpite-duplo',    null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_R16_01', 'meia-adversario',  'DEMO_Delta');

-- ── Coin-bet de Beta no SEMI_01 ───────────────────────────────────────
INSERT INTO public.match_buffs (user_id, match_id, buff_id, target_nickname, settled)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_SEMI_01', 'coin-bet', '1', false
);

SELECT '✅  Dados de teste inseridos com sucesso.' AS setup;


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 1: Funções auxiliares de fase
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 1 ─ app_phase_type ────' AS secao;
SELECT
  public.app_phase_type('FASE DE GRUPOS',   'group')       = 'group'               AS grupos_ok,
  public.app_phase_type('16 AVOS DE FINAL', 'round_of_32') = 'knockout_initial'    AS dezesseis_ok,
  public.app_phase_type('OITAVAS DE FINAL', 'round_of_16') = 'knockout_initial'    AS oitavas_ok,
  public.app_phase_type('QUARTAS DE FINAL', 'quarterfinal')= 'knockout_initial'    AS quartas_ok,
  public.app_phase_type('SEMI FINAL',       'semifinal')   = 'knockout_decisive'   AS semi_ok,
  public.app_phase_type('FINAL',            'final')       = 'knockout_decisive'   AS final_ok,
  public.app_phase_type('DISPUTA 3° LUGAR', null)          = 'knockout_decisive'   AS disputa3_ok;

SELECT '──── SEÇÃO 1 ─ app_phase_max_points ────' AS secao;
SELECT
  public.app_phase_max_points('FASE DE GRUPOS',   'group')        = 1.0 AS grupos_1pt_ok,
  public.app_phase_max_points('OITAVAS DE FINAL', 'round_of_16')  = 2.0 AS oitavas_2pt_ok,
  public.app_phase_max_points('QUARTAS DE FINAL', 'quarterfinal') = 2.0 AS quartas_2pt_ok,
  public.app_phase_max_points('SEMI FINAL',       'semifinal')    = 3.0 AS semi_3pt_ok,
  public.app_phase_max_points('FINAL',            'final')        = 3.0 AS final_3pt_ok;

SELECT '──── SEÇÃO 1 ─ app_phase_absence_penalty ────' AS secao;
SELECT
  public.app_phase_absence_penalty('FASE DE GRUPOS',   'group')       = -0.2 AS grupos_menos02_ok,
  public.app_phase_absence_penalty('OITAVAS DE FINAL', 'round_of_16') = -0.2 AS oitavas_menos02_ok,
  public.app_phase_absence_penalty('SEMI FINAL',       'semifinal')   = -0.5 AS semi_menos05_ok,
  public.app_phase_absence_penalty('FINAL',            'final')       = -0.5 AS final_menos05_ok;


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 2: Pontuação base (app_prediction_points)
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 2 ─ Pontuação GRUPOS ────' AS secao;
SELECT
  -- Exato
  public.app_prediction_points('FASE DE GRUPOS','group', 2,1, null,null,null, 2,1, null,null,null)
    = 1.0  AS exato_ok,
  -- Resultado (direção certa, placar errado)
  public.app_prediction_points('FASE DE GRUPOS','group', 2,1, null,null,null, 3,1, null,null,null)
    = 0.5  AS resultado_ok,
  -- Erro (direção errada)
  public.app_prediction_points('FASE DE GRUPOS','group', 2,1, null,null,null, 0,3, null,null,null)
    = -0.1 AS erro_ok,
  -- Exato empate
  public.app_prediction_points('FASE DE GRUPOS','group', 1,1, null,null,null, 1,1, null,null,null)
    = 1.0  AS exato_empate_ok,
  -- Resultado empate (apostou 0×0, deu 1×1)
  public.app_prediction_points('FASE DE GRUPOS','group', 1,1, null,null,null, 0,0, null,null,null)
    = 0.5  AS resultado_empate_ok,
  -- Erro quando apostou vencedor mas empatou
  public.app_prediction_points('FASE DE GRUPOS','group', 1,1, null,null,null, 2,0, null,null,null)
    = -0.1 AS erro_apostou_vencedor_empatou_ok;

SELECT '──── SEÇÃO 2 ─ Pontuação MATA-MATA INICIAL (Oitavas) ────' AS secao;
SELECT
  -- Exato (placar + vencedor)
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16', 2,0, null,null,'Brasil', 2,0, null,null,'Brasil')
    = 2.0  AS exato_ok,
  -- Avança (vencedor certo, placar errado)
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16', 2,0, null,null,'Brasil', 1,0, null,null,'Brasil')
    = 1.0  AS avanca_ok,
  -- Erro (vencedor errado)
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16', 2,0, null,null,'Brasil', 0,2, null,null,'Argentina')
    = -0.2 AS erro_ok,
  -- IMPORTANTE: acertou direção 90min (2×0) mas errou winner_team → ERRO em mata-mata
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16', 2,0, null,null,'Brasil', 3,0, null,null,'Argentina')
    = -0.2 AS direcao90_sem_winner_eh_erro_ok;

SELECT '──── SEÇÃO 2 ─ Pontuação MATA-MATA DECISIVO (Semi) ────' AS secao;
SELECT
  -- Exato
  public.app_prediction_points('SEMI FINAL','semifinal', 1,0, null,null,'Brasil', 1,0, null,null,'Brasil')
    = 3.0  AS exato_ok,
  -- Vencedor certo
  public.app_prediction_points('SEMI FINAL','semifinal', 1,0, null,null,'Brasil', 2,0, null,null,'Brasil')
    = 2.0  AS vencedor_ok,
  -- Erro
  public.app_prediction_points('SEMI FINAL','semifinal', 1,0, null,null,'Brasil', 0,1, null,null,'França')
    = -0.5 AS erro_ok,
  -- Sem multiplicador automático (Final NÃO é ×3 no sistema novo)
  public.app_prediction_points('FINAL','final', 1,0, null,null,'Brasil', 1,0, null,null,'Brasil')
    = 3.0  AS final_sem_multiplicador_automatico_ok;

SELECT '──── SEÇÃO 2 ─ app_match_auto_multiplier sempre = 1 ────' AS secao;
SELECT
  public.app_match_auto_multiplier('FASE DE GRUPOS',   'group')      = 1 AS grupos_1x_ok,
  public.app_match_auto_multiplier('SEMI FINAL',       'semifinal')  = 1 AS semi_1x_ok,
  public.app_match_auto_multiplier('FINAL',            'final')      = 1 AS final_1x_ok;


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 3: Score Context com Buffs (usa dados inseridos)
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 3 ─ draw-protected: Gamma no GRP_02 ────' AS secao;
-- Gamma apostou 2×0 (vencedor), jogo empatou 1×1 → base=-0.1 → protegido=0
SELECT
  sc.base_points                   AS base_deve_ser_menos01,
  sc.protected_points              AS protegido_deve_ser_0,
  sc.adjusted_points               AS final_deve_ser_0,
  sc.has_draw_protected            AS tem_buff_draw_protected,
  sc.base_points      = -0.1       AS base_ok,
  sc.protected_points = 0          AS protecao_aplicada_ok,
  sc.adjusted_points  = 0          AS resultado_final_ok
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000003',  -- Gamma
  'TEST_GRP_02',
  'FASE DE GRUPOS', 'group',
  1, 1, null, null, null,   -- oficial: 1×1 (empate)
  2, 0, null, null, null    -- Gamma apostou: 2×0
) sc;

SELECT '──── SEÇÃO 3 ─ draw-protected NÃO aplica quando apostou empate ────' AS secao;
-- Alpha apostou 1×1 (empate) e deu 1×1 → exato, não há proteção necessária
SELECT
  sc.base_points       = 1.0  AS base_exato_ok,
  sc.protected_points  = 1.0  AS protegido_igual_base_ok,
  sc.adjusted_points   = 1.0  AS final_ok,
  sc.has_draw_protected        AS alpha_nao_tem_buff  -- deve ser false
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000001',  -- Alpha (sem draw-protected)
  'TEST_GRP_02',
  'FASE DE GRUPOS', 'group',
  1, 1, null, null, null,
  1, 1, null, null, null
) sc;

SELECT '──── SEÇÃO 3 ─ palpite-duplo: Gamma no R16_01 ────' AS secao;
-- Gamma acertou exato 2×0 Brasil nas oitavas + tem palpite-duplo → base=2.0 → ×2 → 4.0
SELECT
  sc.base_points                   AS base_deve_ser_2,
  sc.total_multiplier              AS mult_deve_ser_2,
  sc.points_before_adversario      AS antes_adv_deve_ser_4,
  sc.adjusted_points               AS final_deve_ser_4,
  sc.has_palpite_duplo             AS tem_buff_palpite_duplo,
  sc.base_points          = 2.0    AS base_ok,
  sc.total_multiplier     = 2.0    AS multiplicador_ok,
  sc.adjusted_points      = 4.0    AS resultado_final_ok
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000003',  -- Gamma
  'TEST_R16_01',
  'OITAVAS DE FINAL', 'round_of_16',
  2, 0, null, null, 'Brasil',
  2, 0, null, null, 'Brasil'
) sc;

SELECT '──── SEÇÃO 3 ─ zerar-adversario: Delta zerado por Gamma no GRP_01 ────' AS secao;
-- Delta acertou exato 2×1 → base=1.0, mas Gamma aplicou zerar → adjusted=0
SELECT
  sc.base_points                   AS base_deve_ser_1,
  sc.cancelled_by_rival            AS foi_zerado_deve_ser_true,
  sc.adjusted_points               AS final_deve_ser_0,
  sc.base_points      = 1.0        AS base_ok,
  sc.cancelled_by_rival = true     AS zerado_ok,
  sc.adjusted_points  = 0          AS resultado_final_ok
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000004',  -- Delta
  'TEST_GRP_01',
  'FASE DE GRUPOS', 'group',
  2, 1, null, null, null,
  2, 1, null, null, null
) sc;

SELECT '──── SEÇÃO 3 ─ meia-adversario: Delta dividido por Gamma no R16_01 ────' AS secao;
-- Delta acertou exato 2×0 Brasil → base=2.0, Gamma aplicou meia → adjusted=1.0
SELECT
  sc.base_points                   AS base_deve_ser_2,
  sc.halved_by_rival               AS foi_dividido_deve_ser_true,
  sc.adjusted_points               AS final_deve_ser_1,
  sc.base_points      = 2.0        AS base_ok,
  sc.halved_by_rival  = true       AS meia_ok,
  sc.adjusted_points  = 1.0        AS resultado_final_ok
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000004',  -- Delta
  'TEST_R16_01',
  'OITAVAS DE FINAL', 'round_of_16',
  2, 0, null, null, 'Brasil',
  2, 0, null, null, 'Brasil'
) sc;

SELECT '──── SEÇÃO 3 ─ zerar não afeta quem não é o alvo ────' AS secao;
-- Beta no GRP_01 (não é alvo do zerar de Gamma, que zerou Delta)
SELECT
  sc.cancelled_by_rival = false    AS beta_nao_foi_zerado_ok,
  sc.halved_by_rival    = false    AS beta_nao_foi_meia_ok,
  sc.adjusted_points    = 0.5      AS pontos_normais_ok   -- resultado
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000002',  -- Beta
  'TEST_GRP_01',
  'FASE DE GRUPOS', 'group',
  2, 1, null, null, null,
  3, 1, null, null, null  -- Beta apostou 3×1, resultado certo
) sc;

SELECT '──── SEÇÃO 3 ─ zerar-adversario registrado no campo correto ────' AS secao;
-- Gamma no GRP_01 deve mostrar quem ele zerou
SELECT
  sc.zerar_adversario_target       AS gamma_zerou_quem,
  sc.zerar_adversario_target = 'DEMO_Delta' AS target_correto_ok
FROM public.app_prediction_score_context(
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000003',  -- Gamma
  'TEST_GRP_01',
  'FASE DE GRUPOS', 'group',
  2, 1, null, null, null,
  2, 1, null, null, null
) sc;


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 4: Coin-bet — liquidar apostas (settle)
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 4 ─ coin-bet settle: Beta no SEMI_01 (resultado → 2 moedas) ────' AS secao;
-- Beta apostou resultado (3×0 Brasil), deu 1×0 Brasil → result_hit → 1×2=2 moedas
SELECT
  match_id,
  bet_amount,
  coins_awarded,
  outcome,
  match_id     = 'TEST_SEMI_01' AS match_correto_ok,
  bet_amount   = 1              AS aposta_1_moeda_ok,
  coins_awarded = 2             AS ganhou_2_moedas_ok,
  outcome      = 'result'       AS resultado_correto_ok
FROM public.app_settle_pending_coin_bets(
  'ffffffff-ffff-ffff-ffff-000000000002'  -- token de Beta
);

-- Verificar saldo após settle (100 - 0 inserido direto + 2 award = 102)
SELECT '──── SEÇÃO 4 ─ Saldo de Beta após settle ────' AS secao;
SELECT
  coins                    AS saldo_de_beta,
  coins = 102              AS saldo_102_ok
FROM public.app_users
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000002';


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 5: Pontuação individual por jogo (conferência manual)
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 5 ─ Pontuação esperada por jogador/jogo ────' AS secao;
-- Esta tabela mostra o adjusted_points de cada combinação user×jogo
-- Conferir visualmente se bate com os valores esperados no cabeçalho deste arquivo
SELECT
  u.nickname,
  p.match_id,
  sc.base_points,
  sc.protected_points,
  sc.total_multiplier,
  sc.adjusted_points,
  sc.has_draw_protected,
  sc.has_palpite_duplo,
  sc.cancelled_by_rival,
  sc.halved_by_rival
FROM public.predictions p
JOIN public.app_users u ON u.id = p.user_id
JOIN public.matches m   ON m.id = p.match_id
LEFT JOIN LATERAL public.app_prediction_score_context(
  p.user_id, p.match_id, m.phase_label, m.phase,
  m.score_home, m.score_away, m.extra_time_home, m.extra_time_away, m.winner_team,
  p.home_score, p.away_score, p.extra_time_home, p.extra_time_away, p.winner_team
) sc ON true
WHERE u.nickname LIKE 'DEMO_%'
ORDER BY u.nickname, p.match_id;


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 6: Leaderboard completo com aproveitamento
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 6 ─ Leaderboard (posições e valores dos DEMO_ players) ────' AS secao;
-- Exibe apenas os players de teste com seus rank_positions (no contexto geral do bolão)
SELECT
  rank_position                                  AS pos,
  nickname,
  round(total_points::numeric,  1)               AS pts_total,
  exact_scores                                   AS exatos,
  correct_results                                AS resultados,
  round(coalesce(aproveitamento, 0) * 100, 1)    AS aproveit_pct,
  bonus_points                                   AS bonus
FROM public.app_get_leaderboard(null)
WHERE nickname LIKE 'DEMO_%'
ORDER BY rank_position;

SELECT '──── SEÇÃO 6 ─ Verificações de pontos totais ────' AS secao;
SELECT
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null)
   WHERE nickname='DEMO_Alpha') = 7.0   AS alpha_7pts_ok,
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null)
   WHERE nickname='DEMO_Beta')  = 4.5   AS beta_45pts_ok,
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null)
   WHERE nickname='DEMO_Gamma') = 4.5   AS gamma_45pts_ok,
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null)
   WHERE nickname='DEMO_Delta') = 1.5   AS delta_15pts_ok;

SELECT '──── SEÇÃO 6 ─ Tiebreaker: Gamma > Beta (mesmo pts, Gamma tem mais exatos) ────' AS secao;
SELECT
  (SELECT rank_position FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma') <
  (SELECT rank_position FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')
  AS gamma_acima_de_beta_ok;

SELECT '──── SEÇÃO 6 ─ Verificar exatos corretamente calculados ────' AS secao;
SELECT
  (SELECT exact_scores FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha') = 4
    AS alpha_4_exatos_ok,
  (SELECT exact_scores FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma') = 2
    AS gamma_2_exatos_ok,   -- GRP_01 e R16_01 (GRP_02 foi draw-protected, SEMI errou)
  (SELECT exact_scores FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')  = 1
    AS beta_1_exato_ok,     -- só GRP_02 (1×1)
  (SELECT exact_scores FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Delta') = 2
    AS delta_2_exatos_ok;   -- GRP_02 e R16_01 (GRP_01 foi zerado → conta como 0 pts mas foi exato)

SELECT '──── SEÇÃO 6 ─ Aproveitamento esperado ────' AS secao;
-- Alpha:  7.0/7.0 = 100%
-- Beta:   4.5/7.0 ≈ 64%
-- Gamma:  raw=(1.0-0.1+2.0-0.5)/7.0 = 2.4/7.0 ≈ 34%
-- Delta:  4.0/4.0 = 100% (só 3 jogos palpitados)
SELECT
  nickname,
  round(coalesce(aproveitamento, 0) * 100) AS aproveit_pct,
  CASE nickname
    WHEN 'DEMO_Alpha' THEN round(coalesce(aproveitamento, 0) * 100) = 100
    WHEN 'DEMO_Beta'  THEN round(coalesce(aproveitamento, 0) * 100) BETWEEN 63 AND 65
    WHEN 'DEMO_Gamma' THEN round(coalesce(aproveitamento, 0) * 100) BETWEEN 33 AND 35
    WHEN 'DEMO_Delta' THEN round(coalesce(aproveitamento, 0) * 100) = 100
  END AS aproveit_ok
FROM public.app_get_leaderboard(null)
WHERE nickname LIKE 'DEMO_%'
ORDER BY nickname;


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 7: Ausência — penalidade por jogo não palpitado
-- ════════════════════════════════════════════════════════════════════════

SELECT '──── SEÇÃO 7 ─ Ausência de Delta no SEMI (-0.5) ────' AS secao;
-- Delta não palpitou TEST_SEMI_01 (semi final = -0.5)
-- Pontos de Delta = 0(zerado) + 1.0(grp02) + 1.0(meia r16) + (-0.5)(ausente semi) = 1.5
SELECT
  total_points                     AS delta_total,
  total_points = 1.5               AS delta_1_5_pts_ok
FROM public.app_get_leaderboard(null)
WHERE nickname = 'DEMO_Delta';


-- ════════════════════════════════════════════════════════════════════════
-- SEÇÃO 8: RESUMO FINAL — todos os asserts em uma linha
-- ════════════════════════════════════════════════════════════════════════

SELECT '══════════════════════════════════════════' AS linha;
SELECT '   RESUMO — todos devem ser TRUE           ' AS titulo;
SELECT '══════════════════════════════════════════' AS linha;

SELECT
  -- Funções de fase
  public.app_phase_type('FASE DE GRUPOS','group')        = 'group'              AS phase_group_ok,
  public.app_phase_type('OITAVAS DE FINAL','round_of_16')= 'knockout_initial'  AS phase_initial_ok,
  public.app_phase_type('SEMI FINAL','semifinal')        = 'knockout_decisive' AS phase_decisive_ok,
  public.app_phase_max_points('FASE DE GRUPOS','group')  = 1.0                 AS max_1pt_ok,
  public.app_phase_max_points('OITAVAS DE FINAL',null)   = 2.0                 AS max_2pt_ok,
  public.app_phase_max_points('SEMI FINAL','semifinal')  = 3.0                 AS max_3pt_ok,
  -- Pontuação base
  public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,2,1,null,null,null) = 1.0  AS grupos_exato_ok,
  public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,3,1,null,null,null) = 0.5  AS grupos_resultado_ok,
  public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,0,3,null,null,null) = -0.1 AS grupos_erro_ok,
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',2,0,null,null,'Brasil') = 2.0  AS inicial_exato_ok,
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',1,0,null,null,'Brasil') = 1.0  AS inicial_avanca_ok,
  public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',3,0,null,null,'Argentina') = -0.2 AS inicial_direcao_sem_winner_erro_ok,
  public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',1,0,null,null,'Brasil') = 3.0  AS decisivo_exato_ok,
  public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',2,0,null,null,'Brasil') = 2.0  AS decisivo_vencedor_ok,
  public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',0,1,null,null,'França') = -0.5 AS decisivo_erro_ok,
  public.app_match_auto_multiplier('FINAL','final') = 1                                                AS sem_auto_multiplier_ok,
  -- Leaderboard
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha') = 7.0 AS alpha_7pts_ok,
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma') = 4.5 AS gamma_45pts_ok,
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')  = 4.5 AS beta_45pts_ok,
  (SELECT round(total_points::numeric,1) FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Delta') = 1.5 AS delta_15pts_ok,
  (SELECT rank_position FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma') <
  (SELECT rank_position FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')                        AS tiebreaker_gamma_acima_beta_ok;

SELECT '══════════════════════════════════════════' AS linha;
SELECT '   Dados de teste descartados (ROLLBACK)   ' AS titulo;
SELECT '══════════════════════════════════════════' AS linha;

-- ════════════════════════════════════════════════════════════════════════
-- ROLLBACK — desfaz TUDO. Nenhum dado real foi alterado.
-- ════════════════════════════════════════════════════════════════════════
ROLLBACK;
