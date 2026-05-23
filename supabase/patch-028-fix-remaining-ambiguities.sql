-- Patch 028: Corrige ambiguidades restantes após patch-027
--
-- PROBLEMA 1 — app_cancel_match_buff (já reescrita no patch-027):
--   O DELETE do caminho coin-bet usava match_id, buff_id e user_id
--   sem qualificador de tabela.  Como a função tem RETURNS TABLE com
--   colunas match_id text e buff_id text, o PostgreSQL lança
--   "column reference 'match_id' is ambiguous".
--   FIX: adicionar alias "mb" ao DELETE e qualificar todas as colunas.
--
-- PROBLEMA 2 — app_settle_pending_coin_bets (patch-025):
--   SELECT de predictions usa `match_id` sem qualificador.
--   A função retorna RETURNS TABLE(match_id text, ...), então o
--   PostgreSQL pode confundir o OUT-var com predictions.match_id.
--   FIX: alias "pr" na tabela predictions e qualificar match_id/user_id.


-- ─────────────────────────────────────────────────────────────────
-- 1. app_cancel_match_buff — DELETE coin-bet com alias correto
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

  -- ── coin-bet ──────────────────────────────────────────────────────
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

    -- FIX: alias mb evita ambiguidade de match_id / buff_id / user_id
    --      (todas essas colunas estão no RETURNS TABLE desta função)
    delete from public.match_buffs mb
    where mb.user_id  = v_user.id
      and mb.match_id = p_match_id
      and mb.buff_id  = 'coin-bet';

    -- FIX: app_users.coins evita ambiguidade com o OUT-var coins
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

  -- FIX: app_users.coins evita ambiguidade com o OUT-var coins
  update public.app_users
  set coins = app_users.coins + v_cost
  where id = v_user.id
  returning * into v_user;

  return query select p_match_id, p_buff_id, v_user.coins;
end;
$$;


-- ─────────────────────────────────────────────────────────────────
-- 2. app_settle_pending_coin_bets — SELECT predictions com alias
-- ─────────────────────────────────────────────────────────────────
create or replace function public.app_settle_pending_coin_bets(p_token uuid)
returns table (
  match_id       text,
  bet_amount     integer,
  coins_awarded  integer,
  outcome        text
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

    -- FIX: alias pr + qualificação explícita de match_id e user_id
    --      evita ambiguidade com o OUT-var match_id desta função
    select * into v_pred
    from public.predictions pr
    where pr.user_id  = v_user.id
      and pr.match_id = v_bet.match_id
    limit 1;

    v_bet_amt := v_bet.target_nickname::integer;
    v_exact   := false;
    v_result  := false;

    if v_pred.user_id is not null then
      v_exact := (v_pred.home_score = v_match.score_home
               and v_pred.away_score = v_match.score_away);

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
      set coins = app_users.coins + v_award
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
