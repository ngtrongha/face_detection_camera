import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../controllers/face_camera_controller.dart';
import '../paints/face_painter.dart';

/// An overlay widget that draws a face frame and applies a vignette effect.
/// Một widget lớp phủ vẽ khung khuôn mặt và áp dụng hiệu ứng mờ viền.
class FaceOverlay extends StatelessWidget {
  /// The detected face to draw the frame around.
  /// Khuôn mặt được phát hiện để vẽ khung xung quanh.
  final Face? face;

  /// The original size of the camera image for coordinate mapping.
  /// Kích thước gốc của hình ảnh camera để ánh xạ tọa độ.
  final Size imageSize;

  /// The current state of the face camera.
  /// Trạng thái hiện tại của camera khuôn mặt.
  final FaceCameraState state;

  /// The duration of the countdown (used for animation synchronization).
  /// Thời gian đếm ngược (được sử dụng để đồng bộ hóa hoạt ảnh).
  final int duration;

  /// Padding multiplier for the vignette effect around the face.
  /// Hệ số lề cho hiệu ứng mờ viền xung quanh khuôn mặt.
  final double vignettePaddingFactor;

  /// Base color for the face frame.
  /// Màu cơ bản cho khung khuôn mặt.
  final Color baseColor;

  /// Color for the face frame when a face is detected but not stable.
  /// Màu cho khung khuôn mặt khi phát hiện khuôn mặt nhưng chưa ổn định.
  final Color detectedColor;

  /// Color for the face frame when the face is stable or capturing.
  /// Màu cho khung khuôn mặt khi khuôn mặt ổn định hoặc đang chụp.
  final Color stableColor;

  const FaceOverlay({
    super.key,
    required this.face,
    required this.imageSize,
    required this.state,
    this.duration = 3000,
    this.vignettePaddingFactor = 1.1,
    this.baseColor = Colors.white54,
    this.detectedColor = Colors.yellowAccent,
    this.stableColor = Colors.greenAccent,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.white;
    switch (state) {
      case FaceCameraState.searching:
        color = baseColor;
        break;
      case FaceCameraState.detected:
        color = detectedColor;
        break;
      case FaceCameraState.stable:
      case FaceCameraState.capturing:
        color = stableColor;
        break;
      default:
        color = Colors.white;
    }

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
      animDuration = duration;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        end: targetProgress,
      ),
      duration: Duration(milliseconds: animDuration),
      curve: state == FaceCameraState.stable
          ? Curves.linear
          : Curves.easeOutCubic,
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
