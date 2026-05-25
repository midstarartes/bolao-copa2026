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
--   3. Veja a tabela de resultados — coluna "resultado" deve ser ✅ PASS em todos
--   4. O ROLLBACK ao final descarta tudo automaticamente
-- ════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────
-- SETUP — dados de teste
-- ────────────────────────────────────────────────────────────────────────

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

INSERT INTO public.app_sessions (token, user_id, expires_at)
VALUES (
  'ffffffff-ffff-ffff-ffff-000000000002'::uuid,
  'aaaaaaaa-aaaa-aaaa-aaaa-000000000002'::uuid,
  now() + interval '1 day'
);

INSERT INTO public.matches
  (id, match_number, phase, phase_label, home_team, away_team,
   starts_at, status, score_home, score_away, winner_team)
VALUES
  ('TEST_GRP_01',  99,  'group',       'FASE DE GRUPOS',   'Brasil',  'Argentina',
   '2026-03-01 12:00:00+00', 'completed', 2, 1, null),
  ('TEST_GRP_02',  100, 'group',       'FASE DE GRUPOS',   'França',  'Alemanha',
   '2026-03-01 15:00:00+00', 'completed', 1, 1, null),
  ('TEST_R16_01',  101, 'round_of_16', 'OITAVAS DE FINAL', 'Brasil',  'Argentina',
   '2026-03-02 12:00:00+00', 'completed', 2, 0, 'Brasil'),
  ('TEST_SEMI_01', 102, 'semifinal',   'SEMI FINAL',       'Brasil',  'França',
   '2026-03-03 12:00:00+00', 'completed', 1, 0, 'Brasil');

-- Alpha: acerta tudo exato
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_GRP_01',  2, 1, null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_GRP_02',  1, 1, null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_R16_01',  2, 0, 'Brasil'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000001', 'TEST_SEMI_01', 1, 0, 'Brasil');

-- Beta: resultado (+ coin-bet no semi)
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_GRP_01',  3, 1, null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_GRP_02',  1, 1, null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_R16_01',  1, 0, 'Brasil'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_SEMI_01', 3, 0, 'Brasil');

-- Gamma: usa buffs (draw-protected, palpite-duplo, zerar, meia)
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_01',  2, 1, null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_02',  2, 0, null),       -- apostou França, empatou → draw-protected
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_R16_01',  2, 0, 'Brasil'),   -- exato + palpite-duplo → 4.0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_SEMI_01', 0, 1, 'França');   -- errou

-- Delta: alvo dos buffs, sem palpite no semi (ausência = -0.5)
INSERT INTO public.predictions (user_id, match_id, home_score, away_score, winner_team) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004', 'TEST_GRP_01',  2, 1, null),       -- exato → zerado por Gamma → 0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004', 'TEST_GRP_02',  1, 1, null),       -- exato → 1.0
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000004', 'TEST_R16_01',  2, 0, 'Brasil');   -- exato → meia por Gamma → 1.0

-- Buffs de Gamma
INSERT INTO public.match_buffs (user_id, match_id, buff_id, target_nickname) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_02', 'draw-protected',   null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_GRP_01', 'zerar-adversario', 'DEMO_Delta'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_R16_01', 'palpite-duplo',    null),
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000003', 'TEST_R16_01', 'meia-adversario',  'DEMO_Delta');

-- Coin-bet de Beta no SEMI (resultado → 2 moedas)
INSERT INTO public.match_buffs (user_id, match_id, buff_id, target_nickname, settled) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-000000000002', 'TEST_SEMI_01', 'coin-bet', '1', false);

-- Settle das apostas de Beta antes dos testes do leaderboard
SELECT public.app_settle_pending_coin_bets(
  'ffffffff-ffff-ffff-ffff-000000000002'
);


-- ════════════════════════════════════════════════════════════════════════
-- TODOS OS TESTES EM UM ÚNICO SELECT (Supabase mostra só o último result)
-- ════════════════════════════════════════════════════════════════════════

SELECT
  secao,
  teste,
  CASE WHEN pass THEN '✅ PASS' ELSE '❌ FAIL' END AS resultado,
  detalhe
FROM (

  -- ── 1. app_phase_type ───────────────────────────────────────────────
  SELECT '1 ▸ phase_type' AS secao, 'grupos → group' AS teste,
    public.app_phase_type('FASE DE GRUPOS','group') = 'group' AS pass,
    public.app_phase_type('FASE DE GRUPOS','group') AS detalhe
  UNION ALL
  SELECT '1 ▸ phase_type', 'oitavas → knockout_initial',
    public.app_phase_type('OITAVAS DE FINAL','round_of_16') = 'knockout_initial',
    public.app_phase_type('OITAVAS DE FINAL','round_of_16')
  UNION ALL
  SELECT '1 ▸ phase_type', 'quartas → knockout_initial',
    public.app_phase_type('QUARTAS DE FINAL','quarterfinal') = 'knockout_initial',
    public.app_phase_type('QUARTAS DE FINAL','quarterfinal')
  UNION ALL
  SELECT '1 ▸ phase_type', 'semi → knockout_decisive',
    public.app_phase_type('SEMI FINAL','semifinal') = 'knockout_decisive',
    public.app_phase_type('SEMI FINAL','semifinal')
  UNION ALL
  SELECT '1 ▸ phase_type', 'final → knockout_decisive',
    public.app_phase_type('FINAL','final') = 'knockout_decisive',
    public.app_phase_type('FINAL','final')
  UNION ALL
  SELECT '1 ▸ phase_type', 'disputa 3° → knockout_decisive',
    public.app_phase_type('DISPUTA 3° LUGAR',null) = 'knockout_decisive',
    public.app_phase_type('DISPUTA 3° LUGAR',null)

  -- ── 2. app_phase_max_points ─────────────────────────────────────────
  UNION ALL
  SELECT '2 ▸ max_points', 'grupos = 1.0',
    public.app_phase_max_points('FASE DE GRUPOS','group') = 1.0,
    public.app_phase_max_points('FASE DE GRUPOS','group')::text
  UNION ALL
  SELECT '2 ▸ max_points', 'oitavas = 2.0',
    public.app_phase_max_points('OITAVAS DE FINAL','round_of_16') = 2.0,
    public.app_phase_max_points('OITAVAS DE FINAL','round_of_16')::text
  UNION ALL
  SELECT '2 ▸ max_points', 'semi = 3.0',
    public.app_phase_max_points('SEMI FINAL','semifinal') = 3.0,
    public.app_phase_max_points('SEMI FINAL','semifinal')::text
  UNION ALL
  SELECT '2 ▸ max_points', 'auto_multiplier sempre 1 (sem Final×3)',
    public.app_match_auto_multiplier('FINAL','final') = 1,
    public.app_match_auto_multiplier('FINAL','final')::text

  -- ── 3. app_phase_absence_penalty ────────────────────────────────────
  UNION ALL
  SELECT '3 ▸ absence_penalty', 'grupos = -0.2',
    public.app_phase_absence_penalty('FASE DE GRUPOS','group') = -0.2,
    public.app_phase_absence_penalty('FASE DE GRUPOS','group')::text
  UNION ALL
  SELECT '3 ▸ absence_penalty', 'oitavas = -0.2',
    public.app_phase_absence_penalty('OITAVAS DE FINAL','round_of_16') = -0.2,
    public.app_phase_absence_penalty('OITAVAS DE FINAL','round_of_16')::text
  UNION ALL
  SELECT '3 ▸ absence_penalty', 'semi = -0.5',
    public.app_phase_absence_penalty('SEMI FINAL','semifinal') = -0.5,
    public.app_phase_absence_penalty('SEMI FINAL','semifinal')::text
  UNION ALL
  SELECT '3 ▸ absence_penalty', 'final = -0.5',
    public.app_phase_absence_penalty('FINAL','final') = -0.5,
    public.app_phase_absence_penalty('FINAL','final')::text

  -- ── 4. Pontuação base — Grupos ───────────────────────────────────────
  UNION ALL
  SELECT '4 ▸ pts grupos', 'exato → +1.0',
    public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,2,1,null,null,null) = 1.0,
    public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,2,1,null,null,null)::text
  UNION ALL
  SELECT '4 ▸ pts grupos', 'resultado → +0.5',
    public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,3,1,null,null,null) = 0.5,
    public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,3,1,null,null,null)::text
  UNION ALL
  SELECT '4 ▸ pts grupos', 'erro → -0.1',
    public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,0,3,null,null,null) = -0.1,
    public.app_prediction_points('FASE DE GRUPOS','group',2,1,null,null,null,0,3,null,null,null)::text
  UNION ALL
  SELECT '4 ▸ pts grupos', 'exato empate → +1.0',
    public.app_prediction_points('FASE DE GRUPOS','group',1,1,null,null,null,1,1,null,null,null) = 1.0,
    public.app_prediction_points('FASE DE GRUPOS','group',1,1,null,null,null,1,1,null,null,null)::text
  UNION ALL
  SELECT '4 ▸ pts grupos', 'resultado empate (0×0 vs 1×1) → +0.5',
    public.app_prediction_points('FASE DE GRUPOS','group',1,1,null,null,null,0,0,null,null,null) = 0.5,
    public.app_prediction_points('FASE DE GRUPOS','group',1,1,null,null,null,0,0,null,null,null)::text

  -- ── 5. Pontuação base — Mata-mata Inicial ────────────────────────────
  UNION ALL
  SELECT '5 ▸ pts inicial', 'exato → +2.0',
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',2,0,null,null,'Brasil') = 2.0,
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',2,0,null,null,'Brasil')::text
  UNION ALL
  SELECT '5 ▸ pts inicial', 'avança (vencedor certo) → +1.0',
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',1,0,null,null,'Brasil') = 1.0,
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',1,0,null,null,'Brasil')::text
  UNION ALL
  SELECT '5 ▸ pts inicial', 'erro (vencedor errado) → -0.2',
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',0,2,null,null,'Argentina') = -0.2,
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',0,2,null,null,'Argentina')::text
  UNION ALL
  SELECT '5 ▸ pts inicial', 'direção 90min certa sem winner_team → -0.2 (mata-mata exige winner)',
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',3,0,null,null,'Argentina') = -0.2,
    public.app_prediction_points('OITAVAS DE FINAL','round_of_16',2,0,null,null,'Brasil',3,0,null,null,'Argentina')::text

  -- ── 6. Pontuação base — Mata-mata Decisivo ───────────────────────────
  UNION ALL
  SELECT '6 ▸ pts decisivo', 'exato → +3.0',
    public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',1,0,null,null,'Brasil') = 3.0,
    public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',1,0,null,null,'Brasil')::text
  UNION ALL
  SELECT '6 ▸ pts decisivo', 'vencedor certo → +2.0',
    public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',2,0,null,null,'Brasil') = 2.0,
    public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',2,0,null,null,'Brasil')::text
  UNION ALL
  SELECT '6 ▸ pts decisivo', 'erro → -0.5',
    public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',0,1,null,null,'França') = -0.5,
    public.app_prediction_points('SEMI FINAL','semifinal',1,0,null,null,'Brasil',0,1,null,null,'França')::text

  -- ── 7. Buff: draw-protected ──────────────────────────────────────────
  -- Gamma GRP_02: apostou 2×0 (vencedor), jogo empatou 1×1 → base=-0.1 → protegido=0
  UNION ALL
  SELECT '7 ▸ draw-protected', 'base = -0.1',
    (SELECT sc.base_points = -0.1 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_02',
      'FASE DE GRUPOS','group', 1,1,null,null,null, 2,0,null,null,null) sc),
    (SELECT sc.base_points::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_02',
      'FASE DE GRUPOS','group', 1,1,null,null,null, 2,0,null,null,null) sc)
  UNION ALL
  SELECT '7 ▸ draw-protected', 'protected_points = 0 (não perde)',
    (SELECT sc.protected_points = 0 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_02',
      'FASE DE GRUPOS','group', 1,1,null,null,null, 2,0,null,null,null) sc),
    (SELECT sc.protected_points::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_02',
      'FASE DE GRUPOS','group', 1,1,null,null,null, 2,0,null,null,null) sc)
  UNION ALL
  SELECT '7 ▸ draw-protected', 'adjusted_points = 0',
    (SELECT sc.adjusted_points = 0 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_02',
      'FASE DE GRUPOS','group', 1,1,null,null,null, 2,0,null,null,null) sc),
    (SELECT sc.adjusted_points::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_02',
      'FASE DE GRUPOS','group', 1,1,null,null,null, 2,0,null,null,null) sc)

  -- ── 8. Buff: palpite-duplo ───────────────────────────────────────────
  -- Gamma R16_01: exato 2×0 Brasil + palpite-duplo → base=2.0 → ×2 → 4.0
  UNION ALL
  SELECT '8 ▸ palpite-duplo', 'total_multiplier = 2',
    (SELECT sc.total_multiplier = 2 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc),
    (SELECT sc.total_multiplier::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc)
  UNION ALL
  SELECT '8 ▸ palpite-duplo', 'adjusted_points = 4.0 (base 2.0 × 2)',
    (SELECT sc.adjusted_points = 4.0 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc),
    (SELECT sc.adjusted_points::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc)

  -- ── 9. Buff: zerar-adversario ────────────────────────────────────────
  -- Delta GRP_01: exato 2×1 → base=1.0 → Gamma zerou Delta → adjusted=0
  UNION ALL
  SELECT '9 ▸ zerar-adversario', 'cancelled_by_rival = true',
    (SELECT sc.cancelled_by_rival FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_GRP_01',
      'FASE DE GRUPOS','group', 2,1,null,null,null, 2,1,null,null,null) sc),
    (SELECT sc.cancelled_by_rival::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_GRP_01',
      'FASE DE GRUPOS','group', 2,1,null,null,null, 2,1,null,null,null) sc)
  UNION ALL
  SELECT '9 ▸ zerar-adversario', 'adjusted_points = 0 (zerado)',
    (SELECT sc.adjusted_points = 0 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_GRP_01',
      'FASE DE GRUPOS','group', 2,1,null,null,null, 2,1,null,null,null) sc),
    (SELECT sc.adjusted_points::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_GRP_01',
      'FASE DE GRUPOS','group', 2,1,null,null,null, 2,1,null,null,null) sc)
  UNION ALL
  SELECT '9 ▸ zerar-adversario', 'zerar_adversario_target = DEMO_Delta (quem Gamma zerou)',
    (SELECT sc.zerar_adversario_target = 'DEMO_Delta' FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_01',
      'FASE DE GRUPOS','group', 2,1,null,null,null, 2,1,null,null,null) sc),
    (SELECT sc.zerar_adversario_target FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000003','TEST_GRP_01',
      'FASE DE GRUPOS','group', 2,1,null,null,null, 2,1,null,null,null) sc)

  -- ── 10. Buff: meia-adversario ────────────────────────────────────────
  -- Delta R16_01: exato 2×0 Brasil → base=2.0 → Gamma aplicou meia → adjusted=1.0
  UNION ALL
  SELECT '10 ▸ meia-adversario', 'halved_by_rival = true',
    (SELECT sc.halved_by_rival FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc),
    (SELECT sc.halved_by_rival::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc)
  UNION ALL
  SELECT '10 ▸ meia-adversario', 'adjusted_points = 1.0 (base 2.0 / 2)',
    (SELECT sc.adjusted_points = 1.0 FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc),
    (SELECT sc.adjusted_points::text FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000004','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 2,0,null,null,'Brasil') sc)
  UNION ALL
  SELECT '10 ▸ meia-adversario', 'Beta (não alvo) não é afetado',
    (SELECT sc.halved_by_rival = false AND sc.cancelled_by_rival = false
     FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000002','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 1,0,null,null,'Brasil') sc),
    (SELECT 'halved=' || sc.halved_by_rival::text || ' cancelled=' || sc.cancelled_by_rival::text
     FROM public.app_prediction_score_context(
      'aaaaaaaa-aaaa-aaaa-aaaa-000000000002','TEST_R16_01',
      'OITAVAS DE FINAL','round_of_16', 2,0,null,null,'Brasil', 1,0,null,null,'Brasil') sc)

  -- ── 11. Coin-bet settle ──────────────────────────────────────────────
  -- Beta SEMI_01: acertou resultado (3×0 vs 1×0, winner=Brasil) → 2 moedas
  UNION ALL
  SELECT '11 ▸ coin-bet', 'saldo Beta após settle = 102 (100 + 2)',
    (SELECT coins = 102 FROM public.app_users
     WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000002'),
    (SELECT coins::text FROM public.app_users
     WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-000000000002')

  -- ── 12. Leaderboard — pontos totais ─────────────────────────────────
  -- Alpha:  1.0 + 1.0 + 2.0 + 3.0                        = 7.0
  -- Beta:   0.5 + 1.0 + 1.0 + 2.0                        = 4.5
  -- Gamma:  1.0 + 0(prot) + 4.0(duplo) + (-0.5)          = 4.5
  -- Delta:  0(zerado) + 1.0 + 1.0(meia) + (-0.5)(ausente) = 1.5
  UNION ALL
  SELECT '12 ▸ leaderboard pts', 'Alpha = 7.0',
    (SELECT round(total_points::numeric,1) = 7.0
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha'),
    (SELECT round(total_points::numeric,1)::text
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha')
  UNION ALL
  SELECT '12 ▸ leaderboard pts', 'Gamma = 4.5',
    (SELECT round(total_points::numeric,1) = 4.5
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma'),
    (SELECT round(total_points::numeric,1)::text
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma')
  UNION ALL
  SELECT '12 ▸ leaderboard pts', 'Beta = 4.5',
    (SELECT round(total_points::numeric,1) = 4.5
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta'),
    (SELECT round(total_points::numeric,1)::text
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')
  UNION ALL
  SELECT '12 ▸ leaderboard pts', 'Delta = 1.5 (inclui ausência semi -0.5)',
    (SELECT round(total_points::numeric,1) = 1.5
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Delta'),
    (SELECT round(total_points::numeric,1)::text
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Delta')

  -- ── 13. Leaderboard — tiebreaker ────────────────────────────────────
  -- Gamma e Beta têm 4.5 pts; Gamma tem 2 exatos, Beta tem 1 → Gamma fica acima
  UNION ALL
  SELECT '13 ▸ tiebreaker', 'Gamma rank < Beta rank (mesmo pts, Gamma mais exatos)',
    (SELECT rank_position FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma') <
    (SELECT rank_position FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta'),
    'Gamma #' || (SELECT rank_position::text FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma')
    || ' · Beta #' ||
    (SELECT rank_position::text FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')

  -- ── 14. Leaderboard — exatos contados ───────────────────────────────
  UNION ALL
  SELECT '14 ▸ exact_scores', 'Alpha = 4 exatos',
    (SELECT exact_scores = 4 FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha'),
    (SELECT exact_scores::text FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha')
  UNION ALL
  SELECT '14 ▸ exact_scores', 'Gamma = 2 exatos (GRP_01 e R16_01)',
    (SELECT exact_scores = 2 FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma'),
    (SELECT exact_scores::text FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma')
  UNION ALL
  SELECT '14 ▸ exact_scores', 'Beta = 1 exato (só GRP_02)',
    (SELECT exact_scores = 1 FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta'),
    (SELECT exact_scores::text FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')

  -- ── 15. Aproveitamento % ────────────────────────────────────────────
  -- Alpha:  raw 7.0 / max 7.0 = 100%
  -- Beta:   raw 4.5 / max 7.0 ≈ 64%
  -- Gamma:  raw (1.0-0.1+2.0-0.5) / max 7.0 = 2.4/7 ≈ 34%
  -- Delta:  raw 4.0 / max 4.0 = 100% (só 3 jogos palpitados)
  UNION ALL
  SELECT '15 ▸ aproveitamento', 'Alpha ≈ 100%',
    (SELECT round(coalesce(aproveitamento,0)*100) = 100
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha'),
    (SELECT round(coalesce(aproveitamento,0)*100)::text || '%'
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Alpha')
  UNION ALL
  SELECT '15 ▸ aproveitamento', 'Beta ≈ 64%',
    (SELECT round(coalesce(aproveitamento,0)*100) BETWEEN 63 AND 65
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta'),
    (SELECT round(coalesce(aproveitamento,0)*100)::text || '%'
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Beta')
  UNION ALL
  SELECT '15 ▸ aproveitamento', 'Gamma ≈ 34% (raw sofre penalidades sem buffs)',
    (SELECT round(coalesce(aproveitamento,0)*100) BETWEEN 33 AND 35
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma'),
    (SELECT round(coalesce(aproveitamento,0)*100)::text || '%'
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Gamma')
  UNION ALL
  SELECT '15 ▸ aproveitamento', 'Delta ≈ 100% (3 palpites todos exatos)',
    (SELECT round(coalesce(aproveitamento,0)*100) = 100
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Delta'),
    (SELECT round(coalesce(aproveitamento,0)*100)::text || '%'
     FROM public.app_get_leaderboard(null) WHERE nickname='DEMO_Delta')

) testes
ORDER BY secao, teste;

-- ════════════════════════════════════════════════════════════════════════
-- ROLLBACK — desfaz TUDO. Nenhum dado real foi alterado.
-- ════════════════════════════════════════════════════════════════════════
ROLLBACK;
