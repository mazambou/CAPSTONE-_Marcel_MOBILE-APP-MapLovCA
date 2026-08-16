-- Immediately queue every registration that has remained incomplete for the
-- existing 72-hour abandonment window. The account-deletion Edge Function
-- removes its Supabase objects, private selfie, AWS face index and Auth user.

begin;

do $$
declare
  queued integer;
begin
  loop
    queued := public.enqueue_stale_incomplete_registrations();
    exit when queued = 0;
  end loop;
end;
$$;

comment on function public.enqueue_stale_incomplete_registrations() is
  'Queues abandoned registrations after 72 hours; the deletion worker erases all account data, private selfies and indexed biometric references.';

commit;
