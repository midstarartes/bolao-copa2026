-- Patch 034 - Mata-mata pontua resultado pelo placar de 90 min + acrescimos
-- Nova regra:
-- - Fase de grupos: acertar vencedor ou empate pelo placar.
-- - Mata-mata: mesma logica da fase de grupos, com pontuacoes maiores.
-- - winner_team/quem avanca deixa de ser criterio para pontuacao de resultado do jogo.

create or replace function public.app_prediction_result_hit(
  p_phase_label       text,
  p_phase             text,
  p_official_home     integer,
  p_official_away     integer,
  p_official_winner   text,
  p_predicted_home    integer,
  p_predicted_away    integer,
  p_predicted_winner  text
)
returns boolean
language sql
immutable
as $$
  select
    case
      when p_official_home is null or p_official_away is null then false
      when p_predicted_home is null or p_predicted_away is null then false
      else
           ((p_predicted_home - p_predicted_away) = 0 and (p_official_home - p_official_away) = 0)
        or ((p_predicted_home - p_predicted_away) > 0 and (p_official_home - p_official_away) > 0)
        or ((p_predicted_home - p_predicted_away) < 0 and (p_official_home - p_official_away) < 0)
    end
$$;

create or replace function public.app_get_current_user_mission_progress(p_token uuid)
returns table (
  mission_id    text,
  current_value integer,
  total_value   integer
)
language plpgsql
security definer
set search_path = public
as $missions$
declare
  v_user public.app_users;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if v_user.is_admin then
    return;
  end if;

  return query
  with user_predictions as (
    select
      p.match_id,
      m.match_number,
      m.phase,
      m.phase_label,
      m.group_name,
      m.starts_at,
      m.status,
      m.score_home,
      m.score_away,
      m.extra_time_home,
      m.extra_time_away,
      m.winner_team,
      p.home_score,
      p.away_score,
      p.extra_time_home as predicted_extra_home,
      p.extra_time_away as predicted_extra_away,
      p.winner_team as predicted_winner,
      score_ctx.exact_hit,
      score_ctx.result_hit,
      score_ctx.adjusted_points,
      score_ctx.has_palpite_duplo,
      false as has_points_x3
    from public.predictions p
    join public.matches m on m.id = p.match_id
    join lateral public.app_prediction_score_context(
      v_user.id,
      p.match_id,
      m.phase_label,
      m.phase,
      m.score_home,
      m.score_away,
      m.extra_time_home,
      m.extra_time_away,
      m.winner_team,
      p.home_score,
      p.away_score,
      p.extra_time_home,
      p.extra_time_away,
      p.winner_team
    ) score_ctx on true
    where p.user_id = v_user.id
  ),
  completed_predictions as (
    select *
    from user_predictions
    where score_home is not null
      and score_away is not null
      and status = 'completed'
  ),
  result_streak_source as (
    select
      row_number() over (order by starts_at, match_number) as seq,
      result_hit
    from completed_predictions
  ),
  result_streaks as (
    select count(*)::integer as streak_value
    from (
      select
        seq - row_number() over (order by seq) as grp
      from result_streak_source
      where result_hit
    ) streak_groups
    group by grp
  ),
  non_negative_source as (
    select
      row_number() over (order by starts_at, match_number) as seq,
      (adjusted_points >= 0) as is_non_negative
    from completed_predictions
  ),
  non_negative_streaks as (
    select count(*)::integer as streak_value
    from (
      select
        seq - row_number() over (order by seq) as grp
      from non_negative_source
      where is_non_negative
    ) streak_groups
    group by grp
  ),
  group_totals as (
    select group_name, count(*)::integer as total_matches
    from public.matches
    where phase_label = 'FASE DE GRUPOS'
      and group_name is not null
    group by group_name
  ),
  group_results as (
    select
      up.group_name,
      count(*)::integer as predicted_matches,
      count(*) filter (where up.result_hit)::integer as correct_matches,
      count(*) filter (
        where up.status = 'completed'
          and up.score_home is not null
          and up.score_away is not null
      )::integer as completed_matches
    from user_predictions up
    where up.phase_label = 'FASE DE GRUPOS'
      and up.group_name is not null
    group by up.group_name
  ),
  perfect_groups as (
    select count(*)::integer as qty
    from group_results gr
    join group_totals gt on gt.group_name = gr.group_name
    where gr.predicted_matches = gt.total_matches
      and gr.completed_matches = gt.total_matches
      and gr.correct_matches = gt.total_matches
  ),
  round16_results as (
    select count(*)::integer as qty
    from completed_predictions cp
    where cp.phase_label = 'OITAVAS DE FINAL'
      and cp.result_hit
  ),
  zerar_success as (
    select count(*)::integer as qty
    from public.match_buffs my_buff
    join public.app_users target_user
      on lower(target_user.nickname) = lower(trim(my_buff.target_nickname))
    join public.predictions target_prediction
      on target_prediction.user_id = target_user.id
     and target_prediction.match_id = my_buff.match_id
    join public.matches match_row
      on match_row.id = target_prediction.match_id
    join lateral public.app_prediction_score_context(
      target_user.id,
      target_prediction.match_id,
      match_row.phase_label,
      match_row.phase,
      match_row.score_home,
      match_row.score_away,
      match_row.extra_time_home,
      match_row.extra_time_away,
      match_row.winner_team,
      target_prediction.home_score,
      target_prediction.away_score,
      target_prediction.extra_time_home,
      target_prediction.extra_time_away,
      target_prediction.winner_team
    ) target_score on true
    where my_buff.user_id = v_user.id
      and my_buff.buff_id = 'zerar-adversario'
      and match_row.status = 'completed'
      and match_row.score_home is not null
      and match_row.score_away is not null
      and target_score.points_before_adversario > 0
  )
  select 'finalizar-cadastro'::text, 1, 1
  union all
  select 'palpitar-primeiro-jogo',
    case when exists (
      select 1 from public.predictions
      where user_id = v_user.id and match_id = 'jogo-1'
    ) then 1 else 0 end,
    1
  union all
  select 'palpitar-fase-grupos',
    coalesce((
      select count(*)::integer
      from public.predictions p2
      join public.matches m2 on m2.id = p2.match_id
      where p2.user_id = v_user.id
        and m2.phase_label = 'FASE DE GRUPOS'
    ), 0),
    coalesce((
      select count(*)::integer
      from public.matches
      where phase_label = 'FASE DE GRUPOS'
    ), 1)
  union all
  select 'primeiro-placar-exato',
    least(coalesce((select count(*)::integer from completed_predictions where exact_hit), 0), 1),
    1
  union all
  select 'placares-exatos-5',
    coalesce((select count(*)::integer from completed_predictions where exact_hit), 0),
    5
  union all
  select 'placares-exatos-10',
    coalesce((select count(*)::integer from completed_predictions where exact_hit), 0),
    10
  union all
  select 'resultados-5',
    coalesce((select count(*)::integer from completed_predictions where result_hit), 0),
    5
  union all
  select 'resultados-10',
    coalesce((select count(*)::integer from completed_predictions where result_hit), 0),
    10
  union all
  select 'resultados-20',
    coalesce((select count(*)::integer from completed_predictions where result_hit), 0),
    20
  union all
  select 'resultados-seguidos-3',
    coalesce((select max(streak_value) from result_streaks), 0),
    3
  union all
  select 'resultados-seguidos-5',
    coalesce((select max(streak_value) from result_streaks), 0),
    5
  union all
  select 'sem-negativo-10',
    coalesce((select max(streak_value) from non_negative_streaks), 0),
    10
  union all
  select 'grupo-perfeito',
    least(coalesce((select qty from perfect_groups), 0), 1),
    1
  union all
  select 'oitavas-avanca-8',
    coalesce((select qty from round16_results), 0),
    8
  union all
  select 'mata-mata-exatos-2',
    coalesce((
      select count(*)::integer from completed_predictions
      where phase_label <> 'FASE DE GRUPOS' and exact_hit
    ), 0),
    2
  union all
  select 'buff-x2-exato',
    least(coalesce((
      select count(*)::integer from completed_predictions
      where has_palpite_duplo and exact_hit
    ), 0), 1),
    1
  union all
  select 'buff-x3-exato', 0, 1
  union all
  select 'cancelar-adversario',
    least(coalesce((select qty from zerar_success), 0), 1),
    1;
end;
$missions$;
