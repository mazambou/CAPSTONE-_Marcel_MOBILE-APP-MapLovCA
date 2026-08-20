import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

import 'reference_selfie_image_types.dart';

const _maximumDimension = 1600;

/// Safari can return an HEIC camera capture. The web image-picker resizer asks
/// canvas to preserve that source MIME type and can consequently fall back to
/// the original HEIC bytes. MapLov accepts JPEG/PNG only, so reference selfies
/// are explicitly rendered to a bounded JPEG on Web before upload.
Future<PreparedReferenceSelfie> prepareReferenceSelfie(XFile selfie) async {
  final sourceBytes = await selfie.readAsBytes();
  if (sourceBytes.isEmpty) {
    throw const FormatException('The captured selfie is empty.');
  }
  final mimeType = selfie.mimeType?.trim().isNotEmpty == true
      ? selfie.mimeType!
      : 'application/octet-stream';
  // iOS Safari may revoke or make the image-picker blob URL unreadable before
  // an asynchronous HTMLImageElement load. A data URL owns its bytes for the
  // complete decode/resize operation and works for Safari camera HEIC input.
  final sourceUrl = 'data:$mimeType;base64,${base64Encode(sourceBytes)}';
  final image = web.HTMLImageElement()..src = sourceUrl;
  await image.onLoad.first.timeout(const Duration(seconds: 20));

  final sourceWidth = image.naturalWidth;
  final sourceHeight = image.naturalHeight;
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    throw const FormatException('The captured selfie could not be decoded.');
  }
  final scale = sourceWidth > sourceHeight
      ? (_maximumDimension / sourceWidth).clamp(0.0, 1.0)
      : (_maximumDimension / sourceHeight).clamp(0.0, 1.0);
  final width = (sourceWidth * scale).round().clamp(1, _maximumDimension);
  final height = (sourceHeight * scale).round().clamp(1, _maximumDimension);
  final canvas = web.HTMLCanvasElement()
    ..width = width
    ..height = height;
  final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
  if (context == null) {
    throw const FormatException('The browser cannot prepare this selfie.');
  }
  context.drawImage(image, 0, 0, width, height);

  final blobCompleter = Completer<web.Blob>();
  canvas.toBlob(
    ((web.Blob? blob) {
      if (blob == null) {
        blobCompleter.completeError(
          const FormatException('The browser could not encode the selfie.'),
        );
      } else {
        blobCompleter.complete(blob);
      }
    }).toJS,
    'image/jpeg',
    0.85.toJS,
  );
  final blob = await blobCompleter.future.timeout(const Duration(seconds: 20));
  final reader = web.FileReader()..readAsArrayBuffer(blob);
  await reader.onLoadEnd.first.timeout(const Duration(seconds: 20));
  final bytes = (reader.result as JSArrayBuffer?)?.toDart.asUint8List();
  if (bytes == null || bytes.isEmpty) {
    throw const FormatException('The encoded selfie is empty.');
  }
  return PreparedReferenceSelfie(bytes: bytes, extension: 'jpg');
}
