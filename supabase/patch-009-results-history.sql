create or replace function public.app_prediction_exact_hit(
  p_official_home integer,
  p_official_away integer,
  p_predicted_home integer,
  p_predicted_away integer
)
returns boolean
language sql
immutable
as $$
  select
    p_official_home is not null
    and p_official_away is not null
    and p_predicted_home = p_official_home
    and p_predicted_away = p_official_away
$$;

create or replace function public.app_prediction_result_hit(
  p_phase_label text,
  p_phase text,
  p_official_home integer,
  p_official_away integer,
  p_official_winner text,
  p_predicted_home integer,
  p_predicted_away integer,
  p_predicted_winner text
)
returns boolean
language sql
immutable
as $$
  select
    case
      when p_official_home is null or p_official_away is null then false
      when upper(coalesce(p_phase_label, p_phase, '')) = 'FASE DE GRUPOS' then
        (
          (p_predicted_home - p_predicted_away) = 0 and (p_official_home - p_official_away) = 0
        ) or (
          (p_predicted_home - p_predicted_away) > 0 and (p_official_home - p_official_away) > 0
        ) or (
          (p_predicted_home - p_predicted_away) < 0 and (p_official_home - p_official_away) < 0
        )
      else
        (
          p_official_winner is not null
          and p_predicted_winner is not null
          and lower(trim(p_predicted_winner)) = lower(trim(p_official_winner))
        ) or (
          (p_predicted_home - p_predicted_away) = 0 and (p_official_home - p_official_away) = 0
        ) or (
          (p_predicted_home - p_predicted_away) > 0 and (p_official_home - p_official_away) > 0
        ) or (
          (p_predicted_home - p_predicted_away) < 0 and (p_official_home - p_official_away) < 0
        )
    end
$$;

create or replace function public.app_prediction_points(
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
returns numeric
language sql
immutable
as $$
  select
    case
      when p_official_home is null or p_official_away is null then 0::numeric
      when upper(coalesce(p_phase_label, p_phase, '')) = 'FASE DE GRUPOS' then
        case
          when public.app_prediction_exact_hit(p_official_home, p_official_away, p_predicted_home, p_predicted_away) then 2::numeric
          when public.app_prediction_result_hit(
            p_phase_label, p_phase,
            p_official_home, p_official_away, p_official_winner,
            p_predicted_home, p_predicted_away, p_predicted_winner
          ) then 1::numeric
          else -0.5::numeric
        end
      else
        (
          case
            when public.app_prediction_exact_hit(p_official_home, p_official_away, p_predicted_home, p_predicted_away) then 3::numeric
            else 0::numeric
          end
        )
        + (
          case
            when (p_predicted_home - p_predicted_away) = 0 and (p_official_home - p_official_away) = 0 then 1.5::numeric
            when (p_predicted_home - p_predicted_away) > 0 and (p_official_home - p_official_away) > 0 then 1.5::numeric
            when (p_predicted_home - p_predicted_away) < 0 and (p_official_home - p_official_away) < 0 then 1.5::numeric
            else 0::numeric
          end
        )
        + (
          case
            when p_official_winner is not null
              and p_predicted_winner is not null
              and lower(trim(p_predicted_winner)) = lower(trim(p_official_winner))
            then 1::numeric
            when p_official_winner is not null
              and p_predicted_winner is not null
              and lower(trim(p_predicted_winner)) <> lower(trim(p_official_winner))
            then -0.5::numeric
            else 0::numeric
          end
        )
        + (
          case
            when p_predicted_home = p_predicted_away
              and p_predicted_extra_home is not null
              and p_predicted_extra_away is not null
              and p_official_extra_home is not null
              and p_official_extra_away is not null
              and p_predicted_extra_home = p_official_extra_home
              and p_predicted_extra_away = p_official_extra_away
            then 1::numeric
            else 0::numeric
          end
        )
    end
$$;

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
  v_user app_users;
begin
  if p_token is not null then
    select * into v_user from app_get_user_by_token(p_token);
  end if;

  return query
  with scored_predictions as (
    select
      u.id as leaderboard_user_id,
      u.nickname as leaderboard_nickname,
      u.real_name as leaderboard_real_name,
      u.previous_rank as leaderboard_previous_rank,
      public.app_prediction_points(
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
      ) as points_awarded,
      case
        when public.app_prediction_exact_hit(m.score_home, m.score_away, p.home_score, p.away_score) then 1
        else 0
      end as exact_hit,
      case
        when public.app_prediction_result_hit(
          m.phase_label,
          m.phase,
          m.score_home,
          m.score_away,
          m.winner_team,
          p.home_score,
          p.away_score,
          p.winner_team
        ) then 1
        else 0
      end as result_hit
    from app_users u
    left join predictions p on p.user_id = u.id
    left join matches m on m.id = p.match_id
    where not u.is_blocked
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
    from app_users u
    left join scored_predictions sp on sp.leaderboard_user_id = u.id
    where not u.is_blocked
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

create or replace function public.app_admin_set_match_result(
  p_token uuid,
  p_match_id text,
  p_score_home integer,
  p_score_away integer,
  p_extra_time_home integer default null,
  p_extra_time_away integer default null,
  p_winner_team text default null,
  p_status text default 'completed'
)
returns matches
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin app_users;
  v_match matches;
  v_resolved_winner text;
begin
  select * into v_admin from app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_match from matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo não encontrado.';
  end if;

  v_resolved_winner := nullif(trim(coalesce(p_winner_team, '')), '');

  if v_resolved_winner is null then
    if p_score_home > p_score_away then
      v_resolved_winner := v_match.home_team;
    elsif p_score_home < p_score_away then
      v_resolved_winner := v_match.away_team;
    elsif p_extra_time_home is not null and p_extra_time_away is not null then
      if p_extra_time_home > p_extra_time_away then
        v_resolved_winner := v_match.home_team;
      elsif p_extra_time_home < p_extra_time_away then
        v_resolved_winner := v_match.away_team;
      end if;
    end if;
  end if;

  update matches
  set
    score_home = p_score_home,
    score_away = p_score_away,
    extra_time_home = p_extra_time_home,
    extra_time_away = p_extra_time_away,
    winner_team = v_resolved_winner,
    status = coalesce(nullif(trim(p_status), ''), 'completed'),
    updated_at = now()
  where id = p_match_id
  returning * into v_match;

  return v_match;
end;
$$;

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
  match_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_target_user_id uuid;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
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
    public.app_prediction_exact_hit(m.score_home, m.score_away, p.home_score, p.away_score),
    public.app_prediction_result_hit(
      m.phase_label,
      m.phase,
      m.score_home,
      m.score_away,
      m.winner_team,
      p.home_score,
      p.away_score,
      p.winner_team
    ),
    public.app_prediction_points(
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
    ),
    m.status
  from predictions p
  join matches m on m.id = p.match_id
  where p.user_id = v_target_user_id
  order by m.starts_at asc, m.match_number asc;
end;
$$;
