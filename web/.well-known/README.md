# MapLov verified-link association files

Android and iOS only trust `https://maplov.ca/auth/callback` after the
production signing identities have been published by the same HTTPS origin.

Generate the Android document from the repository root:

```sh
./tool/generate_auth_associations.sh ANDROID_PLAY_SHA256
```

To generate both the Android and iOS documents, also provide the Apple Team ID:

```sh
./tool/generate_auth_associations.sh ANDROID_PLAY_SHA256 APPLE_TEAM_ID
```

The command validates the supplied identifiers and writes:

- `assetlinks.json` for Android App Links;
- `apple-app-site-association` for iOS Universal Links.

Deploy both files at their exact paths without authentication or redirects:

- `https://maplov.ca/.well-known/assetlinks.json`
- `https://maplov.ca/.well-known/apple-app-site-association`

On Cloudflare Pages, upload the entire Flutter `build/web` output after
generating these files. Its `_redirects` file must not contain a `/*`
rewrite: Pages applies that rule even when a static association file exists.
When no matching asset or `404.html` is deployed, Pages automatically serves
`index.html` for other Flutter client-side routes. Check that both public
association URLs return JSON content rather than the Flutter HTML page.

The Android value must come from **Play Console → Setup → App integrity →
App signing key certificate**, not from the local debug keystore. The Apple
value is the ten-character Team ID shown in the Apple Developer account.
