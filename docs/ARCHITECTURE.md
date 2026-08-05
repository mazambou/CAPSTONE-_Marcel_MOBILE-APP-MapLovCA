# MapLov architecture

## System boundary

MapLov consists of a Flutter client and a Supabase backend. Flutter holds only
public configuration and the authenticated user's session. PostgreSQL Row
Level Security and server functions remain authoritative for permissions,
entitlements, moderation, billing, and destructive administration operations.

```text
Flutter client
  ├─ Supabase Auth
  ├─ PostgreSQL + RLS
  ├─ Realtime subscriptions
  ├─ private/public Storage buckets
  └─ Edge Functions
       ├─ profile photo verification
       ├─ native store receipt verification
       ├─ native subscription events
       ├─ admin account deletion
       └─ external Web billing
```

## Flutter layers

- `lib/config`: compile-time public configuration and callback validation.
- `lib/models`: immutable view/domain models used across screens.
- `lib/pages`: product screens grouped by feature.
- `lib/routes`: centralized named routes plus authentication and role guards.
- `lib/services/auth_service.dart`: session and account lifecycle operations.
- `lib/services/maplov_repository.dart`: current Supabase data gateway and
  non-release demo implementation.
- `lib/services/purchase_service.dart`: Apple/Google native purchase flow.
- `lib/services/external_checkout_service.dart`: Web hosted checkout flow.
- `lib/services/locale_service.dart`: persisted English/French translations.
- `lib/shared`: reusable presentation components and theme.

The repository is intentionally the compatibility boundary while the MVP is
stabilized. Future extraction should split it by domain behind interfaces,
without changing queries and UI behavior in the same change.

## Authentication and routing

Public routes are limited to onboarding and account recovery/verification.
Account, social, billing and settings routes use the authenticated route guard.
Administration routes also resolve the current database role and admit only
`admin` or `moderator` accounts. Backend RLS remains required even when the UI
route is guarded.

Production authentication uses a six-digit signup email OTP. Recovery, email
change and OAuth flows use PKCE and the canonical HTTPS callback documented in
`docs/production_auth.md`.

## Data and authorization

Schema changes are append-only migrations in `supabase/migrations`. Deployed
migrations must never be rewritten. Sensitive account, exact-location,
moderation and billing data are separated or exposed through scoped database
functions. pgTAP tests in `supabase/tests` cover high-risk policies and flows.

## Billing boundary

Android and iOS digital purchases use their native stores. Flutter Web may use
hosted Stripe, PayPal or Flutterwave checkout only when both the client and
server feature switches are enabled. The server selects products and tiers;
the browser cannot submit arbitrary prices or entitlements. Webhooks are
verified, reconciled with the provider, and processed idempotently.

## Demo boundary

Demo records exist for widget tests and local UI review. `AppConfig` disables
demo data and testing bypasses in release builds. Production routes must never
fall back to demo identities when configuration or authentication is missing.

## Incremental technical roadmap

Large files should be reduced through behavior-preserving extractions:

1. introduce domain interfaces around the existing repository;
2. extract one domain at a time with repository contract tests;
3. move localization keys to generated ARB resources in small screen groups;
4. introduce explicit screen state objects where asynchronous behavior is
   currently duplicated;
5. keep every extraction independently releasable and test-green.
