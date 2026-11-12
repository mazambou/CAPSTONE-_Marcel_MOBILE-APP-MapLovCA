# MapLov Android Release checklist

## Automated and code-ready

- [x] Flutter Analyze
- [x] Widget test suite
- [x] Reviewed Play Store golden screenshots
- [x] MVP integration smoke-test scenario implemented
- [x] MVP account-to-discovery smoke flow passed on local macOS host
- [x] Local discovery performance budget
- [x] Debug Android APK build
- [x] Release-mode Android App Bundle build as an unsigned validation artifact
- [x] Signed Android App Bundle built from a non-synchronized local copy on 2026-10-25
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
- [x] Apply linked Supabase migrations through migration 065 and deploy the Québec residence function and upgraded face function
- [x] Québec-only account-check registration and optional later face verification added without removing the existing face route; 21 SQL checks pass locally
- [x] Linked PostgreSQL lint has no error-level findings

## Device and release-build validation

- [x] Run the MVP smoke flow on an Android 16 emulator with 16 KB page size
- [ ] Run the MVP smoke flow on a physical Android device
- [ ] Run the MVP smoke flow on an iOS simulator
- [ ] Run the MVP smoke flow on a physical iPhone
- [x] Re-run the release AAB build from a local, non-synchronized workspace
- [x] Build the signed Android App Bundle with the new upload key
- [ ] Build and archive the signed production iOS application
- [ ] Verify foreground location, camera, microphone and file attachments
- [ ] Verify email confirmation, recovery and verified HTTPS callbacks
- [ ] Test both facial and non-biometric registration on a physical Android device

## Owner / Play Console actions

- [x] Create the upload keystore and store its password in the macOS Keychain
- [ ] Back up the upload keystore and Keychain password to a separate secure location
- [x] Configure Release signing with the upload keystore
- [x] Create/verify the Google Play developer account
- [ ] Create the `ca.maplov.app` application in Play Console
- [ ] Enrol in Play App Signing
- [ ] Get the Play **app-signing** certificate SHA-256 and publish `/.well-known/assetlinks.json` on Cloudflare Pages
- [x] Prepare public privacy-policy, account-deletion and child-safety pages
- [ ] Deploy and verify the latest public legal pages on `maplov.ca`
- [ ] Verify support and child-safety email addresses
- [ ] Name a backup child-safety contact and run the fictitious case exercise in `docs/child_safety_response.md`
- [ ] Verify the child-safety case log and external-referral process before checking the Play Console compliance declaration
- [ ] Complete Data Safety, Child Safety, content rating and app access forms
- [ ] Configure Google Play subscription products and purchase verification
- [ ] Configure SMS and Google OAuth
- [ ] Decide whether to implement Firebase Cloud Messaging before offering push notifications
- [ ] Upload the AAB to Internal testing
- [ ] Complete required closed testing when applicable
- [ ] Review Android vitals and pre-launch report
- [ ] Obtain legal review of Terms, Privacy and Community Guidelines
- [ ] Confirm Québec biometric-system declaration and privacy assessment before offering the optional face route there

## Release command

`android/key.properties` is ignored by Git. On this Mac it points to the upload
keystore under `~/Library/Application Support/MapLov/signing` and reads the
password from `MAPLOV_UPLOAD_PASSWORD`. The password is stored in the login
Keychain as account `maplov-upload`, service
`ca.maplov.app.android.upload`. Back up both the keystore and password
before enrolling in Play App Signing.

```bash
flutter test
flutter test integration_test/mvp_release_smoke_test.dart
export MAPLOV_UPLOAD_PASSWORD="$(security find-generic-password -a maplov-upload -s ca.maplov.app.android.upload -w)"
MAPLOV_REQUIRE_RELEASE_SIGNING=true flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
unset MAPLOV_UPLOAD_PASSWORD
```

Build from a local, non-synchronized copy of the project. The current signed
`1.0.0+1` candidate, including the Québec-only account-check path and voluntary
later photo verification, is stored at
`~/Library/Application Support/MapLov/releases/maplov-1.0.0+1-android-signed-20261025-quebec.aab`.
Its SHA-256 is
`86419289e6cbbf42e353456b4f163561ac9203d990f754468774a9ad5c89c0f0`.
Do not upload the earlier `-fr-ca.aab` candidate.
Rebuild after any source or version change. Play App Signing uses its own
app-signing certificate: use that certificate's SHA-256, not this upload
certificate, in `assetlinks.json`.
