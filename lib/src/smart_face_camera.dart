import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'controllers/face_camera_controller.dart';
import 'widgets/face_overlay.dart';

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
  final Function(File image) onCapture;
  final Widget? Function(BuildContext context, FaceCameraState state)?
  messageBuilder; // Optional builder for status messages
  final bool autoCapture;
  final int captureCountdownDuration; // Add this
  final bool showControls;
  final bool enableAudio;
  final ResolutionPreset resolutionPreset;
  final CameraLensDirection initialCameraLensDirection;
  final FaceCameraMessageStrings? messageStrings;
  final FaceCameraController? controller;

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
  });

  @override
  State<SmartFaceCamera> createState() => _SmartFaceCameraState();
}

class _SmartFaceCameraState extends State<SmartFaceCamera>
    with WidgetsBindingObserver {
  late FaceCameraController _controller;
  File? _lastCapturedImage;

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
        msg = widget.messageStrings?.stable ?? 'Hold still...';
        color = Colors.greenAccent;
        break;
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
