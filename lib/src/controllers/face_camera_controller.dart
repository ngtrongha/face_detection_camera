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

  // Output
  Uint8List? _capturedImage;
  Uint8List? get capturedImage => _capturedImage;

  // Stream for UI feedback (bounding box)
  final ValueNotifier<Face?> _detectedFace = ValueNotifier<Face?>(null);
  ValueNotifier<Face?> get detectedFace => _detectedFace;

  // Stream for Countdown (High frequency update)
  final ValueNotifier<int> remainingSeconds = ValueNotifier<int>(0);
  // Facing forward status
  final ValueNotifier<bool> facingForward = ValueNotifier<bool>(true);

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
  }) {
    _countdownMilliseconds = captureCountdownDuration;
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
      notifyListeners();
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _state = FaceCameraState.error;
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
      _state = FaceCameraState.error;
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
    await _cameraController!.startImageStream(_processCameraImage);
  }

  void _initFaceDetector() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours:
          false, // Optimized: Turned off as we only need bounding box
      enableClassification: false,
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

        if (faces.isNotEmpty) {
          final face = faces.first;
          _detectedFace.value = face;

          if (autoCapture) {
            _checkStability(face);
          }
        } else {
          _detectedFace.value = null;
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
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
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

  CameraController? get cameraController => _cameraController;
  CameraLensDirection get cameraLensDirection =>
      _currentCamera?.lensDirection ?? CameraLensDirection.front;
}
