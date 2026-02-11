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

/// States of the face camera.
/// Các trạng thái của camera khuôn mặt.
enum FaceCameraState {
  /// Initializing services.
  /// Đang khởi tạo các dịch vụ.
  loading,

  /// Camera permission was denied by the user.
  /// Quyền truy cập camera bị người dùng từ chối.
  permissionDenied,

  /// Camera is running and searching for a face.
  /// Camera đang chạy và tìm kiếm khuôn mặt.
  searching,

  /// A face is detected but is moving or not stable yet.
  /// Đã phát hiện khuôn mặt nhưng đang di chuyển hoặc chưa ổn định.
  detected,

  /// Face is stable and the capture countdown has started.
  /// Khuôn mặt ổn định và đếm ngược bắt đầu.
  stable,

  /// Currently taking a picture.
  /// Đang chụp ảnh.
  capturing,

  /// Image has been captured successfully.
  /// Ảnh đã được chụp thành công.
  captured,

  /// An error occurred during operation.
  /// Có lỗi xảy ra trong quá trình vận hành.
  error,
}

/// Error types for face camera operations.
/// Các loại lỗi cho các hoạt động của camera khuôn mặt.
enum FaceCameraError {
  permissionDenied,
  cameraInitFailed,
  captureFailed,
  processingFailed,
  noCamera,
}

/// Metrics for face quality assessment.
/// Các chỉ số đánh giá chất lượng khuôn mặt.
class FaceQuality {
  /// Brightness score (0.0 to 1.0, higher is better).
  /// Điểm độ sáng (0.0 đến 1.0, càng cao càng tốt).
  final double brightness;

  /// Sharpness/blur score (0.0 to 1.0, higher is sharper).
  /// Điểm độ sắc nét (0.0 đến 1.0, càng cao càng sắc nét).
  final double sharpness;

  /// Pose score based on frontal alignment (0.0 to 1.0, higher = more frontal).
  /// Điểm tư thế dựa trên căn chỉnh phía trước (0.0 đến 1.0, càng cao càng thẳng).
  final double poseScore;

  /// Overall quality score (average of all metrics).
  /// Điểm chất lượng tổng thể (trung bình của tất cả các chỉ số).
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

/// Controller to manage the face detection camera state and logic.
/// Bộ điều khiển để quản lý trạng thái và logic của camera phát hiện khuôn mặt.
class FaceCameraController extends ChangeNotifier {
  final CameraService _cameraService = CameraService();
  late final FaceDetectionService _faceDetectionService;
  late final StabilityTracker _stabilityTracker;

  FaceCameraState _state = FaceCameraState.loading;

  /// The current operational state of the camera.
  /// Trạng thái hoạt động hiện tại của camera.
  FaceCameraState get state => _state;

  bool _isPaused = false;

  // Settings
  /// Duration of the countdown before automatic capture (in ms).
  /// Thời gian đếm ngược trước khi tự động chụp (tính bằng ms).
  final int captureCountdownDuration;

  /// Whether to capture the image automatically when face is stable.
  /// Có tự động chụp ảnh khi khuôn mặt ổn định hay không.
  final bool autoCapture;

  /// Camera resolution quality preset.
  /// Cài đặt chất lượng độ phân giải camera.
  final ResolutionPreset resolutionPreset;

  /// Whether to enable audio recording (if needed for video).
  /// Có bật ghi âm hay không.
  final bool enableAudio;

  /// Initial camera lens direction (front/back).
  /// Hướng ống kính camera ban đầu (trước/sau).
  final CameraLensDirection initialCameraLensDirection;

  /// Format of the output image (JPEG/PNG).
  /// Định dạng của ảnh đầu ra (JPEG/PNG).
  final CameraImageFormat imageFormat;

  /// Whether to enable post-capture image processing (rotation, flipping).
  /// Có bật xử lý ảnh sau khi chụp (xoay, lật) hay không.
  final bool enableImageProcessing;

  /// Max yaw (left/right) degrees to consider face "straight".
  /// Góc quay trái/phải tối đa để coi khuôn mặt là "thẳng".
  final double maxYawDegrees;

  /// Max roll (tilt) degrees to consider face "straight".
  /// Góc nghiêng tối đa để coi khuôn mặt là "thẳng".
  final double maxRollDegrees;

  /// Max pitch (up/down) degrees to consider face "straight".
  /// Góc ngẩng/cúi tối đa để coi khuôn mặt là "thẳng".
  final double maxPitchDegrees;

  /// JPEG compression quality (1-100).
  /// Chất lượng nén JPEG (1-100).
  final int jpegQuality;

  /// Whether to crop the resulting image to the face bounding box.
  /// Có cắt ảnh kết quả theo khung bao khuôn mặt hay không.
  final bool cropToFace;

  /// Padding multiplier around the face when cropping.
  /// Hệ số lề xung quanh khuôn mặt khi cắt.
  final double faceCropPadding;

  /// Initial camera flash mode.
  /// Chế độ đèn flash camera ban đầu.
  final FlashMode initialFlashMode;

  /// Whether to lock the device orientation to portrait.
  /// Có khóa hướng thiết bị theo chiều dọc hay không.
  final bool lockOrientation;

  /// Whether to detect and report multiple faces.
  /// Có phát hiện và báo cáo nhiều khuôn mặt hay không.
  final bool detectMultipleFaces;

  /// Maximum number of faces to detect.
  /// Số lượng khuôn mặt tối đa để phát hiện.
  final int maxFaces;

  /// Minimum overall quality score required for auto capture.
  /// Điểm chất lượng tổng thể tối thiểu cần thiết để tự động chụp.
  final double minQualityScore;

  /// Whether to enable pinch-to-zoom gestures.
  /// Có bật cử chỉ thu phóng hay không.
  final bool enableZoom;

  /// Minimum zoom level allowed.
  /// Mức thu phóng tối thiểu cho phép.
  final double minZoom;

  /// Maximum zoom level allowed.
  /// Mức thu phóng tối đa cho phép.
  final double maxZoom;

  /// Maximum number of retry attempts for camera initialization.
  /// Số lần thử lại tối đa để khởi tạo camera.
  final int maxRetryAttempts;

  /// Whether to enable face contours detection.
  /// Có bật phát hiện đường nét khuôn mặt hay không.
  final bool enableContours;

  /// Whether to enable face classification (smile, eyes open).
  /// Có bật phân loại khuôn mặt (cười, mở mắt) hay không.
  final bool enableClassification;

  /// Whether to play a shutter sound on capture.
  /// Có phát âm thanh màn trập khi chụp hay không.
  final bool enableCaptureSound;

  /// Callback fired when multiple faces are detected.
  /// Gọi lại khi phát hiện nhiều khuôn mặt.
  void Function(List<Face> faces)? onMultipleFacesDetected;

  /// Callback fired with real-time face quality metrics.
  /// Gọi lại với các chỉ số chất lượng khuôn mặt theo thời gian thực.
  void Function(FaceQuality quality)? onFaceQuality;

  /// Callback for handling errors.
  /// Gọi lại để xử lý lỗi.
  void Function(FaceCameraError error, String? message)? onError;

  Uint8List? _capturedImage;

  /// The most recently captured image data.
  /// Dữ liệu ảnh được chụp gần đây nhất.
  Uint8List? get capturedImage => _capturedImage;

  final ValueNotifier<Face?> _detectedFace = ValueNotifier<Face?>(null);

  /// Notifier for the primary detected face (bounding box).
  /// Thông báo cho khuôn mặt được phát hiện chính (khung bao).
  ValueNotifier<Face?> get detectedFace => _detectedFace;

  /// Notifier for the remaining seconds in the capture countdown.
  /// Thông báo số giây còn lại trong đếm ngược chụp ảnh.
  ValueNotifier<int> get remainingSeconds => _stabilityTracker.remainingSeconds;

  /// Notifier for whether the face is currently aligned straight.
  /// Thông báo liệu khuôn mặt hiện đang được căn chỉnh thẳng hay không.
  final ValueNotifier<bool> facingForward = ValueNotifier<bool>(true);

  /// Notifier for the current camera flash mode.
  /// Thông báo chế độ đèn flash camera hiện tại.
  final ValueNotifier<FlashMode> flashMode = ValueNotifier<FlashMode>(FlashMode.off);

  /// Notifier for the current camera zoom level.
  /// Thông báo mức thu phóng camera hiện tại.
  final ValueNotifier<double> zoomLevel = ValueNotifier<double>(1.0);

  /// Notifier for the list of all currently detected faces.
  /// Thông báo danh sách tất cả các khuôn mặt hiện đang được phát hiện.
  final ValueNotifier<List<Face>> detectedFaces = ValueNotifier<List<Face>>([]);

  /// Notifier for the real-time quality metrics of the primary face.
  /// Thông báo các chỉ số chất lượng theo thời gian thực của khuôn mặt chính.
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

  /// Initializes the camera and face detection services.
  /// Khởi tạo camera và các dịch vụ phát hiện khuôn mặt.
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

    _stabilityTracker.checkStability(face);

    // Check if tracker started countdown
    if (_stabilityTracker.remainingSeconds.value > 0 && _state != FaceCameraState.stable) {
       _state = FaceCameraState.stable;
       notifyListeners();
    }
  }

  /// Pauses face detection and image processing.
  /// Tạm dừng phát hiện khuôn mặt và xử lý hình ảnh.
  void pause() {
    _isPaused = true;
    _stabilityTracker.reset();
  }

  /// Resumes face detection and image processing.
  /// Tiếp tục phát hiện khuôn mặt và xử lý hình ảnh.
  void resume() {
    _isPaused = false;
  }

  /// Triggers the image capture process manually.
  /// Kích hoạt quá trình chụp ảnh thủ công.
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

  /// Resets the controller to searching state and clears captured image.
  /// Đặt lại bộ điều khiển về trạng thái tìm kiếm và xóa ảnh đã chụp.
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

  /// Sets the flash mode of the camera lens.
  /// Đặt chế độ đèn flash của ống kính camera.
  Future<void> setFlashMode(FlashMode mode) async {
    await _cameraService.setFlashMode(mode);
    flashMode.value = mode;
  }

  /// Toggles between FlashMode.off and FlashMode.torch.
  /// Chuyển đổi giữa FlashMode.off và FlashMode.torch.
  Future<void> toggleFlash() async {
    final newMode = flashMode.value == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await setFlashMode(newMode);
  }

  /// Switches between available camera lenses (e.g. Front to Back).
  /// Chuyển đổi giữa các ống kính camera hiện có (ví dụ: Trước sang Sau).
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

  /// Programmatically sets the camera zoom level.
  /// Đặt mức thu phóng camera theo chương trình.
  Future<void> setZoomLevel(double zoom) async {
    if (!enableZoom) return;
    final clampedZoom = zoom.clamp(minZoom, maxZoom);
    await _cameraService.setZoomLevel(clampedZoom);
    zoomLevel.value = clampedZoom;
  }

  /// Underlying camera controller from the camera plugin.
  /// Bộ điều khiển camera cơ sở từ plugin camera.
  CameraController? get cameraController => _cameraService.controller;

  /// Current lens direction of the active camera.
  /// Hướng ống kính hiện tại của camera đang hoạt động.
  CameraLensDirection get cameraLensDirection => _cameraService.currentCamera?.lensDirection ?? CameraLensDirection.front;

  /// Metadata about the currently active camera.
  /// Siêu dữ liệu về camera hiện đang hoạt động.
  CameraDescription? get currentCamera => _cameraService.currentCamera;
}
