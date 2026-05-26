-- Patch 030: Multiplicadores de dificuldade na Zebra da Copa
--
-- MUDANÇA: A pontuação da Zebra agora considera um multiplicador (×1 a ×4)
-- baseado no nível de azarão da seleção escolhida.
--
-- FÓRMULA ANTIGA: fases_avançadas × 2
-- FÓRMULA NOVA:   fases_avançadas × 2 × multiplicador
--
-- MULTIPLICADORES:
--   ×1 (favoritinhos): Estados Unidos, Coreia do Sul, Equador, Turquia,
--                      Áustria, Noruega, Suíça, Suécia
--   ×2 (desconhecidos): Canadá, Egito, Gana, Argélia, República Tcheca,
--                       Paraguai, Escócia, Arábia Saudita
--   ×3 (grandes zebras): Austrália, Uzbequistão, Iraque, Irã,
--                        Nova Zelândia, Bósnia e Herzegovina,
--                        África do Sul, Costa do Marfim
--   ×4 (azarões totais): Curaçao, Haiti, Catar, Panamá, Tunísia,
--                        Jordânia, Cabo Verde, RD Congo
--
-- EXEMPLO: Haiti (×4) avança 3 fases → 3 × 2 × 4 = 24 pts
--
-- Apenas redefine app_score_bonus_prediction — app_get_leaderboard
-- chama esta função e herda a nova lógica automaticamente.

create or replace function public.app_score_bonus_prediction(
  p_user_id uuid,
  p_results jsonb
)
returns table (
  pts_champion numeric,
  pts_runner_up numeric,
  pts_third_place numeric,
  pts_fourth_place numeric,
  pts_top_scorer numeric,
  pts_best_group numeric,
  pts_total_goals numeric,
  pts_zebra numeric,
  total_bonus_points numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_bp public.bonus_predictions;
  v_champion_pts    numeric := 0;
  v_runner_up_pts   numeric := 0;
  v_third_pts       numeric := 0;
  v_fourth_pts      numeric := 0;
  v_top_scorer_pts  numeric := 0;
  v_best_group_pts  numeric := 0;
  v_total_goals_pts numeric := 0;
  v_zebra_pts       numeric := 0;

  v_result_champion    text;
  v_result_runner_up   text;
  v_result_third       text;
  v_result_fourth      text;
  v_result_top_scorer  text;
  v_result_best_group  text;
  v_result_total_goals integer;
  v_result_zebra_team  text;
  v_result_zebra_phases integer;

  v_zebra_multiplier integer := 1;
  v_min_goals_diff   integer;
begin
  -- Resultados reais
  v_result_champion      := nullif(trim(p_results->>'champion'), '');
  v_result_runner_up     := nullif(trim(p_results->>'runner_up'), '');
  v_result_third         := nullif(trim(p_results->>'third_place'), '');
  v_result_fourth        := nullif(trim(p_results->>'fourth_place'), '');
  v_result_top_scorer    := nullif(trim(p_results->>'top_scorer'), '');
  v_result_best_group    := nullif(trim(p_results->>'best_group_stage_team'), '');
  v_result_total_goals   := (p_results->>'total_goals')::integer;
  v_result_zebra_team    := nullif(trim(p_results->>'zebra_team'), '');
  v_result_zebra_phases  := coalesce((p_results->>'zebra_phases_advanced')::integer, 0);

  -- Palpite do usuário
  select * into v_bp
  from public.bonus_predictions
  where user_id = p_user_id
  limit 1;

  if v_bp.user_id is null then
    return query select 0,0,0,0,0,0,0,0,0::numeric;
    return;
  end if;

  -- Campeão +8
  if v_result_champion is not null
    and v_bp.champion is not null
    and lower(trim(v_bp.champion)) = lower(v_result_champion)
  then v_champion_pts := 8; end if;

  -- Vice +5
  if v_result_runner_up is not null
    and v_bp.runner_up is not null
    and lower(trim(v_bp.runner_up)) = lower(v_result_runner_up)
  then v_runner_up_pts := 5; end if;

  -- 3º lugar +3
  if v_result_third is not null
    and v_bp.third_place is not null
    and lower(trim(v_bp.third_place)) = lower(v_result_third)
  then v_third_pts := 3; end if;

  -- 4º lugar +2
  if v_result_fourth is not null
    and v_bp.fourth_place is not null
    and lower(trim(v_bp.fourth_place)) = lower(v_result_fourth)
  then v_fourth_pts := 2; end if;

  -- Artilheiro +4
  if v_result_top_scorer is not null
    and v_bp.top_scorer is not null
    and lower(trim(v_bp.top_scorer)) = lower(v_result_top_scorer)
  then v_top_scorer_pts := 4; end if;

  -- Melhor campanha grupos +3
  if v_result_best_group is not null
    and v_bp.best_group_stage_team is not null
    and lower(trim(v_bp.best_group_stage_team)) = lower(v_result_best_group)
  then v_best_group_pts := 3; end if;

  -- Zebra: fases × 2 × multiplicador de dificuldade
  if v_result_zebra_team is not null
    and v_bp.tournament_zebra is not null
    and lower(trim(v_bp.tournament_zebra)) = lower(v_result_zebra_team)
    and v_result_zebra_phases > 0
  then
    v_zebra_multiplier := case lower(trim(v_bp.tournament_zebra))
      -- ×4 — azarões totais
      when 'curaçao'               then 4
      when 'haiti'                 then 4
      when 'catar'                 then 4
      when 'panamá'                then 4
      when 'tunísia'               then 4
      when 'jordânia'              then 4
      when 'cabo verde'            then 4
      when 'rd congo'              then 4
      -- ×3 — grandes zebras
      when 'austrália'             then 3
      when 'uzbequistão'           then 3
      when 'iraque'                then 3
      when 'irã'                   then 3
      when 'nova zelândia'         then 3
      when 'bósnia e herzegovina'  then 3
      when 'áfrica do sul'         then 3
      when 'costa do marfim'       then 3
      -- ×2 — desconhecidos
      when 'canadá'                then 2
      when 'egito'                 then 2
      when 'gana'                  then 2
      when 'argélia'               then 2
      when 'república tcheca'      then 2
      when 'paraguai'              then 2
      when 'escócia'               then 2
      when 'arábia saudita'        then 2
      -- ×1 — favoritinhos (e qualquer outro não mapeado)
      else 1
    end;
    v_zebra_pts := v_result_zebra_phases * 2 * v_zebra_multiplier;
  end if;

  -- Total de gols: quem chegou mais perto ganha +4
  if v_result_total_goals is not null and v_bp.total_goals is not null then
    select min(abs(bp2.total_goals - v_result_total_goals))
    into v_min_goals_diff
    from public.bonus_predictions bp2
    where bp2.total_goals is not null;

    if abs(v_bp.total_goals - v_result_total_goals) = v_min_goals_diff then
      v_total_goals_pts := 4;
    end if;
  end if;

  return query select
    v_champion_pts,
    v_runner_up_pts,
    v_third_pts,
    v_fourth_pts,
    v_top_scorer_pts,
    v_best_group_pts,
    v_total_goals_pts,
    v_zebra_pts,
    (v_champion_pts + v_runner_up_pts + v_third_pts + v_fourth_pts +
     v_top_scorer_pts + v_best_group_pts + v_total_goals_pts + v_zebra_pts);
end;
$$;
