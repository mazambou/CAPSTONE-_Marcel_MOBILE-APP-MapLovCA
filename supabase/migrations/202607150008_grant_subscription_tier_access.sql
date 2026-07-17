-- Discovery and the profile-like RLS policies evaluate the signed-in user's
-- subscription tier. Keep the helper private while allowing authenticated
-- sessions to execute it through those policies.
revoke execute on function private.current_subscription_tier(uuid) from public, anon;
grant execute on function private.current_subscription_tier(uuid) to authenticated;
