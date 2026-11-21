import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Turns the raw photo from the camera into the final mirrored photo.
///
/// The raw photo (front or back) is NOT mirrored by the camera hardware, so
/// the final file is always: bake EXIF rotation -> light enhancement ->
/// flip horizontally. The preview shows exactly the same mirrored view, so
/// what you see is what is saved. The flip is never undone.
///
/// All heavy work runs in a background isolate so the preview never lags.
class MirrorProcessor {
  MirrorProcessor._();

  /// Slight brightness/contrast + very light sharpening. Set false to skip.
  static const bool enhance = true;

  /// JPEG quality of the saved file (100 = maximum quality).
  static const int jpegQuality = 100;

  /// Returns the path of the mirrored JPEG (written next to [inputPath]).
  static Future<String> process(String inputPath) {
    final dir = File(inputPath).parent.path;
    final output = '$dir/mycam_${DateTime.now().microsecondsSinceEpoch}.jpg';
    return compute(
      _mirrorJob,
      _MirrorJob(inputPath, output, enhance, jpegQuality),
    );
  }
}

class _MirrorJob {
  const _MirrorJob(this.input, this.output, this.enhance, this.quality);

  final String input;
  final String output;
  final bool enhance;
  final int quality;
}

String _mirrorJob(_MirrorJob job) {
  final bytes = File(job.input).readAsBytesSync();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) {
    throw const FormatException('Could not decode the captured photo.');
  }

  // Make pixels upright first (applies EXIF orientation), then mirror.
  image = img.bakeOrientation(image);

  if (job.enhance) {
    image = img.adjustColor(image, brightness: 1.03, contrast: 1.04);
    // Gentle sharpen kernel (sums to 1, so overall brightness is unchanged).
    image = img.convolution(
      image,
      filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
      amount: 0.25,
    );
  }

  image = img.flip(image, direction: img.FlipDirection.horizontal);

  final jpg = img.encodeJpg(image, quality: job.quality);
  File(job.output).writeAsBytesSync(jpg, flush: true);
  return job.output;
}
