import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'controllers/face_camera_controller.dart';
import 'widgets/face_overlay.dart';

import 'utils/image_processing.dart'; // Import for CameraImageFormat

typedef StatusMessageBuilder =
    Widget? Function(
      BuildContext context,
      FaceCameraState state,
      bool isFacingForward,
      int remainingSeconds,
    );

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

  /// Rich customization builder for status message, with extra context:
  /// - [isFacingForward]: whether the user is looking straight
  /// - [remainingSeconds]: countdown seconds (0 if not counting)
  final StatusMessageBuilder? statusBuilder;

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

  /// Controls the gap between the face and the dark vignette (encroaching effect).
  /// Higher value = bigger clear area around the face. Default: 1.1
  final double vignettePaddingFactor;

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
        maxYawDegrees: widget.controller?.maxYawDegrees ?? 12.0,
        maxRollDegrees: widget.controller?.maxRollDegrees ?? 12.0,
        maxPitchDegrees: widget.controller?.maxPitchDegrees ?? 12.0,
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
                    vignettePaddingFactor: widget.vignettePaddingFactor,
                  );
                },
              ),

              // Status Message (listen to facingForward as well)
              ValueListenableBuilder<bool>(
                valueListenable: _controller.facingForward,
                builder: (context, isFacingForward, _) {
                  return Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Center(child: _buildStatusMessage(isFacingForward)),
                  );
                },
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

  Widget _buildStatusMessage(bool isFacingForward) {
    final int seconds = _controller.remainingSeconds.value;

    // New rich builder takes priority
    if (widget.statusBuilder != null) {
      final custom = widget.statusBuilder!(
        context,
        _controller.state,
        isFacingForward,
        seconds,
      );
      if (custom != null) return custom;
    }

    // Legacy builder fallback (without facing info)
    if (widget.messageBuilder != null) {
      final customMessage = widget.messageBuilder!(context, _controller.state);
      if (customMessage != null) return customMessage;
    }

    String msg = '';
    Color color = Colors.white;

    // Warning if not facing forward
    if (!isFacingForward) {
      msg =
          widget.messageStrings?.capturing ??
          'Please look straight at the camera';
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
