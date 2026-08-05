# MapLov roadmap

This roadmap starts from the accepted advanced-MVP baseline. It prioritizes
release reliability over adding new product features.

## Release candidate — local engineering

- [x] Keep production demo bypasses disabled.
- [x] Guard authenticated and administration routes.
- [x] Maintain Flutter analysis and functional widget coverage.
- [x] Maintain versioned Supabase migrations and Edge Functions.
- [x] Refresh reviewed Play Store golden screenshots.
- [x] Document the real Flutter/Supabase architecture.
- [x] Add continuous validation for formatting, analysis, tests and Android.
- [x] Pass the account-to-discovery smoke flow in a local desktop host build.
- [ ] Run the smoke flow on an Android emulator and a physical Android device.
- [ ] Run the smoke flow on an iOS simulator and a physical iPhone.
- [ ] Complete accessibility and small/large-screen manual review.

## Store and hosted-payment acceptance

- [ ] Configure Android upload signing and Play App Signing.
- [ ] Create and verify Google Play subscription and one-time products.
- [ ] Create and verify App Store Connect products.
- [ ] Configure the Stripe webhook signing secret.
- [ ] Synchronize and verify the Stripe product catalog.
- [ ] Configure PayPal and Flutterwave merchant plans if they remain in scope.
- [ ] Complete the hosted-payment sandbox matrix in
  `docs/external_payments_setup.md`.
- [ ] Verify refunds, renewal failures, cancellation and duplicate webhooks.

## Production services

- [ ] Publish the Web callback application and verified association files.
- [ ] Verify email delivery, OAuth, SMS and push notifications end to end.
- [ ] Confirm monitoring, alerting and an operational support procedure.
- [ ] Test account export, scheduled deletion and retention exceptions.

## Legal and store submission

- [ ] Complete the decisions in the legal review notes.
- [ ] Provide a non-biometric alternative before a Québec launch.
- [ ] Complete privacy and cross-border impact assessments.
- [ ] Publish privacy-policy, account-deletion and child-safety pages.
- [ ] Complete Play/App Store privacy, safety and content-rating forms.
- [ ] Upload to internal testing, review pre-launch results, then promote.

## Post-release architecture

- [ ] Split `MapLovRepository` behind domain interfaces.
- [ ] Extract large discovery, Premium, photo and chat widgets incrementally.
- [ ] Migrate localized strings to generated ARB resources.
- [ ] Add device-farm coverage for critical account and purchase flows.
- [ ] Add production observability only after privacy review and consent design.
