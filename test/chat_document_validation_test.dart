import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/config/supabase_config.dart';
import 'package:maplove/services/maplov_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SupabaseConfig.forceUiOnlyForTesting = true;

  Future<void> send(Uint8List bytes, String extension) =>
      MapLovRepository.instance.sendMessageMedia(
        conversationId: 'demo-conversation',
        bytes: bytes,
        extension: extension,
        kind: 'document',
        fileName: 'test.$extension',
      );

  test('accepts valid PDF and office document signatures', () async {
    await send(Uint8List.fromList('%PDF-1.7'.codeUnits), 'pdf');
    await send(Uint8List.fromList([0x50, 0x4b, 0x03, 0x04, 0]), 'docx');
    await send(Uint8List.fromList('Hello, world'.codeUnits), 'txt');
  });

  test('rejects mismatched document content', () async {
    await expectLater(
      send(Uint8List.fromList('not a pdf'.codeUnits), 'pdf'),
      throwsArgumentError,
    );
    await expectLater(
      send(Uint8List.fromList([0, 1, 2]), 'txt'),
      throwsArgumentError,
    );
  });
}
