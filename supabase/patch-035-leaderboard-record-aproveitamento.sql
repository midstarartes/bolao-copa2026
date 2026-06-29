-- Ajusta o aproveitamento do ranking para formato "placar exato - resultado - erro".
-- Jogo concluido sem palpite conta como erro para usuarios criados antes do jogo.

drop function if exists public.app_get_leaderboard(uuid);

create or replace function public.app_get_leaderboard(p_token uuid default null)
returns table (
  rank_position              integer,
  user_id                    uuid,
  nickname                   text,
  real_name                  text,
  avatar_type                text,
  avatar_value               text,
  exact_scores               integer,
  correct_results            integer,
  total_points               numeric,
  bonus_points               numeric,
  aproveitamento             numeric,
  previous_rank              integer,
  is_current_user            boolean,
  aproveitamento_exact       integer,
  aproveitamento_result      integer,
  aproveitamento_miss        integer
)
language plpgsql
security definer
set search_path = public
as $leaderboard$
declare
  v_user          public.app_users;
  v_bonus_results jsonb;
begin
  if p_token is not null then
    select * into v_user from public.app_get_user_by_token(p_token);
  end if;

  v_bonus_results := public.app_get_bonus_results();

  return query
  with scored_predictions as (
    select
      u.id as leaderboard_user_id,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.adjusted_points
        else 0::numeric
      end as points_awarded,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
          and score_ctx.exact_hit
        then 1 else 0
      end as exact_hit,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
          and score_ctx.result_hit
        then 1 else 0
      end as result_hit
    from public.app_users u
    left join public.predictions p on p.user_id = u.id
    left join public.matches m     on m.id = p.match_id
    left join lateral public.app_prediction_score_context(
      u.id, p.match_id, m.phase_label, m.phase,
      m.score_home, m.score_away, m.extra_time_home, m.extra_time_away, m.winner_team,
      p.home_score, p.away_score, p.extra_time_home, p.extra_time_away, p.winner_team
    ) score_ctx on p.match_id is not null
    where not u.is_blocked and not u.is_admin
  ),

  missed_penalties as (
    select
      u.id as mp_user_id,
      sum(public.app_phase_absence_penalty(m.phase_label, m.phase))::numeric as mp_penalty
    from public.app_users u
    cross join public.matches m
    where not u.is_blocked
      and not u.is_admin
      and m.status     = 'completed'
      and m.score_home is not null
      and m.score_away is not null
      and m.match_number > 3
      and m.starts_at >= u.created_at
      and not exists (
        select 1 from public.predictions p
        where p.user_id = u.id and p.match_id = m.id
      )
    group by u.id
  ),

  aproveitamento_data as (
    select
      u.id as ap_user_id,
      coalesce(sum(case when score_ctx.exact_hit then 1 else 0 end), 0)::integer as ap_exact,
      coalesce(sum(case when not score_ctx.exact_hit and score_ctx.result_hit then 1 else 0 end), 0)::integer as ap_result,
      coalesce(sum(
        case
          when m.id is null then 0
          when p.id is null then 1
          when score_ctx.exact_hit or score_ctx.result_hit then 0
          else 1
        end
      ), 0)::integer as ap_miss
    from public.app_users u
    left join public.matches m
      on m.status = 'completed'
     and m.score_home is not null
     and m.score_away is not null
     and m.starts_at >= u.created_at
    left join public.predictions p
      on p.user_id = u.id
     and p.match_id = m.id
    left join lateral public.app_prediction_score_context(
      u.id, p.match_id, m.phase_label, m.phase,
      m.score_home, m.score_away, m.extra_time_home, m.extra_time_away, m.winner_team,
      p.home_score, p.away_score, p.extra_time_home, p.extra_time_away, p.winner_team
    ) score_ctx on p.id is not null
    where not u.is_blocked
      and not u.is_admin
    group by u.id
  ),

  champion_data as (
    select
      bp.user_id as ch_user_id,
      case
        when (
          select trim(lower(coalesce(s.value->'bonus_results'->>'champion', '')))
          from public.app_settings s
          where s.key = 'system'
          limit 1
        ) <> ''
          and lower(trim(coalesce(bp.champion, ''))) = (
          select trim(lower(coalesce(s.value->'bonus_results'->>'champion', '')))
          from public.app_settings s
          where s.key = 'system'
          limit 1
        )
        then 1 else 0
      end as got_champion
    from public.bonus_predictions bp
  ),

  aggregated as (
    select
      u.id            as agg_user_id,
      u.nickname      as agg_nickname,
      u.real_name     as agg_real_name,
      u.avatar_type   as agg_avatar_type,
      u.avatar_value  as agg_avatar_value,
      u.previous_rank as agg_previous_rank,
      coalesce(sum(sp.points_awarded), 0)::numeric
        + coalesce(mp.mp_penalty, 0)            as agg_game_points,
      coalesce(sum(sp.exact_hit),   0)::integer as agg_exact_scores,
      coalesce(sum(sp.result_hit),  0)::integer as agg_correct_results,
      coalesce(ap.ap_exact, 0)::integer         as agg_aproveitamento_exact,
      coalesce(ap.ap_result, 0)::integer        as agg_aproveitamento_result,
      coalesce(ap.ap_miss, 0)::integer          as agg_aproveitamento_miss,
      coalesce(ch.got_champion, 0)              as agg_got_champion
    from public.app_users u
    left join scored_predictions sp  on sp.leaderboard_user_id = u.id
    left join missed_penalties   mp  on mp.mp_user_id          = u.id
    left join aproveitamento_data ap on ap.ap_user_id          = u.id
    left join champion_data       ch on ch.ch_user_id          = u.id
    where not u.is_blocked and not u.is_admin
    group by
      u.id, u.nickname, u.real_name, u.avatar_type, u.avatar_value,
      u.previous_rank, mp.mp_penalty, ap.ap_exact, ap.ap_result, ap.ap_miss, ch.got_champion
  ),

  with_bonus as (
    select
      agg.*,
      case
        when v_bonus_results <> '{}'::jsonb
        then coalesce(
          (select bs.total_bonus_points
           from public.app_score_bonus_prediction(agg.agg_user_id, v_bonus_results) bs
           limit 1),
          0::numeric
        )
        else 0::numeric
      end as agg_bonus_points
    from aggregated agg
  ),

  ranked as (
    select
      row_number() over (
        order by
          (agg_game_points + agg_bonus_points) desc,
          agg_exact_scores                     desc,
          agg_aproveitamento_result           desc,
          agg_aproveitamento_miss             asc,
          agg_got_champion                    desc,
          agg_nickname                        asc
      )::integer as computed_rank_position,
      agg_user_id, agg_nickname, agg_real_name, agg_avatar_type, agg_avatar_value,
      agg_exact_scores, agg_correct_results,
      agg_game_points + agg_bonus_points as agg_total_points,
      agg_bonus_points,
      agg_previous_rank,
      agg_aproveitamento_exact,
      agg_aproveitamento_result,
      agg_aproveitamento_miss
    from with_bonus
  )
  select
    ranked.computed_rank_position,
    ranked.agg_user_id,
    ranked.agg_nickname,
    ranked.agg_real_name,
    ranked.agg_avatar_type,
    ranked.agg_avatar_value,
    ranked.agg_exact_scores,
    ranked.agg_correct_results,
    ranked.agg_total_points,
    ranked.agg_bonus_points,
    null::numeric,
    ranked.agg_previous_rank,
    case when v_user.id is not null and ranked.agg_user_id = v_user.id then true else false end,
    ranked.agg_aproveitamento_exact,
    ranked.agg_aproveitamento_result,
    ranked.agg_aproveitamento_miss
  from ranked
  order by ranked.computed_rank_position;
end;
$leaderboard$;
