# MapLov Supabase/PostgreSQL setup

Supabase is the backend platform; PostgreSQL is the database engine underneath
it. The SQL migration in this repository remains the source of truth and can be
run on a Supabase-hosted PostgreSQL project.

## What the migrations create

`supabase/migrations/202607120001_initial_maplove_schema.sql` creates:

- profiles, preferences, interests, profile photos, photo likes/comments;
- friendships and blocks;
- direct conversations, members, messages, and read cursors;
- friends-only posts, media, likes, and comments;
- Secret Garden albums, photos, requests, temporary access, and revocation;
- profile views and compatibility score storage;
- reports, notifications, notification preferences, subscriptions, and audit
  actions;
- exact locations in the non-exposed `private` schema;
- controlled RPCs for location updates, nearby searches, direct conversations,
  and message deletion;
- private Storage buckets for profile, post, chat, and Secret Garden media;
- RLS policies for every table containing user data.

`202607120002_auth_and_account_deletion.sql` connects Auth account creation and
safe deletion. `202607130003_realtime_notifications.sql` publishes the realtime
tables and creates trusted PostgreSQL notification triggers for messages,
friendships, posts, and Secret Garden requests.

## Apply the migration

1. Create a Supabase project in the Supabase dashboard.
2. Install and authenticate the Supabase CLI.
3. From the Flutter project directory, initialize/link the local folder and push
   the migration:

```sh
supabase init
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

If the project already has a Supabase CLI configuration, do not run
`supabase init` again; link it and run `supabase db push`.

The migration can also be reviewed and executed through the Supabase SQL Editor,
but the CLI migration workflow is preferred because it records migration state.

## Run Flutter against Supabase

Use the project URL and the client-safe publishable key from Supabase project
settings:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Older Supabase projects can use `SUPABASE_ANON_KEY` instead. Never pass a
`service_role` key to Flutter. A mobile binary cannot keep such a key secret,
and it bypasses RLS.

When no Supabase variables are supplied, MapLov intentionally starts in its
current UI/mock-data mode. This allows backend integration to happen feature by
feature without removing validated interfaces.

## Configure Supabase Auth redirects

In Supabase Dashboard, open **Authentication > URL Configuration** and add this
value to **Additional Redirect URLs**:

```text
io.maplov.app://auth-callback
```

The same callback is registered in Android's `AndroidManifest.xml` and iOS's
`Info.plist`. It is used for email confirmation, password recovery, Google, and
Apple OAuth.

Enable the Email, Google, and Apple providers in **Authentication > Providers**.
Google and Apple still require their provider-specific client IDs/secrets in the
Supabase Dashboard; those secrets must not be stored in the Flutter repository.

## Deploy purchase verification

The Flutter app starts App Store / Google Play subscription purchases, but it
never activates Premium from a client assertion. Deploy the verifier Edge
Function and configure a server that validates signed transactions with Apple
or purchase tokens with Google:

```sh
supabase functions deploy verify-store-purchase
supabase secrets set \
  STORE_VERIFICATION_URL=https://YOUR_SECURE_VERIFIER.example/verify \
  STORE_VERIFICATION_SECRET=YOUR_SERVER_TO_SERVER_SECRET
```

Create these subscription product IDs in both stores:

```text
maplov_plus_monthly
maplov_elite_monthly
maplov_vip_monthly
```

The secure verifier must return `valid`, `subscriptionId`, `periodStart`, and
`periodEnd`. Until this is configured, purchases fail closed and Premium is not
granted.

## Storage path conventions

RLS expects these object paths:

```text
profile-media/<owner_uuid>/<file_name>
post-media/<owner_uuid>/<post_uuid>/<file_name>
chat-media/<sender_uuid>/<conversation_uuid>/<file_name>
secret-garden/<owner_uuid>/<album_uuid>/<file_name>
```

All four buckets are private. Access is granted by PostgreSQL policies, not by
guessing an object URL.

## Security decisions

- Exact coordinates live in `private.user_locations`, which is not exposed to
  the client API. `find_nearby_profiles` returns approximate distance only.
- `auth.users` automatically creates a basic profile, preferences, and
  notification settings. User metadata cannot assign admin roles or verification.
- Profile roles, verification, subscription state, moderation state, and Garden
  access are protected from self-assignment.
- Blocks are checked when profiles, posts, messages, and private albums are read
  or used.
- Posts remain friends-only at both the table and Storage layers.
- Secret Garden access checks status, revocation, and expiration on every read.
- Subscription records are readable by their owner but writable only through a
  trusted server/service workflow.

## Required verification before production

After applying the migration to a development project, create two regular test
users and one admin test user, then verify:

1. a user cannot read another user's exact coordinates;
2. a blocked pair cannot discover each other or send new messages;
3. a non-friend cannot read a friends-only post or its media;
4. Garden media becomes unreadable immediately after expiry or revocation;
5. a regular user cannot set `role`, verification flags, or subscriptions;
6. a user cannot read another user's reports, notifications, or preferences;
7. malformed Storage paths cannot bypass owner-folder policies.

The Flutter repository now connects these flows through `MapLovRepository`.
Mock profiles remain only as an intentional offline/demo fallback; they are not
used after a configured user session is available.

## Production release checklist

1. Apply all migrations to staging and run the seven RLS checks above.
2. Enable Supabase Realtime for the project and test two physical devices.
3. Configure Apple/Google OAuth and subscription products.
4. Deploy the receipt verifier and test purchase, restore, expiry, cancellation,
   refund, and account changes in store sandboxes.
5. Supply production `SUPABASE_URL` and the publishable key as CI secrets.
6. Replace the example Android application ID and configure release signing.
7. Set the final iOS bundle ID, signing team, Associated Domains if needed, and
   App Store privacy declarations.
8. Run `flutter analyze`, `flutter test`, Android release build, and iOS archive
   on CI. Test English and French on small and large devices.
9. Add APNs/FCM delivery credentials if notifications must arrive while MapLov
   is closed. In-app notifications and realtime database updates already work;
   background push delivery is an external platform configuration.
