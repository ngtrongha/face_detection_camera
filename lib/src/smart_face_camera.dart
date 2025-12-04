import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'controllers/face_camera_controller.dart';
import 'widgets/face_overlay.dart';

import 'utils/image_processing.dart'; // Import for CameraImageFormat

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

/// A widget that integrates a camera with ML Kit face detection to capture
/// profile pictures automatically.
///
/// Features:
/// - Auto-detects face and starts a countdown.
/// - Shows a visual overlay (face frame) that animates.
/// - Captures image when the face is stable.
/// - Returns the captured image as [Uint8List] for easy usage.
///
/// Usage:
/// ```dart
/// SmartFaceCamera(
///   onCapture: (image) {
///     // Handle the captured image (Uint8List)
///   },
///   messageStrings: FaceCameraMessageStrings(
///     stable: 'Hold still for a moment...',
///   ),
/// )
/// ```
class SmartFaceCamera extends StatefulWidget {
  /// Callback fired when an image is captured successfully.
  ///
  /// The returned [Uint8List] contains the bytes of the captured image
  /// (encoded as JPEG or PNG based on [imageFormat]).
  final Function(Uint8List image) onCapture;

  /// Optional builder to customize the status message widget.
  final Widget? Function(BuildContext context, FaceCameraState state)?
  messageBuilder;

  /// Whether to automatically capture the image when a face is detected and stable.
  /// Defaults to true.
  final bool autoCapture;

  /// Duration of the countdown before capturing (in milliseconds).
  /// Defaults to 3000ms (3 seconds).
  final int captureCountdownDuration;

  /// Whether to show camera controls (switch camera button).
  /// Defaults to false.
  final bool showControls;

  /// Whether to enable audio for the camera.
  /// Defaults to true.
  final bool enableAudio;

  /// The resolution preset for the camera.
  /// Defaults to [ResolutionPreset.high].
  final ResolutionPreset resolutionPreset;

  /// The initial direction of the camera lens.
  /// Defaults to [CameraLensDirection.front].
  final CameraLensDirection initialCameraLensDirection;

  /// Custom strings for status messages.
  final FaceCameraMessageStrings? messageStrings;

  /// Optional controller to manage camera state externally.
  final FaceCameraController? controller;

  /// The format of the captured image.
  /// Use [CameraImageFormat.jpeg] for smaller size (default).
  /// Use [CameraImageFormat.png] for lossless quality but larger size.
  final CameraImageFormat imageFormat;

  /// Whether to enable image processing (rotation, format conversion).
  /// Defaults to true.
  ///
  /// Set to false to disable processing and return raw image bytes from the camera.
  /// This significantly improves capture speed but might result in incorrect
  /// image orientation on some devices.
  final bool enableImageProcessing;

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
    } else {
      _controller = FaceCameraController(
        autoCapture: widget.autoCapture,
        captureCountdownDuration: widget.captureCountdownDuration,
        resolutionPreset: widget.resolutionPreset,
        enableAudio: widget.enableAudio,
        initialCameraLensDirection: widget.initialCameraLensDirection,
        imageFormat: widget.imageFormat,
        enableImageProcessing: widget.enableImageProcessing,
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
    // Handle camera lifecycle if needed (pause/resume)
    // Ideally controller handles this, but camera plugin needs re-init on resume often.
    // For simplicity, we skip deep lifecycle handling here, but in production it's needed.
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
                widget.messageStrings?.permissionDenied ??
                    'Camera permission denied',
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

          // Handle Captured State
          if (_controller.capturedImage == null) {
            _lastCapturedImage = null;
          } else if (_controller.state == FaceCameraState.captured &&
              _controller.capturedImage != null) {
            if (_controller.capturedImage != _lastCapturedImage) {
              _lastCapturedImage = _controller.capturedImage;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onCapture(_controller.capturedImage!);
              });
            }
          }

          final size = MediaQuery.of(context).size;
          // Calculate scale to cover screen
          var scale =
              size.aspectRatio *
              _controller.cameraController!.value.aspectRatio;
          if (scale < 1) scale = 1 / scale;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera Preview
              Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(_controller.cameraController!),
                ),
              ),

              // Face Overlay
              ValueListenableBuilder(
                valueListenable: _controller.detectedFace,
                builder: (context, face, child) {
                  // We pass the camera preview size to the overlay to map coordinates
                  // Note: The input image size in controller might be different from preview size
                  // But usually previewSize is what matters for mapping if we use that ratio.
                  // Actually, ML Kit coordinates are based on the sensor image.
                  // We can pass the preview size from controller.value.previewSize
                  return FaceOverlay(
                    face: face,
                    imageSize: _controller.cameraController!.value.previewSize!,
                    state: _controller.state,
                    duration: widget.captureCountdownDuration,
                  );
                },
              ),

              // Status Message
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Center(child: _buildStatusMessage()),
              ),

              // Controls
              Positioned(
                top: 40,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    _controller.switchCamera();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.switch_camera,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusMessage() {
    if (widget.messageBuilder != null) {
      final customMessage = widget.messageBuilder!(context, _controller.state);
      if (customMessage != null) return customMessage;
    }

    String msg = '';
    Color color = Colors.white;

    switch (_controller.state) {
      case FaceCameraState.searching:
        msg = widget.messageStrings?.searching ?? 'Looking for face...';
        break;
      case FaceCameraState.detected:
        msg = widget.messageStrings?.detected ?? 'Keep face steady';
        color = Colors.yellow;
        break;
      case FaceCameraState.stable:
        return ValueListenableBuilder<int>(
          valueListenable: _controller.remainingSeconds,
          builder: (context, seconds, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                // Show message with countdown
                '${widget.messageStrings?.stable ?? 'Hold still...'} ($seconds)',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }

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
