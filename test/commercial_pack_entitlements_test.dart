import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migrationPath =
      'supabase/migrations/202608200057_complete_commercial_pack_entitlements.sql';

  late String migration;

  setUpAll(() {
    migration = File(migrationPath).readAsStringSync();
  });

  test('Super Likes are consumed atomically through a server RPC', () {
    expect(migration, contains('toggle_my_photo_super_like'));
    expect(migration, contains('for update'));
    expect(
      migration,
      contains('super_likes_balance = super_likes_balance - 1'),
    );
    expect(
      migration,
      contains('revoke insert, delete on public.photo_super_likes'),
    );
  });

  test('Boosts are the first stable Discover cursor key', () {
    expect(
      migration,
      contains("boost.entitlement_kind = ''boost''"),
      reason: 'The migration must inspect active Boost entitlements.',
    );
    expect(migration, contains('sort_boost'));
    expect(migration, contains("''boost'', value.sort_boost"));
  });

  test('Plus features are enforced at the database boundary', () {
    expect(migration, contains('rewind_my_last_profile_like'));
    expect(migration, contains('priority_rank'));
    expect(migration, contains('conversation_reads_plan_read'));
    expect(migration, contains('Secret Garden requests require Premium Plus'));
  });

  test('international discovery and VIP support use consistent rights', () {
    expect(
      migration,
      contains(
        'International discovery requires Premium VIP or an International Pass',
      ),
    );
    expect(migration, contains('submit_my_support_request'));
    expect(migration, contains('request_priority := 1'));
  });
}
