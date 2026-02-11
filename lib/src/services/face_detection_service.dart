import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../utils/camera_image_converter.dart';

class FaceDetectionService {
  FaceDetector? _faceDetector;
  final bool enableContours;
  final bool enableClassification;

  FaceDetectionService({
    this.enableContours = false,
    this.enableClassification = false,
  }) {
    _initDetector();
  }

  void _initDetector() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: enableContours,
      enableClassification: enableClassification,
      minFaceSize: 0.15,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<List<Face>> processImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_faceDetector == null) return [];

    final rotation = rotationIntToImageRotation(camera.sensorOrientation);
    final inputImage = inputImageFromCameraImage(
      image: image,
      camera: camera,
      rotation: rotation,
    );

    if (inputImage == null) return [];

    return await _faceDetector!.processImage(inputImage);
  }

  void dispose() {
    _faceDetector?.close();
  }
}
