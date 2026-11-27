-- Registration notification worker: service-role-only RPCs.
begin;
alter table wli_private.registration_notifications
  add column if not exists claimed_at timestamptz,
  add column if not exists attempts integer not null default 0;
create or replace function public.wli_mark_notification_delivered(p_user_id uuid)
returns void language sql security definer set search_path = '' as $$
  update wli_private.registration_notifications
    set delivered_at = now() where user_id = p_user_id and delivered_at is null
$$;
revoke all on function public.wli_mark_notification_delivered(uuid) from public, anon, authenticated;
grant execute on function public.wli_mark_notification_delivered(uuid) to service_role;
commit;