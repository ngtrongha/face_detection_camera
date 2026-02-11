import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'controllers/face_camera_controller.dart';
import 'widgets/face_overlay.dart';
import 'widgets/sub_widgets/camera_preview_widget.dart';
import 'widgets/sub_widgets/camera_controls_widget.dart';
import 'widgets/sub_widgets/capture_button_widget.dart';

import 'utils/image_processing.dart';

/// Builder to customize the status message shown during the process.
/// Hàm xây dựng để tùy chỉnh thông báo trạng thái hiển thị trong quá trình.
typedef StatusMessageBuilder =
    Widget? Function(
      BuildContext context,
      FaceCameraState state,
      bool isFacingForward,
      int remainingSeconds,
    );

/// Callback for handling camera and processing errors.
/// Gọi lại để xử lý các lỗi camera và xử lý.
typedef FaceCameraErrorCallback =
    void Function(FaceCameraError error, String? message);

/// Custom strings for the default status messages.
/// Các chuỗi tùy chỉnh cho các thông báo trạng thái mặc định.
class FaceCameraMessageStrings {
  final String? searching;
  final String? detected;
  final String? stable;
  final String? capturing;
  final String? permissionDenied;
  final String? error;

  const FaceCameraMessageStrings({
    this.searching,
    this.detected,
    this.stable,
    this.capturing,
    this.permissionDenied,
    this.error,
  });
}

/// A smart camera widget that automatically detects faces and captures images.
/// Một widget camera thông minh tự động phát hiện khuôn mặt và chụp ảnh.
class SmartFaceCamera extends StatefulWidget {
  /// Callback when an image is captured successfully. Returns the image bytes.
  /// Gọi lại khi ảnh được chụp thành công. Trả về byte của ảnh.
  final Function(Uint8List image) onCapture;

  /// Optional legacy builder for basic status messages.
  /// Hàm xây dựng cũ tùy chọn cho các thông báo trạng thái cơ bản.
  final Widget? Function(BuildContext context, FaceCameraState state)?
  messageBuilder;

  /// Rich builder for customized status messages with extra context.
  /// Hàm xây dựng phong phú cho các thông báo trạng thái tùy chỉnh với thêm ngữ cảnh.
  final StatusMessageBuilder? statusBuilder;

  /// Whether to capture automatically when a face is detected and stable.
  /// Có tự động chụp khi phát hiện khuôn mặt và ổn định hay không.
  final bool autoCapture;

  /// Duration of the countdown before automatic capture (in ms).
  /// Thời gian đếm ngược trước khi tự động chụp (tính bằng ms).
  final int captureCountdownDuration;

  /// Whether to show camera lens switch controls.
  /// Có hiển thị bộ điều khiển chuyển đổi ống kính camera hay không.
  final bool showControls;

  /// Whether to enable audio recording.
  /// Có bật ghi âm hay không.
  final bool enableAudio;

  /// The resolution quality preset for the camera.
  /// Cài đặt chất lượng độ phân giải cho camera.
  final ResolutionPreset resolutionPreset;

  /// The initial camera lens direction (front/back).
  /// Hướng ống kính camera ban đầu (trước/sau).
  final CameraLensDirection initialCameraLensDirection;

  /// Custom text strings for status messages.
  /// Các chuỗi văn bản tùy chỉnh cho thông báo trạng thái.
  final FaceCameraMessageStrings? messageStrings;

  /// External controller to manage camera state.
  /// Bộ điều khiển bên ngoài để quản lý trạng thái camera.
  final FaceCameraController? controller;

  /// Image format to save (JPEG/PNG).
  /// Định dạng ảnh để lưu (JPEG/PNG).
  final CameraImageFormat imageFormat;

  /// Whether to enable post-capture rotation and flipping.
  /// Có bật xoay và lật sau khi chụp hay không.
  final bool enableImageProcessing;

  /// Padding factor for the vignette overlay around the face.
  /// Hệ số lề cho lớp phủ mờ xung quanh khuôn mặt.
  final double vignettePaddingFactor;

  /// JPEG compression quality (1-100).
  /// Chất lượng nén JPEG (1-100).
  final int jpegQuality;

  /// Whether to crop the resulting image to the face bounding box.
  /// Có cắt ảnh kết quả theo khung bao khuôn mặt hay không.
  final bool cropToFace;

  /// Margin multiplier around face when cropping.
  /// Hệ số lề xung quanh khuôn mặt khi cắt.
  final double faceCropPadding;

  /// Whether to enable high-accuracy face contours (CPU intensive).
  /// Có bật đường nét khuôn mặt độ chính xác cao hay không.
  final bool enableContours;

  /// Whether to enable classification (smiling, eyes open).
  /// Có bật phân loại (mỉm cười, mở mắt) hay không.
  final bool enableClassification;

  /// Initial flash mode setting.
  /// Cài đặt chế độ đèn flash ban đầu.
  final FlashMode initialFlashMode;

  /// Whether to show the flash toggle button.
  /// Có hiển thị nút chuyển đổi đèn flash hay không.
  final bool showFlashButton;

  /// Error handling callback.
  /// Gọi lại xử lý lỗi.
  final FaceCameraErrorCallback? onError;

  /// Max yaw degrees to consider face frontal.
  /// Góc quay tối đa để coi khuôn mặt là hướng thẳng.
  final double maxYawDegrees;

  /// Max roll degrees to consider face frontal.
  /// Góc nghiêng tối đa để coi khuôn mặt là hướng thẳng.
  final double maxRollDegrees;

  /// Max pitch degrees to consider face frontal.
  /// Góc ngẩng tối đa để coi khuôn mặt là hướng thẳng.
  final double maxPitchDegrees;

  /// Whether to force portrait orientation.
  /// Có bắt buộc hướng dọc hay không.
  final bool lockOrientation;

  /// Whether to show a manual capture button.
  /// Có hiển thị nút chụp thủ công hay không.
  final bool showCaptureButton;

  /// Custom builder for the manual capture button.
  /// Hàm xây dựng tùy chỉnh cho nút chụp thủ công.
  final Widget Function(VoidCallback onCapture)? captureButtonBuilder;

  /// Whether to show a preview dialog before returning the image.
  /// Có hiển thị hộp thoại xem trước trước khi trả về ảnh hay không.
  final bool showPreview;

  /// Callback when the preview is confirmed.
  /// Gọi lại khi xem trước được xác nhận.
  final Function(Uint8List image)? onPreviewConfirm;

  /// Callback when the preview is retried.
  /// Gọi lại khi xem trước được thử lại.
  final VoidCallback? onPreviewRetry;

  /// Whether to enable pinch-to-zoom gestures.
  /// Có bật cử chỉ thu phóng hay không.
  final bool enableZoom;

  /// Callback when multiple faces are detected.
  /// Gọi lại khi phát hiện nhiều khuôn mặt.
  final void Function(List<dynamic> faces)? onMultipleFacesDetected;

  /// Callback for face quality updates.
  /// Gọi lại cho các cập nhật chất lượng khuôn mặt.
  final void Function(FaceQuality quality)? onFaceQuality;

  /// Minimum quality score (0-1) required for capture.
  /// Điểm chất lượng tối thiểu (0-1) cần thiết để chụp.
  final double minQualityScore;

  const SmartFaceCamera({
    super.key,
    required this.onCapture,
    this.messageBuilder,
    this.autoCapture = true,
    this.captureCountdownDuration = 3000,
    this.showControls = false,
    this.enableAudio = true,
    this.resolutionPreset = ResolutionPreset.high,
    this.initialCameraLensDirection = CameraLensDirection.front,
    this.messageStrings,
    this.controller,
    this.imageFormat = CameraImageFormat.jpeg,
    this.enableImageProcessing = true,
    this.vignettePaddingFactor = 1.1,
    this.statusBuilder,
    this.jpegQuality = 90,
    this.cropToFace = false,
    this.faceCropPadding = 1.5,
    this.enableContours = false,
    this.enableClassification = false,
    this.initialFlashMode = FlashMode.off,
    this.showFlashButton = false,
    this.onError,
    this.maxYawDegrees = 12.0,
    this.maxRollDegrees = 12.0,
    this.maxPitchDegrees = 12.0,
    this.lockOrientation = true,
    this.showCaptureButton = false,
    this.captureButtonBuilder,
    this.showPreview = false,
    this.onPreviewConfirm,
    this.onPreviewRetry,
    this.enableZoom = false,
    this.onMultipleFacesDetected,
    this.onFaceQuality,
    this.minQualityScore = 0.0,
  });

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera>
    with WidgetsBindingObserver {
  late FaceCameraController _controller;
  Uint8List? _lastCapturedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller != null) {
      _controller = widget.controller!;
      _controller.onError = widget.onError;
    } else {
      _controller = FaceCameraController(
        autoCapture: widget.autoCapture,
        captureCountdownDuration: widget.captureCountdownDuration,
        resolutionPreset: widget.resolutionPreset,
        enableAudio: widget.enableAudio,
        initialCameraLensDirection: widget.initialCameraLensDirection,
        imageFormat: widget.imageFormat,
        enableImageProcessing: widget.enableImageProcessing,
        maxYawDegrees: widget.maxYawDegrees,
        maxRollDegrees: widget.maxRollDegrees,
        maxPitchDegrees: widget.maxPitchDegrees,
        jpegQuality: widget.jpegQuality,
        cropToFace: widget.cropToFace,
        faceCropPadding: widget.faceCropPadding,
        enableContours: widget.enableContours,
        enableClassification: widget.enableClassification,
        initialFlashMode: widget.initialFlashMode,
        lockOrientation: widget.lockOrientation,
        enableZoom: widget.enableZoom,
        detectMultipleFaces: widget.onMultipleFacesDetected != null,
        onMultipleFacesDetected: widget.onMultipleFacesDetected != null
            ? (faces) => widget.onMultipleFacesDetected!(faces)
            : null,
        onFaceQuality: widget.onFaceQuality,
        minQualityScore: widget.minQualityScore,
        onError: widget.onError,
      );
    }
    _initializeController();
  }

  Future<void> _initializeController() async {
    if (widget.controller == null || _controller.cameraController == null) {
      await _controller.initialize();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller.cameraController == null ||
        !_controller.cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _controller.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (_controller.state == FaceCameraState.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.state == FaceCameraState.permissionDenied) {
            return Center(
              child: Text(
                widget.messageStrings?.permissionDenied ?? 'Camera permission denied',
              ),
            );
          }
          if (_controller.state == FaceCameraState.error) {
            return Center(
              child: Text(widget.messageStrings?.error ?? 'Camera error'),
            );
          }

          if (_controller.cameraController == null ||
              !_controller.cameraController!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          _handleCaptureState();

          final size = MediaQuery.of(context).size;
          var scale = size.aspectRatio * _controller.cameraController!.value.aspectRatio;
          if (scale < 1) scale = 1 / scale;

          return GestureDetector(
            onScaleUpdate: widget.enableZoom ? (details) => _controller.setZoomLevel(details.scale) : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreviewWidget(
                  controller: _controller.cameraController!,
                  scale: scale,
                ),
                ValueListenableBuilder(
                  valueListenable: _controller.detectedFace,
                  builder: (context, face, child) {
                    return FaceOverlay(
                      face: face,
                      imageSize: _controller.cameraController!.value.previewSize!,
                      state: _controller.state,
                      duration: widget.captureCountdownDuration,
                      vignettePaddingFactor: widget.vignettePaddingFactor,
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _controller.facingForward,
                  builder: (context, isFacingForward, _) {
                    return Positioned(
                      top: 100,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: _buildStatusMessage(isFacingForward),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<FlashMode>(
                  valueListenable: _controller.flashMode,
                  builder: (context, mode, _) {
                    return CameraControlsWidget(
                      showControls: widget.showControls,
                      showFlashButton: widget.showFlashButton,
                      flashMode: mode,
                      onSwitchCamera: _controller.switchCamera,
                      onToggleFlash: _controller.toggleFlash,
                    );
                  },
                ),
                if (widget.showCaptureButton)
                  CaptureButtonWidget(
                    onTap: _controller.capture,
                    builder: widget.captureButtonBuilder,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleCaptureState() {
    if (_controller.capturedImage == null) {
      _lastCapturedImage = null;
    } else if (_controller.state == FaceCameraState.captured && _controller.capturedImage != null) {
      if (_controller.capturedImage != _lastCapturedImage) {
        _lastCapturedImage = _controller.capturedImage;
        if (widget.showPreview) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPreviewDialog(_controller.capturedImage!);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onCapture(_controller.capturedImage!);
          });
        }
      }
    }
  }

  void _showPreviewDialog(Uint8List imageBytes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        widget.onPreviewRetry?.call();
                        _controller.reset();
                      },
                      child: const Text('Retry'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        widget.onPreviewConfirm?.call(imageBytes);
                        widget.onCapture(imageBytes);
                      },
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusMessage(bool isFacingForward) {
    final int seconds = _controller.remainingSeconds.value;

    if (widget.statusBuilder != null) {
      final custom = widget.statusBuilder!(context, _controller.state, isFacingForward, seconds);
      if (custom != null) return custom;
    }

    if (widget.messageBuilder != null) {
      final customMessage = widget.messageBuilder!(context, _controller.state);
      if (customMessage != null) return customMessage;
    }

    String msg = '';
    Color color = Colors.white;

    if (!isFacingForward) {
      msg = widget.messageStrings?.capturing ?? 'Please look straight at the camera';
      color = Colors.redAccent;
      return _statusChip(msg, color);
    }

    switch (_controller.state) {
      case FaceCameraState.searching:
        msg = widget.messageStrings?.searching ?? 'Looking for face...';
        break;
      case FaceCameraState.detected:
        msg = widget.messageStrings?.detected ?? 'Keep face steady';
        color = Colors.yellow;
        break;
      case FaceCameraState.stable:
        return _statusChip(
          '${widget.messageStrings?.stable ?? 'Hold still...'} ($seconds)',
          Colors.greenAccent,
        );
      default:
        return const SizedBox.shrink();
    }

    return _statusChip(msg, color);
  }

  Widget _statusChip(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        msg,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
