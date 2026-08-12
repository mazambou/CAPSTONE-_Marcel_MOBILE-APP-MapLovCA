import 'package:image_picker/image_picker.dart';

import 'reference_selfie_image_io.dart'
    if (dart.library.js_interop) 'reference_selfie_image_web.dart'
    as platform;
import 'reference_selfie_image_types.dart';

export 'reference_selfie_image_types.dart';

Future<PreparedReferenceSelfie> prepareReferenceSelfie(XFile selfie) =>
    platform.prepareReferenceSelfie(selfie);
