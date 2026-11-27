-- Return only registration IDs and a count to the server-side notification worker.
begin;
create or replace function public.wli_claim_notification_ids()
returns table(user_id uuid)
language sql security definer set search_path = '' as $$
  with pending as (
    select q.user_id from wli_private.registration_notifications q
    join auth.users u on u.id=q.user_id
    where q.delivered_at is null and (q.claimed_at is null or q.claimed_at < now()-interval '15 minutes')
      and q.attempts<5 and u.email_confirmed_at is not null
      and (u.raw_user_meta_data ->> 'registration_notice_acknowledged' = 'true' or u.raw_app_meta_data ->> 'provider' = 'google')
    order by q.created_at limit 10 for update of q skip locked
  )
  update wli_private.registration_notifications q
    set claimed_at=now(), attempts=attempts+1
    from pending p where q.user_id=p.user_id returning q.user_id
$$;
revoke all on function public.wli_claim_notification_ids() from public, anon, authenticated;
grant execute on function public.wli_claim_notification_ids() to service_role;
commit;