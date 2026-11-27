-- Registration notification worker: service-role-only RPCs.
begin;
alter table wli_private.registration_notifications
  add column if not exists claimed_at timestamptz,
  add column if not exists attempts integer not null default 0;
create or replace function public.wli_claim_notifications()
returns table(user_id uuid, full_name text, email text, verified_at timestamptz)
language sql security definer set search_path = '' as $$
  with pending as (
    select q.user_id
    from wli_private.registration_notifications q
    join auth.users u on u.id = q.user_id
    where q.delivered_at is null
      and (q.claimed_at is null or q.claimed_at < now() - interval '15 minutes')
      and q.attempts < 5
      and u.email_confirmed_at is not null
      and u.raw_user_meta_data ->> 'registration_notice_acknowledged' = 'true'
    order by q.created_at
    limit 10 for update of q skip locked
  ), claimed as (
    update wli_private.registration_notifications q
    set claimed_at = now(), attempts = attempts + 1
    from pending p where q.user_id = p.user_id
    returning q.user_id, q.verified_at
  )
  select c.user_id, left(coalesce(u.raw_user_meta_data ->> 'full_name', ''), 150),
    u.email, c.verified_at
  from claimed c join auth.users u on u.id = c.user_id
$$;
create or replace function public.wli_mark_notification_delivered(p_user_id uuid)
returns void language sql security definer set search_path = '' as $$
  update wli_private.registration_notifications
    set delivered_at = now() where user_id = p_user_id and delivered_at is null
$$;
revoke all on function public.wli_claim_notifications() from public, anon, authenticated;
revoke all on function public.wli_mark_notification_delivered(uuid) from public, anon, authenticated;
grant execute on function public.wli_claim_notifications() to service_role;
grant execute on function public.wli_mark_notification_delivered(uuid) to service_role;
commit;