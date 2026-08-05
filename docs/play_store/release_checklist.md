# MapLov Android Release checklist

## Automated and code-ready

- [x] Flutter Analyze
- [x] Widget test suite
- [x] Reviewed Play Store golden screenshots
- [x] MVP integration smoke-test scenario implemented
- [x] MVP account-to-discovery smoke flow passed on local macOS host
- [x] Local discovery performance budget
- [x] Debug Android APK build
- [x] Release-mode Android App Bundle build using temporary debug signing
- [x] Debug iOS simulator build
- [x] R8 code shrinking and resource shrinking
- [x] Cleartext traffic disabled
- [x] Android backups disabled for sensitive account data
- [x] Debug phone-verification bypass excluded from Release
- [x] Public routes guarded against unauthenticated demo leakage
- [x] Account, social, billing and settings routes authentication-guarded
- [x] Data export and delayed permanent-erasure backend
- [x] Report rate limits and target validation
- [x] Permanent Android application ID set to `ca.maplov.app`
- [x] Local and linked Supabase migrations synchronized through migration 049
- [x] Linked PostgreSQL lint has no error-level findings

## Device and release-build validation

- [ ] Run the MVP smoke flow on an Android emulator
- [ ] Run the MVP smoke flow on a physical Android device
- [ ] Run the MVP smoke flow on an iOS simulator
- [ ] Run the MVP smoke flow on a physical iPhone
- [ ] Build the signed production Android App Bundle
- [ ] Build and archive the signed production iOS application
- [ ] Verify foreground location, camera, microphone and file attachments
- [ ] Verify email confirmation, recovery and verified HTTPS callbacks

## Owner / Play Console actions

- [ ] Create and securely back up the upload keystore
- [ ] Replace debug Release signing with the upload signing configuration
- [ ] Create/verify the Google Play developer account
- [ ] Enrol in Play App Signing
- [ ] Configure public privacy-policy and account-deletion URLs
- [ ] Verify support and child-safety email addresses
- [ ] Complete Data Safety, Child Safety, content rating and app access forms
- [ ] Configure Google Play subscription products and purchase verification
- [ ] Configure SMS, Google OAuth and Firebase Cloud Messaging
- [ ] Upload the AAB to Internal testing
- [ ] Complete required closed testing when applicable
- [ ] Review Android vitals and pre-launch report
- [ ] Obtain legal review of Terms, Privacy and Community Guidelines

## Release command

```bash
flutter test
flutter test integration_test/mvp_release_smoke_test.dart
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```
