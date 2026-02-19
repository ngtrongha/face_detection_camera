import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum CameraImageFormat { jpeg, png }

class ImageProcessingRequest {
  final String filePath;
  final CameraImageFormat format;
  final bool flipHorizontal;
  final int jpegQuality;
  final Rect? cropRect;
  final double cropPadding;

  ImageProcessingRequest(
    this.filePath,
    this.format, {
    this.flipHorizontal = false,
    this.jpegQuality = 90,
    this.cropRect,
    this.cropPadding = 1.5,
  });
}

/// Returns the processed image as Uint8List.
Future<Uint8List> processCapturedImage(
  File file, {
  CameraImageFormat format = CameraImageFormat.jpeg,
  bool enableProcessing = true,
  bool flipHorizontal = false,
  int jpegQuality = 90,
  Rect? cropRect,
  double cropPadding = 1.5,
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
    jpegQuality: jpegQuality,
    cropRect: cropRect,
    cropPadding: cropPadding,
  );
  final processedBytes = await compute(_processImageIsolate, request);
  return processedBytes;
}

Uint8List _processImageIsolate(ImageProcessingRequest request) {
  final file = File(request.filePath);
  final bytes = file.readAsBytesSync();

  // Decode the image first, before deleting the file
  final image = img.decodeImage(bytes);

  if (image == null) {
    // Keep original file for debugging if decode fails
    throw Exception('Unable to decode image: ${request.filePath}');
  }

  // Clean up original file only after successful decode
  try {
    file.deleteSync();
  } catch (_) {}

  // Flip for front camera if requested
  img.Image processedImage = request.flipHorizontal
      ? img.flipHorizontal(image)
      : image;

  // Crop to face if cropRect is provided
  if (request.cropRect != null) {
    processedImage = _cropToFace(
      processedImage,
      request.cropRect!,
      request.cropPadding,
    );
  }

  // Encode based on requested format
  if (request.format == CameraImageFormat.png) {
    return img.encodePng(processedImage);
  } else {
    return img.encodeJpg(processedImage, quality: request.jpegQuality);
  }
}

/// Crops the image to the face bounding box with padding.
img.Image _cropToFace(img.Image image, Rect faceRect, double padding) {
  // Calculate padded rect
  final centerX = faceRect.center.dx;
  final centerY = faceRect.center.dy;
  final halfWidth = (faceRect.width * padding) / 2;
  final halfHeight = (faceRect.height * padding) / 2;

  // Ensure bounds are within image
  int x = (centerX - halfWidth).round().clamp(0, image.width - 1);
  int y = (centerY - halfHeight).round().clamp(0, image.height - 1);
  int width = (halfWidth * 2).round().clamp(1, image.width - x);
  int height = (halfHeight * 2).round().clamp(1, image.height - y);

  return img.copyCrop(image, x: x, y: y, width: width, height: height);
}
