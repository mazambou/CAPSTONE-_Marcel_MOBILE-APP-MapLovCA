import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/services/location_service.dart';

void main() {
  group('Web residence reverse geocoding', () {
    test('parses a complete server response', () {
      final address = LocationService.parseWebResidence({
        'country': 'Canada',
        'countryCode': 'ca',
        'region': 'Ontario',
        'city': 'Toronto',
      });

      expect(address.country, 'Canada');
      expect(address.countryCode, 'CA');
      expect(address.region, 'Ontario');
      expect(address.city, 'Toronto');
    });

    test('rejects a response without a valid country', () {
      expect(
        () => LocationService.parseWebResidence({
          'country': '',
          'countryCode': '',
        }),
        throwsA(isA<ResidenceDetectionFailure>()),
      );
    });

    test('does not expose unexpected platform exceptions to users', () {
      final message = LocationService.residenceErrorMessage(
        StateError('Null check operator used on a null value'),
      );

      expect(message, contains('Unable to verify'));
      expect(message, isNot(contains('Null check operator')));
    });
  });
}
