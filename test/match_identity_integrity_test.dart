import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matching migration rejects profile and photo self-likes', () {
    final migration = File(
      'supabase/migrations/202608200058_match_identity_integrity.sql',
    ).readAsStringSync();

    expect(migration, contains('profile_likes_distinct_users'));
    expect(migration, contains('liker_id <> liked_id'));
    expect(migration, contains('reject_own_photo_like'));
    expect(migration, contains('photo.user_id <> auth.uid()'));
  });
}
