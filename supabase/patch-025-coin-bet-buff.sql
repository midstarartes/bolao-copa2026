-- Patch 025: Buff "Multiplicador de Moedas" (coin-bet)
--
-- REGRA:
--   O usuário aposta moedas num jogo antes do início.
--   - Mínimo 2, máximo 5 moedas
--   - Acertar resultado (sem precisar de placar exato): recebe bet × 2
--   - Acertar placar exato:                            recebe bet × 3
--   - Errar: perde as moedas apostadas (já foram debitadas na aplicação)
--   - 1 aposta por jogo; combinável com outros buffs
--   - Não afeta pontos do ranking, só moedas
--
-- MUDANÇAS:
--   1. Adiciona coluna `settled boolean` em match_buffs (evita pagar duas vezes)
--   2. Atualiza app_apply_match_buff  — aceita coin-bet com valor variável
--   3. Atualiza app_cancel_match_buff — devolve o valor apostado
--   4. Nova função app_settle_pending_coin_bets — paga apostas de jogos encerrados

-- ─────────────────────────────────────────────────────────────────
-- 1. Coluna settled em match_buffs
-- ─────────────────────────────────────────────────────────────────
alter table public.match_buffs
  add column if not exists settled boolean not null default false;


-- ─────────────────────────────────────────────────────────────────
-- 2. app_apply_match_buff com coin-bet
-- ─────────────────────────────────────────────────────────────────
create or replace function public.app_apply_match_buff(
  p_token          uuid,
  p_match_id       text,
  p_buff_id        text,
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
  v_user   public.app_users;
  v_match  public.matches;
  v_cost   integer;
  v_phase  text;
  v_bet    integer;
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
      raise exception 'Valor de aposta inválido.';
    end;

    if v_bet < 2 or v_bet > 5 then
      raise exception 'Aposta deve ser entre 2 e 5 moedas.';
    end if;

    if v_user.coins < v_bet then
      raise exception 'Moedas insuficientes.';
    end if;

    if exists (
      select 1 from public.match_buffs mb
      where mb.user_id = v_user.id
        and mb.match_id = p_match_id
        and mb.buff_id = 'coin-bet'
    ) then
      raise exception 'Aposta já registrada neste jogo.';
    end if;

    update public.app_users
    set coins = coins - v_bet
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
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id = p_buff_id
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

  update public.app_users
  set coins = coins - v_cost
  where id = v_user.id
  returning * into v_user;

  insert into public.match_buffs (user_id, match_id, buff_id, target_nickname)
  values (v_user.id, p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''));

  return query
  select p_match_id, p_buff_id, nullif(trim(p_target_nickname), ''), v_user.coins;
end;
$$;


-- ─────────────────────────────────────────────────────────────────
-- 3. app_cancel_match_buff com coin-bet
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
  v_user   public.app_users;
  v_match  public.matches;
  v_cost   integer;
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
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = 'coin-bet';

    if v_bet_row.id is null then
      raise exception 'Aposta nao encontrada neste jogo.';
    end if;

    -- Não permite cancelar aposta de jogo já iniciado
    select * into v_match from public.matches where id = p_match_id;
    if now() >= (v_match.starts_at - interval '30 minutes') then
      raise exception 'Jogo ja iniciado. Nao e possivel cancelar a aposta.';
    end if;

    v_cost := v_bet_row.target_nickname::integer;

    delete from public.match_buffs
    where user_id = v_user.id
      and match_id = p_match_id
      and buff_id  = 'coin-bet';

    update public.app_users
    set coins = coins + v_cost
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
    where mb.user_id = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = p_buff_id
  ) then
    raise exception 'Buff nao encontrado neste jogo.';
  end if;

  delete from public.match_buffs mb
  where mb.user_id = v_user.id
    and mb.match_id = p_match_id
    and mb.buff_id  = p_buff_id;

  update public.app_users
  set coins = coins + v_cost
  where id = v_user.id
  returning * into v_user;

  return query select p_match_id, p_buff_id, v_user.coins;
end;
$$;


-- ─────────────────────────────────────────────────────────────────
-- 4. app_settle_pending_coin_bets
--    Chamada pelo frontend ao carregar o app ou após update de resultados.
--    Encontra todas as apostas do usuário em jogos já encerrados
--    que ainda não foram liquidadas, paga o prêmio e marca como settled.
-- ─────────────────────────────────────────────────────────────────
create or replace function public.app_settle_pending_coin_bets(p_token uuid)
returns table (
  match_id       text,
  bet_amount     integer,
  coins_awarded  integer,
  outcome        text   -- 'exact', 'result', 'loss'
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    public.app_users;
  v_bet     public.match_buffs;
  v_match   public.matches;
  v_pred    public.predictions;
  v_exact   boolean;
  v_result  boolean;
  v_bet_amt integer;
  v_award   integer;
  v_outcome text;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  for v_bet in
    select mb.*
    from public.match_buffs mb
    join public.matches m on m.id = mb.match_id
    where mb.user_id  = v_user.id
      and mb.buff_id  = 'coin-bet'
      and mb.settled  = false
      and m.status    = 'completed'
      and m.score_home is not null
      and m.score_away is not null
    order by mb.created_at
  loop
    select * into v_match from public.matches where id = v_bet.match_id;
    select * into v_pred  from public.predictions
    where user_id = v_user.id and match_id = v_bet.match_id
    limit 1;

    v_bet_amt := v_bet.target_nickname::integer;
    v_exact   := false;
    v_result  := false;

    if v_pred.user_id is not null then
      -- Verifica placar exato
      v_exact := (v_pred.home_score = v_match.score_home
               and v_pred.away_score = v_match.score_away);

      -- Verifica acerto de resultado (vencedor / empate)
      if not v_exact then
        select score_ctx.result_hit
        into v_result
        from public.app_prediction_result_hit(
          v_match.phase_label,
          v_match.phase,
          v_match.score_home,
          v_match.score_away,
          v_match.winner_team,
          v_pred.home_score,
          v_pred.away_score,
          v_pred.winner_team
        ) score_ctx;
      end if;
    end if;

    if v_exact then
      v_award   := v_bet_amt * 3;
      v_outcome := 'exact';
    elsif v_result then
      v_award   := v_bet_amt * 2;
      v_outcome := 'result';
    else
      v_award   := 0;
      v_outcome := 'loss';
    end if;

    if v_award > 0 then
      update public.app_users
      set coins = coins + v_award
      where id = v_user.id
      returning * into v_user;
    end if;

    update public.match_buffs
    set settled = true
    where id = v_bet.id;

    match_id      := v_bet.match_id;
    bet_amount    := v_bet_amt;
    coins_awarded := v_award;
    outcome       := v_outcome;
    return next;
  end loop;
end;
$$;
