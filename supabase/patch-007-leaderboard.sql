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
      case
        when m.score_home is null or m.score_away is null then 0::numeric
        when upper(coalesce(m.phase_label, m.phase, '')) = 'FASE DE GRUPOS' then
          case
            when p.home_score = m.score_home and p.away_score = m.score_away then 2::numeric
            when (p.home_score - p.away_score) = 0 and (m.score_home - m.score_away) = 0 then 1::numeric
            when (p.home_score - p.away_score) > 0 and (m.score_home - m.score_away) > 0 then 1::numeric
            when (p.home_score - p.away_score) < 0 and (m.score_home - m.score_away) < 0 then 1::numeric
            else -0.5::numeric
          end
        else
          (
            case
              when p.home_score = m.score_home and p.away_score = m.score_away then 3::numeric
              else 0::numeric
            end
          )
          + (
            case
              when (p.home_score - p.away_score) = 0 and (m.score_home - m.score_away) = 0 then 1.5::numeric
              when (p.home_score - p.away_score) > 0 and (m.score_home - m.score_away) > 0 then 1.5::numeric
              when (p.home_score - p.away_score) < 0 and (m.score_home - m.score_away) < 0 then 1.5::numeric
              else 0::numeric
            end
          )
          + (
            case
              when m.winner_team is not null and p.winner_team is not null and lower(trim(p.winner_team)) = lower(trim(m.winner_team)) then 1::numeric
              when m.winner_team is not null and p.winner_team is not null and lower(trim(p.winner_team)) <> lower(trim(m.winner_team)) then -0.5::numeric
              else 0::numeric
            end
          )
          + (
            case
              when p.home_score = p.away_score
                and p.extra_time_home is not null
                and p.extra_time_away is not null
                and m.extra_time_home is not null
                and m.extra_time_away is not null
                and p.extra_time_home = m.extra_time_home
                and p.extra_time_away = m.extra_time_away
              then 1::numeric
              else 0::numeric
            end
          )
      end as points_awarded,
      case
        when m.score_home is not null
          and m.score_away is not null
          and p.home_score = m.score_home
          and p.away_score = m.score_away
        then 1
        else 0
      end as exact_hit,
      case
        when m.score_home is null or m.score_away is null then 0
        when upper(coalesce(m.phase_label, m.phase, '')) = 'FASE DE GRUPOS' then
          case
            when (p.home_score - p.away_score) = 0 and (m.score_home - m.score_away) = 0 then 1
            when (p.home_score - p.away_score) > 0 and (m.score_home - m.score_away) > 0 then 1
            when (p.home_score - p.away_score) < 0 and (m.score_home - m.score_away) < 0 then 1
            else 0
          end
        else
          case
            when m.winner_team is not null and p.winner_team is not null and lower(trim(p.winner_team)) = lower(trim(m.winner_team)) then 1
            when (p.home_score - p.away_score) = 0 and (m.score_home - m.score_away) = 0 then 1
            when (p.home_score - p.away_score) > 0 and (m.score_home - m.score_away) > 0 then 1
            when (p.home_score - p.away_score) < 0 and (m.score_home - m.score_away) < 0 then 1
            else 0
          end
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
