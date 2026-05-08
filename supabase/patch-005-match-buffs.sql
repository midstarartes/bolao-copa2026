create table if not exists match_buffs (
  id bigint generated always as identity primary key,
  user_id uuid not null references app_users(id) on delete cascade,
  match_id text not null references matches(id) on delete cascade,
  buff_id text not null,
  target_nickname text,
  created_at timestamptz not null default now(),
  unique (user_id, match_id, buff_id)
);

alter table match_buffs enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'match_buffs'
      and policyname = 'Public read match buffs'
  ) then
    create policy "Public read match buffs" on match_buffs for select using (true);
  end if;
end $$;

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
