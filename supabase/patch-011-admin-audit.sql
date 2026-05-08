create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_user_id uuid not null references public.app_users(id) on delete cascade,
  target_user_id uuid references public.app_users(id) on delete set null,
  action_key text not null,
  action_label text not null,
  summary text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.app_admin_log_action(
  p_admin_user_id uuid,
  p_target_user_id uuid,
  p_action_key text,
  p_action_label text,
  p_summary text default null,
  p_payload jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.admin_audit_log (
    admin_user_id,
    target_user_id,
    action_key,
    action_label,
    summary,
    payload
  )
  values (
    p_admin_user_id,
    p_target_user_id,
    p_action_key,
    p_action_label,
    p_summary,
    coalesce(p_payload, '{}'::jsonb)
  );
$$;

create or replace function public.app_admin_get_audit_log(
  p_token uuid,
  p_limit integer default 30
)
returns table (
  id bigint,
  created_at timestamptz,
  admin_user_id uuid,
  admin_nickname text,
  target_user_id uuid,
  target_nickname text,
  action_key text,
  action_label text,
  summary text,
  payload jsonb
)
language plpgsql
security definer
set search_path = public
as $audit$
declare
  v_admin public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  return query
  select
    log.id,
    log.created_at,
    log.admin_user_id,
    admin_user.nickname,
    log.target_user_id,
    target_user.nickname,
    log.action_key,
    log.action_label,
    log.summary,
    log.payload
  from public.admin_audit_log log
  join public.app_users admin_user on admin_user.id = log.admin_user_id
  left join public.app_users target_user on target_user.id = log.target_user_id
  order by log.created_at desc
  limit greatest(coalesce(p_limit, 30), 1);
end;
$audit$;

create or replace function public.app_admin_update_user(
  p_token uuid,
  p_user_id uuid,
  p_nickname text default null,
  p_real_name text default null,
  p_password text default null,
  p_avatar_type text default null,
  p_avatar_value text default null,
  p_is_blocked boolean default null
)
returns public.app_users
language plpgsql
security definer
set search_path = public
as $admin_update_user$
declare
  v_admin public.app_users;
  v_user public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  update public.app_users
  set
    nickname = coalesce(p_nickname, nickname),
    real_name = coalesce(p_real_name, real_name),
    password_hash = case when p_password is null or trim(p_password) = '' then password_hash else public.app_hash_password(p_password) end,
    avatar_type = coalesce(p_avatar_type, avatar_type),
    avatar_value = coalesce(p_avatar_value, avatar_value),
    is_blocked = coalesce(p_is_blocked, is_blocked)
  where id = p_user_id
  returning * into v_user;

  if v_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  perform public.app_admin_log_action(
    v_admin.id,
    v_user.id,
    'user_updated',
    'Conta atualizada',
    format('Conta de %s foi atualizada pelo admin.', v_user.nickname),
    jsonb_build_object(
      'nickname', v_user.nickname,
      'real_name', v_user.real_name,
      'is_blocked', v_user.is_blocked,
      'password_reset', (p_password is not null and trim(p_password) <> '')
    )
  );

  return v_user;
end;
$admin_update_user$;

create or replace function public.app_admin_set_user_coins(
  p_token uuid,
  p_user_id uuid,
  p_coins integer
)
returns public.app_users
language plpgsql
security definer
set search_path = public
as $admin_set_coins$
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

  perform public.app_admin_log_action(
    v_admin.id,
    v_user.id,
    'coins_set',
    'Saldo definido',
    format('Saldo de moedas de %s definido para %s.', v_user.nickname, v_user.coins),
    jsonb_build_object('coins', v_user.coins)
  );

  return v_user;
end;
$admin_set_coins$;

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

  perform public.app_admin_log_action(
    v_admin.id,
    v_user.id,
    'coins_adjusted',
    'Moedas ajustadas',
    format('Saldo de moedas de %s alterado em %s e ficou em %s.', v_user.nickname, p_delta, v_user.coins),
    jsonb_build_object('delta', p_delta, 'coins', v_user.coins)
  );

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

  perform public.app_admin_log_action(
    v_admin.id,
    v_target_user.id,
    'prediction_set',
    'Palpite manual',
    format('Palpite de %s foi alterado no jogo %s.', v_target_user.nickname, p_match_id),
    jsonb_build_object(
      'match_id', p_match_id,
      'home_score', p_home_score,
      'away_score', p_away_score,
      'extra_time_home', p_extra_time_home,
      'extra_time_away', p_extra_time_away,
      'winner_team', p_winner_team
    )
  );

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

  perform public.app_admin_log_action(
    v_admin.id,
    v_target_user.id,
    'bonus_prediction_set',
    'Palpites extras atualizados',
    format('Palpites extras de %s foram alterados.', v_target_user.nickname),
    jsonb_build_object(
      'champion', p_champion,
      'runner_up', p_runner_up,
      'third_place', p_third_place,
      'fourth_place', p_fourth_place,
      'top_scorer', p_top_scorer,
      'best_group_stage_team', p_best_group_stage_team,
      'tournament_zebra', p_tournament_zebra,
      'total_goals', p_total_goals
    )
  );

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

  perform public.app_admin_log_action(
    v_admin.id,
    v_target_user.id,
    'buff_set',
    'Buff aplicado manualmente',
    format('Buff %s foi aplicado a %s no jogo %s.', p_buff_id, v_target_user.nickname, p_match_id),
    jsonb_build_object(
      'match_id', p_match_id,
      'buff_id', p_buff_id,
      'target_nickname', p_target_nickname
    )
  );

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
  v_target_user public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_target_user from public.app_users where id = p_user_id;
  if v_target_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  delete from public.match_buffs
  where user_id = p_user_id
    and match_id = p_match_id
    and buff_id = p_buff_id;

  perform public.app_admin_log_action(
    v_admin.id,
    v_target_user.id,
    'buff_removed',
    'Buff removido manualmente',
    format('Buff %s foi removido de %s no jogo %s.', p_buff_id, v_target_user.nickname, p_match_id),
    jsonb_build_object(
      'match_id', p_match_id,
      'buff_id', p_buff_id
    )
  );
end;
$admin_remove_buff$;

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
returns public.matches
language plpgsql
security definer
set search_path = public
as $admin_result$
declare
  v_admin public.app_users;
  v_match public.matches;
  v_resolved_winner text;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
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

  update public.matches
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

  perform public.app_admin_log_action(
    v_admin.id,
    null,
    'official_result_set',
    'Resultado oficial publicado',
    format('Resultado oficial do jogo %s foi publicado como %s x %s.', p_match_id, p_score_home, p_score_away),
    jsonb_build_object(
      'match_id', p_match_id,
      'score_home', p_score_home,
      'score_away', p_score_away,
      'extra_time_home', p_extra_time_home,
      'extra_time_away', p_extra_time_away,
      'winner_team', v_resolved_winner,
      'status', p_status
    )
  );

  return v_match;
end;
$admin_result$;
