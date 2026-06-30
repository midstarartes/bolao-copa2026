-- Patch 037: debita/devolve moedas em buffs aplicados manualmente pelo ADMIN
-- Objetivo:
-- - app_admin_set_user_buff passa a debitar o custo quando cria um buff novo.
-- - app_admin_remove_user_buff passa a devolver o custo quando remove um buff existente.
-- - Atualizar um buff ja existente nao debita novamente.

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
  v_existing public.match_buffs;
  v_cost integer := 0;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_target_user from public.app_users where id = p_user_id;
  if v_target_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  v_cost := case p_buff_id
    when 'draw-protected' then 1
    when 'coin-bet' then 1
    when 'palpite-duplo' then 4
    when 'zerar-adversario' then 4
    when 'meia-adversario' then 3
    else 0
  end;

  select * into v_existing
  from public.match_buffs
  where user_id = p_user_id
    and match_id = p_match_id
    and buff_id = p_buff_id;

  if v_existing.id is null and v_cost > 0 then
    update public.app_users
    set coins = greatest(public.app_users.coins - v_cost, 0)
    where id = p_user_id
    returning * into v_target_user;
  end if;

  insert into public.match_buffs (user_id, match_id, buff_id, target_nickname)
  values (
    p_user_id,
    p_match_id,
    p_buff_id,
    case
      when p_buff_id = 'coin-bet' then coalesce(nullif(trim(p_target_nickname), ''), '1')
      else nullif(trim(p_target_nickname), '')
    end
  )
  on conflict (user_id, match_id, buff_id)
  do update set
    target_nickname = excluded.target_nickname,
    created_at = public.match_buffs.created_at
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
      'target_nickname', p_target_nickname,
      'coin_cost', case when v_existing.id is null then v_cost else 0 end,
      'coins_after', v_target_user.coins
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
  v_existing public.match_buffs;
  v_cost integer := 0;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  select * into v_target_user from public.app_users where id = p_user_id;
  if v_target_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  select * into v_existing
  from public.match_buffs
  where user_id = p_user_id
    and match_id = p_match_id
    and buff_id = p_buff_id;

  v_cost := case p_buff_id
    when 'draw-protected' then 1
    when 'coin-bet' then coalesce(nullif(v_existing.target_nickname, '')::integer, 1)
    when 'palpite-duplo' then 4
    when 'zerar-adversario' then 4
    when 'meia-adversario' then 3
    else 0
  end;

  delete from public.match_buffs
  where user_id = p_user_id
    and match_id = p_match_id
    and buff_id = p_buff_id;

  if v_existing.id is not null and v_cost > 0 then
    update public.app_users
    set coins = public.app_users.coins + v_cost
    where id = p_user_id
    returning * into v_target_user;
  end if;

  perform public.app_admin_log_action(
    v_admin.id,
    v_target_user.id,
    'buff_removed',
    'Buff removido manualmente',
    format('Buff %s foi removido de %s no jogo %s.', p_buff_id, v_target_user.nickname, p_match_id),
    jsonb_build_object(
      'match_id', p_match_id,
      'buff_id', p_buff_id,
      'coin_refund', case when v_existing.id is not null then v_cost else 0 end,
      'coins_after', v_target_user.coins
    )
  );
end;
$admin_remove_buff$;
