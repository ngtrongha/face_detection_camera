import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'controllers/face_camera_controller.dart';
import 'widgets/face_overlay.dart';
import 'widgets/sub_widgets/camera_preview_widget.dart';
import 'widgets/sub_widgets/camera_controls_widget.dart';
import 'widgets/sub_widgets/capture_button_widget.dart';

import 'utils/image_processing.dart';

typedef StatusMessageBuilder =
    Widget? Function(
      BuildContext context,
      FaceCameraState state,
      bool isFacingForward,
      int remainingSeconds,
    );

typedef FaceCameraErrorCallback =
    void Function(FaceCameraError error, String? message);

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

class SmartFaceCamera extends StatefulWidget {
  final Function(Uint8List image) onCapture;
  final Widget? Function(BuildContext context, FaceCameraState state)?
  messageBuilder;
  final StatusMessageBuilder? statusBuilder;
  final bool autoCapture;
  final int captureCountdownDuration;
  final bool showControls;
  final bool enableAudio;
  final ResolutionPreset resolutionPreset;
  final CameraLensDirection initialCameraLensDirection;
  final FaceCameraMessageStrings? messageStrings;
  final FaceCameraController? controller;
  final CameraImageFormat imageFormat;
  final bool enableImageProcessing;
  final double vignettePaddingFactor;
  final int jpegQuality;
  final bool cropToFace;
  final double faceCropPadding;
  final bool enableContours;
  final bool enableClassification;
  final FlashMode initialFlashMode;
  final bool showFlashButton;
  final FaceCameraErrorCallback? onError;
  final double maxYawDegrees;
  final double maxRollDegrees;
  final double maxPitchDegrees;
  final bool lockOrientation;
  final bool showCaptureButton;
  final Widget Function(VoidCallback onCapture)? captureButtonBuilder;
  final bool showPreview;
  final Function(Uint8List image)? onPreviewConfirm;
  final VoidCallback? onPreviewRetry;
  final bool enableZoom;
  final void Function(List<dynamic> faces)? onMultipleFacesDetected;
  final void Function(FaceQuality quality)? onFaceQuality;
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
