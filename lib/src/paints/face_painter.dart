import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Custom painter to draw the face detection frame and vignette effect.
/// Họa sĩ tùy chỉnh để vẽ khung phát hiện khuôn mặt và hiệu ứng mờ viền.
class FacePainter extends CustomPainter {
  /// The detected face metadata.
  /// Siêu dữ liệu khuôn mặt được phát hiện.
  final Face? face;

  /// The original image size for coordinate scaling.
  /// Kích thước hình ảnh gốc để tỷ lệ hóa tọa độ.
  final Size imageSize;

  /// Color of the visual elements.
  /// Màu sắc của các yếu tố trực quan.
  final Color color;

  /// Animation progress for the vignette effect (0.0 to 1.0).
  /// Tiến trình hoạt ảnh cho hiệu ứng mờ viền (0.0 đến 1.0).
  final double effectProgress;

  /// Factor to control the gap between the face and the dark region.
  /// Hệ số để kiểm soát khoảng cách giữa khuôn mặt và vùng tối.
  final double facePaddingFactor;

  /// Opacity of the darkest part of the vignette.
  /// Độ mờ của phần tối nhất của hiệu ứng mờ viền.
  final double vignetteOpacity;

  late final Paint _paintVignette;

  FacePainter({
    required this.face,
    required this.imageSize,
    this.color = Colors.white,
    this.effectProgress = 1.0,
    this.facePaddingFactor = 1.1,
    this.vignetteOpacity = 0.92,
  }) {
    _paintVignette = Paint()..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;

    // Calculate scaling factors
    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final rect = face!.boundingBox;

    // Handle horizontal mirroring for front camera
    final double left = size.width - (rect.left * scaleX);
    final double right = size.width - (rect.right * scaleX);
    final double top = rect.top * scaleY;
    final double bottom = rect.bottom * scaleY;

    final faceRect = Rect.fromLTRB(
      min(left, right),
      top,
      max(left, right),
      bottom,
    );
    final center = faceRect.center;

    // Define vignette boundaries based on progress
    final double startRadius = max(size.width, size.height) * 1.6;
    final double endRadius = max(faceRect.width, faceRect.height) * facePaddingFactor;

    final double currentRadiusEnd = ui.lerpDouble(
      startRadius,
      endRadius,
      effectProgress,
    )!;

    final double radiusStart = (faceRect.shortestSide) * 0.6;

    // Apply radial gradient for the "focus" effect
    _paintVignette.shader = ui.Gradient.radial(
      center,
      currentRadiusEnd,
      [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.35),
        Colors.black.withValues(alpha: vignetteOpacity),
      ],
      [0.0, (radiusStart / currentRadiusEnd).clamp(0.0, 1.0), 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _paintVignette,
    );
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.color != color ||
        oldDelegate.effectProgress != effectProgress ||
        oldDelegate.vignetteOpacity != vignetteOpacity;
  }
}
