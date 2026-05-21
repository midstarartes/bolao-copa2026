-- Patch 021: Apagar resultado de uma partida (admin)
--
-- Permite ao admin desfazer um resultado lançado manualmente,
-- zerando placar, prorrogação, quem avança e voltando o status
-- para 'scheduled'. Isso remove a partida do histórico de pontuação.

create or replace function public.app_admin_clear_match_result(
  p_token    uuid,
  p_match_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  update public.matches
  set
    score_home      = null,
    score_away      = null,
    extra_time_home = null,
    extra_time_away = null,
    winner_team     = null,
    status          = 'scheduled'
  where id = p_match_id;

  if not found then
    raise exception 'Partida não encontrada.';
  end if;
end;
$$;
