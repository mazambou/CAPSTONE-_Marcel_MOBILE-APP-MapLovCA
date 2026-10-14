# Generated screenshots

Run `flutter test test/play_store_screenshots_test.dart --update-goldens` to regenerate the five phone screenshots from the current Flutter UI.

Run `flutter test test/play_store_screenshots_test.dart` on macOS to compare
them with the committed references. The Linux CI excludes these platform-
dependent golden comparisons while still verifying that every required PNG is
present and non-empty.
