import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'face verification accepts authenticated browser preflight requests',
    () {
      final source = File(
        'supabase/functions/verify-profile-photo/index.ts',
      ).readAsStringSync();
      final config = File('supabase/config.toml').readAsStringSync();

      expect(source, contains("request.method === 'OPTIONS'"));
      expect(source, contains("'Access-Control-Allow-Origin': '*'"));
      expect(
        source,
        contains('authorization, apikey, content-type, x-client-info'),
      );
      final functionConfig = config
          .split('[functions.verify-profile-photo]')[1]
          .split('[functions.verify-store-purchase]')[0];
      expect(functionConfig, contains('verify_jwt = true'));
    },
  );
}
