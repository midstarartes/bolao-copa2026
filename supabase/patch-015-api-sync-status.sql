create or replace function public.app_admin_set_api_sync_status(
  p_token uuid,
  p_source text,
  p_updated_count integer,
  p_checked_count integer,
  p_success boolean,
  p_message text default null,
  p_requested_by text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin app_users;
  v_payload jsonb;
begin
  select * into v_admin from app_get_user_by_token(p_token);
  if v_admin.id is null or not v_admin.is_admin then
    raise exception 'Acesso negado.';
  end if;

  insert into app_settings (key, value)
  values (
    'system',
    jsonb_build_object(
      'api_sync',
      jsonb_build_object(
        'source', coalesce(p_source, 'system'),
        'updated_count', greatest(coalesce(p_updated_count, 0), 0),
        'checked_count', greatest(coalesce(p_checked_count, 0), 0),
        'success', coalesce(p_success, false),
        'message', p_message,
        'requested_by', p_requested_by,
        'last_attempt_at', now(),
        'last_synced_at', case when coalesce(p_success, false) then now() else null end
      )
    )
  )
  on conflict (key)
  do update set
    value = coalesce(app_settings.value, '{}'::jsonb) || jsonb_build_object(
      'api_sync',
      coalesce(app_settings.value->'api_sync', '{}'::jsonb) || jsonb_build_object(
        'source', coalesce(p_source, 'system'),
        'updated_count', greatest(coalesce(p_updated_count, 0), 0),
        'checked_count', greatest(coalesce(p_checked_count, 0), 0),
        'success', coalesce(p_success, false),
        'message', p_message,
        'requested_by', p_requested_by,
        'last_attempt_at', now(),
        'last_synced_at',
          case
            when coalesce(p_success, false) then to_jsonb(now())
            else coalesce(app_settings.value->'api_sync'->'last_synced_at', 'null'::jsonb)
          end
      )
    ),
    updated_at = now()
  returning value into v_payload;

  return v_payload;
end;
$$;
