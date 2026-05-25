-- ============================================================
-- Patch 029: Reformulação Completa — Pontuação, Buffs e Ranking
-- ============================================================
--
-- PONTUAÇÃO NÃO CUMULATIVA:
--   Fase de Grupos:      exato=+1.0  resultado=+0.5  erro=-0.1  ausente=-0.2
--   Mata-mata Inicial:   exato=+2.0  avança=+1.0     erro=-0.2  ausente=-0.2
--     (16 avos, Oitavas, Quartas)
--   Mata-mata Decisivo:  exato=+3.0  vencedor=+2.0   erro=-0.5  ausente=-0.5
--     (Semi Final, Final, Disputa 3° Lugar)
--
-- BUFFS NOVOS:
--   draw-protected    1 moeda  apostou vencedor + jogo empatou → não perde pts
--   palpite-duplo     4 moedas ×2 nos pontos (grupos a quartas)
--   zerar-adversario  4 moedas rival recebe 0 (só grupos, max 2/torneio)
--   meia-adversario   3 moedas rival recebe metade (mata-mata inicial, max 2/torneio)
--   coin-bet          1 moeda  exato=3 moedas, resultado=2 moedas, erro=0
--
-- REMOVIDOS: error-shield, points-x3, multiplicadores automáticos
-- RENOMEADOS: points-x2→palpite-duplo, cancel-rival→zerar-adversario
--
-- DESEMPATE:
--   1° pontos totais  2° placares exatos  3° aproveitamento%
--   4° acertou campeão  5° ordem alfabética
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 0. Migração de dados — renomear/remover buff IDs antigos
-- ─────────────────────────────────────────────────────────────
delete from public.match_buffs where buff_id in ('error-shield', 'points-x3');
update public.match_buffs set buff_id = 'palpite-duplo'     where buff_id = 'points-x2';
update public.match_buffs set buff_id = 'zerar-adversario'  where buff_id = 'cancel-rival';


-- ─────────────────────────────────────────────────────────────
-- 1. app_phase_type — classifica a fase em 3 tipos
-- ─────────────────────────────────────────────────────────────
create or replace function public.app_phase_type(
  p_phase_label text,
  p_phase       text
)
returns text   -- 'group' | 'knockout_initial' | 'knockout_decisive'
language sql
immutable
as $$
  select
    case
      when upper(coalesce(p_phase_label, '')) = 'FASE DE GRUPOS'
        or lower(coalesce(p_phase, ''))       = 'group'
      then 'group'
      when upper(coalesce(p_phase_label, ''))  in ('SEMI FINAL', 'FINAL')
        or upper(coalesce(p_phase_label, ''))  like 'DISPUTA 3%'
        or lower(coalesce(p_phase, ''))        in ('semifinal', 'final', 'third_place')
      then 'knockout_decisive'
      else 'knockout_initial'
    end
$$;


-- ─────────────────────────────────────────────────────────────
-- 2. app_phase_max_points — pontos máximos possíveis por fase
-- ─────────────────────────────────────────────────────────────
create or replace function public.app_phase_max_points(
  p_phase_label text,
  p_phase       text
)
returns numeric
language sql
immutable
as $$
  select
    case public.app_phase_type(p_phase_label, p_phase)
      when 'group'             then 1.0::numeric
      when 'knockout_initial'  then 2.0::numeric
      else                          3.0::numeric  -- knockout_decisive
    end
$$;


-- ─────────────────────────────────────────────────────────────
-- 3. app_phase_absence_penalty — penalidade por ausência
-- ─────────────────────────────────────────────────────────────
create or replace function public.app_phase_absence_penalty(
  p_phase_label text,
  p_phase       text
)
returns numeric
language sql
immutable
as $$
  select
    case public.app_phase_type(p_phase_label, p_phase)
      when 'knockout_decisive' then -0.5::numeric
      else                          -0.2::numeric
    end
$$;


-- ─────────────────────────────────────────────────────────────
-- 4. app_match_auto_multiplier — removido (sempre retorna 1)
-- ─────────────────────────────────────────────────────────────
create or replace function public.app_match_auto_multiplier(
  p_phase_label text,
  p_phase       text
)
returns numeric
language sql
immutable
as $$
  select 1::numeric
$$;


-- ─────────────────────────────────────────────────────────────
-- 5. app_prediction_result_hit — nova lógica para mata-mata
--    Grupos:     direção 90min (casa/empate/fora)
--    Mata-mata:  verifica winner_team (quem avançou/venceu)
-- ─────────────────────────────────────────────────────────────
create or replace function public.app_prediction_result_hit(
  p_phase_label     text,
  p_phase           text,
  p_official_home   integer,
  p_official_away   integer,
  p_official_winner text,
  p_predicted_home  integer,
  p_predicted_away  integer,
  p_predicted_winner text
)
returns boolean
language sql
immutable
as $$
  select
    case
      when p_official_home is null or p_official_away is null then false
      when public.app_phase_type(p_phase_label, p_phase) = 'group' then
        -- Fase de grupos: acertar direção do placar (90min)
           ((p_predicted_home - p_predicted_away) = 0  and (p_official_home - p_official_away) = 0)
        or ((p_predicted_home - p_predicted_away) > 0  and (p_official_home - p_official_away) > 0)
        or ((p_predicted_home - p_predicted_away) < 0  and (p_official_home - p_official_away) < 0)
      else
        -- Mata-mata: acertar quem avançou / vencedor
        p_official_winner  is not null
        and p_predicted_winner is not null
        and lower(trim(p_predicted_winner)) = lower(trim(p_official_winner))
    end
$$;


-- ─────────────────────────────────────────────────────────────
-- 6. app_prediction_points — pontuação NÃO cumulativa
-- ─────────────────────────────────────────────────────────────
create or replace function public.app_prediction_points(
  p_phase_label         text,
  p_phase               text,
  p_official_home       integer,
  p_official_away       integer,
  p_official_extra_home integer,   -- ignorado no novo sistema
  p_official_extra_away integer,   -- ignorado no novo sistema
  p_official_winner     text,
  p_predicted_home      integer,
  p_predicted_away      integer,
  p_predicted_extra_home integer,  -- ignorado no novo sistema
  p_predicted_extra_away integer,  -- ignorado no novo sistema
  p_predicted_winner    text
)
returns numeric
language sql
immutable
as $$
  select
    case
      when p_official_home is null or p_official_away is null then 0::numeric
      when public.app_phase_type(p_phase_label, p_phase) = 'group' then
        case
          when public.app_prediction_exact_hit(
            p_official_home, p_official_away, p_predicted_home, p_predicted_away
          ) then 1.0::numeric
          when public.app_prediction_result_hit(
            p_phase_label, p_phase,
            p_official_home, p_official_away, p_official_winner,
            p_predicted_home, p_predicted_away, p_predicted_winner
          ) then 0.5::numeric
          else -0.1::numeric
        end
      when public.app_phase_type(p_phase_label, p_phase) = 'knockout_initial' then
        case
          when public.app_prediction_exact_hit(
            p_official_home, p_official_away, p_predicted_home, p_predicted_away
          ) then 2.0::numeric
          when public.app_prediction_result_hit(
            p_phase_label, p_phase,
            p_official_home, p_official_away, p_official_winner,
            p_predicted_home, p_predicted_away, p_predicted_winner
          ) then 1.0::numeric
          else -0.2::numeric
        end
      else  -- knockout_decisive (semi, final, disputa 3°)
        case
          when public.app_prediction_exact_hit(
            p_official_home, p_official_away, p_predicted_home, p_predicted_away
          ) then 3.0::numeric
          when public.app_prediction_result_hit(
            p_phase_label, p_phase,
            p_official_home, p_official_away, p_official_winner,
            p_predicted_home, p_predicted_away, p_predicted_winner
          ) then 2.0::numeric
          else -0.5::numeric
        end
    end
$$;


-- ─────────────────────────────────────────────────────────────
-- 7. app_prediction_score_context — nova lógica de buffs
-- ─────────────────────────────────────────────────────────────
drop function if exists public.app_prediction_score_context(
  uuid, text, text, text,
  integer, integer, integer, integer, text,
  integer, integer, integer, integer, text
);

create or replace function public.app_prediction_score_context(
  p_user_id              uuid,
  p_match_id             text,
  p_phase_label          text,
  p_phase                text,
  p_official_home        integer,
  p_official_away        integer,
  p_official_extra_home  integer,
  p_official_extra_away  integer,
  p_official_winner      text,
  p_predicted_home       integer,
  p_predicted_away       integer,
  p_predicted_extra_home integer,
  p_predicted_extra_away integer,
  p_predicted_winner     text
)
returns table (
  exact_hit                 boolean,
  result_hit                boolean,
  base_points               numeric,
  protected_points          numeric,
  total_multiplier          numeric,
  points_before_adversario  numeric,
  adjusted_points           numeric,
  has_draw_protected        boolean,
  has_palpite_duplo         boolean,
  cancelled_by_rival        boolean,   -- foi zerado por zerar-adversario
  halved_by_rival           boolean,   -- foi dividido por meia-adversario
  zerar_adversario_target   text,      -- este usuário aplicou zerar em quem
  meia_adversario_target    text       -- este usuário aplicou meia em quem
)
language plpgsql
stable
security definer
set search_path = public
as $score_context$
declare
  v_exact_hit               boolean;
  v_result_hit              boolean;
  v_base_points             numeric;
  v_protected_points        numeric;
  v_has_draw_protected      boolean;
  v_has_palpite_duplo       boolean;
  v_total_multiplier        numeric;
  v_points_before_adv       numeric;
  v_adjusted_points         numeric;
  v_cancelled_by_rival      boolean;
  v_halved_by_rival         boolean;
  v_zerar_target            text;
  v_meia_target             text;
begin
  -- ── Pontuação base (não cumulativa, sem buffs) ─────────────────────
  v_exact_hit := public.app_prediction_exact_hit(
    p_official_home, p_official_away,
    p_predicted_home, p_predicted_away
  );

  v_result_hit := public.app_prediction_result_hit(
    p_phase_label, p_phase,
    p_official_home, p_official_away, p_official_winner,
    p_predicted_home, p_predicted_away, p_predicted_winner
  );

  v_base_points := public.app_prediction_points(
    p_phase_label, p_phase,
    p_official_home, p_official_away,
    p_official_extra_home, p_official_extra_away,
    p_official_winner,
    p_predicted_home, p_predicted_away,
    p_predicted_extra_home, p_predicted_extra_away,
    p_predicted_winner
  );

  -- ── Verificar buffs do usuário neste jogo ─────────────────────────
  select exists (
    select 1 from public.match_buffs mb
    where mb.user_id = p_user_id and mb.match_id = p_match_id and mb.buff_id = 'draw-protected'
  ) into v_has_draw_protected;

  select exists (
    select 1 from public.match_buffs mb
    where mb.user_id = p_user_id and mb.match_id = p_match_id and mb.buff_id = 'palpite-duplo'
  ) into v_has_palpite_duplo;

  select mb.target_nickname
  into v_zerar_target
  from public.match_buffs mb
  where mb.user_id = p_user_id and mb.match_id = p_match_id and mb.buff_id = 'zerar-adversario'
  limit 1;

  select mb.target_nickname
  into v_meia_target
  from public.match_buffs mb
  where mb.user_id = p_user_id and mb.match_id = p_match_id and mb.buff_id = 'meia-adversario'
  limit 1;

  -- ── Verificar se algum adversário aplicou buffs contra este usuário ─
  select exists (
    select 1 from public.match_buffs mb
    join public.app_users target_user
      on lower(target_user.nickname) = lower(trim(mb.target_nickname))
    where mb.match_id = p_match_id
      and mb.buff_id  = 'zerar-adversario'
      and target_user.id = p_user_id
  ) into v_cancelled_by_rival;

  select exists (
    select 1 from public.match_buffs mb
    join public.app_users target_user
      on lower(target_user.nickname) = lower(trim(mb.target_nickname))
    where mb.match_id = p_match_id
      and mb.buff_id  = 'meia-adversario'
      and target_user.id = p_user_id
  ) into v_halved_by_rival;

  -- ── Aplicar draw-protected ─────────────────────────────────────────
  -- Nova regra: apostou vencedor (não empate) E jogo empatou → 0 pts
  v_protected_points := v_base_points;
  if v_has_draw_protected
     and p_predicted_home is not null and p_predicted_away is not null
     and (p_predicted_home <> p_predicted_away)  -- apostou vencedor
     and p_official_home is not null and p_official_away is not null
     and (p_official_home = p_official_away)      -- jogo empatou
     and v_protected_points < 0
  then
    v_protected_points := 0;
  end if;

  -- ── Aplicar multiplicador (apenas palpite-duplo, sem auto-multiplier) ──
  v_total_multiplier := case when v_has_palpite_duplo then 2::numeric else 1::numeric end;
  v_points_before_adv := v_protected_points * v_total_multiplier;

  -- ── Aplicar efeito de adversário ──────────────────────────────────
  -- zerar (prioridade) > meia
  if v_cancelled_by_rival then
    v_adjusted_points := 0::numeric;
  elsif v_halved_by_rival then
    v_adjusted_points := v_points_before_adv / 2.0;
  else
    v_adjusted_points := v_points_before_adv;
  end if;

  return query
  select
    v_exact_hit,
    v_result_hit,
    v_base_points,
    v_protected_points,
    v_total_multiplier,
    v_points_before_adv,
    v_adjusted_points,
    v_has_draw_protected,
    v_has_palpite_duplo,
    v_cancelled_by_rival,
    v_halved_by_rival,
    v_zerar_target,
    v_meia_target;
end;
$score_context$;


-- ─────────────────────────────────────────────────────────────
-- 8. app_apply_match_buff — nova estrutura de buffs
-- ─────────────────────────────────────────────────────────────
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

  if now() >= (v_match.starts_at - interval '30 minutes') then
    raise exception 'Mercado fechado para este jogo.';
  end if;

  v_phase := upper(coalesce(v_match.phase_label, v_match.phase, ''));

  -- ── 1. Custo de cada buff ─────────────────────────────────────────
  case p_buff_id
    when 'draw-protected'    then v_cost := 1;
    when 'palpite-duplo'     then v_cost := 4;
    when 'zerar-adversario'  then v_cost := 4;
    when 'meia-adversario'   then v_cost := 3;
    when 'coin-bet'          then v_cost := 1;
    else raise exception 'Buff invalido.';
  end case;

  -- ── 2. Restrições de fase ─────────────────────────────────────────

  if p_buff_id = 'draw-protected' then
    -- Disponível: grupos, 16avos, oitavas, quartas, SEMI FINAL
    -- Bloqueado: FINAL e DISPUTA 3°
    if v_phase = 'FINAL' or v_phase like 'DISPUTA 3%' then
      raise exception 'Empate Protegido indisponivel na Final e Disputa de 3 lugar.';
    end if;

  elsif p_buff_id = 'palpite-duplo' then
    -- Disponível: grupos, 16avos, oitavas, quartas
    -- Bloqueado: semi, final, disputa3
    if v_phase not in ('FASE DE GRUPOS', '16 AVOS DE FINAL', 'OITAVAS DE FINAL', 'QUARTAS DE FINAL') then
      raise exception 'Palpite Duplo disponivel apenas ate as Quartas de Final.';
    end if;

  elsif p_buff_id = 'zerar-adversario' then
    -- Disponível: SOMENTE fase de grupos
    if v_phase <> 'FASE DE GRUPOS' then
      raise exception 'Zerar Adversario disponivel apenas na Fase de Grupos.';
    end if;
    -- Limite: max 2 por torneio
    if (
      select count(*) from public.match_buffs mb
      where mb.user_id = v_user.id and mb.buff_id = 'zerar-adversario'
    ) >= 2 then
      raise exception 'Limite de 2 usos de Zerar Adversario por torneio atingido.';
    end if;
    -- Alvo obrigatório
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
    -- Disponível: mata-mata inicial (16avos, oitavas, quartas)
    if v_phase not in ('16 AVOS DE FINAL', 'OITAVAS DE FINAL', 'QUARTAS DE FINAL') then
      raise exception 'Meia Adversario disponivel apenas no Mata-Mata Inicial (16avos a Quartas).';
    end if;
    -- Limite: max 2 por torneio
    if (
      select count(*) from public.match_buffs mb
      where mb.user_id = v_user.id and mb.buff_id = 'meia-adversario'
    ) >= 2 then
      raise exception 'Limite de 2 usos de Meia Adversario por torneio atingido.';
    end if;
    -- Alvo obrigatório
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
    -- Disponível em todas as fases; sem restrição de fase
    -- Verificar se já tem aposta neste jogo
    if exists (
      select 1 from public.match_buffs mb
      where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = 'coin-bet'
    ) then
      raise exception 'Aposta ja registrada neste jogo.';
    end if;
  end if;

  -- ── 3. Verificar duplicata (exceto coin-bet já tratado acima) ─────
  if p_buff_id <> 'coin-bet' then
    if exists (
      select 1 from public.match_buffs mb
      where mb.user_id = v_user.id and mb.match_id = p_match_id and mb.buff_id = p_buff_id
    ) then
      raise exception 'Buff ja ativo neste jogo.';
    end if;
  end if;

  -- ── 4. Verificar saldo ────────────────────────────────────────────
  if v_user.coins < v_cost then
    raise exception 'Moedas insuficientes.';
  end if;

  -- ── 5. Debitar moedas ────────────────────────────────────────────
  update public.app_users
  set coins = app_users.coins - v_cost
  where id = v_user.id
  returning * into v_user;

  -- ── 6. Inserir buff ──────────────────────────────────────────────
  if p_buff_id = 'coin-bet' then
    -- target_nickname armazena o valor apostado (fixo = '1')
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


-- ─────────────────────────────────────────────────────────────
-- 9. app_cancel_match_buff — cancelar buffs com novos IDs
-- ─────────────────────────────────────────────────────────────
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

  -- ── Coin-bet: devolve o valor apostado armazenado em target_nickname ──
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

  -- ── Buffs normais ─────────────────────────────────────────────────
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


-- ─────────────────────────────────────────────────────────────
-- 10. app_settle_pending_coin_bets — liquidar apostas (custo fixo)
-- ─────────────────────────────────────────────────────────────
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

    select * into v_pred
    from public.predictions pr
    where pr.user_id  = v_user.id
      and pr.match_id = v_bet.match_id
    limit 1;

    -- Valor apostado (armazenado em target_nickname; novo sistema sempre '1')
    v_bet_amt := coalesce(v_bet.target_nickname::integer, 1);
    v_exact   := false;
    v_result  := false;

    if v_pred.user_id is not null then
      v_exact := public.app_prediction_exact_hit(
        v_match.score_home, v_match.score_away,
        v_pred.home_score,  v_pred.away_score
      );

      if not v_exact then
        v_result := public.app_prediction_result_hit(
          v_match.phase_label, v_match.phase,
          v_match.score_home, v_match.score_away, v_match.winner_team,
          v_pred.home_score, v_pred.away_score, v_pred.winner_team
        );
      end if;
    end if;

    -- Novo sistema: exato=bet*3, resultado=bet*2, erro=0
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


-- ─────────────────────────────────────────────────────────────
-- 11. app_get_leaderboard — novos critérios de desempate
--     1° pontos totais  2° placares exatos  3° aproveitamento%
--     4° acertou campeão  5° ordem alfabética
-- ─────────────────────────────────────────────────────────────
drop function if exists public.app_get_leaderboard(uuid);

create or replace function public.app_get_leaderboard(p_token uuid default null)
returns table (
  rank_position    integer,
  user_id          uuid,
  nickname         text,
  real_name        text,
  avatar_type      text,
  avatar_value     text,
  exact_scores     integer,
  correct_results  integer,
  total_points     numeric,
  bonus_points     numeric,
  aproveitamento   numeric,
  previous_rank    integer,
  is_current_user  boolean
)
language plpgsql
security definer
set search_path = public
as $leaderboard$
declare
  v_user          public.app_users;
  v_bonus_results jsonb;
begin
  if p_token is not null then
    select * into v_user from public.app_get_user_by_token(p_token);
  end if;

  v_bonus_results := public.app_get_bonus_results();

  return query
  with scored_predictions as (
    select
      u.id as leaderboard_user_id,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.adjusted_points
        else 0::numeric
      end as points_awarded,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
          and score_ctx.exact_hit
        then 1 else 0
      end as exact_hit,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
          and score_ctx.result_hit
        then 1 else 0
      end as result_hit
    from public.app_users u
    left join public.predictions p on p.user_id = u.id
    left join public.matches m     on m.id = p.match_id
    left join lateral public.app_prediction_score_context(
      u.id, p.match_id, m.phase_label, m.phase,
      m.score_home, m.score_away, m.extra_time_home, m.extra_time_away, m.winner_team,
      p.home_score, p.away_score, p.extra_time_home, p.extra_time_away, p.winner_team
    ) score_ctx on p.match_id is not null
    where not u.is_blocked and not u.is_admin
  ),

  -- Penalidade por ausência (varia por fase)
  missed_penalties as (
    select
      u.id as mp_user_id,
      sum(
        public.app_phase_absence_penalty(m.phase_label, m.phase)
      )::numeric as mp_penalty
    from public.app_users u
    cross join public.matches m
    where not u.is_blocked
      and not u.is_admin
      and m.status     = 'completed'
      and m.score_home is not null
      and m.score_away is not null
      and m.match_number > 3
      and m.starts_at >= u.created_at
      and not exists (
        select 1 from public.predictions p
        where p.user_id = u.id and p.match_id = m.id
      )
    group by u.id
  ),

  -- Aproveitamento: pontos obtidos / pontos máximos (jogos palpitados, sem buffs)
  aproveitamento_data as (
    select
      u.id as ap_user_id,
      case
        when sum(public.app_phase_max_points(m.phase_label, m.phase)) > 0
        then sum(public.app_prediction_points(
          m.phase_label, m.phase,
          m.score_home, m.score_away,
          m.extra_time_home, m.extra_time_away,
          m.winner_team,
          p.home_score, p.away_score,
          p.extra_time_home, p.extra_time_away,
          p.winner_team
        )) / sum(public.app_phase_max_points(m.phase_label, m.phase))
        else null
      end as aproveitamento_pct
    from public.app_users u
    join public.predictions p on p.user_id = u.id
    join public.matches m      on m.id = p.match_id
    where not u.is_blocked
      and not u.is_admin
      and m.status     = 'completed'
      and m.score_home is not null
      and m.score_away is not null
    group by u.id
  ),

  -- Acertou o campeão da Copa
  champion_data as (
    select
      bp.user_id as ch_user_id,
      case
        when (
          select trim(lower(coalesce(s.value->'bonus_results'->>'champion', '')))
          from public.app_settings s
          where s.key = 'system'
          limit 1
        ) <> ''
          and lower(trim(coalesce(bp.champion, ''))) = (
          select trim(lower(coalesce(s.value->'bonus_results'->>'champion', '')))
          from public.app_settings s
          where s.key = 'system'
          limit 1
        )
        then 1 else 0
      end as got_champion
    from public.bonus_predictions bp
  ),

  aggregated as (
    select
      u.id            as agg_user_id,
      u.nickname      as agg_nickname,
      u.real_name     as agg_real_name,
      u.avatar_type   as agg_avatar_type,
      u.avatar_value  as agg_avatar_value,
      u.previous_rank as agg_previous_rank,
      coalesce(sum(sp.points_awarded), 0)::numeric
        + coalesce(mp.mp_penalty, 0)                         as agg_game_points,
      coalesce(sum(sp.exact_hit),   0)::integer              as agg_exact_scores,
      coalesce(sum(sp.result_hit),  0)::integer              as agg_correct_results,
      coalesce(ap.aproveitamento_pct, null)                  as agg_aproveitamento,
      coalesce(ch.got_champion, 0)                           as agg_got_champion
    from public.app_users u
    left join scored_predictions sp  on sp.leaderboard_user_id = u.id
    left join missed_penalties   mp  on mp.mp_user_id          = u.id
    left join aproveitamento_data ap on ap.ap_user_id          = u.id
    left join champion_data       ch on ch.ch_user_id          = u.id
    where not u.is_blocked and not u.is_admin
    group by
      u.id, u.nickname, u.real_name, u.avatar_type, u.avatar_value,
      u.previous_rank, mp.mp_penalty, ap.aproveitamento_pct, ch.got_champion
  ),

  with_bonus as (
    select
      agg.*,
      case
        when v_bonus_results <> '{}'::jsonb
        then coalesce(
          (select bs.total_bonus_points
           from public.app_score_bonus_prediction(agg.agg_user_id, v_bonus_results) bs
           limit 1),
          0::numeric
        )
        else 0::numeric
      end as agg_bonus_points
    from aggregated agg
  ),

  ranked as (
    select
      row_number() over (
        order by
          (agg_game_points + agg_bonus_points) desc,
          agg_exact_scores                     desc,
          coalesce(agg_aproveitamento, -1)     desc,
          agg_got_champion                     desc,
          agg_nickname                         asc
      )::integer                     as computed_rank_position,
      agg_user_id, agg_nickname, agg_real_name, agg_avatar_type, agg_avatar_value,
      agg_exact_scores, agg_correct_results,
      agg_game_points + agg_bonus_points as agg_total_points,
      agg_bonus_points,
      agg_aproveitamento,
      agg_previous_rank
    from with_bonus
  )
  select
    ranked.computed_rank_position,
    ranked.agg_user_id,
    ranked.agg_nickname,
    ranked.agg_real_name,
    ranked.agg_avatar_type,
    ranked.agg_avatar_value,
    ranked.agg_exact_scores,
    ranked.agg_correct_results,
    ranked.agg_total_points,
    ranked.agg_bonus_points,
    ranked.agg_aproveitamento,
    ranked.agg_previous_rank,
    case when v_user.id is not null and ranked.agg_user_id = v_user.id then true else false end
  from ranked
  order by ranked.computed_rank_position;
end;
$leaderboard$;


-- ─────────────────────────────────────────────────────────────
-- 12. app_get_user_history — novo sistema de pontuação e buffs
-- ─────────────────────────────────────────────────────────────
drop function if exists public.app_get_user_history(uuid, uuid);

create or replace function public.app_get_user_history(
  p_token   uuid,
  p_user_id uuid default null
)
returns table (
  match_id              text,
  match_number          integer,
  phase_label           text,
  group_name            text,
  starts_at             timestamptz,
  home_team             text,
  away_team             text,
  official_home         integer,
  official_away         integer,
  official_extra_home   integer,
  official_extra_away   integer,
  official_winner       text,
  predicted_home        integer,
  predicted_away        integer,
  predicted_extra_home  integer,
  predicted_extra_away  integer,
  predicted_winner      text,
  exact_hit             boolean,
  result_hit            boolean,
  points_awarded        numeric,
  raw_points            numeric,
  total_multiplier      numeric,
  cancelled_by_rival    boolean,
  applied_buffs         text,
  rival_cancel_target   text,
  match_status          text,
  was_predicted         boolean
)
language plpgsql
security definer
set search_path = public
as $history$
declare
  v_user              public.app_users;
  v_target_user_id    uuid;
  v_target_created_at timestamptz;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  if p_user_id is not null and v_user.is_admin then
    v_target_user_id := p_user_id;
  else
    v_target_user_id := v_user.id;
  end if;

  select created_at into v_target_created_at
  from public.app_users
  where id = v_target_user_id;

  return query
  select * from (
    -- ── Jogos com palpite ─────────────────────────────────────────
    select
      m.id,
      m.match_number,
      m.phase_label,
      m.group_name,
      m.starts_at,
      m.home_team,
      m.away_team,
      m.score_home,
      m.score_away,
      m.extra_time_home,
      m.extra_time_away,
      m.winner_team,
      p.home_score,
      p.away_score,
      p.extra_time_home,
      p.extra_time_away,
      p.winner_team,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.exact_hit else false
      end,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.result_hit else false
      end,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.adjusted_points else 0::numeric
      end,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.points_before_adversario else 0::numeric
      end,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.total_multiplier else 1::numeric
      end,
      case
        when m.status = 'completed' and m.score_home is not null and m.score_away is not null
        then score_ctx.cancelled_by_rival else false
      end,
      -- Texto de buffs ativos
      trim(both ' •' from concat(
        case when score_ctx.has_draw_protected then 'Empate Protegido • ' else '' end,
        case when score_ctx.has_palpite_duplo  then 'Palpite Duplo • ' else '' end,
        case when score_ctx.zerar_adversario_target is not null
          then concat('Zerou ', score_ctx.zerar_adversario_target, ' • ') else '' end,
        case when score_ctx.meia_adversario_target is not null
          then concat('Meia em ', score_ctx.meia_adversario_target, ' • ') else '' end,
        case when score_ctx.cancelled_by_rival then 'Sofreu Anulacao • ' else '' end,
        case when score_ctx.halved_by_rival     then 'Sofreu Meia Pontuacao • ' else '' end
      )),
      score_ctx.zerar_adversario_target,  -- rival_cancel_target (mantém campo por compatibilidade)
      m.status,
      true::boolean  -- was_predicted
    from public.predictions p
    join public.matches m on m.id = p.match_id
    join lateral public.app_prediction_score_context(
      p.user_id, p.match_id, m.phase_label, m.phase,
      m.score_home, m.score_away, m.extra_time_home, m.extra_time_away, m.winner_team,
      p.home_score, p.away_score, p.extra_time_home, p.extra_time_away, p.winner_team
    ) score_ctx on true
    where p.user_id = v_target_user_id

    union all

    -- ── Jogos perdidos (sem palpite): penalidade por fase ────────
    select
      m.id,
      m.match_number,
      m.phase_label,
      m.group_name,
      m.starts_at,
      m.home_team,
      m.away_team,
      m.score_home,
      m.score_away,
      m.extra_time_home,
      m.extra_time_away,
      m.winner_team,
      null::integer,
      null::integer,
      null::integer,
      null::integer,
      null::text,
      false::boolean,
      false::boolean,
      public.app_phase_absence_penalty(m.phase_label, m.phase),  -- pontuação negativa por fase
      public.app_phase_absence_penalty(m.phase_label, m.phase),
      1::numeric,
      false::boolean,
      'Sem palpite'::text,
      null::text,
      m.status,
      false::boolean
    from public.matches m
    where m.status     = 'completed'
      and m.score_home is not null
      and m.score_away is not null
      and m.match_number > 3
      and m.starts_at >= v_target_created_at
      and not exists (
        select 1 from public.predictions p
        where p.user_id = v_target_user_id and p.match_id = m.id
      )
  ) all_entries
  order by all_entries.starts_at asc, all_entries.match_number asc;
end;
$history$;
