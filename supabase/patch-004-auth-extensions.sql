create extension if not exists pgcrypto with schema extensions;

create or replace function public.app_hash_password(raw_password text)
returns text
language sql
immutable
as $$
  select extensions.crypt(raw_password, extensions.gen_salt('bf'));
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
