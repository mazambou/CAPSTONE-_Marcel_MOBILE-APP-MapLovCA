# MapLov production authentication

MapLov uses a eight-digit Supabase email OTP to confirm new email/password
accounts. The user enters that code directly in the application, so signup
confirmation emails do not contain an authentication link.

The other Supabase Auth flows use PKCE and one canonical callback:

`https://maplov.ca/auth/callback`

The HTTPS callback is shared by password recovery, Magic Link, email change,
Google OAuth, and Apple OAuth. `supabase_flutter` exchanges the PKCE code and
emits the auth event that selects the correct Flutter screen. The legacy
callback `io.maplov.app://auth-callback` remains allow-listed only for links
issued by older builds.

## Signup email verification

Supabase Auth must keep email confirmations enabled with an eight-digit OTP. The
confirmation template uses `{{ .Token }}` and intentionally does not use
`{{ .ConfirmationURL }}`. The Flutter client verifies the code with the
`signup` OTP type, which confirms the address and creates the authenticated
session used to continue profile setup.

## Registration SMS fallback

When a registrant taps **Resend code** on the email verification screen, they
can choose another email code or Twilio Verify SMS. They must re-enter the
registration password for SMS. The `registration-sms-fallback` Edge Function
checks that password with Supabase Auth, checks that the phone matches the
pending account, limits SMS requests per phone, and then asks Twilio Verify to
send a code. After the code is approved, the server confirms that phone and
records an administrator-only `maplov_sms_fallback_verified` flag. The client
signs in with the verified phone number and password. The email remains
unconfirmed and can be confirmed later from **Security**; an SMS code is never
treated as proof of email ownership.

Supabase Auth permits a phone number on only one account. Before sending an
SMS, the fallback checks the stored number without its optional leading `+`.
If another account already owns that number, it shows a specific error and
leaves the existing account unchanged. An email code remains available, but a
unique phone number is still required to complete this registration.

## Temporary duplicate-account testing

The 14-day window ends at `2026-11-13T03:52:58Z` (November 12 at 22:52 in
Toronto). `DUPLICATE_ACCOUNT_BYPASS_UNTIL` controls both the selfie match pause
and the test signup option. After that instant, new duplicate test signups stop
automatically; accounts created during the window remain accessible.

The **Create another test account** option requires an existing active account
whose email and phone are both confirmed. The tester enters that same email
and phone, receives a Twilio Verify SMS, and enters the code before the server
creates a separate Supabase Auth identity. The Auth identity uses a unique
internal email under `accounts.maplov.ca`, while service-controlled app metadata
stores the real contact email and phone. The physical phone is verified but is
not assigned to a second `auth.users.phone` field. The account selector sends
an SMS, then lists the accounts for that phone. The tester signs in with the
password for the chosen account. Password recovery for a test identity routes
through the signed Auth Send Email Hook to the real contact email.

This flow preserves the unique Auth email and phone constraints. It does not
change existing accounts or make the normal signup path accept duplicates.
Existing test identities retain their verified-phone proof and selfie allowance
after the window closes. Contact email changes are disabled for test accounts;
other accounts retain their normal email-change path.

Keep the `TWILIO_VERIFY_API_KEY_SID`, `TWILIO_VERIFY_API_KEY_SECRET`, and
`TWILIO_VERIFY_SERVICE_SID` Edge Function secrets configured. The deployed
function must use `verify_jwt = false` because it runs before the first user
session; it still requires the correct registration password and phone number.
Phone/password sign-in must be enabled in Supabase Auth. The app continues to
create accounts with email/password, and email confirmations stay enabled.
Supabase's own SMS provider is not configured: the registration code comes
from Twilio Verify through the Edge Function. Therefore the CLI warns that it
disables **local** phone login when loading `config.toml`. After any production
`supabase config push`, explicitly re-enable phone login with a Supabase
Management API token (the token stays out of the repository):

```sh
curl -fsS -X PATCH \
  'https://api.supabase.com/v1/projects/heqkgexzlhdnmrkuikle/config/auth' \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  --data '{"external_phone_enabled":true}'
```

Keep email confirmations enabled. A phone/password request with a nonexistent
number should return `invalid_credentials`, not `phone_provider_disabled`.
Test one pending registration on a real phone before publishing an Android
build containing this fallback.

## Supabase URL configuration

Set **Authentication → URL Configuration → Site URL** to:

`https://maplov.ca`

Add these exact **Redirect URLs**:

- `https://maplov.ca/auth/callback`
- `io.maplov.app://auth-callback`

Exact URLs are intentional. A wildcard would allow callbacks to unrelated
paths and is not required by MapLov.

## Namecheap Private Email SMTP

The checked-in Supabase configuration contains the non-secret settings:

- Host: `mail.privateemail.com`
- Port: `587`
- Username and sender: `noreply@maplov.ca`
- Sender name: `MapLov`

Before applying the configuration, expose the mailbox password only in the
current shell:

```sh
export MAPLOV_SMTP_PASSWORD='the mailbox password'
supabase config push
unset MAPLOV_SMTP_PASSWORD
```

Never store the real mailbox password in `.env.example`, Dart defines, the
Flutter binary, or version control.

## Domain association deployment

Run `tool/generate_auth_associations.sh` with the Google Play App Signing
SHA-256 certificate. Add the production Apple Team ID as the optional second
argument when preparing the iOS association too, then deploy the generated
files under `web/.well-known`.

Both files must be served by `maplov.ca` over HTTPS with status 200, without a
redirect. The web host must also rewrite `/auth/callback` to the Flutter web
application entry point so users without the native app see the web callback
screen.

## OAuth provider callbacks

Google and Apple provider consoles redirect to Supabase, not directly to the
mobile application. Use the callback shown by the MapLov Supabase project:

`https://heqkgexzlhdnmrkuikle.supabase.co/auth/v1/callback`

Supabase then validates the requested MapLov redirect and returns the browser
to `https://maplov.ca/auth/callback`, which opens the verified installed app.
