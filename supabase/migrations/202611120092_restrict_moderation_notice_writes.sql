-- Supabase's default table grants include direct writes for API roles.
-- A recipient may read a notice, but acknowledgements go through the
-- ownership-checking RPC and warnings through the admin-only RPC.
revoke all on public.admin_user_notices from public, anon, authenticated;
grant select on public.admin_user_notices to authenticated;
