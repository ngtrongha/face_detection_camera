import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

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
  // Convert YUV_420_888 to NV21 (Y + interleaved VU)
  final bytes = _convertYUV420ToNV21(image);
  final size = Size(image.width.toDouble(), image.height.toDouble());

  final imageMetaData = InputImageMetadata(
    size: size,
    rotation: rotation,
    format: InputImageFormat.nv21,
    bytesPerRow: image.planes.first.bytesPerRow,
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

/// Convert [CameraImage] in YUV_420_888 to a single NV21 byte buffer.
Uint8List _convertYUV420ToNV21(CameraImage image) {
  final int width = image.width;
  final int height = image.height;
  final int ySize = width * height;
  final Uint8List nv21 = Uint8List(ySize + width * height ~/ 2);

  // Y plane
  final Plane yPlane = image.planes[0];
  int offset = 0;
  for (int row = 0; row < height; row++) {
    final int rowStart = row * yPlane.bytesPerRow;
    nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
    offset += width;
  }

  // UV planes (interleave V then U)
  final Plane uPlane = image.planes[1];
  final Plane vPlane = image.planes[2];
  final int uvWidth = (width / 2).ceil();
  final int uvHeight = (height / 2).ceil();
  int uvIndex = ySize;
  for (int row = 0; row < uvHeight; row++) {
    final int uRowStart = row * uPlane.bytesPerRow;
    final int vRowStart = row * vPlane.bytesPerRow;
    for (int col = 0; col < uvWidth; col++) {
      final int uIndex = uRowStart + col * (uPlane.bytesPerPixel ?? 1);
      final int vIndex = vRowStart + col * (vPlane.bytesPerPixel ?? 1);
      nv21[uvIndex++] = vPlane.bytes[vIndex];
      nv21[uvIndex++] = uPlane.bytes[uIndex];
    }
  }

  return nv21;
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
