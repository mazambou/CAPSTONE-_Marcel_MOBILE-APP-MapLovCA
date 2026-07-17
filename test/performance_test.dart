import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';

void main() {
  SupabaseConfig.forceUiOnlyForTesting = true;

  test('demo discovery transformations stay within the MVP budget', () async {
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < 100; index++) {
      final profiles = await MapLovRepository.instance.discoverProfiles();
      expect(profiles, isNotEmpty);
      profiles.toList().sort(
        (left, right) =>
            right.compatibilityScore.compareTo(left.compatibilityScore),
      );
    }
    stopwatch.stop();
    expect(
      stopwatch.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason: 'Local discovery work must not block a 60 fps interface.',
    );
  });
}
