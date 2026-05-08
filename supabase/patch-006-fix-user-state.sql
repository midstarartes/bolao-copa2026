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
as $$
declare
  v_user app_users;
begin
  select * into v_user from app_get_user_by_token(p_token);

  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  update app_users
  set
    coins = coalesce(p_coins, app_users.coins),
    mission_claims = coalesce(p_mission_claims, app_users.mission_claims),
    has_seen_welcome = coalesce(p_has_seen_welcome, app_users.has_seen_welcome)
  where app_users.id = v_user.id
  returning *
  into v_user;

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
$$;
