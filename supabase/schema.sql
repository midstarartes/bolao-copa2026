create extension if not exists pgcrypto;

create table if not exists app_users (
  id uuid primary key default gen_random_uuid(),
  nickname text not null unique check (char_length(nickname) between 3 and 20),
  real_name text not null check (char_length(real_name) between 3 and 60),
  password_hash text not null,
  avatar_type text not null default 'preset' check (avatar_type in ('preset', 'upload')),
  avatar_value text,
  is_admin boolean not null default false,
  is_blocked boolean not null default false,
  coins integer not null default 0,
  mission_claims jsonb not null default '{}'::jsonb,
  has_seen_welcome boolean not null default false,
  previous_rank integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists app_sessions (
  token uuid primary key default gen_random_uuid(),
  user_id uuid not null references app_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days'
);

create table if not exists app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists matches (
  id text primary key,
  match_number integer not null,
  phase text not null,
  phase_label text not null,
  group_name text,
  home_team text not null,
  away_team text not null,
  home_code text,
  away_code text,
  starts_at timestamptz not null,
  stadium text,
  location text,
  status text not null default 'scheduled',
  score_home integer,
  score_away integer,
  extra_time_home integer,
  extra_time_away integer,
  winner_team text,
  provider_id text,
  provider_payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists predictions (
  id bigint generated always as identity primary key,
  user_id uuid not null references app_users(id) on delete cascade,
  match_id text not null references matches(id) on delete cascade,
  home_score integer not null,
  away_score integer not null,
  extra_time_home integer,
  extra_time_away integer,
  winner_team text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, match_id)
);

create table if not exists match_buffs (
  id bigint generated always as identity primary key,
  user_id uuid not null references app_users(id) on delete cascade,
  match_id text not null references matches(id) on delete cascade,
  buff_id text not null,
  target_nickname text,
  created_at timestamptz not null default now(),
  unique (user_id, match_id, buff_id)
);

create table if not exists bonus_predictions (
  user_id uuid primary key references app_users(id) on delete cascade,
  champion text,
  runner_up text,
  third_place text,
  fourth_place text,
  top_scorer text,
  best_group_stage_team text,
  tournament_zebra text,
  total_goals integer,
  updated_at timestamptz not null default now()
);

create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app_users(id) on delete cascade,
  message text not null check (char_length(message) between 1 and 240),
  created_at timestamptz not null default now()
);

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_app_users_updated_at on app_users;
create trigger trg_app_users_updated_at before update on app_users for each row execute procedure set_updated_at();

drop trigger if exists trg_matches_updated_at on matches;
create trigger trg_matches_updated_at before update on matches for each row execute procedure set_updated_at();

drop trigger if exists trg_predictions_updated_at on predictions;
create trigger trg_predictions_updated_at before update on predictions for each row execute procedure set_updated_at();

create or replace function public.app_hash_password(raw_password text)
returns text
language sql
immutable
as $$
  select extensions.crypt(raw_password, extensions.gen_salt('bf'));
$$;

create or replace function public.app_get_user_by_token(session_token uuid)
returns app_users
language sql
security definer
set search_path = public
as $$
  select u.*
  from app_users u
  join app_sessions s on s.user_id = u.id
  where s.token = session_token and s.expires_at > now()
  limit 1;
$$;

create or replace function public.app_register_user(
  p_nickname text,
  p_real_name text,
  p_password text,
  p_avatar_type text default 'preset',
  p_avatar_value text default null
)
returns table (
  token uuid,
  user_id uuid,
  nickname text,
  real_name text,
  avatar_type text,
  avatar_value text,
  coins integer,
  mission_claims jsonb,
  has_seen_welcome boolean,
  is_admin boolean,
  is_blocked boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_session app_sessions;
begin
  if exists (select 1 from app_users where lower(app_users.nickname) = lower(p_nickname)) then
    raise exception 'Apelido já utilizado.';
  end if;

  insert into app_users (nickname, real_name, password_hash, avatar_type, avatar_value)
  values (trim(p_nickname), trim(p_real_name), app_hash_password(p_password), p_avatar_type, p_avatar_value)
  returning * into v_user;

  insert into app_sessions (user_id) values (v_user.id) returning * into v_session;

  return query
  select v_session.token, v_user.id, v_user.nickname, v_user.real_name, v_user.avatar_type, v_user.avatar_value, v_user.coins, v_user.mission_claims, v_user.has_seen_welcome, v_user.is_admin, v_user.is_blocked;
end;
$$;

create or replace function public.app_login_user(p_nickname text, p_password text)
returns table (
  token uuid,
  user_id uuid,
  nickname text,
  real_name text,
  avatar_type text,
  avatar_value text,
  coins integer,
  mission_claims jsonb,
  has_seen_welcome boolean,
  is_admin boolean,
  is_blocked boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_session app_sessions;
begin
  select *
  into v_user
  from app_users
  where lower(app_users.nickname) = lower(trim(p_nickname))
    and password_hash = extensions.crypt(p_password, password_hash)
  limit 1;

  if v_user.id is null then
    raise exception 'Apelido ou senha inválidos.';
  end if;

  if v_user.is_blocked then
    raise exception 'Usuário bloqueado.';
  end if;

  insert into app_sessions (user_id) values (v_user.id) returning * into v_session;

  return query
  select v_session.token, v_user.id, v_user.nickname, v_user.real_name, v_user.avatar_type, v_user.avatar_value, v_user.coins, v_user.mission_claims, v_user.has_seen_welcome, v_user.is_admin, v_user.is_blocked;
end;
$$;

create or replace function public.app_logout_user(p_token uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from app_sessions where token = p_token;
$$;

create or replace function public.app_save_prediction(
  p_token uuid,
  p_match_id text,
  p_home_score integer,
  p_away_score integer,
  p_extra_time_home integer default null,
  p_extra_time_away integer default null,
  p_winner_team text default null
)
returns predictions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_match matches;
  v_prediction predictions;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
  end if;

  select * into v_match from matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo não encontrado.';
  end if;

  if now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Palpite fechado para este jogo.';
  end if;

  insert into predictions (user_id, match_id, home_score, away_score, extra_time_home, extra_time_away, winner_team)
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
$$;

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
returns bonus_predictions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_lock_at timestamptz;
  v_bonus bonus_predictions;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
  end if;

  select (value->>'bonus_lock_at')::timestamptz into v_lock_at from app_settings where key = 'system';
  if v_lock_at is not null and now() >= v_lock_at then
    raise exception 'Palpites extras já foram fechados.';
  end if;

  insert into bonus_predictions (
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
$$;

create or replace function public.app_get_match_buffs(p_token uuid)
returns table (
  match_id text,
  buff_id text,
  target_nickname text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  return query
  select mb.match_id, mb.buff_id, mb.target_nickname
  from match_buffs mb
  where mb.user_id = v_user.id
  order by 1, 2;
end;
$$;

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
as $$
declare
  v_user app_users;
  v_match matches;
  v_cost integer;
  v_phase text;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  select * into v_match from matches where id = p_match_id;
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
    else
      raise exception 'Buff invalido.';
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
      select 1
      from app_users
      where lower(nickname) = lower(trim(p_target_nickname))
    ) then
      raise exception 'Adversario nao encontrado.';
    end if;
  end if;

  if exists (
    select 1
    from match_buffs mb
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id = p_buff_id
  ) then
    raise exception 'Buff ja ativo neste jogo.';
  end if;

  if p_buff_id = 'points-x2' and exists (
    select 1 from match_buffs mb where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'points-x3'
  ) then
    raise exception 'Nao pode combinar x2 e x3.';
  end if;

  if p_buff_id = 'points-x3' and exists (
    select 1 from match_buffs mb where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'points-x2'
  ) then
    raise exception 'Nao pode combinar x2 e x3.';
  end if;

  if v_user.coins < v_cost then
    raise exception 'Moedas insuficientes.';
  end if;

  update app_users
  set coins = app_users.coins - v_cost
  where app_users.id = v_user.id
  returning * into v_user;

  insert into match_buffs (user_id, match_id, buff_id, target_nickname)
  values (v_user.id, p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''));

  return query
  select p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''), v_user.coins;
end;
$$;

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
as $$
declare
  v_user app_users;
  v_cost integer;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  case p_buff_id
    when 'draw-protected' then v_cost := 1;
    when 'error-shield' then v_cost := 2;
    when 'points-x2' then v_cost := 3;
    when 'points-x3' then v_cost := 4;
    when 'cancel-rival' then v_cost := 5;
    else
      raise exception 'Buff invalido.';
  end case;

  if not exists (
    select 1
    from match_buffs mb
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id = p_buff_id
  ) then
    raise exception 'Buff nao encontrado neste jogo.';
  end if;

  delete from match_buffs mb
  where mb.user_id = v_user.id
    and mb.match_id = p_match_id
    and mb.buff_id = p_buff_id;

  update app_users
  set coins = app_users.coins + v_cost
  where app_users.id = v_user.id
  returning * into v_user;

  return query
  select p_match_id, p_buff_id, v_user.coins;
end;
$$;

create or replace function public.app_send_chat_message(p_token uuid, p_message text)
returns chat_messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_message chat_messages;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
  end if;

  insert into chat_messages (user_id, message) values (v_user.id, trim(p_message)) returning * into v_message;
  return v_message;
end;
$$;

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
returns app_users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin app_users;
  v_user app_users;
begin
  select * into v_admin from app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  update app_users
  set
    nickname = coalesce(p_nickname, nickname),
    real_name = coalesce(p_real_name, real_name),
    password_hash = case when p_password is null then password_hash else app_hash_password(p_password) end,
    avatar_type = coalesce(p_avatar_type, avatar_type),
    avatar_value = coalesce(p_avatar_value, avatar_value),
    is_blocked = coalesce(p_is_blocked, is_blocked)
  where id = p_user_id
  returning * into v_user;

  return v_user;
end;
$$;

create or replace function public.app_admin_delete_user(p_token uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin app_users;
  v_user app_users;
begin
  select * into v_admin from app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  if v_admin.id = p_user_id then
    raise exception 'O admin não pode excluir a própria conta.';
  end if;

  select * into v_user from app_users where id = p_user_id;
  if v_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_user.is_admin then
    raise exception 'Nao é permitido excluir outro usuario administrador por esta função.';
  end if;

  delete from app_users where id = p_user_id;
end;
$$;

create or replace function public.app_admin_delete_message(p_token uuid, p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin app_users;
begin
  select * into v_admin from app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  delete from chat_messages where id = p_message_id;
end;
$$;

create or replace function public.app_admin_set_banner(p_token uuid, p_message text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin app_users;
  v_payload jsonb;
begin
  select * into v_admin from app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  insert into app_settings (key, value)
  values ('system', jsonb_build_object('banner', p_message))
  on conflict (key)
  do update set
    value = coalesce(app_settings.value, '{}'::jsonb) || jsonb_build_object('banner', p_message),
    updated_at = now()
  returning value into v_payload;

  return v_payload;
end;
$$;

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

alter table app_users enable row level security;
alter table matches enable row level security;
alter table predictions enable row level security;
alter table match_buffs enable row level security;
alter table bonus_predictions enable row level security;
alter table chat_messages enable row level security;
alter table app_settings enable row level security;

create policy "Public read app users" on app_users for select using (true);
create policy "Public read matches" on matches for select using (true);
create policy "Public read predictions" on predictions for select using (true);
create policy "Public read match buffs" on match_buffs for select using (true);
create policy "Public read bonus predictions" on bonus_predictions for select using (true);
create policy "Public read chat messages" on chat_messages for select using (true);
create policy "Public read settings" on app_settings for select using (true);
