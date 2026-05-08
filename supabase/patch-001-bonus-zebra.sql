alter table bonus_predictions
add column if not exists tournament_zebra text;

create or replace function public.app_save_bonus_prediction(
  p_token uuid,
  p_champion text,
  p_runner_up text,
  p_third_place text,
  p_fourth_place text,
  p_top_scorer text,
  p_best_group_stage_team text,
  p_tournament_zebra text,
  p_total_goals integer
)
returns bonus_predictions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user app_users;
  v_lock_at timestamptz;
  v_bonus bonus_predictions;
begin
  select * into v_user from app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
  end if;

  select (value->>'bonus_lock_at')::timestamptz into v_lock_at from app_settings where key = 'system';
  if v_lock_at is not null and now() >= v_lock_at then
    raise exception 'Palpites extras já foram fechados.';
  end if;

  insert into bonus_predictions (
    user_id, champion, runner_up, third_place, fourth_place, top_scorer, best_group_stage_team, tournament_zebra, total_goals
  )
  values (
    v_user.id, p_champion, p_runner_up, p_third_place, p_fourth_place, p_top_scorer, p_best_group_stage_team, p_tournament_zebra, p_total_goals
  )
  on conflict (user_id)
  do update set
    champion = excluded.champion,
    runner_up = excluded.runner_up,
    third_place = excluded.third_place,
    fourth_place = excluded.fourth_place,
    top_scorer = excluded.top_scorer,
    best_group_stage_team = excluded.best_group_stage_team,
    tournament_zebra = excluded.tournament_zebra,
    total_goals = excluded.total_goals,
    updated_at = now()
  returning * into v_bonus;

  return v_bonus;
end;
$$;
