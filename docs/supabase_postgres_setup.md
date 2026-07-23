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
never activates Premium from a client assertion. The Edge Functions validate
Google purchase tokens with the Google Play Developer API and Apple transaction
IDs with the App Store Server API. Store server notifications then keep renewal,
cancellation, expiration and refund state synchronized even when the app is not
open.

Create an ignored `supabase/.env.billing` file containing the following values:

```dotenv
GOOGLE_PLAY_PACKAGE_NAME=ca.maplov.app
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON={...single-line service account JSON...}
GOOGLE_PUBSUB_AUDIENCE=https://YOUR_PROJECT_REF.supabase.co/functions/v1/store-subscription-events
GOOGLE_PUBSUB_SERVICE_ACCOUNT=play-billing-push@YOUR_PROJECT.iam.gserviceaccount.com

APPLE_BUNDLE_ID=ca.maplov.app
APPLE_APP_ID=YOUR_NUMERIC_APPLE_APP_ID
APPLE_IAP_ISSUER_ID=YOUR_APP_STORE_CONNECT_ISSUER_ID
APPLE_IAP_KEY_ID=YOUR_IN_APP_PURCHASE_KEY_ID
APPLE_IAP_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
APPLE_ROOT_CERTIFICATES_BASE64=["BASE64_DER_APPLE_ROOT_CA", "BASE64_DER_SECOND_ROOT_IF_REQUIRED"]
```

The Google service account needs only the Google Play Android Developer API
permissions required to view and acknowledge subscriptions. Download the Apple
In-App Purchase key and Apple root certificates from App Store Connect/Apple
PKI; never commit them. Deploy with:

```sh
supabase secrets set --env-file supabase/.env.billing
supabase functions deploy verify-store-purchase
supabase functions deploy store-subscription-events --no-verify-jwt
```

Create these subscription product IDs in both stores:

```text
maplov_plus_monthly
maplov_elite_monthly
maplov_vip_monthly
```

In Google Cloud Pub/Sub, configure the Play real-time developer notification
topic to push to the `store-subscription-events` URL with authenticated push and
the exact audience/email above. In App Store Connect, configure the same URL as
the Version 2 production and sandbox server notification URL.

The database records each verified purchase, restore, renewal, cancellation,
expiration, refund and billing issue. Event IDs are unique, so store retries are
safe. Until the credentials and store notifications are configured, purchases
fail closed and Premium is not granted.

Official references: [Google Play backend integration](https://developer.android.com/google/play/billing/backend),
[Google subscriptions v2 API](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2),
[Apple App Store Server API](https://developer.apple.com/documentation/appstoreserverapi),
and [Apple Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications).

## Deploy AWS Rekognition face verification

Migration `202607200025_aws_face_reference_verification.sql` creates two
server-only biometric tables and two private Storage buckets:

- `identity-selfies` stores the one-time private reference selfie;
- `profile-media-pending` holds a new profile photo only while it is checked;
- only the Edge Function can copy a matching photo into `profile-media` and
  create its public database record.

Create a dedicated AWS IAM user or workload credential with only these
permissions (do not use an AWS root or administrator key):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rekognition:DetectFaces",
        "rekognition:CompareFaces"
      ],
      "Resource": "*"
    }
  ]
}
```

Store the credentials only as Supabase Function secrets and deploy the
function:

```sh
supabase secrets set \
  AWS_ACCESS_KEY_ID=YOUR_DEDICATED_ACCESS_KEY \
  AWS_SECRET_ACCESS_KEY=YOUR_DEDICATED_SECRET_KEY \
  AWS_REGION=ca-central-1 \
  REKOGNITION_SIMILARITY_THRESHOLD=95

supabase functions deploy verify-profile-photo
```

If temporary AWS credentials are used, also set `AWS_SESSION_TOKEN`. The
threshold is clamped to 80–100 and defaults to 95. Rekognition accepts only
JPEG/PNG byte payloads up to 5 MB, so both private buckets enforce the same
limits. The service fails closed when AWS is unavailable or not configured.
Each user is limited to 20 enrollment/comparison attempts per hour, and a
profile image must contain exactly one detectable face.

The initial selfie must contain exactly one high-confidence face. Subsequent
profile photos use `CompareFaces` with the `HIGH` quality filter. Comparison is
probabilistic: rejected photos should be retried with a clear image and edge
cases should be handled through a human support process rather than treating a
score as proof of identity.

## Storage path conventions

RLS expects these object paths:

```text
profile-media/<owner_uuid>/<file_name>
profile-media-pending/<owner_uuid>/<file_name>
identity-selfies/<owner_uuid>/<file_name>
post-media/<owner_uuid>/<post_uuid>/<file_name>
chat-media/<sender_uuid>/<conversation_uuid>/<file_name>
secret-garden/<owner_uuid>/<album_uuid>/<file_name>
```

All buckets are private. Access is granted by PostgreSQL policies, not by
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
- Reference selfies and face-comparison audit logs are never readable through
  the mobile Data API. Account erasure removes their rows and Storage objects.
- Authenticated clients cannot insert a public profile-photo row or upload into
  the final profile bucket; only the Rekognition Edge Function can do so.

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
