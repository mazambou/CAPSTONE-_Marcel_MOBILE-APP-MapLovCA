import 'dart:typed_data';

class PreparedReferenceSelfie {
  const PreparedReferenceSelfie({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

String supportedReferenceSelfieExtension(String fileName, String? mimeType) {
  final normalizedMime = mimeType?.trim().toLowerCase();
  if (normalizedMime == 'image/png') return 'png';
  if (normalizedMime == 'image/jpeg' || normalizedMime == 'image/jpg') {
    return 'jpg';
  }
  final dot = fileName.lastIndexOf('.');
  final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  return switch (extension) {
    'jpeg' => 'jpg',
    'jpg' || 'png' => extension,
    _ => '',
  };
}
