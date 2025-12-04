import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Converts a [CameraImage] to an [InputImage] for ML Kit.
InputImage? inputImageFromCameraImage({
  required CameraImage image,
  required CameraDescription camera,
  required InputImageRotation? rotation,
}) {
  if (rotation == null) return null;

  // get image rotation
  // Note: The rotation calculation is usually done in the controller or view
  // based on device orientation and camera sensor orientation.
  // Here we assume the correct rotation is passed.

  // get image format
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  // validate format depending on platform
  // On Android, usually YUV_420_888 (35)
  // On iOS, usually BGRA8888 (1111970369)
  if (format == null ||
      (format != InputImageFormat.nv21 &&
          format != InputImageFormat.bgra8888)) {
    // For simplicity in this example, we might want to handle yuv420 specifically if nv21 isn't the direct map
    // But ML Kit usually handles yuv420 via nv21 or yuv420 mapping
  }

  // since format is nullable, we can try to proceed if we have planes
  if (image.planes.isEmpty) return null;

  // Compose InputImage
  // For Android (YUV420):
  if (image.format.group == ImageFormatGroup.yuv420) {
    return _processCameraImageYuv420(image, rotation);
  } else if (image.format.group == ImageFormatGroup.bgra8888) {
    return _processCameraImageBgra8888(image, rotation);
  }

  // Default fallback or error
  return null;
}

InputImage _processCameraImageYuv420(
  CameraImage image,
  InputImageRotation rotation,
) {
  final allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  final size = Size(image.width.toDouble(), image.height.toDouble());

  final imageMetaData = InputImageMetadata(
    size: size,
    rotation: rotation,
    format: InputImageFormat
        .nv21, // Android YUV420 is compatible with NV21 handling in ML Kit
    bytesPerRow: image.planes[0].bytesPerRow,
  );

  return InputImage.fromBytes(bytes: bytes, metadata: imageMetaData);
}

InputImage _processCameraImageBgra8888(
  CameraImage image,
  InputImageRotation rotation,
) {
  final allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  final size = Size(image.width.toDouble(), image.height.toDouble());

  final imageMetaData = InputImageMetadata(
    size: size,
    rotation: rotation,
    format: InputImageFormat.bgra8888,
    bytesPerRow: image.planes[0].bytesPerRow,
  );

  return InputImage.fromBytes(bytes: bytes, metadata: imageMetaData);
}

/// Helper to get [InputImageRotation] from camera sensor orientation and device orientation
InputImageRotation rotationIntToImageRotation(int rotation) {
  switch (rotation) {
    case 90:
      return InputImageRotation.rotation90deg;
    case 180:
      return InputImageRotation.rotation180deg;
    case 270:
      return InputImageRotation.rotation270deg;
    default:
      return InputImageRotation.rotation0deg;
  }
}
