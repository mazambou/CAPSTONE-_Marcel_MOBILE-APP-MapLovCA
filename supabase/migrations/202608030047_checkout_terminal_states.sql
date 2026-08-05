-- Allow a signed-in user to mark only their own abandoned checkout as
-- cancelled. Provider webhooks remain authoritative for paid transactions.

begin;

create or replace function public.cancel_own_external_checkout(
  checkout_reference_value text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare updated_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(length(trim(checkout_reference_value)), 0) < 16 then
    raise exception 'Invalid checkout reference';
  end if;

  update public.external_checkout_sessions
  set status = 'cancelled', updated_at = now()
  where user_id = auth.uid()
    and checkout_reference = checkout_reference_value
    and status in ('created', 'pending');
  get diagnostics updated_count = row_count;
  return updated_count > 0;
end;
$$;

revoke all on function public.cancel_own_external_checkout(text)
from public, anon;
grant execute on function public.cancel_own_external_checkout(text)
to authenticated;

commit;
