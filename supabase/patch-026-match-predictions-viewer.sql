-- Patch 026: Visualização de palpites por jogo
--
-- REGRA:
--   Após o fechamento do mercado de cada jogo (30 min antes do início),
--   qualquer participante logado pode ver os palpites de todos os outros.
--
-- NOVA FUNÇÃO: app_get_match_predictions
--   - Exige token válido
--   - Só retorna dados se now() >= starts_at - 30 min (mercado fechado)
--   - Retorna nickname, avatar, placar palpitado e buffs usados
--   - Exclui admins e usuários bloqueados

create or replace function public.app_get_match_predictions(
  p_token    uuid,
  p_match_id text
)
returns table (
  nickname     text,
  avatar_type  text,
  avatar_value text,
  home_score   integer,
  away_score   integer,
  buff_ids     text[]   -- ex: ['draw-protected', 'coin-bet:3']
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user  public.app_users;
  v_match public.matches;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessao invalida.';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if v_match.id is null then
    raise exception 'Jogo nao encontrado.';
  end if;

  -- Só libera quando o mercado fechou (30 min antes do início)
  if now() < (v_match.starts_at - interval '30 minutes') then
    raise exception 'Os palpites ficam visíveis somente após o fechamento do mercado.';
  end if;

  return query
  select
    u.nickname,
    u.avatar_type,
    u.avatar_value,
    p.home_score,
    p.away_score,
    coalesce(
      array_agg(
        case
          when mb.buff_id = 'coin-bet'
          then 'coin-bet:' || coalesce(mb.target_nickname, '0')
          else mb.buff_id
        end
        order by mb.buff_id
      ) filter (where mb.buff_id is not null),
      '{}'::text[]
    ) as buff_ids
  from public.predictions p
  join public.app_users u on u.id = p.user_id
  left join public.match_buffs mb
         on mb.user_id = p.user_id
        and mb.match_id = p.match_id
  where p.match_id = p_match_id
    and not u.is_blocked
    and not u.is_admin
  group by u.id, u.nickname, u.avatar_type, u.avatar_value, p.home_score, p.away_score
  order by u.nickname asc;
end;
$$;
