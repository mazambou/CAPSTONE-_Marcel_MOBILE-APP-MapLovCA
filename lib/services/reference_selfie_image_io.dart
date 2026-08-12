import 'package:image_picker/image_picker.dart';

import 'reference_selfie_image_types.dart';

Future<PreparedReferenceSelfie> prepareReferenceSelfie(XFile selfie) async {
  final extension = supportedReferenceSelfieExtension(
    selfie.name,
    selfie.mimeType,
  );
  if (extension.isEmpty) {
    throw const FormatException('Use a JPEG or PNG reference selfie.');
  }
  return PreparedReferenceSelfie(
    bytes: await selfie.readAsBytes(),
    extension: extension,
  );
}
