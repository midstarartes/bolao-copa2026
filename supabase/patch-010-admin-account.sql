do $admin_setup$
declare
  v_admin_id uuid;
begin
  select id
  into v_admin_id
  from public.app_users
  where lower(nickname) = 'admin'
  limit 1;

  if v_admin_id is null then
    insert into public.app_users (
      nickname,
      real_name,
      password_hash,
      avatar_type,
      avatar_value,
      is_admin,
      is_blocked,
      coins,
      mission_claims,
      has_seen_welcome,
      previous_rank
    )
    values (
      'ADMIN',
      'Administrador',
      public.app_hash_password('SENHA_REDEFINIDA_VIA_PAINEL'),
      'preset',
      null,
      true,
      false,
      0,
      '{}'::jsonb,
      true,
      null
    )
    returning id into v_admin_id;
  else
    update public.app_users
    set
      nickname = 'ADMIN',
      real_name = 'Administrador',
      password_hash = public.app_hash_password('SENHA_REDEFINIDA_VIA_PAINEL'),
      is_admin = true,
      is_blocked = false,
      coins = 0,
      mission_claims = '{}'::jsonb,
      has_seen_welcome = true,
      previous_rank = null
    where id = v_admin_id;
  end if;

  delete from public.predictions where user_id = v_admin_id;
  delete from public.bonus_predictions where user_id = v_admin_id;
  delete from public.match_buffs where user_id = v_admin_id;
end;
$admin_setup$;

create or replace function public.app_update_current_user_state(
  p_token uuid,
  p_coins integer default null,
  p_mission_claims jsonb default null,
  p_has_seen_welcome boolean default null
)
returns table (
  user_id uuid,
  nickname text,
  real_name text,
  avatar_type text,
  avatar_value text,
  coins integer,
  mission_claims jsonb,
  has_seen_welcome boolean,
  is_admin boolean,
  is_blocked boolean,
  previous_rank integer
)
language plpgsql
security definer
set search_path = public
as $state$
declare
  v_user public.app_users;
begin
  select * into v_user from public.app_get_user_by_token(p_token);

  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if v_user.is_admin then
    update public.app_users
    set
      coins = 0,
      mission_claims = '{}'::jsonb,
      has_seen_welcome = coalesce(p_has_seen_welcome, public.app_users.has_seen_welcome)
    where public.app_users.id = v_user.id
    returning * into v_user;
  else
    update public.app_users
    set
      coins = coalesce(greatest(p_coins, 0), public.app_users.coins),
      mission_claims = coalesce(p_mission_claims, public.app_users.mission_claims),
      has_seen_welcome = coalesce(p_has_seen_welcome, public.app_users.has_seen_welcome)
    where public.app_users.id = v_user.id
    returning * into v_user;
  end if;

  return query
  select
    v_user.id,
    v_user.nickname,
    v_user.real_name,
    v_user.avatar_type,
    v_user.avatar_value,
    v_user.coins,
    v_user.mission_claims,
    v_user.has_seen_welcome,
    v_user.is_admin,
    v_user.is_blocked,
    v_user.previous_rank;
end;
$state$;

create or replace function public.app_save_prediction(
  p_token uuid,
  p_match_id text,
  p_home_score integer,
  p_away_score integer,
  p_extra_time_home integer default null,
  p_extra_time_away integer default null,
  p_winner_team text default null
)
returns public.predictions
language plpgsql
security definer
set search_path = public
as $save_prediction$
declare
  v_user public.app_users;
  v_match public.matches;
  v_prediction public.predictions;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if v_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  if now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Palpite fechado para este jogo.';
  end if;

  insert into public.predictions (user_id, match_id, home_score, away_score, extra_time_home, extra_time_away, winner_team)
  values (v_user.id, p_match_id, p_home_score, p_away_score, p_extra_time_home, p_extra_time_away, p_winner_team)
  on conflict (user_id, match_id)
  do update set
    home_score = excluded.home_score,
    away_score = excluded.away_score,
    extra_time_home = excluded.extra_time_home,
    extra_time_away = excluded.extra_time_away,
    winner_team = excluded.winner_team,
    updated_at = now()
  returning * into v_prediction;

  return v_prediction;
end;
$save_prediction$;

create or replace function public.app_save_bonus_prediction(
  p_token uuid,
  p_champion text,
  p_runner_up text,
  p_third_place text,
  p_fourth_place text,
  p_top_scorer text,
  p_best_group_stage_team text,
  p_tournament_zebra text,
  p_total_goals integer
)
returns public.bonus_predictions
language plpgsql
security definer
set search_path = public
as $save_bonus$
declare
  v_user public.app_users;
  v_lock_at timestamptz;
  v_bonus public.bonus_predictions;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if v_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  select (value->>'bonus_lock_at')::timestamptz into v_lock_at from public.app_settings where key = 'system';
  if v_lock_at is not null and now() >= v_lock_at then
    raise exception 'Palpites extras ja foram fechados.';
  end if;

  insert into public.bonus_predictions (
    user_id, champion, runner_up, third_place, fourth_place, top_scorer, best_group_stage_team, tournament_zebra, total_goals
  )
  values (
    v_user.id, p_champion, p_runner_up, p_third_place, p_fourth_place, p_top_scorer, p_best_group_stage_team, p_tournament_zebra, p_total_goals
  )
  on conflict (user_id)
  do update set
    champion = excluded.champion,
    runner_up = excluded.runner_up,
    third_place = excluded.third_place,
    fourth_place = excluded.fourth_place,
    top_scorer = excluded.top_scorer,
    best_group_stage_team = excluded.best_group_stage_team,
    tournament_zebra = excluded.tournament_zebra,
    total_goals = excluded.total_goals,
    updated_at = now()
  returning * into v_bonus;

  return v_bonus;
end;
$save_bonus$;

create or replace function public.app_apply_match_buff(
  p_token uuid,
  p_match_id text,
  p_buff_id text,
  p_target_nickname text default null
)
returns table (
  match_id text,
  buff_id text,
  target_nickname text,
  coins integer
)
language plpgsql
security definer
set search_path = public
as $apply_buff$
declare
  v_user public.app_users;
  v_match public.matches;
  v_cost integer;
  v_phase text;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if v_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  if now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Mercado fechado para este jogo.';
  end if;

  v_phase := upper(coalesce(v_match.phase_label, v_match.phase, ''));

  case p_buff_id
    when 'draw-protected' then v_cost := 1;
    when 'error-shield' then v_cost := 2;
    when 'points-x2' then v_cost := 3;
    when 'points-x3' then v_cost := 4;
    when 'cancel-rival' then v_cost := 5;
    else raise exception 'Buff invalido.';
  end case;

  if p_buff_id = 'draw-protected' then
    if v_phase = 'FINAL' or v_phase like 'DISPUTA 3%' then
      raise exception 'Buff indisponivel nesta fase.';
    end if;
  elsif v_phase not in ('FASE DE GRUPOS', '16 AVOS DE FINAL', 'OITAVAS DE FINAL', 'QUARTAS DE FINAL') then
    raise exception 'Buff indisponivel nesta fase.';
  end if;

  if p_buff_id = 'cancel-rival' then
    if coalesce(trim(p_target_nickname), '') = '' then
      raise exception 'Selecione um adversario.';
    end if;

    if lower(trim(p_target_nickname)) = lower(v_user.nickname) then
      raise exception 'Nao e possivel anular o proprio palpite.';
    end if;

    if not exists (
      select 1 from public.app_users where lower(nickname) = lower(trim(p_target_nickname))
    ) then
      raise exception 'Adversario nao encontrado.';
    end if;
  end if;

  if exists (
    select 1 from public.match_buffs mb
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id = p_buff_id
  ) then
    raise exception 'Buff ja ativo neste jogo.';
  end if;

  if p_buff_id = 'points-x2' and exists (
    select 1 from public.match_buffs mb where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'points-x3'
  ) then
    raise exception 'Nao pode combinar x2 e x3.';
  end if;

  if p_buff_id = 'points-x3' and exists (
    select 1 from public.match_buffs mb where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'points-x2'
  ) then
    raise exception 'Nao pode combinar x2 e x3.';
  end if;

  if v_user.coins < v_cost then
    raise exception 'Moedas insuficientes.';
  end if;

  update public.app_users
  set coins = public.app_users.coins - v_cost
  where public.app_users.id = v_user.id
  returning * into v_user;

  insert into public.match_buffs (user_id, match_id, buff_id, target_nickname)
  values (v_user.id, p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''));

  return query
  select p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''), v_user.coins;
end;
$apply_buff$;

create or replace function public.app_cancel_match_buff(
  p_token uuid,
  p_match_id text,
  p_buff_id text
)
returns table (
  match_id text,
  buff_id text,
  coins integer
)
language plpgsql
security definer
set search_path = public
as $cancel_buff$
declare
  v_user public.app_users;
  v_cost integer;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if v_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  case p_buff_id
    when 'draw-protected' then v_cost := 1;
    when 'error-shield' then v_cost := 2;
    when 'points-x2' then v_cost := 3;
    when 'points-x3' then v_cost := 4;
    when 'cancel-rival' then v_cost := 5;
    else raise exception 'Buff invalido.';
  end case;

  if not exists (
    select 1
    from public.match_buffs mb
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id = p_buff_id
  ) then
    raise exception 'Buff nao encontrado neste jogo.';
  end if;

  delete from public.match_buffs mb
  where mb.user_id = v_user.id
    and mb.match_id = p_match_id
    and mb.buff_id = p_buff_id;

  update public.app_users
  set coins = public.app_users.coins + v_cost
  where public.app_users.id = v_user.id
  returning * into v_user;

  return query
  select p_match_id, p_buff_id, v_user.coins;
end;
$cancel_buff$;

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
    from public.app_users u
    left join public.predictions p on p.user_id = u.id
    left join public.matches m on m.id = p.match_id
    where not u.is_blocked and not u.is_admin
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
    where not u.is_blocked and not u.is_admin
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

create or replace function public.app_admin_list_users(p_token uuid)
returns table (
  user_id uuid,
  nickname text,
  real_name text,
  is_admin boolean,
  is_blocked boolean,
  coins integer,
  has_seen_welcome boolean,
  created_at timestamptz,
  updated_at timestamptz,
  predictions_count bigint,
  has_bonus_prediction boolean
)
language plpgsql
security definer
set search_path = public
as $admin_list$
declare
  v_admin public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  return query
  select
    u.id,
    u.nickname,
    u.real_name,
    u.is_admin,
    u.is_blocked,
    u.coins,
    u.has_seen_welcome,
    u.created_at,
    u.updated_at,
    coalesce(pred.stats_count, 0)::bigint,
    (bp.user_id is not null)
  from public.app_users u
  left join (
    select p.user_id, count(*) as stats_count
    from public.predictions p
    group by p.user_id
  ) pred on pred.user_id = u.id
  left join public.bonus_predictions bp on bp.user_id = u.id
  order by u.is_admin desc, u.created_at asc;
end;
$admin_list$;

create or replace function public.app_admin_set_user_coins(
  p_token uuid,
  p_user_id uuid,
  p_coins integer
)
returns public.app_users
language plpgsql
security definer
set search_path = public
as $admin_coins$
declare
  v_admin public.app_users;
  v_user public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  update public.app_users
  set coins = greatest(p_coins, 0)
  where id = p_user_id
  returning * into v_user;

  if v_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_user.is_admin then
    update public.app_users
    set coins = 0
    where id = v_user.id
    returning * into v_user;
  end if;

  return v_user;
end;
$admin_coins$;

create or replace function public.app_admin_adjust_user_coins(
  p_token uuid,
  p_user_id uuid,
  p_delta integer
)
returns public.app_users
language plpgsql
security definer
set search_path = public
as $admin_adjust_coins$
declare
  v_admin public.app_users;
  v_user public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  update public.app_users
  set coins = greatest(public.app_users.coins + p_delta, 0)
  where id = p_user_id
  returning * into v_user;

  if v_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_user.is_admin then
    update public.app_users
    set coins = 0
    where id = v_user.id
    returning * into v_user;
  end if;

  return v_user;
end;
$admin_adjust_coins$;

create or replace function public.app_admin_set_user_prediction(
  p_token uuid,
  p_user_id uuid,
  p_match_id text,
  p_home_score integer,
  p_away_score integer,
  p_extra_time_home integer default null,
  p_extra_time_away integer default null,
  p_winner_team text default null
)
returns public.predictions
language plpgsql
security definer
set search_path = public
as $admin_prediction$
declare
  v_admin public.app_users;
  v_target_user public.app_users;
  v_match public.matches;
  v_prediction public.predictions;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_target_user from public.app_users where id = p_user_id;
  if v_target_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_target_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  insert into public.predictions (user_id, match_id, home_score, away_score, extra_time_home, extra_time_away, winner_team)
  values (p_user_id, p_match_id, p_home_score, p_away_score, p_extra_time_home, p_extra_time_away, p_winner_team)
  on conflict (user_id, match_id)
  do update set
    home_score = excluded.home_score,
    away_score = excluded.away_score,
    extra_time_home = excluded.extra_time_home,
    extra_time_away = excluded.extra_time_away,
    winner_team = excluded.winner_team,
    updated_at = now()
  returning * into v_prediction;

  return v_prediction;
end;
$admin_prediction$;

create or replace function public.app_admin_set_user_bonus_prediction(
  p_token uuid,
  p_user_id uuid,
  p_champion text,
  p_runner_up text,
  p_third_place text,
  p_fourth_place text,
  p_top_scorer text,
  p_best_group_stage_team text,
  p_tournament_zebra text,
  p_total_goals integer
)
returns public.bonus_predictions
language plpgsql
security definer
set search_path = public
as $admin_bonus$
declare
  v_admin public.app_users;
  v_target_user public.app_users;
  v_bonus public.bonus_predictions;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_target_user from public.app_users where id = p_user_id;
  if v_target_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_target_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  insert into public.bonus_predictions (
    user_id, champion, runner_up, third_place, fourth_place, top_scorer, best_group_stage_team, tournament_zebra, total_goals
  )
  values (
    p_user_id, p_champion, p_runner_up, p_third_place, p_fourth_place, p_top_scorer, p_best_group_stage_team, p_tournament_zebra, p_total_goals
  )
  on conflict (user_id)
  do update set
    champion = excluded.champion,
    runner_up = excluded.runner_up,
    third_place = excluded.third_place,
    fourth_place = excluded.fourth_place,
    top_scorer = excluded.top_scorer,
    best_group_stage_team = excluded.best_group_stage_team,
    tournament_zebra = excluded.tournament_zebra,
    total_goals = excluded.total_goals,
    updated_at = now()
  returning * into v_bonus;

  return v_bonus;
end;
$admin_bonus$;

create or replace function public.app_admin_set_user_buff(
  p_token uuid,
  p_user_id uuid,
  p_match_id text,
  p_buff_id text,
  p_target_nickname text default null
)
returns public.match_buffs
language plpgsql
security definer
set search_path = public
as $admin_buff$
declare
  v_admin public.app_users;
  v_target_user public.app_users;
  v_match public.matches;
  v_buff public.match_buffs;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_target_user from public.app_users where id = p_user_id;
  if v_target_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_target_user.is_admin then
    raise exception 'Conta ADMIN nao participa do bolao.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  if p_buff_id not in ('draw-protected', 'error-shield', 'points-x2', 'points-x3', 'cancel-rival') then
    raise exception 'Buff invalido.';
  end if;

  if p_buff_id = 'points-x2' then
    delete from public.match_buffs where user_id = p_user_id and match_id = p_match_id and buff_id = 'points-x3';
  elsif p_buff_id = 'points-x3' then
    delete from public.match_buffs where user_id = p_user_id and match_id = p_match_id and buff_id = 'points-x2';
  end if;

  insert into public.match_buffs (user_id, match_id, buff_id, target_nickname)
  values (p_user_id, p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''))
  on conflict (user_id, match_id, buff_id)
  do update set
    target_nickname = excluded.target_nickname,
    created_at = now()
  returning * into v_buff;

  return v_buff;
end;
$admin_buff$;

create or replace function public.app_admin_remove_user_buff(
  p_token uuid,
  p_user_id uuid,
  p_match_id text,
  p_buff_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $admin_remove_buff$
declare
  v_admin public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  delete from public.match_buffs
  where user_id = p_user_id
    and match_id = p_match_id
    and buff_id = p_buff_id;
end;
$admin_remove_buff$;
