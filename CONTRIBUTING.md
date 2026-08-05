# Contributing to MapLov

The current application behavior is the accepted product baseline. Changes
must preserve existing user flows unless a product change is explicitly
approved.

## Before editing

1. Start from a clean working tree.
2. Read `README.md`, `docs/ARCHITECTURE.md`, and the documentation for the
   product area being changed.
3. Do not place private credentials in Dart defines, source files, fixtures,
   screenshots, logs, or commits.

## Required validation

Run these commands before proposing a change:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
git diff --check
```

For changes that affect Android configuration or plugins, also run:

```bash
flutter build appbundle --release
```

For schema and RLS changes, add a versioned migration and a pgTAP regression
test. Never edit a migration that has already been applied remotely.

## Change discipline

- Keep commits focused on one product or infrastructure concern.
- Add or update tests before changing validated behavior.
- Treat golden screenshots as reviewed release artifacts; do not regenerate
  them merely to hide a regression.
- Keep demo behavior behind the existing non-release safeguards.
- Perform authorization in PostgreSQL/RLS or a server function, not only in
  Flutter widgets.
- Never expose a Supabase service-role key or merchant secret to the client.
- Preserve English and French behavior when adding user-facing text.

## Generated and local files

Do not commit Flutter plugin metadata, `local.properties`, generated Xcode
configuration, build folders, test failures, environment files, signing keys,
or IDE-specific state. The repository ignore files cover these artifacts.
