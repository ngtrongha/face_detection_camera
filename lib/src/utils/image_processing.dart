import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Processes the captured image in a background isolate.
///
/// This function will:
/// 1. Decode the image file.
/// 2. Fix orientation if needed (though Camera plugin usually handles Exif).
/// 3. (Optional) Crop or resize if specified.
///
/// Returns the path to the processed file.
Future<File> processCapturedImage(File file) async {
  // Use compute to run image processing in a separate isolate
  final processedPath = await compute(_processImageIsolate, file.path);
  return File(processedPath);
}

String _processImageIsolate(String filePath) {
  final file = File(filePath);
  final bytes = file.readAsBytesSync();

  // Decode the image
  final image = img.decodeImage(bytes);

  if (image == null) {
    throw Exception('Unable to decode image');
  }

  // If we need to do any specific processing like resizing or baking orientation:
  // Note: img.decodeImage usually handles Exif orientation baking automatically
  // if we use decodeImage(bytes), but sometimes we might want to be explicit.

  // Example: Resize if too large (optional, based on requirements)
  // For now, we just re-encode to JPEG to ensure standard format and strip extra metadata if needed,
  // or simply return the original if no processing is actually needed.
  // But to demonstrate Isolate usage:

  // Let's say we just want to ensure it's a valid jpeg and maybe compress it slightly for performance
  final jpg = img.encodeJpg(image, quality: 90);

  // Overwrite or write to new file
  // For this example, we overwrite
  file.writeAsBytesSync(jpg);

  return filePath;
}
