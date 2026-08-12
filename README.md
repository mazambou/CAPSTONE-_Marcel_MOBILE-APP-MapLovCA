# MapLov Canada

MapLov is a bilingual English/French dating and social discovery application
for adults in Canada. The product combines profiles, geographic discovery,
likes and matches, private messaging, community posts, private photo albums,
moderation, and paid membership tiers.

This repository contains the Flutter client, the Supabase/PostgreSQL schema,
Row Level Security policies, database tests, and Supabase Edge Functions used
by the application.

## Current status

MapLov is an advanced MVP in release-candidate preparation. The validated
functional baseline includes:

- email/password authentication and six-digit email confirmation;
- profile setup, photos, preferences, residence and origin geography;
- discovery, nearby profiles, filters, likes, matches and compatibility;
- real-time conversations with text, voice, photo and document messages;
- friends, posts, comments, notifications and Secret Garden albums;
- reporting, blocking, profile/photo moderation and admin operations;
- English and French UI;
- Free, Plus and VIP feature tiers;
- native App Store/Play Billing integration points;
- Web-only hosted checkout architecture for Stripe, PayPal and Flutterwave;
- account export and delayed permanent deletion.

External checkout remains disabled by default until merchant configuration and
sandbox acceptance testing are complete. Mobile builds continue to use native
store billing.

See [the current release report](docs/MVP_RELEASE_READINESS_REPORT_2026-07-16.md)
and [the roadmap](docs/ROADMAP.md) for the remaining release work.

## Technology

- Flutter 3.44 / Dart 3.12
- Supabase Auth, PostgreSQL, Realtime, Storage and Edge Functions
- PostgreSQL Row Level Security
- Google Play Billing and Apple In-App Purchase through `in_app_purchase`
- Stripe, PayPal and Flutterwave hosted checkout on Flutter Web
- AWS Rekognition for consent-based profile photo comparison

## Repository layout

```text
lib/                  Flutter application
  config/             compile-time configuration and auth link rules
  models/             client domain models
  pages/              screens grouped by product area
  routes/             named routes and authentication/admin guards
  services/           auth, location, billing, localization and data access
  shared/             shared theme and widgets
supabase/
  functions/          server-side Edge Functions
  migrations/         versioned schema, RLS and database functions
  templates/          production authentication emails
  tests/              pgTAP database tests
test/                  unit, widget, performance and golden tests
integration_test/      release smoke flow
docs/                  operations, legal and store-release documentation
```

More detail is available in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Local setup

Prerequisites:

- Flutter stable compatible with Dart `^3.12.2`;
- Xcode for iOS/macOS builds;
- Android SDK and Java 17 for Android builds;
- Supabase CLI for schema and Edge Function work.

Install packages and validate the client:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Debug builds can use the checked-in publishable Supabase project configuration.
For an explicit environment, pass only the public client values:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never include the Supabase service-role key, payment provider secrets, SMTP
passwords, or AWS private credentials in Flutter defines or committed files.

## Validation commands

```bash
flutter analyze
flutter test
flutter test integration_test/mvp_release_smoke_test.dart -d DEVICE_ID
flutter build apk --debug
```

Golden Play Store screenshots are intentional release artifacts. Update them
only after the corresponding UI has been reviewed and accepted:

```bash
flutter test test/play_store_screenshots_test.dart --update-goldens
```

For linked-database validation:

```bash
supabase migration list
supabase db lint --linked --level error
```

## Production documentation

- [Authentication and verified links](docs/production_auth.md)
- [Supabase/PostgreSQL setup](docs/supabase_postgres_setup.md)
- [External payments](docs/external_payments_setup.md)
- [Face verification operations](docs/face_verification_operations.md)
- [Google Play release checklist](docs/play_store/release_checklist.md)
- [Google Play data safety](docs/play_store/data_safety_checklist.md)
- [Legal review notes](docs/legal/LEGAL_REVIEW_NOTES_2026-07-30.md)

## Contribution rules

The validated behavior must remain stable. Every change should pass formatting,
analysis and the complete test suite. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Author

Marcel Azambou — Mobile Developer, Trios College.

## License

See [LICENSE](LICENSE).
