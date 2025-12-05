import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../controllers/face_camera_controller.dart';
import '../paints/face_painter.dart';

class FaceOverlay extends StatelessWidget {
  final Face? face;
  final Size imageSize;
  final FaceCameraState state;
  final int duration;
  final double vignettePaddingFactor;

  const FaceOverlay({
    super.key,
    required this.face,
    required this.imageSize,
    required this.state,
    this.duration = 3000,
    this.vignettePaddingFactor = 1.1,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.white;
    switch (state) {
      case FaceCameraState.searching:
        color = Colors.white54;
        break;
      case FaceCameraState.detected:
        color = Colors.yellowAccent;
        break;
      case FaceCameraState.stable:
      case FaceCameraState.capturing:
        color = Colors.greenAccent;
        break;
      default:
        color = Colors.white;
    }

    // Encroaching effect mapping:
    // - searching: 0.0 (clear)
    // - detected: 0.6 (viền đã tối khá rõ)
    // - stable/capturing: 1.0 (tối sát khuôn mặt) trong thời gian countdown
    double targetProgress = 0.0;
    int animDuration = 400;

    if (state == FaceCameraState.searching) {
      targetProgress = 0.0;
      animDuration = 400;
    } else if (state == FaceCameraState.detected) {
      targetProgress = 0.6;
      animDuration = 700;
    } else if (state == FaceCameraState.stable ||
        state == FaceCameraState.capturing) {
      targetProgress = 1.0;
      animDuration = duration; // đồng bộ với thời gian chụp
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        // We might want to start from previous value, but TweenAnimationBuilder handles implicit animations well
        // if we change the target. However, going from 0.3 to 1.0 over 3 seconds is what we want.
        end: targetProgress,
      ),
      duration: Duration(milliseconds: animDuration),
      curve: state == FaceCameraState.stable
          ? Curves.linear
          : Curves.easeOutCubic, // Linear for countdown sync
      builder: (context, progress, child) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: Colors.white, end: color),
          duration: const Duration(milliseconds: 300),
          builder: (context, animatedColor, child) {
            return CustomPaint(
              painter: FacePainter(
                face: face,
                imageSize: imageSize,
                color: animatedColor ?? Colors.white,
                effectProgress: progress,
                facePaddingFactor: vignettePaddingFactor,
              ),
              size: Size.infinite,
            );
          },
        );
      },
    );
  }
}
