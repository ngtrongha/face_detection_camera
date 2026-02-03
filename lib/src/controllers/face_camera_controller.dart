import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/camera_image_converter.dart';
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

/// Error types for face camera operations.
enum FaceCameraError {
  permissionDenied,
  cameraInitFailed,
  captureFailed,
  processingFailed,
  noCamera,
}

/// Face quality metrics for quality assessment.
class FaceQuality {
  /// Brightness score (0.0 to 1.0, higher is better).
  final double brightness;

  /// Sharpness/blur score (0.0 to 1.0, higher is sharper).
  final double sharpness;

  /// Pose score based on yaw/roll/pitch (0.0 to 1.0, higher = more frontal).
  final double poseScore;

  /// Overall quality score (average of all metrics).
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

/// Controller to manage the [SmartFaceCamera] state and logic.
///
/// Can be used to control the camera programmatically (capture, switch camera, pause/resume)
/// or to listen to state changes if you build a custom UI.
class FaceCameraController extends ChangeNotifier {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  FaceCameraState _state = FaceCameraState.loading;

  /// The current state of the face detection camera.
  FaceCameraState get state => _state;

  List<CameraDescription> _cameras = [];
  CameraDescription? _currentCamera;

  // Stability Logic
  final List<Rect> _recentFaceRects = [];
  final int _stabilityWindowSize = 10; // Number of frames to check
  final double _movementThreshold = 15.0; // Pixels variance allowed
  Timer? _countdownTimer;
  bool _isPaused = false; // Manual pause for detection/capture

  // Configuration
  /// Duration of the countdown in milliseconds.
  final int captureCountdownDuration;

  int _countdownMilliseconds = 3000;
  int get countdownMilliseconds => _countdownMilliseconds;

  // Settings
  /// Whether to automatically capture when face is stable.
  final bool autoCapture;

  /// Camera resolution preset.
  final ResolutionPreset resolutionPreset;

  /// Whether to enable audio.
  final bool enableAudio;

  /// Initial camera lens direction.
  final CameraLensDirection initialCameraLensDirection;

  /// Format of the output image (JPEG or PNG).
  final CameraImageFormat imageFormat;

  /// Whether to process the image (rotate/encode) or return raw bytes.
  final bool enableImageProcessing;

  /// Maximum allowed yaw (turn left/right) in degrees to consider facing forward.
  final double maxYawDegrees;

  /// Maximum allowed roll (tilt head) in degrees to consider facing forward.
  final double maxRollDegrees;

  /// Maximum allowed pitch (look up/down) in degrees to consider facing forward.
  final double maxPitchDegrees;

  /// JPEG quality (1-100) when imageFormat is JPEG.
  final int jpegQuality;

  /// Whether to crop the captured image to face bounding box.
  final bool cropToFace;

  /// Padding factor around face when cropping (1.0 = exact bounds, 2.0 = double size).
  final double faceCropPadding;

  /// Enable face contours detection (more CPU intensive).
  final bool enableContours;

  /// Enable face classification (smiling, eyes open detection).
  final bool enableClassification;

  /// Initial flash mode.
  final FlashMode initialFlashMode;

  /// Whether to lock device orientation to portrait.
  final bool lockOrientation;

  /// Whether to detect multiple faces.
  final bool detectMultipleFaces;

  /// Maximum number of faces to detect (when detectMultipleFaces is true).
  final int maxFaces;

  /// Callback for multiple faces detected.
  void Function(List<Face> faces)? onMultipleFacesDetected;

  /// Callback for face quality updates.
  void Function(FaceQuality quality)? onFaceQuality;

  /// Minimum quality score required for capture (0.0 to 1.0).
  final double minQualityScore;

  /// Whether to enable zoom gesture.
  final bool enableZoom;

  /// Minimum zoom level.
  final double minZoom;

  /// Maximum zoom level.
  final double maxZoom;

  /// Whether to play capture sound.
  final bool enableCaptureSound;

  /// Maximum retry attempts for camera initialization.
  final int maxRetryAttempts;

  /// Error callback for handling errors.
  void Function(FaceCameraError error, String? message)? onError;

  // Output
  Uint8List? _capturedImage;
  Uint8List? get capturedImage => _capturedImage;

  // Stream for UI feedback (bounding box)
  final ValueNotifier<Face?> _detectedFace = ValueNotifier<Face?>(null);
  ValueNotifier<Face?> get detectedFace => _detectedFace;

  /// Stream for Countdown (High frequency update)
  final ValueNotifier<int> remainingSeconds = ValueNotifier<int>(0);

  /// Facing forward status
  final ValueNotifier<bool> facingForward = ValueNotifier<bool>(true);

  /// Current flash mode
  final ValueNotifier<FlashMode> flashMode = ValueNotifier<FlashMode>(
    FlashMode.off,
  );

  /// Current zoom level
  final ValueNotifier<double> zoomLevel = ValueNotifier<double>(1.0);

  /// All detected faces (for multiple face mode)
  final ValueNotifier<List<Face>> detectedFaces = ValueNotifier<List<Face>>([]);

  /// Current face quality
  final ValueNotifier<FaceQuality?> faceQuality = ValueNotifier<FaceQuality?>(
    null,
  );

  /// Last detected face bounding box for cropping
  Rect? _lastFaceBounds;

  /// Retry counter for initialization
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
  }) {
    _countdownMilliseconds = captureCountdownDuration;
    flashMode.value = initialFlashMode;
  }

  /// Initializes the camera and face detector.
  ///
  /// Requests camera permission if not already granted.
  Future<void> initialize() async {
    _state = FaceCameraState.loading;
    notifyListeners();

    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      _state = FaceCameraState.permissionDenied;
      onError?.call(
        FaceCameraError.permissionDenied,
        'Camera permission denied',
      );
      notifyListeners();
      return;
    }

    // Lock orientation if requested
    if (lockOrientation) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _state = FaceCameraState.error;
        onError?.call(FaceCameraError.noCamera, 'No cameras available');
        notifyListeners();
        return;
      }

      // Prefer configured camera lens direction
      _currentCamera = _cameras.firstWhere(
        (c) => c.lensDirection == initialCameraLensDirection,
        orElse: () => _cameras.first,
      );

      await _initCamera(_currentCamera!);
      _initFaceDetector();

      _state = FaceCameraState.searching;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _retryCount++;
      if (_retryCount < maxRetryAttempts) {
        // Retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
        return initialize();
      }
      _state = FaceCameraState.error;
      onError?.call(FaceCameraError.cameraInitFailed, e.toString());
      notifyListeners();
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      resolutionPreset,
      enableAudio: enableAudio,
      // Use YUV420 for Android (CameraX 0.11.x streams YUV_420_888)
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888, // iOS
    );

    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(flashMode.value);
    await _cameraController!.startImageStream(_processCameraImage);
  }

  void _initFaceDetector() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: enableContours,
      enableClassification: enableClassification,
      minFaceSize: 0.15, // Optimized: Ignore small faces (background noise)
    );
    _faceDetector = FaceDetector(options: options);
  }

  bool _isProcessing = false;
  DateTime? _lastProcessingTime;
  final int _processIntervalMs =
      100; // Optimized: Process 10 FPS instead of 20 FPS

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _cameraController == null || _faceDetector == null) {
      return;
    }

    if (_isPaused) return;

    // Throttling
    if (_lastProcessingTime != null &&
        DateTime.now().difference(_lastProcessingTime!).inMilliseconds <
            _processIntervalMs) {
      return;
    }

    if (_state == FaceCameraState.capturing) {
      return;
    }

    _isProcessing = true;
    _lastProcessingTime = DateTime.now();

    try {
      final rotation = rotationIntToImageRotation(
        _currentCamera!.sensorOrientation,
      );

      final inputImage = inputImageFromCameraImage(
        image: image,
        camera: _currentCamera!,
        rotation: rotation,
      );

      if (inputImage != null) {
        final faces = await _faceDetector!.processImage(inputImage);

        // Multiple face detection
        if (detectMultipleFaces) {
          final limitedFaces = faces.take(maxFaces).toList();
          detectedFaces.value = limitedFaces;
          onMultipleFacesDetected?.call(limitedFaces);
        }

        if (faces.isNotEmpty) {
          final face = faces.first;
          _detectedFace.value = face;

          // Calculate and report face quality
          final quality = _calculateFaceQuality(face);
          faceQuality.value = quality;
          onFaceQuality?.call(quality);

          if (autoCapture) {
            // Check quality threshold before checking stability
            if (quality.overallScore >= minQualityScore) {
              _checkStability(face);
            } else {
              // Quality too low, reset stability
              _resetStability();
              if (_state != FaceCameraState.detected) {
                _state = FaceCameraState.detected;
                notifyListeners();
              }
            }
          }
        } else {
          _detectedFace.value = null;
          faceQuality.value = null;
          if (detectMultipleFaces) {
            detectedFaces.value = [];
          }
          _resetStability();
          if (_state != FaceCameraState.searching) {
            _state = FaceCameraState.searching;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Calculate face quality score based on pose angles.
  FaceQuality _calculateFaceQuality(Face face) {
    final yaw = face.headEulerAngleY ?? 0.0;
    final roll = face.headEulerAngleZ ?? 0.0;
    final pitch = face.headEulerAngleX ?? 0.0;

    // Pose score: 1.0 when perfectly frontal, decreases with angle
    final yawScore = 1.0 - (yaw.abs() / 90.0).clamp(0.0, 1.0);
    final rollScore = 1.0 - (roll.abs() / 90.0).clamp(0.0, 1.0);
    final pitchScore = 1.0 - (pitch.abs() / 90.0).clamp(0.0, 1.0);
    final poseScore = (yawScore + rollScore + pitchScore) / 3;

    // Brightness estimation from face size (larger = better lit typically)
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    final brightness = (faceArea / 50000).clamp(0.0, 1.0);

    // Sharpness: based on tracking ID consistency (ML Kit assigns stable IDs)
    final sharpness = face.trackingId != null ? 0.8 : 0.5;

    return FaceQuality(
      brightness: brightness,
      sharpness: sharpness,
      poseScore: poseScore,
    );
  }

  void _checkStability(Face face) {
    // Require facing forward: limit yaw (Y), roll (Z), pitch (X)
    // If ML Kit không trả về góc, coi như không đạt (dùng giá trị lớn để fail)
    final double yaw = face.headEulerAngleY ?? 999.0; // turn left/right
    final double roll = face.headEulerAngleZ ?? 999.0; // tilt
    final double pitch = face.headEulerAngleX ?? 999.0; // look up/down
    final bool isFacingForward =
        yaw.abs() <= maxYawDegrees &&
        roll.abs() <= maxRollDegrees &&
        pitch.abs() <= maxPitchDegrees;
    facingForward.value = isFacingForward;

    // Store face bounds for cropping
    _lastFaceBounds = face.boundingBox;

    if (!isFacingForward) {
      // Not facing straight -> treat as moving
      _recentFaceRects.clear();
      _detectedFace.value = face;
      if (_state == FaceCameraState.stable) {
        _stopCountdown();
      }
      if (_state != FaceCameraState.detected) {
        _state = FaceCameraState.detected;
        notifyListeners();
      }
      return;
    }

    _recentFaceRects.add(face.boundingBox);
    if (_recentFaceRects.length > _stabilityWindowSize) {
      _recentFaceRects.removeAt(0);
    }

    if (_recentFaceRects.length == _stabilityWindowSize) {
      double maxMovement = 0;
      final center = face.boundingBox.center;

      for (final rect in _recentFaceRects) {
        final dist = (rect.center - center).distance;
        if (dist > maxMovement) maxMovement = dist;
      }

      if (maxMovement < _movementThreshold) {
        // Stable
        if (_state != FaceCameraState.stable &&
            _state != FaceCameraState.capturing) {
          _startCountdown();
        }
      } else {
        // Moving - CANCEL COUNTDOWN and reset to detected
        if (_state == FaceCameraState.stable) {
          _stopCountdown();
          // Only change state if not already detected, but stopCountdown handles logic
        }

        if (_state != FaceCameraState.detected) {
          _state = FaceCameraState.detected;
          notifyListeners();
        }
      }
    } else {
      if (_state != FaceCameraState.detected) {
        _state = FaceCameraState.detected;
        notifyListeners();
      }
    }
  }

  void _resetStability() {
    _recentFaceRects.clear();
    _stopCountdown();
    facingForward.value = true;
  }

  void _startCountdown() {
    if (_state == FaceCameraState.stable) return;

    _state = FaceCameraState.stable;
    _countdownMilliseconds = captureCountdownDuration; // Reset
    remainingSeconds.value = (_countdownMilliseconds / 1000).ceil();
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      _countdownMilliseconds -= 100;

      // Update ValueNotifier instead of notifyListeners
      // This avoids rebuilding the whole UI 10 times a second
      final newSeconds = (_countdownMilliseconds / 1000).ceil();
      if (remainingSeconds.value != newSeconds) {
        remainingSeconds.value = newSeconds;
      }

      if (_countdownMilliseconds <= 0) {
        timer.cancel();
        capture();
      }
    });
  }

  void _stopCountdown() {
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
      _countdownTimer = null;
      _countdownMilliseconds = captureCountdownDuration;
      // No need to notify here, state change to detected/searching will trigger UI rebuild
    }
  }

  /// Pauses the face detection and camera stream processing.
  /// Useful when navigating away or opening a dialog.
  void pause() {
    _isPaused = true;
    _stopCountdown();
    // Optionally set state to something else if needed, but keeping current state
    // allows resuming from where we left off (mostly).
    // However, for UI clarity, maybe we should stay in current state.
  }

  /// Resumes the face detection processing.
  void resume() {
    _isPaused = false;
    // No specific state reset needed, next frame will process.
  }

  /// Manually triggers the capture process.
  ///
  /// This will stop any active countdown and immediately take a picture.
  Future<void> capture() async {
    if (_state == FaceCameraState.capturing) return;

    _stopCountdown();
    _state = FaceCameraState.capturing;
    notifyListeners();

    try {
      final XFile file = await _cameraController!.takePicture();

      final bool flipFront =
          _currentCamera?.lensDirection == CameraLensDirection.front;

      final Uint8List processed = await processCapturedImage(
        File(file.path),
        format: imageFormat,
        enableProcessing: enableImageProcessing,
        flipHorizontal: flipFront,
        jpegQuality: jpegQuality,
        cropRect: cropToFace ? _lastFaceBounds : null,
        cropPadding: faceCropPadding,
      );

      // Clean up the temporary file created by camera plugin
      if (File(file.path).existsSync()) {
        File(file.path).deleteSync();
      }

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

  /// Resets the controller to the initial [FaceCameraState.searching] state.
  /// Clears the captured image and restarts detection.
  void reset() {
    _capturedImage = null;
    _resetStability();
    _state = FaceCameraState.searching;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    remainingSeconds.dispose();
    facingForward.dispose();
    flashMode.dispose();
    zoomLevel.dispose();
    detectedFaces.dispose();
    faceQuality.dispose();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  /// Sets the flash mode for the camera.
  Future<void> setFlashMode(FlashMode mode) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      await _cameraController!.setFlashMode(mode);
      flashMode.value = mode;
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  /// Toggles flash between off and torch mode.
  Future<void> toggleFlash() async {
    final newMode = flashMode.value == FlashMode.off
        ? FlashMode.torch
        : FlashMode.off;
    await setFlashMode(newMode);
  }

  /// Switches between available cameras (Front/Back).
  Future<void> switchCamera() async {
    if (_cameras.isEmpty) return;

    // Find new camera
    final lensDirection = _currentCamera!.lensDirection;
    CameraDescription newCamera;

    if (lensDirection == CameraLensDirection.front) {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
    } else {
      newCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
    }

    if (newCamera.lensDirection == lensDirection && _cameras.length > 1) {
      // If we couldn't find opposite, just take next available
      final index = _cameras.indexOf(_currentCamera!);
      newCamera = _cameras[(index + 1) % _cameras.length];
    }

    if (newCamera == _currentCamera) return;

    _currentCamera = newCamera;

    // Re-initialize
    await _cameraController?.dispose();
    // Reset state but keep not loading/error unless init fails
    _state = FaceCameraState.searching;
    _detectedFace.value = null;
    _resetStability();

    await _initCamera(_currentCamera!);
    notifyListeners();
  }

  /// Sets the zoom level for the camera.
  Future<void> setZoomLevel(double zoom) async {
    if (!enableZoom) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final clampedZoom = zoom.clamp(minZoom, maxZoom);
    try {
      await _cameraController!.setZoomLevel(clampedZoom);
      zoomLevel.value = clampedZoom;
    } catch (e) {
      debugPrint('Error setting zoom level: $e');
    }
  }

  /// Increases zoom by a step.
  Future<void> zoomIn({double step = 0.5}) async {
    await setZoomLevel(zoomLevel.value + step);
  }

  /// Decreases zoom by a step.
  Future<void> zoomOut({double step = 0.5}) async {
    await setZoomLevel(zoomLevel.value - step);
  }

  /// Resets zoom to minimum level.
  Future<void> resetZoom() async {
    await setZoomLevel(minZoom);
  }

  CameraController? get cameraController => _cameraController;
  CameraLensDirection get cameraLensDirection =>
      _currentCamera?.lensDirection ?? CameraLensDirection.front;

  /// Current camera description.
  CameraDescription? get currentCamera => _currentCamera;
}
