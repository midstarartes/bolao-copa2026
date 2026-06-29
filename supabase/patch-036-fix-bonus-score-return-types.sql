-- Corrige o tipo de retorno de app_score_bonus_prediction.
-- Quando algum resultado extra parcial era salvo, a funcao podia retornar
-- literais integer em colunas declaradas como numeric e quebrar app_get_leaderboard.

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

  v_result_champion     text;
  v_result_runner_up    text;
  v_result_third        text;
  v_result_fourth       text;
  v_result_top_scorer   text;
  v_result_best_group   text;
  v_result_total_goals  integer;
  v_result_zebra_team   text;
  v_result_zebra_phases integer;

  v_zebra_multiplier integer := 1;
  v_min_goals_diff   integer;
begin
  v_result_champion      := nullif(trim(p_results->>'champion'), '');
  v_result_runner_up     := nullif(trim(p_results->>'runner_up'), '');
  v_result_third         := nullif(trim(p_results->>'third_place'), '');
  v_result_fourth        := nullif(trim(p_results->>'fourth_place'), '');
  v_result_top_scorer    := nullif(trim(p_results->>'top_scorer'), '');
  v_result_best_group    := nullif(trim(p_results->>'best_group_stage_team'), '');
  v_result_total_goals   := nullif(trim(p_results->>'total_goals'), '')::integer;
  v_result_zebra_team    := nullif(trim(p_results->>'zebra_team'), '');
  v_result_zebra_phases  := coalesce(nullif(trim(p_results->>'zebra_phases_advanced'), '')::integer, 0);

  select * into v_bp
  from public.bonus_predictions
  where user_id = p_user_id
  limit 1;

  if v_bp.user_id is null then
    return query select
      0::numeric, 0::numeric, 0::numeric, 0::numeric, 0::numeric,
      0::numeric, 0::numeric, 0::numeric, 0::numeric;
    return;
  end if;

  if v_result_champion is not null
    and v_bp.champion is not null
    and lower(trim(v_bp.champion)) = lower(v_result_champion)
  then v_champion_pts := 8; end if;

  if v_result_runner_up is not null
    and v_bp.runner_up is not null
    and lower(trim(v_bp.runner_up)) = lower(v_result_runner_up)
  then v_runner_up_pts := 5; end if;

  if v_result_third is not null
    and v_bp.third_place is not null
    and lower(trim(v_bp.third_place)) = lower(v_result_third)
  then v_third_pts := 3; end if;

  if v_result_fourth is not null
    and v_bp.fourth_place is not null
    and lower(trim(v_bp.fourth_place)) = lower(v_result_fourth)
  then v_fourth_pts := 2; end if;

  if v_result_top_scorer is not null
    and v_bp.top_scorer is not null
    and lower(trim(v_bp.top_scorer)) = lower(v_result_top_scorer)
  then v_top_scorer_pts := 4; end if;

  if v_result_best_group is not null
    and v_bp.best_group_stage_team is not null
    and lower(trim(v_bp.best_group_stage_team)) = lower(v_result_best_group)
  then v_best_group_pts := 3; end if;

  if v_result_zebra_team is not null
    and v_bp.tournament_zebra is not null
    and lower(trim(v_bp.tournament_zebra)) = lower(v_result_zebra_team)
    and v_result_zebra_phases > 0
  then
    v_zebra_multiplier := case lower(trim(v_bp.tournament_zebra))
      when 'curaçao' then 4
      when 'haiti' then 4
      when 'catar' then 4
      when 'panamá' then 4
      when 'tunísia' then 4
      when 'jordânia' then 4
      when 'cabo verde' then 4
      when 'rd congo' then 4
      when 'austrália' then 3
      when 'uzbequistão' then 3
      when 'iraque' then 3
      when 'irã' then 3
      when 'nova zelândia' then 3
      when 'bósnia e herzegovina' then 3
      when 'áfrica do sul' then 3
      when 'costa do marfim' then 3
      when 'canadá' then 2
      when 'egito' then 2
      when 'gana' then 2
      when 'argélia' then 2
      when 'república tcheca' then 2
      when 'paraguai' then 2
      when 'escócia' then 2
      when 'arábia saudita' then 2
      else 1
    end;
    v_zebra_pts := v_result_zebra_phases * 2 * v_zebra_multiplier;
  end if;

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
    v_champion_pts::numeric,
    v_runner_up_pts::numeric,
    v_third_pts::numeric,
    v_fourth_pts::numeric,
    v_top_scorer_pts::numeric,
    v_best_group_pts::numeric,
    v_total_goals_pts::numeric,
    v_zebra_pts::numeric,
    (v_champion_pts + v_runner_up_pts + v_third_pts + v_fourth_pts +
     v_top_scorer_pts + v_best_group_pts + v_total_goals_pts + v_zebra_pts)::numeric;
end;
$$;
