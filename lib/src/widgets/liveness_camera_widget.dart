import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:face_detection_camera/src/widgets/sub_widgets/camera_controls_widget.dart';
import 'package:flutter/material.dart';
import '../controllers/face_camera_controller.dart';
import '../controllers/liveness_controller.dart';
import '../models/liveness_types.dart';
import '../widgets/face_overlay.dart';
import 'sub_widgets/camera_preview_widget.dart';
import 'sub_widgets/liveness_progress_indicator.dart';
import 'sub_widgets/liveness_challenge_overlay.dart';

/// A widget that performs liveness detection using a sequence of challenges.
/// Một widget thực hiện phát hiện tính liveness bằng một chuỗi các thử thách.
class LivenessCameraWidget extends StatefulWidget {
  /// The sequence of challenges to perform.
  /// Chuỗi các thử thách cần thực hiện.
  final List<LivenessChallengeConfig> challenges;

  /// Callback when the liveness detection flow completes.
  /// Gọi lại khi luồng phát hiện tính liveness hoàn tất.
  final Function(LivenessResult result) onLivenessComplete;

  /// Whether to start the detection flow automatically on initialization.
  /// Có tự động bắt đầu luồng phát hiện khi khởi tạo hay không.
  final bool autoStart;

  /// Camera resolution quality preset.
  /// Cài đặt chất lượng độ phân giải cho camera.
  final ResolutionPreset resolutionPreset;

  /// The initial camera lens direction (front/back).
  /// Hướng ống kính camera ban đầu (trước/sau).
  final CameraLensDirection initialCameraLensDirection;

  /// Whether to show the camera lens switch controls.
  /// Có hiển thị bộ điều khiển chuyển đổi ống kính camera hay không.
  final bool showControls;

  /// Whether to show the flash toggle button.
  /// Có hiển thị nút chuyển đổi đèn flash hay không.
  final bool showFlashButton;

  /// Delay between challenges for UX transition.
  /// Thời gian chờ giữa các thử thách để chuyển đổi UX.
  final Duration challengeDelay;

  /// Custom builder for the progress indicator. Use [LivenessProgressInfo] to build your UI.
  /// Hàm xây dựng tùy chỉnh cho chỉ báo tiến trình. Dùng [LivenessProgressInfo] để build UI.
  final Widget Function(BuildContext context, LivenessProgressInfo progress)?
  progressBuilder;

  /// Custom builder for the challenge instructions.
  /// Hàm xây dựng tùy chỉnh cho các hướng dẫn thử thách.
  final Widget Function(
    BuildContext context,
    LivenessChallenge challenge,
    LivenessChallengeState state,
  )?
  instructionBuilder;

  const LivenessCameraWidget({
    super.key,
    required this.challenges,
    required this.onLivenessComplete,
    this.autoStart = true,
    this.resolutionPreset = ResolutionPreset.high,
    this.initialCameraLensDirection = CameraLensDirection.front,
    this.showControls = false,
    this.showFlashButton = false,
    this.challengeDelay = const Duration(milliseconds: 500),
    this.progressBuilder,
    this.instructionBuilder,
  });

  @override
  State<LivenessCameraWidget> createState() => _LivenessCameraWidgetState();
}

class _LivenessCameraWidgetState extends State<LivenessCameraWidget>
    with WidgetsBindingObserver {
  late FaceCameraController _cameraController;
  late LivenessController _livenessController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _livenessController = LivenessController(
      challenges: widget.challenges,
      onLivenessComplete: widget.onLivenessComplete,
      captureCallback: _captureImage,
      challengeDelay: widget.challengeDelay,
    );

    _cameraController = FaceCameraController(
      autoCapture: false,
      resolutionPreset: widget.resolutionPreset,
      initialCameraLensDirection: widget.initialCameraLensDirection,
      enableClassification: true,
      enableContours: true,
    );

    // Listen for face changes outside the build method to avoid
    // triggering state changes during the widget build phase.
    _cameraController.detectedFace.addListener(_onFaceDetected);

    _cameraController.initialize().then((_) {
      if (mounted && widget.autoStart) {
        _livenessController.start();
      }
    });
  }

  /// Captures an image from the camera for the liveness result.
  Future<Uint8List?> _captureImage() async {
    await _cameraController.capture();
    return _cameraController.capturedImage;
  }

  void _onFaceDetected() {
    final face = _cameraController.detectedFace.value;
    if (face != null) {
      _livenessController.processFace(face);
    } else {
      // Cancel hold timer when face is lost to prevent
      // challenge from passing without a face present.
      _livenessController.onFaceLost();
    }
  }

  /// Starts the liveness detection flow manually.
  /// Call this when [autoStart] is false to begin the detection process.
  /// Bắt đầu luồng phát hiện tính liveness thủ công.
  /// Gọi khi [autoStart] là false để bắt đầu quá trình phát hiện.
  void startLiveness() {
    _livenessController.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController.cameraController == null ||
        !_cameraController.cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController.pause();
      // Also cancel hold timer to prevent false positives while in background.
      _livenessController.onFaceLost();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController.detectedFace.removeListener(_onFaceDetected);
    _cameraController.dispose();
    _livenessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: _cameraController,
        builder: (context, _) {
          if (_cameraController.state == FaceCameraState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_cameraController.cameraController == null ||
              !_cameraController.cameraController!.value.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final size = MediaQuery.of(context).size;
          var scale =
              size.aspectRatio *
              _cameraController.cameraController!.value.aspectRatio;
          if (scale < 1) scale = 1 / scale;

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreviewWidget(
                controller: _cameraController.cameraController!,
                scale: scale,
              ),

              ValueListenableBuilder(
                valueListenable: _cameraController.detectedFace,
                builder: (context, face, _) {
                  return FaceOverlay(
                    face: face,
                    imageSize:
                        _cameraController.cameraController!.value.previewSize!,
                    state: _cameraController.state,
                    duration: 0,
                  );
                },
              ),

              ListenableBuilder(
                listenable: _livenessController,
                builder: (context, _) {
                  final lState = _livenessController.livenessState.value;
                  final currentIdx =
                      _livenessController.currentChallengeIndex.value;
                  final currentChallengeState =
                      _livenessController.currentChallengeState.value;

                  return Stack(
                    children: [
                      if (lState == LivenessState.detecting)
                        Positioned(
                          top: 100,
                          left: 40,
                          right: 40,
                          child:
                              widget.instructionBuilder?.call(
                                context,
                                widget.challenges[currentIdx].challenge,
                                currentChallengeState,
                              ) ??
                              LivenessChallengeOverlay(
                                challenge:
                                    widget.challenges[currentIdx].challenge,
                                state: currentChallengeState,
                                customInstruction: widget
                                    .challenges[currentIdx]
                                    .instructionText,
                              ),
                        ),

                      Positioned(
                        bottom: 60,
                        left: 0,
                        right: 0,
                        child: ValueListenableBuilder<double>(
                          valueListenable:
                              _livenessController.challengeProgress,
                          builder: (context, stepProgress, _) {
                            final total = widget.challenges.length;
                            final overall = total > 0
                                ? (currentIdx + stepProgress.clamp(0.0, 1.0)) /
                                      total
                                : 0.0;
                            final progressInfo = LivenessProgressInfo(
                              currentIndex: currentIdx,
                              total: total,
                              currentStepProgress: stepProgress,
                              overallProgress: overall.clamp(0.0, 1.0),
                            );
                            return widget.progressBuilder?.call(
                                  context,
                                  progressInfo,
                                ) ??
                                LivenessProgressIndicator(
                                  totalChallenges: total,
                                  currentChallengeIndex: currentIdx,
                                  progress: stepProgress,
                                );
                          },
                        ),
                      ),

                      if (lState == LivenessState.completed)
                        const Center(
                          child: Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 100,
                          ),
                        ),

                      if (lState == LivenessState.failed)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.red,
                                size: 100,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  _livenessController.reset();
                                  _livenessController.start();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),

                      // Show Start button when autoStart is false and state is idle
                      if (!widget.autoStart && lState == LivenessState.idle)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: startLiveness,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Bắt đầu xác thực'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              // Controls Overlay
              ValueListenableBuilder<FlashMode>(
                valueListenable: _cameraController.flashMode,
                builder: (context, mode, _) {
                  return CameraControlsWidget(
                    showControls: widget.showControls,
                    showFlashButton: widget.showFlashButton,
                    flashMode: mode,
                    onSwitchCamera: _cameraController.switchCamera,
                    onToggleFlash: _cameraController.toggleFlash,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
