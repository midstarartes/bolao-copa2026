create or replace function public.app_match_auto_multiplier(
  p_phase_label text,
  p_phase text
)
returns numeric
language sql
immutable
as $$
  select
    case
      when lower(coalesce(p_phase, '')) = 'final' or upper(coalesce(p_phase_label, '')) = 'FINAL' then 3::numeric
      when lower(coalesce(p_phase, '')) in ('semifinal', 'third_place')
        or upper(coalesce(p_phase_label, '')) = 'SEMI FINAL'
        or upper(coalesce(p_phase_label, '')) like 'DISPUTA 3%'
      then 2::numeric
      else 1::numeric
    end
$$;

drop function if exists public.app_prediction_score_context(uuid, text, text, text, integer, integer, integer, integer, text, integer, integer, integer, integer, text);

create or replace function public.app_prediction_score_context(
  p_user_id uuid,
  p_match_id text,
  p_phase_label text,
  p_phase text,
  p_official_home integer,
  p_official_away integer,
  p_official_extra_home integer,
  p_official_extra_away integer,
  p_official_winner text,
  p_predicted_home integer,
  p_predicted_away integer,
  p_predicted_extra_home integer,
  p_predicted_extra_away integer,
  p_predicted_winner text
)
returns table (
  exact_hit boolean,
  result_hit boolean,
  base_points numeric,
  protected_points numeric,
  total_multiplier numeric,
  points_before_cancel numeric,
  adjusted_points numeric,
  has_draw_protected boolean,
  has_error_shield boolean,
  has_points_x2 boolean,
  has_points_x3 boolean,
  cancelled_by_rival boolean,
  rival_cancel_target text
)
language plpgsql
stable
security definer
set search_path = public
as $score_context$
declare
  v_exact_hit boolean;
  v_result_hit boolean;
  v_base_points numeric;
  v_protected_points numeric;
  v_auto_multiplier numeric;
  v_user_multiplier numeric;
  v_total_multiplier numeric;
  v_has_draw_protected boolean;
  v_has_error_shield boolean;
  v_has_points_x2 boolean;
  v_has_points_x3 boolean;
  v_cancelled_by_rival boolean;
  v_rival_cancel_target text;
  v_points_before_cancel numeric;
  v_adjusted_points numeric;
begin
  v_exact_hit := public.app_prediction_exact_hit(
    p_official_home,
    p_official_away,
    p_predicted_home,
    p_predicted_away
  );

  v_result_hit := public.app_prediction_result_hit(
    p_phase_label,
    p_phase,
    p_official_home,
    p_official_away,
    p_official_winner,
    p_predicted_home,
    p_predicted_away,
    p_predicted_winner
  );

  v_base_points := public.app_prediction_points(
    p_phase_label,
    p_phase,
    p_official_home,
    p_official_away,
    p_official_extra_home,
    p_official_extra_away,
    p_official_winner,
    p_predicted_home,
    p_predicted_away,
    p_predicted_extra_home,
    p_predicted_extra_away,
    p_predicted_winner
  );

  select exists (
    select 1
    from public.match_buffs mb
    where mb.user_id = p_user_id
      and mb.match_id = p_match_id
      and mb.buff_id = 'draw-protected'
  ) into v_has_draw_protected;

  select exists (
    select 1
    from public.match_buffs mb
    where mb.user_id = p_user_id
      and mb.match_id = p_match_id
      and mb.buff_id = 'error-shield'
  ) into v_has_error_shield;

  select exists (
    select 1
    from public.match_buffs mb
    where mb.user_id = p_user_id
      and mb.match_id = p_match_id
      and mb.buff_id = 'points-x2'
  ) into v_has_points_x2;

  select exists (
    select 1
    from public.match_buffs mb
    where mb.user_id = p_user_id
      and mb.match_id = p_match_id
      and mb.buff_id = 'points-x3'
  ) into v_has_points_x3;

  select mb.target_nickname
  into v_rival_cancel_target
  from public.match_buffs mb
  where mb.user_id = p_user_id
    and mb.match_id = p_match_id
    and mb.buff_id = 'cancel-rival'
  limit 1;

  select exists (
    select 1
    from public.match_buffs mb
    join public.app_users target_user
      on lower(target_user.nickname) = lower(trim(mb.target_nickname))
    where mb.match_id = p_match_id
      and mb.buff_id = 'cancel-rival'
      and target_user.id = p_user_id
  ) into v_cancelled_by_rival;

  v_protected_points := v_base_points;
  if v_has_draw_protected
    and p_predicted_home is not null
    and p_predicted_away is not null
    and p_predicted_home = p_predicted_away
    and v_protected_points < 0 then
    v_protected_points := 0;
  end if;

  if v_has_error_shield and v_protected_points < 0 then
    v_protected_points := 0;
  end if;

  v_auto_multiplier := public.app_match_auto_multiplier(p_phase_label, p_phase);
  if v_auto_multiplier > 1 then
    v_user_multiplier := 1;
  elsif v_has_points_x3 then
    v_user_multiplier := 3;
  elsif v_has_points_x2 then
    v_user_multiplier := 2;
  else
    v_user_multiplier := 1;
  end if;

  v_total_multiplier := case when v_auto_multiplier > 1 then v_auto_multiplier else v_user_multiplier end;
  v_points_before_cancel := v_protected_points * v_total_multiplier;
  v_adjusted_points := case when v_cancelled_by_rival then 0::numeric else v_points_before_cancel end;

  return query
  select
    v_exact_hit,
    v_result_hit,
    v_base_points,
    v_protected_points,
    v_total_multiplier,
    v_points_before_cancel,
    v_adjusted_points,
    v_has_draw_protected,
    v_has_error_shield,
    v_has_points_x2,
    v_has_points_x3,
    v_cancelled_by_rival,
    v_rival_cancel_target;
end;
$score_context$;

drop function if exists public.app_get_leaderboard(uuid);

create or replace function public.app_get_leaderboard(p_token uuid default null)
returns table (
  rank_position integer,
  user_id uuid,
  nickname text,
  real_name text,
  exact_scores integer,
  correct_results integer,
  total_points numeric,
  previous_rank integer,
  is_current_user boolean
)
language plpgsql
security definer
set search_path = public
as $leaderboard$
declare
  v_user public.app_users;
begin
  if p_token is not null then
    select * into v_user from public.app_get_user_by_token(p_token);
  end if;

  return query
  with scored_predictions as (
    select
      u.id as leaderboard_user_id,
      u.nickname as leaderboard_nickname,
      u.real_name as leaderboard_real_name,
      u.previous_rank as leaderboard_previous_rank,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.adjusted_points
        else 0::numeric
      end as points_awarded,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null and score_ctx.exact_hit
        then 1
        else 0
      end as exact_hit,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null and score_ctx.result_hit
        then 1
        else 0
      end as result_hit
    from public.app_users u
    left join public.predictions p on p.user_id = u.id
    left join public.matches m on m.id = p.match_id
    left join lateral public.app_prediction_score_context(
      u.id,
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
    ) score_ctx on p.match_id is not null
    where not u.is_blocked
      and not u.is_admin
  ),
  aggregated as (
    select
      u.id as agg_user_id,
      u.nickname as agg_nickname,
      u.real_name as agg_real_name,
      u.previous_rank as agg_previous_rank,
      coalesce(sum(sp.points_awarded), 0)::numeric as agg_total_points,
      coalesce(sum(sp.exact_hit), 0)::integer as agg_exact_scores,
      coalesce(sum(sp.result_hit), 0)::integer as agg_correct_results
    from public.app_users u
    left join scored_predictions sp on sp.leaderboard_user_id = u.id
    where not u.is_blocked
      and not u.is_admin
    group by u.id, u.nickname, u.real_name, u.previous_rank
  ),
  ranked as (
    select
      row_number() over (
        order by
          agg_total_points desc,
          agg_exact_scores desc,
          agg_correct_results desc,
          agg_nickname asc
      )::integer as computed_rank_position,
      agg_user_id,
      agg_nickname,
      agg_real_name,
      agg_exact_scores,
      agg_correct_results,
      agg_total_points,
      agg_previous_rank
    from aggregated
  )
  select
    ranked.computed_rank_position,
    ranked.agg_user_id,
    ranked.agg_nickname,
    ranked.agg_real_name,
    ranked.agg_exact_scores,
    ranked.agg_correct_results,
    ranked.agg_total_points,
    ranked.agg_previous_rank,
    case
      when v_user.id is not null and ranked.agg_user_id = v_user.id then true
      else false
    end
  from ranked
  order by ranked.computed_rank_position;
end;
$leaderboard$;

drop function if exists public.app_get_user_history(uuid, uuid);

create or replace function public.app_get_user_history(
  p_token uuid,
  p_user_id uuid default null
)
returns table (
  match_id text,
  match_number integer,
  phase_label text,
  group_name text,
  starts_at timestamptz,
  home_team text,
  away_team text,
  official_home integer,
  official_away integer,
  official_extra_home integer,
  official_extra_away integer,
  official_winner text,
  predicted_home integer,
  predicted_away integer,
  predicted_extra_home integer,
  predicted_extra_away integer,
  predicted_winner text,
  exact_hit boolean,
  result_hit boolean,
  points_awarded numeric,
  raw_points numeric,
  total_multiplier numeric,
  cancelled_by_rival boolean,
  applied_buffs text,
  rival_cancel_target text,
  match_status text
)
language plpgsql
security definer
set search_path = public
as $history$
declare
  v_user public.app_users;
  v_target_user_id uuid;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if p_user_id is not null and v_user.is_admin then
    v_target_user_id := p_user_id;
  else
    v_target_user_id := v_user.id;
  end if;

  return query
  select
    m.id,
    m.match_number,
    m.phase_label,
    m.group_name,
    m.starts_at,
    m.home_team,
    m.away_team,
    m.score_home,
    m.score_away,
    m.extra_time_home,
    m.extra_time_away,
    m.winner_team,
    p.home_score,
    p.away_score,
    p.extra_time_home,
    p.extra_time_away,
    p.winner_team,
    case
      when m.status = 'completed' and m.score_home is not null and m.score_away is not null
      then score_ctx.exact_hit
      else false
    end,
    case
      when m.status = 'completed' and m.score_home is not null and m.score_away is not null
      then score_ctx.result_hit
      else false
    end,
    case
      when m.status = 'completed' and m.score_home is not null and m.score_away is not null
      then score_ctx.adjusted_points
      else 0::numeric
    end,
    case
      when m.status = 'completed' and m.score_home is not null and m.score_away is not null
      then score_ctx.points_before_cancel
      else 0::numeric
    end,
    case
      when m.status = 'completed' and m.score_home is not null and m.score_away is not null
      then score_ctx.total_multiplier
      else 1::numeric
    end,
    case
      when m.status = 'completed' and m.score_home is not null and m.score_away is not null
      then score_ctx.cancelled_by_rival
      else false
    end,
    trim(both ' •' from concat(
      case when score_ctx.has_draw_protected then 'Empate protegido • ' else '' end,
      case when score_ctx.has_error_shield then 'Seguro de erro • ' else '' end,
      case when score_ctx.has_points_x2 then 'Buff x2 • ' else '' end,
      case when score_ctx.has_points_x3 then 'Buff x3 • ' else '' end,
      case when score_ctx.rival_cancel_target is not null then concat('Anulou ', score_ctx.rival_cancel_target, ' • ') else '' end,
      case when score_ctx.cancelled_by_rival then 'Sofreu anulação • ' else '' end,
      case when public.app_match_auto_multiplier(m.phase_label, m.phase) = 2 then 'Multiplicador automático x2 • ' else '' end,
      case when public.app_match_auto_multiplier(m.phase_label, m.phase) = 3 then 'Multiplicador automático x3 • ' else '' end
    )),
    score_ctx.rival_cancel_target,
    m.status
  from public.predictions p
  join public.matches m on m.id = p.match_id
  join lateral public.app_prediction_score_context(
    p.user_id,
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
  where p.user_id = v_target_user_id
  order by m.starts_at asc, m.match_number asc;
end;
$history$;

drop function if exists public.app_get_current_user_mission_progress(uuid);

create or replace function public.app_get_current_user_mission_progress(p_token uuid)
returns table (
  mission_id text,
  current_value integer,
  total_value integer
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
      score_ctx.points_before_cancel,
      score_ctx.has_points_x2,
      score_ctx.has_points_x3
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
      count(*) filter (where up.status = 'completed' and up.score_home is not null and up.score_away is not null)::integer as completed_matches
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
  round16_advance as (
    select count(*)::integer as qty
    from completed_predictions cp
    where cp.phase_label = 'OITAVAS DE FINAL'
      and cp.winner_team is not null
      and cp.predicted_winner is not null
      and lower(trim(cp.predicted_winner)) = lower(trim(cp.winner_team))
  ),
  cancel_success as (
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
      and my_buff.buff_id = 'cancel-rival'
      and match_row.status = 'completed'
      and match_row.score_home is not null
      and match_row.score_away is not null
      and target_score.points_before_cancel > 0
  )
  select 'finalizar-cadastro', 1, 1
  union all
  select 'palpitar-primeiro-jogo', case when exists (select 1 from public.predictions where user_id = v_user.id and match_id = 'jogo-1') then 1 else 0 end, 1
  union all
  select 'palpitar-fase-grupos',
    coalesce((select count(*)::integer from public.predictions p join public.matches m on m.id = p.match_id where p.user_id = v_user.id and m.phase_label = 'FASE DE GRUPOS'), 0),
    coalesce((select count(*)::integer from public.matches where phase_label = 'FASE DE GRUPOS'), 1)
  union all
  select 'primeiro-placar-exato', least(coalesce((select count(*)::integer from completed_predictions where exact_hit), 0), 1), 1
  union all
  select 'placares-exatos-5', coalesce((select count(*)::integer from completed_predictions where exact_hit), 0), 5
  union all
  select 'placares-exatos-10', coalesce((select count(*)::integer from completed_predictions where exact_hit), 0), 10
  union all
  select 'resultados-5', coalesce((select count(*)::integer from completed_predictions where result_hit), 0), 5
  union all
  select 'resultados-10', coalesce((select count(*)::integer from completed_predictions where result_hit), 0), 10
  union all
  select 'resultados-20', coalesce((select count(*)::integer from completed_predictions where result_hit), 0), 20
  union all
  select 'resultados-seguidos-3', coalesce((select max(streak_value) from result_streaks), 0), 3
  union all
  select 'resultados-seguidos-5', coalesce((select max(streak_value) from result_streaks), 0), 5
  union all
  select 'sem-negativo-10', coalesce((select max(streak_value) from non_negative_streaks), 0), 10
  union all
  select 'grupo-perfeito', least(coalesce((select qty from perfect_groups), 0), 1), 1
  union all
  select 'oitavas-avanca-8', coalesce((select qty from round16_advance), 0), 8
  union all
  select 'mata-mata-exatos-2', coalesce((select count(*)::integer from completed_predictions where phase_label <> 'FASE DE GRUPOS' and exact_hit), 0), 2
  union all
  select 'buff-x2-exato', least(coalesce((select count(*)::integer from completed_predictions where has_points_x2 and exact_hit), 0), 1), 1
  union all
  select 'buff-x3-exato', least(coalesce((select count(*)::integer from completed_predictions where has_points_x3 and exact_hit), 0), 1), 1
  union all
  select 'cancelar-adversario', least(coalesce((select qty from cancel_success), 0), 1), 1;
end;
$missions$;
