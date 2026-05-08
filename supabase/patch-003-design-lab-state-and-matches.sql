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
    raise exception 'Sessão inválida.';
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

insert into app_settings (key, value)
values (
  'system',
  jsonb_build_object(
    'bonus_lock_at', '2026-06-11T17:30:00Z',
    'banner', 'Base visual do design-lab carregada.'
  )
)
on conflict (key)
do update set
  value = coalesce(app_settings.value, '{}'::jsonb) || excluded.value,
  updated_at = now();

insert into matches (
  id,
  match_number,
  phase,
  phase_label,
  group_name,
  home_team,
  away_team,
  home_code,
  away_code,
  starts_at,
  stadium,
  location,
  status
)
values
  ('jogo-1', 1, 'group', 'FASE DE GRUPOS', 'GRUPO A', 'México', 'África do Sul', 'MEX', 'RSA', '2026-06-11T18:00:00Z', 'Mock Arena 1', 'Cidade do México', 'scheduled'),
  ('jogo-2', 2, 'group', 'FASE DE GRUPOS', 'GRUPO B', 'Brasil', 'Japão', 'BRA', 'JPN', '2026-06-11T22:00:00Z', 'Mock Arena 2', 'Brasília', 'scheduled'),
  ('jogo-3', 3, 'group', 'FASE DE GRUPOS', 'GRUPO C', 'Argentina', 'Uruguai', 'ARG', 'URU', '2026-06-12T19:00:00Z', 'Mock Arena 3', 'Buenos Aires', 'scheduled'),
  ('jogo-4', 4, 'group', 'FASE DE GRUPOS', 'GRUPO D', 'França', 'Noruega', 'FRA', 'NOR', '2026-06-12T21:30:00Z', 'Mock Arena 4', 'Paris', 'scheduled'),
  ('jogo-5', 5, 'group', 'FASE DE GRUPOS', 'GRUPO E', 'Alemanha', 'Equador', 'GER', 'EQU', '2026-06-13T16:00:00Z', 'Mock Arena 5', 'Berlim', 'scheduled'),
  ('jogo-6', 6, 'group', 'FASE DE GRUPOS', 'GRUPO F', 'Portugal', 'Colômbia', 'POR', 'COL', '2026-06-13T19:00:00Z', 'Mock Arena 6', 'Lisboa', 'scheduled')
on conflict (id)
do update set
  match_number = excluded.match_number,
  phase = excluded.phase,
  phase_label = excluded.phase_label,
  group_name = excluded.group_name,
  home_team = excluded.home_team,
  away_team = excluded.away_team,
  home_code = excluded.home_code,
  away_code = excluded.away_code,
  starts_at = excluded.starts_at,
  stadium = excluded.stadium,
  location = excluded.location,
  status = excluded.status,
  updated_at = now();
