# MapLov MVP release-readiness report

Last updated: 2026-08-04

Accepted functional baseline: commit `ee26ffa`

## Executive assessment

MapLov is an advanced MVP in release-candidate preparation. The client and
backend feature set are substantially implemented and covered by automated
tests. The remaining launch risk is concentrated in store credentials,
merchant-provider acceptance, hosted-domain deployment, physical-device
testing, operational readiness, and legal/privacy decisions.

No new product functionality should be added to the release candidate unless
it resolves a launch blocker. Engineering work should preserve the accepted
baseline and improve verification, security, documentation and maintainability.

## Verified engineering baseline

- Flutter analysis completes without issues.
- Functional unit/widget/performance tests pass.
- The account-to-discovery integration smoke flow passes on macOS when built
  from a temporary path without File Provider metadata.
- Reviewed Play Store golden screenshots match the current UI.
- The Flutter release configuration disables demo data and testing bypasses.
- Account/social/billing/settings routes require authentication.
- Administration routes require an `admin` or `moderator` database role.
- All 49 repository migrations through `202608040049` match the linked
  Supabase project.
- Linked PostgreSQL lint reports no error-level findings.
- Eight Supabase Edge Functions are deployed and active.
- External hosted checkout is disabled by default on both client and server.

## Implemented product surface

- account signup, confirmation, login, recovery and deletion;
- profile, photo, residence/origin, body type and dating preferences;
- geographic discovery, nearby results and tier-based filters;
- likes, photo engagement, matches and compatibility details;
- conversations with text, audio, images and documents;
- posts, comments, friendships and notifications;
- private Secret Garden albums and access requests;
- reporting, blocking, moderation and administration console;
- English/French interface and persisted language preference;
- Free, Plus and VIP product presentation and entitlements;
- native store purchase verification and subscription event endpoints;
- Web hosted-checkout architecture, catalog and promotions;
- legal consent versions, data export and delayed erasure workflow.

## Release blockers outside the repository

1. Configure and protect Android upload signing; enroll in Play App Signing.
2. Complete App Store Connect and Google Play merchant products and sandbox
   acceptance tests.
3. Configure the Stripe webhook secret and complete payment-provider sandbox
   tests before enabling hosted checkout.
4. Deploy and verify `maplov.ca`, callback rewrites, Universal Links and Android
   App Links.
5. Validate production email, OAuth, SMS and push-notification delivery.
6. Complete physical-device acceptance testing and store pre-launch reports.
7. Resolve the legal/privacy decisions documented in the legal review notes,
   especially biometric processing and a non-biometric Québec alternative.
8. Publish and monitor support, privacy and child-safety contact channels.

## Local build-environment note

The workspace location is managed by macOS File Provider. Builds created
directly there can inherit Finder metadata that macOS codesigning rejects. The
same source builds and passes its smoke flow from `/private/tmp`, confirming an
environment/location issue rather than a Flutter failure. Android and iOS
simulator builds are not affected. Actual Android/iOS device smoke runs remain
required before release.

## Release decision

The codebase is suitable for continued internal testing. Public release should
remain blocked until every external item above has documented evidence and the
complete release checklist is signed off.
