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
