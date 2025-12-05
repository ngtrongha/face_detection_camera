import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final Face? face;
  final Size imageSize;
  final Color color;
  final double effectProgress; // 0.0 to 1.0
  final double facePaddingFactor; // controls distance from face to dark region

  // Cached paint to avoid recreation
  late final Paint _paintVignette;

  FacePainter({
    required this.face,
    required this.imageSize,
    this.color = Colors.white,
    this.effectProgress = 1.0,
    this.facePaddingFactor = 1.1, // user-adjustable gap
  }) {
    _paintVignette = Paint()..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (face == null) return;

    // Calculate scaling
    // Cache this or accept it as parameter if size doesn't change often
    final double scaleX = size.width / imageSize.height;
    final double scaleY = size.height / imageSize.width;

    final rect = face!.boundingBox;

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

    // Encroaching radius calculation (more dramatic):
    // Start: very large radius so preview gần như không bị tối.
    // End: bán kính nhỏ quanh khuôn mặt để tối rõ rệt vùng biên.
    final double startRadius =
        max(size.width, size.height) * 1.6; // bắt đầu rất lớn (tối ở viền)
    final double endRadius =
        max(faceRect.width, faceRect.height) *
        facePaddingFactor; // kết thúc sát mặt tuỳ chỉnh

    final double currentRadiusEnd = ui.lerpDouble(
      startRadius,
      endRadius,
      effectProgress,
    )!;

    final double radiusStart =
        (faceRect.shortestSide) * 0.6; // trong suốt quanh mặt

    // Update shader
    _paintVignette.shader = ui.Gradient.radial(
      center,
      currentRadiusEnd,
      [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.35),
        Colors.black.withValues(alpha: 0.92),
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
        oldDelegate.effectProgress != effectProgress;
  }
}
