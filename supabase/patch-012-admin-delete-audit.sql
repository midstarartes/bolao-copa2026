drop function if exists public.app_admin_delete_user(uuid, uuid);

create or replace function public.app_admin_delete_user(
  p_token uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $admin_delete_user$
declare
  v_admin public.app_users;
  v_user public.app_users;
begin
  select * into v_admin from public.app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  if v_admin.id = p_user_id then
    raise exception 'O admin não pode excluir a própria conta.';
  end if;

  select * into v_user
  from public.app_users
  where id = p_user_id;

  if v_user.id is null then
    raise exception 'Usuario nao encontrado.';
  end if;

  if v_user.is_admin then
    raise exception 'Nao é permitido excluir outro usuario administrador por esta função.';
  end if;

  perform public.app_admin_log_action(
    v_admin.id,
    v_user.id,
    'user_deleted',
    'Usuário excluído',
    format('Conta de %s foi removida pelo admin.', v_user.nickname),
    jsonb_build_object(
      'nickname', v_user.nickname,
      'real_name', v_user.real_name,
      'coins', v_user.coins
    )
  );

  delete from public.app_users
  where id = v_user.id;
end;
$admin_delete_user$;
