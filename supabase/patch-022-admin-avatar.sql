-- Patch 022: Permite que admin atualize o próprio avatar pelo perfil
--
-- PROBLEMA: app_update_current_user_profile bloqueava todo admin com
--   "Conta ADMIN: use o painel administrativo."
--   incluindo troca de avatar, que não tem painel dedicado.
--
-- CORREÇÃO: A restrição agora bloqueia apenas troca de apelido e senha
--   para contas admin. Avatar pode ser atualizado por qualquer usuário.

create or replace function public.app_update_current_user_profile(
  p_token            uuid,
  p_nickname         text    default null,
  p_current_password text    default null,
  p_new_password     text    default null,
  p_avatar_type      text    default null,
  p_avatar_value     text    default null
)
returns table (
  user_id          uuid,
  nickname         text,
  real_name        text,
  avatar_type      text,
  avatar_value     text,
  coins            integer,
  mission_claims   jsonb,
  has_seen_welcome boolean,
  is_admin         boolean,
  is_blocked       boolean,
  previous_rank    integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.app_users;
begin
  select * into v_user from public.app_get_user_by_token(p_token);
  if v_user.id is null then
    raise exception 'Sessão inválida.';
  end if;

  -- Admin não pode alterar apelido ou senha aqui — use o painel administrativo.
  -- Mas pode alterar o próprio avatar (sem painel dedicado para isso).
  if v_user.is_admin then
    if (p_nickname is not null and trim(p_nickname) <> '') or
       (p_new_password is not null and trim(p_new_password) <> '') then
      raise exception 'Conta ADMIN: use o painel administrativo para alterar apelido ou senha.';
    end if;
  end if;

  -- Validação de apelido único (não-admin)
  if p_nickname is not null and trim(p_nickname) <> '' then
    if exists (
      select 1 from public.app_users
      where lower(nickname) = lower(trim(p_nickname))
        and id <> v_user.id
    ) then
      raise exception 'Esse apelido já está em uso.';
    end if;
  end if;

  -- Validação de troca de senha: exige senha atual correta
  if p_new_password is not null and trim(p_new_password) <> '' then
    if p_current_password is null or
       public.app_hash_password(p_current_password) <> v_user.password_hash then
      raise exception 'Senha atual incorreta.';
    end if;
    if length(trim(p_new_password)) < 6 then
      raise exception 'A nova senha precisa ter pelo menos 6 caracteres.';
    end if;
  end if;

  -- Validação do tipo de avatar
  if p_avatar_type is not null and p_avatar_type not in ('preset', 'upload') then
    raise exception 'Tipo de avatar inválido.';
  end if;

  update public.app_users
  set
    nickname = case
      when p_nickname is not null and trim(p_nickname) <> ''
      then trim(p_nickname)
      else nickname
    end,
    password_hash = case
      when p_new_password is not null and trim(p_new_password) <> ''
      then public.app_hash_password(p_new_password)
      else password_hash
    end,
    avatar_type  = coalesce(p_avatar_type, avatar_type),
    avatar_value = case
      when p_avatar_type is not null then p_avatar_value
      else avatar_value
    end
  where id = v_user.id
  returning * into v_user;

  return query select
    v_user.id,
    v_user.nickname,
    v_user.real_name,
    v_user.avatar_type,
    v_user.avatar_value,
    v_user.coins,
    v_user.mission_claims,
    v_user.has_seen_welcome,
    v_user.is_admin,
    v_user.is_blocked,
    v_user.previous_rank;
end;
$$;
