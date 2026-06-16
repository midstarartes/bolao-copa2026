-- Patch 032 - Bloqueia cancelamento/devolucao de buffs apos fechamento do jogo
-- Objetivo:
-- - manter a regra de que buffs so podem ser aplicados/cancelados enquanto o jogo esta aberto;
-- - impedir devolucao de moedas quando o jogo ja fechou, foi concluido ou tem resultado oficial.

create or replace function public.app_apply_match_buff(
  p_token            uuid,
  p_match_id         text,
  p_buff_id          text,
  p_target_nickname  text default null
)
returns table (
  match_id        text,
  buff_id         text,
  target_nickname text,
  coins           integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    public.app_users;
  v_match   public.matches;
  v_cost    integer;
  v_phase   text;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  if lower(coalesce(v_match.status, '')) in ('completed', 'cancelled')
     or v_match.score_home is not null
     or v_match.score_away is not null
     or now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Mercado fechado para este jogo.';
  end if;

  v_phase := upper(coalesce(v_match.phase_label, v_match.phase, ''));

  case p_buff_id
    when 'draw-protected'    then v_cost := 1;
    when 'palpite-duplo'     then v_cost := 4;
    when 'zerar-adversario'  then v_cost := 4;
    when 'meia-adversario'   then v_cost := 3;
    when 'coin-bet'          then v_cost := 1;
    else raise exception 'Buff invalido.';
  end case;

  if p_buff_id = 'draw-protected' then
    if v_phase = 'FINAL' or v_phase like 'DISPUTA 3%' then
      raise exception 'Empate Protegido indisponivel na Final e Disputa de 3 lugar.';
    end if;

  elsif p_buff_id = 'palpite-duplo' then
    if v_phase not in ('FASE DE GRUPOS', '16 AVOS DE FINAL', 'OITAVAS DE FINAL', 'QUARTAS DE FINAL') then
      raise exception 'Palpite Duplo disponivel apenas ate as Quartas de Final.';
    end if;

  elsif p_buff_id = 'zerar-adversario' then
    if v_phase <> 'FASE DE GRUPOS' then
      raise exception 'Zerar Adversario disponivel apenas na Fase de Grupos.';
    end if;
    if (
      select count(*) from public.match_buffs mb
      where mb.user_id = v_user.id and mb.buff_id = 'zerar-adversario'
    ) >= 2 then
      raise exception 'Limite de 2 usos de Zerar Adversario por torneio atingido.';
    end if;
    if coalesce(trim(p_target_nickname), '') = '' then
      raise exception 'Selecione um adversario para zerar.';
    end if;
    if lower(trim(p_target_nickname)) = lower(v_user.nickname) then
      raise exception 'Nao e possivel zerar o proprio palpite.';
    end if;
    if not exists (
      select 1 from public.app_users
      where lower(nickname) = lower(trim(p_target_nickname))
    ) then
      raise exception 'Adversario nao encontrado.';
    end if;

  elsif p_buff_id = 'meia-adversario' then
    if v_phase not in ('16 AVOS DE FINAL', 'OITAVAS DE FINAL', 'QUARTAS DE FINAL') then
      raise exception 'Meia Adversario disponivel apenas no Mata-Mata Inicial (16avos a Quartas).';
    end if;
    if (
      select count(*) from public.match_buffs mb
      where mb.user_id = v_user.id and mb.buff_id = 'meia-adversario'
    ) >= 2 then
      raise exception 'Limite de 2 usos de Meia Adversario por torneio atingido.';
    end if;
    if coalesce(trim(p_target_nickname), '') = '' then
      raise exception 'Selecione um adversario.';
    end if;
    if lower(trim(p_target_nickname)) = lower(v_user.nickname) then
      raise exception 'Nao e possivel usar contra si mesmo.';
    end if;
    if not exists (
      select 1 from public.app_users
      where lower(nickname) = lower(trim(p_target_nickname))
    ) then
      raise exception 'Adversario nao encontrado.';
    end if;

  elsif p_buff_id = 'coin-bet' then
    if exists (
      select 1 from public.match_buffs mb
      where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'coin-bet'
    ) then
      raise exception 'Aposta ja registrada neste jogo.';
    end if;
  end if;

  if p_buff_id <> 'coin-bet' then
    if exists (
      select 1 from public.match_buffs mb
      where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = p_buff_id
    ) then
      raise exception 'Buff ja ativo neste jogo.';
    end if;
  end if;

  if v_user.coins < v_cost then
    raise exception 'Moedas insuficientes.';
  end if;

  update public.app_users
  set coins = app_users.coins - v_cost
  where id = v_user.id
  returning * into v_user;

  if p_buff_id = 'coin-bet' then
    insert into public.match_buffs (user_id, match_id, buff_id, target_nickname, settled)
    values (v_user.id, p_match_id, 'coin-bet', '1', false);
    return query select p_match_id, 'coin-bet'::text, '1'::text, v_user.coins;
  else
    insert into public.match_buffs (user_id, match_id, buff_id, target_nickname)
    values (v_user.id, p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''));
    return query select p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''), v_user.coins;
  end if;
end;
$$;

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

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  if lower(coalesce(v_match.status, '')) in ('completed', 'cancelled')
     or v_match.score_home is not null
     or v_match.score_away is not null
     or now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Jogo fechado. Nao e possivel cancelar buff deste jogo.';
  end if;

  if p_buff_id = 'coin-bet' then
    select * into v_bet_row
    from public.match_buffs mb
    where mb.user_id  = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = 'coin-bet';

    if v_bet_row.id is null then
      raise exception 'Aposta nao encontrada neste jogo.';
    end if;

    v_cost := v_bet_row.target_nickname::integer;

    delete from public.match_buffs mb
    where mb.user_id  = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = 'coin-bet';

    update public.app_users
    set coins = app_users.coins + v_cost
    where id = v_user.id
    returning * into v_user;

    return query select p_match_id, 'coin-bet'::text, v_user.coins;
    return;
  end if;

  case p_buff_id
    when 'draw-protected'   then v_cost := 1;
    when 'palpite-duplo'    then v_cost := 4;
    when 'zerar-adversario' then v_cost := 4;
    when 'meia-adversario'  then v_cost := 3;
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

  update public.app_users
  set coins = app_users.coins + v_cost
  where id = v_user.id
  returning * into v_user;

  return query select p_match_id, p_buff_id, v_user.coins;
end;
$$;
