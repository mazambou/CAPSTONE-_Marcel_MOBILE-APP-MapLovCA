# MapLov production authentication

MapLov uses Supabase Auth with PKCE and one canonical callback:

`https://maplov.ca/auth/callback`

The HTTPS callback is shared by email confirmation, password recovery, Magic
Link, email change, Google OAuth, and Apple OAuth. `supabase_flutter` exchanges
the PKCE code and emits the auth event that selects the correct Flutter screen.
The legacy callback `io.maplov.app://auth-callback` remains allow-listed only
for links issued by older builds.

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

Run `tool/generate_auth_associations.sh` with the production Apple Team ID and
Google Play App Signing SHA-256 certificate, then deploy the generated files
under `web/.well-known`.

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
