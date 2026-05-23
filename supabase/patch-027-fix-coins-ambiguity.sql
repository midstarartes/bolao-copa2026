-- Patch 027: Corrige "column reference 'coins' is ambiguous" em app_apply_match_buff
--            e app_cancel_match_buff
--
-- PROBLEMA (idêntico ao corrigido no patch-023 para app_update_current_user_profile):
--   Ambas as funções têm `coins integer` na sua cláusula RETURNS TABLE.
--   No PL/pgSQL, os nomes das colunas de retorno funcionam como variáveis OUT.
--   Por isso, no UPDATE `SET coins = coins - v_cost`, o PostgreSQL não sabe
--   se o `coins` do lado direito é a coluna da tabela app_users ou a variável OUT.
--   Resultado: "column reference 'coins' is ambiguous"
--
-- CORREÇÃO: Qualificar explicitamente com `app_users.coins` no lado direito
--   do SET — mesma técnica usada no patch-023 com `v_user.nickname`.


-- ─────────────────────────────────────────────────────────────────
-- 1. app_apply_match_buff  (reescrita completa com fix)
-- ─────────────────────────────────────────────────────────────────
create or replace function public.app_apply_match_buff(
  p_token           uuid,
  p_match_id        text,
  p_buff_id         text,
  p_target_nickname text default null
)
returns table (
  match_id         text,
  buff_id          text,
  target_nickname  text,
  coins            integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user  public.app_users;
  v_match public.matches;
  v_cost  integer;
  v_phase text;
  v_bet   integer;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  if now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Mercado fechado para este jogo.';
  end if;

  v_phase := upper(coalesce(v_match.phase_label, v_match.phase, ''));

  -- ── coin-bet: custo variável (2-5) armazenado em target_nickname ──
  if p_buff_id = 'coin-bet' then
    begin
      v_bet := p_target_nickname::integer;
    exception when others then
      raise exception 'Valor de aposta invalido.';
    end;

    if v_bet < 2 or v_bet > 5 then
      raise exception 'Aposta deve ser entre 2 e 5 moedas.';
    end if;

    if v_user.coins < v_bet then
      raise exception 'Moedas insuficientes.';
    end if;

    if exists (
      select 1 from public.match_buffs mb
      where mb.user_id  = v_user.id
        and mb.match_id = p_match_id
        and mb.buff_id  = 'coin-bet'
    ) then
      raise exception 'Aposta ja registrada neste jogo.';
    end if;

    -- FIX: app_users.coins evita ambiguidade com a coluna de retorno "coins"
    update public.app_users
    set coins = app_users.coins - v_bet
    where id = v_user.id
    returning * into v_user;

    insert into public.match_buffs (user_id, match_id, buff_id, target_nickname, settled)
    values (v_user.id, p_match_id, 'coin-bet', v_bet::text, false);

    return query select p_match_id, 'coin-bet'::text, v_bet::text, v_user.coins;
    return;
  end if;

  -- ── Buffs tradicionais ────────────────────────────────────────────
  case p_buff_id
    when 'draw-protected' then v_cost := 1;
    when 'error-shield'   then v_cost := 2;
    when 'points-x2'      then v_cost := 3;
    when 'points-x3'      then v_cost := 4;
    when 'cancel-rival'   then v_cost := 5;
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
      select 1 from public.app_users
      where lower(nickname) = lower(trim(p_target_nickname))
    ) then
      raise exception 'Adversario nao encontrado.';
    end if;
  end if;

  if exists (
    select 1 from public.match_buffs mb
    where mb.user_id  = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = p_buff_id
  ) then
    raise exception 'Buff ja ativo neste jogo.';
  end if;

  if p_buff_id = 'points-x2' and exists (
    select 1 from public.match_buffs mb
    where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'points-x3'
  ) then
    raise exception 'Nao pode combinar x2 e x3.';
  end if;

  if p_buff_id = 'points-x3' and exists (
    select 1 from public.match_buffs mb
    where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'points-x2'
  ) then
    raise exception 'Nao pode combinar x2 e x3.';
  end if;

  if v_user.coins < v_cost then
    raise exception 'Moedas insuficientes.';
  end if;

  -- FIX: app_users.coins evita ambiguidade com a coluna de retorno "coins"
  update public.app_users
  set coins = app_users.coins - v_cost
  where id = v_user.id
  returning * into v_user;

  insert into public.match_buffs (user_id, match_id, buff_id, target_nickname)
  values (v_user.id, p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''));

  return query
  select p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''), v_user.coins;
end;
$$;


-- ─────────────────────────────────────────────────────────────────
-- 2. app_cancel_match_buff  (reescrita completa com fix)
-- ─────────────────────────────────────────────────────────────────
create or replace function public.app_cancel_match_buff(
  p_token    uuid,
  p_match_id text,
  p_buff_id  text
)
returns table (
  match_id text,
  buff_id  text,
  coins    integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    public.app_users;
  v_match   public.matches;
  v_cost    integer;
  v_bet_row public.match_buffs;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  -- ── coin-bet: devolve valor armazenado em target_nickname ─────────
  if p_buff_id = 'coin-bet' then
    select * into v_bet_row
    from public.match_buffs mb
    where mb.user_id  = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = 'coin-bet';

    if v_bet_row.id is null then
      raise exception 'Aposta nao encontrada neste jogo.';
    end if;

    select * into v_match from public.matches where id = p_match_id;
    if now() >= (v_match.starts_at - interval '30 minutes') then
      raise exception 'Jogo ja iniciado. Nao e possivel cancelar a aposta.';
    end if;

    v_cost := v_bet_row.target_nickname::integer;

    delete from public.match_buffs
    where user_id  = v_user.id
      and match_id = p_match_id
      and buff_id  = 'coin-bet';

    -- FIX: app_users.coins evita ambiguidade com a coluna de retorno "coins"
    update public.app_users
    set coins = app_users.coins + v_cost
    where id = v_user.id
    returning * into v_user;

    return query select p_match_id, 'coin-bet'::text, v_user.coins;
    return;
  end if;

  -- ── Buffs tradicionais ────────────────────────────────────────────
  case p_buff_id
    when 'draw-protected' then v_cost := 1;
    when 'error-shield'   then v_cost := 2;
    when 'points-x2'      then v_cost := 3;
    when 'points-x3'      then v_cost := 4;
    when 'cancel-rival'   then v_cost := 5;
    else raise exception 'Buff invalido.';
  end case;

  if not exists (
    select 1 from public.match_buffs mb
    where mb.user_id  = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = p_buff_id
  ) then
    raise exception 'Buff nao encontrado neste jogo.';
  end if;

  delete from public.match_buffs mb
  where mb.user_id  = v_user.id
    and mb.match_id = p_match_id
    and mb.buff_id  = p_buff_id;

  -- FIX: app_users.coins evita ambiguidade com a coluna de retorno "coins"
  update public.app_users
  set coins = app_users.coins + v_cost
  where id = v_user.id
  returning * into v_user;

  return query select p_match_id, p_buff_id, v_user.coins;
end;
$$;
