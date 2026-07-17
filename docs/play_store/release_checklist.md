# MapLov Android Release checklist

## Automated and code-ready

- [x] Flutter Analyze
- [x] Widget test suite
- [x] MVP integration smoke test
- [x] Local discovery performance budget
- [x] Android App Bundle build
- [x] R8 code shrinking and resource shrinking
- [x] Cleartext traffic disabled
- [x] Android backups disabled for sensitive account data
- [x] Debug phone-verification bypass excluded from Release
- [x] Public routes guarded against unauthenticated demo leakage
- [x] Data export and delayed permanent-erasure backend
- [x] Report rate limits and target validation

## Owner / Play Console actions

- [ ] Confirm the permanent application ID (currently `com.example.maplove`)
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
