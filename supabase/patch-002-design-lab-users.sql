alter table app_users
add column if not exists coins integer not null default 0;

alter table app_users
add column if not exists mission_claims jsonb not null default '{}'::jsonb;

alter table app_users
add column if not exists has_seen_welcome boolean not null default false;

drop function if exists public.app_register_user(text, text, text, text, text);

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
  select
    v_session.token,
    v_user.id,
    v_user.nickname,
    v_user.real_name,
    v_user.avatar_type,
    v_user.avatar_value,
    v_user.coins,
    v_user.mission_claims,
    v_user.has_seen_welcome,
    v_user.is_admin,
    v_user.is_blocked;
end;
$$;

drop function if exists public.app_login_user(text, text);

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
    and password_hash = crypt(p_password, password_hash)
  limit 1;

  if v_user.id is null then
    raise exception 'Apelido ou senha inválidos.';
  end if;

  if v_user.is_blocked then
    raise exception 'Usuário bloqueado.';
  end if;

  insert into app_sessions (user_id) values (v_user.id) returning * into v_session;

  return query
  select
    v_session.token,
    v_user.id,
    v_user.nickname,
    v_user.real_name,
    v_user.avatar_type,
    v_user.avatar_value,
    v_user.coins,
    v_user.mission_claims,
    v_user.has_seen_welcome,
    v_user.is_admin,
    v_user.is_blocked;
end;
$$;
