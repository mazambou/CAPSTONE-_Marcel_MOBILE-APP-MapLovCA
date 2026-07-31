# MapLov verified-link association files

Android and iOS only trust `https://maplov.ca/auth/callback` after the
production signing identities have been published by the same HTTPS origin.

Generate both JSON documents from the repository root:

```sh
./tool/generate_auth_associations.sh APPLE_TEAM_ID ANDROID_PLAY_SHA256
```

The command validates both identifiers and writes:

- `assetlinks.json` for Android App Links;
- `apple-app-site-association` for iOS Universal Links.

Deploy both files at their exact paths without authentication or redirects:

- `https://maplov.ca/.well-known/assetlinks.json`
- `https://maplov.ca/.well-known/apple-app-site-association`

The Android value must come from **Play Console → Setup → App integrity →
App signing key certificate**, not from the local debug keystore. The Apple
value is the ten-character Team ID shown in the Apple Developer account.
