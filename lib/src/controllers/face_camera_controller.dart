import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/camera_service.dart';
import '../services/face_detection_service.dart';
import '../services/stability_tracker.dart';
import '../utils/image_processing.dart';

enum FaceCameraState {
  loading,
  permissionDenied,
  searching, // Camera running, no face detected
  detected, // Face detected but moving/not stable
  stable, // Face stable, countdown started
  capturing, // Taking picture
  captured, // Picture taken
  error,
}

enum FaceCameraError {
  permissionDenied,
  cameraInitFailed,
  captureFailed,
  processingFailed,
  noCamera,
}

class FaceQuality {
  final double brightness;
  final double sharpness;
  final double poseScore;

  double get overallScore => (brightness + sharpness + poseScore) / 3;

  const FaceQuality({
    required this.brightness,
    required this.sharpness,
    required this.poseScore,
  });

  @override
  String toString() =>
      'FaceQuality(brightness: ${brightness.toStringAsFixed(2)}, '
      'sharpness: ${sharpness.toStringAsFixed(2)}, '
      'poseScore: ${poseScore.toStringAsFixed(2)}, '
      'overall: ${overallScore.toStringAsFixed(2)})';
}

class FaceCameraController extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  late final FaceDetectionService _faceDetectionService;
  late final StabilityTracker _stabilityTracker;

  FaceCameraState _state = FaceCameraState.loading;
  FaceCameraState get state => _state;

  bool _isPaused = false;

  // Settings
  final int captureCountdownDuration;
  final bool autoCapture;
  final ResolutionPreset resolutionPreset;
  final bool enableAudio;
  final CameraLensDirection initialCameraLensDirection;
  final CameraImageFormat imageFormat;
  final bool enableImageProcessing;
  final double maxYawDegrees;
  final double maxRollDegrees;
  final double maxPitchDegrees;
  final int jpegQuality;
  final bool cropToFace;
  final double faceCropPadding;
  final FlashMode initialFlashMode;
  final bool lockOrientation;
  final bool detectMultipleFaces;
  final int maxFaces;
  final double minQualityScore;
  final bool enableZoom;
  final double minZoom;
  final double maxZoom;
  final int maxRetryAttempts;

  final bool enableContours;
  final bool enableClassification;
  final bool enableCaptureSound;

  void Function(List<Face> faces)? onMultipleFacesDetected;
  void Function(FaceQuality quality)? onFaceQuality;
  void Function(FaceCameraError error, String? message)? onError;

  Uint8List? _capturedImage;
  Uint8List? get capturedImage => _capturedImage;

  final ValueNotifier<Face?> _detectedFace = ValueNotifier<Face?>(null);
  ValueNotifier<Face?> get detectedFace => _detectedFace;

  ValueNotifier<int> get remainingSeconds => _stabilityTracker.remainingSeconds;

  final ValueNotifier<bool> facingForward = ValueNotifier<bool>(true);
  final ValueNotifier<FlashMode> flashMode = ValueNotifier<FlashMode>(FlashMode.off);
  final ValueNotifier<double> zoomLevel = ValueNotifier<double>(1.0);
  final ValueNotifier<List<Face>> detectedFaces = ValueNotifier<List<Face>>([]);
  final ValueNotifier<FaceQuality?> faceQuality = ValueNotifier<FaceQuality?>(null);

  Rect? _lastFaceBounds;
  int _retryCount = 0;

  FaceCameraController({
    this.autoCapture = true,
    this.resolutionPreset = ResolutionPreset.high,
    this.enableAudio = true,
    this.captureCountdownDuration = 3000,
    this.initialCameraLensDirection = CameraLensDirection.front,
    this.imageFormat = CameraImageFormat.jpeg,
    this.enableImageProcessing = true,
    this.maxYawDegrees = 12.0,
    this.maxRollDegrees = 12.0,
    this.maxPitchDegrees = 12.0,
    this.jpegQuality = 90,
    this.cropToFace = false,
    this.faceCropPadding = 1.5,
    this.enableContours = false,
    this.enableClassification = false,
    this.initialFlashMode = FlashMode.off,
    this.lockOrientation = true,
    this.detectMultipleFaces = false,
    this.maxFaces = 5,
    this.onMultipleFacesDetected,
    this.onFaceQuality,
    this.minQualityScore = 0.0,
    this.enableZoom = false,
    this.minZoom = 1.0,
    this.maxZoom = 5.0,
    this.enableCaptureSound = false,
    this.maxRetryAttempts = 3,
    this.onError,
  }) : _faceDetectionService = FaceDetectionService(
          enableContours: enableContours,
          enableClassification: enableClassification,
        ) {
    flashMode.value = initialFlashMode;
    _stabilityTracker = StabilityTracker(
      countdownDuration: captureCountdownDuration,
      onStable: capture,
      onUnstable: () {
        if (_state == FaceCameraState.stable) {
          _state = FaceCameraState.detected;
          notifyListeners();
        }
      },
    );
  }

  Future<void> initialize() async {
    _state = FaceCameraState.loading;
    notifyListeners();

    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      _state = FaceCameraState.permissionDenied;
      onError?.call(FaceCameraError.permissionDenied, 'Camera permission denied');
      notifyListeners();
      return;
    }

    try {
      await _cameraService.initialize(
        initialDirection: initialCameraLensDirection,
        resolutionPreset: resolutionPreset,
        enableAudio: enableAudio,
        initialFlashMode: flashMode.value,
        lockOrientation: lockOrientation,
        onImageStream: _processCameraImage,
      );

      _state = FaceCameraState.searching;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _retryCount++;
      if (_retryCount < maxRetryAttempts) {
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
        return initialize();
      }
      _state = FaceCameraState.error;
      onError?.call(FaceCameraError.cameraInitFailed, e.toString());
      notifyListeners();
    }
  }

  bool _isProcessing = false;
  DateTime? _lastProcessingTime;
  final int _processIntervalMs = 100;

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _cameraService.controller == null || _isPaused) return;

    if (_lastProcessingTime != null &&
        DateTime.now().difference(_lastProcessingTime!).inMilliseconds < _processIntervalMs) {
      return;
    }

    if (_state == FaceCameraState.capturing) return;

    _isProcessing = true;
    _lastProcessingTime = DateTime.now();

    try {
      final faces = await _faceDetectionService.processImage(
        image,
        _cameraService.currentCamera!,
      );

      if (detectMultipleFaces) {
        final limitedFaces = faces.take(maxFaces).toList();
        detectedFaces.value = limitedFaces;
        onMultipleFacesDetected?.call(limitedFaces);
      }

      if (faces.isNotEmpty) {
        final face = faces.first;
        _detectedFace.value = face;

        final quality = _calculateFaceQuality(face);
        faceQuality.value = quality;
        onFaceQuality?.call(quality);

        if (autoCapture) {
          if (quality.overallScore >= minQualityScore) {
            _checkFaceMetadata(face);
          } else {
            _stabilityTracker.reset();
            _updateState(FaceCameraState.detected);
          }
        }
      } else {
        _detectedFace.value = null;
        faceQuality.value = null;
        if (detectMultipleFaces) detectedFaces.value = [];
        _stabilityTracker.reset();
        _updateState(FaceCameraState.searching);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _updateState(FaceCameraState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  FaceQuality _calculateFaceQuality(Face face) {
    final yaw = face.headEulerAngleY ?? 0.0;
    final roll = face.headEulerAngleZ ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;

    final yawScore = 1.0 - (yaw.abs() / 90.0).clamp(0.0, 1.0);
    final rollScore = 1.0 - (roll.abs() / 90.0).clamp(0.0, 1.0);
    final pitchScore = 1.0 - (pitch.abs() / 90.0).clamp(0.0, 1.0);
    final poseScore = (yawScore + rollScore + pitchScore) / 3;

    const brightness = 0.8;
    final sharpness = face.trackingId != null ? 0.9 : 0.6;

    return FaceQuality(
      brightness: brightness,
      sharpness: sharpness,
      poseScore: poseScore,
    );
  }

  void _checkFaceMetadata(Face face) {
    final double yaw = face.headEulerAngleY ?? 999.0;
    final double roll = face.headEulerAngleZ ?? 999.0;
    final double pitch = face.headEulerAngleX ?? 999.0;

    final bool isFacingForward =
        yaw.abs() <= maxYawDegrees &&
        roll.abs() <= maxRollDegrees &&
        pitch.abs() <= maxPitchDegrees;

    facingForward.value = isFacingForward;
    _lastFaceBounds = face.boundingBox;

    if (!isFacingForward) {
      _stabilityTracker.reset();
      _updateState(FaceCameraState.detected);
      return;
    }

    if (_state != FaceCameraState.stable && _state != FaceCameraState.capturing) {
      if (_state != FaceCameraState.stable) {
         // This is a bit tricky with the new tracker, we need to know if it's about to start
      }
    }

    _stabilityTracker.checkStability(face);

    // Check if tracker started countdown
    if (_stabilityTracker.remainingSeconds.value > 0 && _state != FaceCameraState.stable) {
       _state = FaceCameraState.stable;
       notifyListeners();
    }
  }

  void pause() {
    _isPaused = true;
    _stabilityTracker.reset();
  }

  void resume() {
    _isPaused = false;
  }

  Future<void> capture() async {
    if (_state == FaceCameraState.capturing) return;

    _stabilityTracker.reset();
    _state = FaceCameraState.capturing;
    notifyListeners();

    try {
      final XFile file = await _cameraService.takePicture();
      final bool flipFront = _cameraService.currentCamera?.lensDirection == CameraLensDirection.front;

      final Uint8List processed = await processCapturedImage(
        File(file.path),
        format: imageFormat,
        enableProcessing: enableImageProcessing,
        flipHorizontal: flipFront,
        jpegQuality: jpegQuality,
        cropRect: cropToFace ? _lastFaceBounds : null,
        cropPadding: faceCropPadding,
      );

      _capturedImage = processed;
      _state = FaceCameraState.captured;
      notifyListeners();
    } catch (e) {
      debugPrint('Error capturing: $e');
      _state = FaceCameraState.error;
      onError?.call(FaceCameraError.captureFailed, e.toString());
      notifyListeners();
    }
  }

  void reset() {
    _capturedImage = null;
    _stabilityTracker.reset();
    _state = FaceCameraState.searching;
    notifyListeners();
  }

  @override
  void dispose() {
    _stabilityTracker.dispose();
    _detectedFace.dispose();
    facingForward.dispose();
    flashMode.dispose();
    zoomLevel.dispose();
    detectedFaces.dispose();
    faceQuality.dispose();
    _cameraService.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  Future<void> setFlashMode(FlashMode mode) async {
    await _cameraService.setFlashMode(mode);
    flashMode.value = mode;
  }

  Future<void> toggleFlash() async {
    final newMode = flashMode.value == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await setFlashMode(newMode);
  }

  Future<void> switchCamera() async {
    await _cameraService.switchCamera(
      resolutionPreset: resolutionPreset,
      enableAudio: enableAudio,
      currentFlashMode: flashMode.value,
      onImageStream: _processCameraImage,
    );
    _state = FaceCameraState.searching;
    _detectedFace.value = null;
    _stabilityTracker.reset();
    notifyListeners();
  }

  Future<void> setZoomLevel(double zoom) async {
    if (!enableZoom) return;
    final clampedZoom = zoom.clamp(minZoom, maxZoom);
    await _cameraService.setZoomLevel(clampedZoom);
    zoomLevel.value = clampedZoom;
  }

  CameraController? get cameraController => _cameraService.controller;
  CameraLensDirection get cameraLensDirection => _cameraService.currentCamera?.lensDirection ?? CameraLensDirection.front;
  CameraDescription? get currentCamera => _cameraService.currentCamera;
}
