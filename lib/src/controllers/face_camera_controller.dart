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

class FaceCameraController extends ChangeNotifier {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;

  FaceCameraState _state = FaceCameraState.loading;
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
  final int captureCountdownDuration; // ms

  int _countdownMilliseconds = 3000;
  int get countdownMilliseconds => _countdownMilliseconds;

  // Settings
  final bool autoCapture;
  final ResolutionPreset resolutionPreset;
  final bool enableAudio;
  final CameraLensDirection initialCameraLensDirection;

  // Output
  File? _capturedImage;
  File? get capturedImage => _capturedImage;

  // Stream for UI feedback (bounding box)
  final ValueNotifier<Face?> _detectedFace = ValueNotifier<Face?>(null);
  ValueNotifier<Face?> get detectedFace => _detectedFace;

  FaceCameraController({
    this.autoCapture = true,
    this.resolutionPreset = ResolutionPreset.high,
    this.enableAudio = true,
    this.captureCountdownDuration = 3000,
    this.initialCameraLensDirection = CameraLensDirection.front,
  }) {
    _countdownMilliseconds = captureCountdownDuration;
  }

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
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup
                .nv21 // Better for ML Kit on Android
          : ImageFormatGroup.bgra8888, // iOS
    );

    await _cameraController!.initialize();
    await _cameraController!.startImageStream(_processCameraImage);
  }

  void _initFaceDetector() {
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: true,
      enableClassification: false,
    );
    _faceDetector = FaceDetector(options: options);
  }

  bool _isProcessing = false;
  DateTime? _lastProcessingTime;
  final int _processIntervalMs = 50; // Throttle: process every 50ms

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
  }

  void _startCountdown() {
    if (_state == FaceCameraState.stable) return;

    _state = FaceCameraState.stable;
    _countdownMilliseconds = captureCountdownDuration; // Reset
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      _countdownMilliseconds -= 100;
      if (_countdownMilliseconds <= 0) {
        timer.cancel();
        capture();
      } else {
        notifyListeners();
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

  void pause() {
    _isPaused = true;
    _stopCountdown();
    // Optionally set state to something else if needed, but keeping current state
    // allows resuming from where we left off (mostly).
    // However, for UI clarity, maybe we should stay in current state.
  }

  void resume() {
    _isPaused = false;
    // No specific state reset needed, next frame will process.
  }

  Future<void> capture() async {
    if (_state == FaceCameraState.capturing) return;

    _stopCountdown();
    _state = FaceCameraState.capturing;
    notifyListeners();

    try {
      final XFile file = await _cameraController!.takePicture();

      final File processed = await processCapturedImage(File(file.path));

      _capturedImage = processed;
      _state = FaceCameraState.captured;
      notifyListeners();
    } catch (e) {
      debugPrint('Error capturing: $e');
      _state = FaceCameraState.error;
      notifyListeners();
    }
  }

  void reset() {
    _capturedImage = null;
    _resetStability();
    _state = FaceCameraState.searching;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

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
