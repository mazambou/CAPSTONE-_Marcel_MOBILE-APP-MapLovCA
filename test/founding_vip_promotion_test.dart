import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/services/maplov_repository.dart';

void main() {
  const migrationPath =
      'supabase/migrations/202608200059_founding_vip_first_1000.sql';

  late String migration;

  setUpAll(() {
    migration = File(migrationPath).readAsStringSync();
  });

  test('the 1,001st profile irreversibly ends the founding promotion', () {
    expect(
      migration,
      contains('member_threshold integer not null default 1000'),
    );
    expect(migration, contains('registered_count + 1 > member_threshold'));
    expect(
      migration,
      contains('ended_at is deliberately preserved'),
      reason: 'Deleting accounts must never restart an expired promotion.',
    );
  });

  test('profile counter transition is serialized in the database', () {
    expect(migration, contains('update private.founding_vip_promotion'));
    expect(migration, contains('after insert or delete on public.profiles'));
    expect(migration, contains('for each row execute function'));
  });

  test('paid tiers remain separate from effective promotional VIP', () {
    expect(migration, contains('private.actual_subscription_tier'));
    expect(migration, contains("base_tier not in ('elite', 'vip')"));
    expect(migration, contains("'base_tier', base_tier::text"));

    const promotional = SubscriptionInfo(
      tier: 'vip',
      baseTier: 'free',
      isPromotionalVip: true,
      promotionActive: true,
      promotionMemberCount: 742,
    );
    expect(promotional.isVip, isTrue);
    expect(promotional.hasPaidSubscription, isFalse);
    expect(promotional.baseDisplayName, 'Standard');

    const paidVip = SubscriptionInfo(tier: 'vip', baseTier: 'vip');
    expect(paidVip.hasPaidSubscription, isTrue);
    expect(paidVip.baseDisplayName, 'VIP');
  });
}
