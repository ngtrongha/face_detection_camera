import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final Face? face;
  final Size imageSize;
  final Color color;
  final double effectProgress; // 0.0 to 1.0

  // Cached paints to avoid recreation
  late final Paint _paintVignette;
  late final Paint _paintBorder;

  FacePainter({
    required this.face,
    required this.imageSize,
    this.color = Colors.white,
    this.effectProgress = 1.0,
  }) {
    _paintVignette = Paint()..style = PaintingStyle.fill;
    _paintBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
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

    // Optimized radius calculation
    final double maxScreenRadius =
        size.shortestSide * 1.5; // Approximate enough for max coverage
    final double targetRadius = max(size.width, size.height) * 0.8;

    final double currentRadiusEnd = ui.lerpDouble(
      maxScreenRadius,
      targetRadius,
      effectProgress,
    )!;

    final double radiusStart = max(faceRect.width, faceRect.height) * 0.6;

    // Update shader
    _paintVignette.shader = ui.Gradient.radial(
      center,
      currentRadiusEnd,
      [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.2),
        Colors.black.withValues(alpha: 0.8),
      ],
      [0.0, (radiusStart / currentRadiusEnd).clamp(0.0, 1.0), 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _paintVignette,
    );

    // Draw border
    if (effectProgress > 0.5) {
      _paintBorder.color = color.withValues(
        alpha: (effectProgress - 0.5) * 2.0,
      );
      canvas.drawOval(faceRect.inflate(20), _paintBorder);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.color != color ||
        oldDelegate.effectProgress != effectProgress;
  }
}
