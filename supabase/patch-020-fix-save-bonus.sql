-- Patch 020: Corrige app_save_bonus_prediction
--
-- PROBLEMA: A função retornava `public.bonus_predictions` (tipo composto),
-- o que pode causar incompatibilidade com o PostgREST dependendo da versão
-- (PGRST202 - function not found in schema cache) quando o tipo de retorno
-- não é `RETURNS TABLE` nem `RETURNS void`.
--
-- SOLUÇÃO:
--   - Muda o retorno para RETURNS void (o front-end não usa o dado retornado)
--   - Adiciona DEFAULT NULL em todos os parâmetros opcionais para robustez
--   - Remove o drop forçado para evitar dependências quebradas

-- Necessário porque o tipo de retorno está mudando (bonus_predictions → void)
drop function if exists public.app_save_bonus_prediction(uuid,text,text,text,text,text,text,text,integer);

create or replace function public.app_save_bonus_prediction(
  p_token                 uuid,
  p_champion              text    default null,
  p_runner_up             text    default null,
  p_third_place           text    default null,
  p_fourth_place          text    default null,
  p_top_scorer            text    default null,
  p_best_group_stage_team text    default null,
  p_tournament_zebra      text    default null,
  p_total_goals           integer default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user    public.app_users;
  v_lock_at timestamptz;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
  end if;

  if v_user.is_admin then
    raise exception 'Conta ADMIN não participa do bolão.';
  end if;

  select (value->>'bonus_lock_at')::timestamptz
    into v_lock_at
    from public.app_settings
   where key = 'system';

  if v_lock_at is not null and now() >= v_lock_at then
    raise exception 'Palpites extras já foram fechados.';
  end if;

  insert into public.bonus_predictions (
    user_id, champion, runner_up, third_place, fourth_place,
    top_scorer, best_group_stage_team, tournament_zebra, total_goals
  )
  values (
    v_user.id, p_champion, p_runner_up, p_third_place, p_fourth_place,
    p_top_scorer, p_best_group_stage_team, p_tournament_zebra, p_total_goals
  )
  on conflict (user_id)
  do update set
    champion              = excluded.champion,
    runner_up             = excluded.runner_up,
    third_place           = excluded.third_place,
    fourth_place          = excluded.fourth_place,
    top_scorer            = excluded.top_scorer,
    best_group_stage_team = excluded.best_group_stage_team,
    tournament_zebra      = excluded.tournament_zebra,
    total_goals           = excluded.total_goals,
    updated_at            = now();
end;
$$;
