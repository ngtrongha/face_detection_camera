import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum CameraImageFormat { jpeg, png }

class ImageProcessingRequest {
  final String filePath;
  final CameraImageFormat format;
  final bool flipHorizontal;

  ImageProcessingRequest(
    this.filePath,
    this.format, {
    this.flipHorizontal = false,
  });
}

/// Returns the processed image as Uint8List.
Future<Uint8List> processCapturedImage(
  File file, {
  CameraImageFormat format = CameraImageFormat.jpeg,
  bool enableProcessing = true,
  bool flipHorizontal = false,
}) async {
  if (!enableProcessing) {
    // Optimization: Skip isolate and decoding entirely.
    // Returns raw bytes from camera. Fast but might have wrong orientation.
    final bytes = file.readAsBytesSync();
    file.deleteSync();
    return bytes;
  }

  // Use compute to run image processing in a separate isolate
  final request = ImageProcessingRequest(
    file.path,
    format,
    flipHorizontal: flipHorizontal,
  );
  final processedBytes = await compute(_processImageIsolate, request);
  return processedBytes;
}

Uint8List _processImageIsolate(ImageProcessingRequest request) {
  final file = File(request.filePath);
  final bytes = file.readAsBytesSync();

  // Clean up original file immediately
  file.deleteSync();

  // If default JPEG and no rotation needed, we could return bytes directly.
  // But to ensure consistency (and handle orientation), we decode & encode.
  // Optimization: If you TRUST the camera plugin's orientation, you can skip this.

  // Decode the image
  final image = img.decodeImage(bytes);

  if (image == null) {
    throw Exception('Unable to decode image');
  }

  // Flip for front camera if requested
  img.Image finalImage = request.flipHorizontal
      ? img.flipHorizontal(image)
      : image;

  // Encode based on requested format
  if (request.format == CameraImageFormat.png) {
    return img.encodePng(finalImage);
  } else {
    return img.encodeJpg(finalImage, quality: 90);
  }
}
