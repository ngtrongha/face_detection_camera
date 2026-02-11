import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class StabilityTracker {
  final List<Rect> _recentFaceRects = [];
  final int windowSize;
  final double movementThreshold;
  final int countdownDuration;

  Timer? _countdownTimer;
  int _remainingMs = 0;

  final ValueNotifier<int> remainingSeconds = ValueNotifier<int>(0);
  final VoidCallback onStable;
  final VoidCallback onUnstable;

  StabilityTracker({
    this.windowSize = 10,
    this.movementThreshold = 15.0,
    required this.countdownDuration,
    required this.onStable,
    required this.onUnstable,
  });

  void checkStability(Face face) {
    _recentFaceRects.add(face.boundingBox);
    if (_recentFaceRects.length > windowSize) {
      _recentFaceRects.removeAt(0);
    }

    if (_recentFaceRects.length == windowSize) {
      double maxMovement = 0;
      final center = face.boundingBox.center;

      for (final rect in _recentFaceRects) {
        final dist = (rect.center - center).distance;
        if (dist > maxMovement) maxMovement = dist;
      }

      if (maxMovement < movementThreshold) {
        _startCountdown();
      } else {
        _stopCountdown();
      }
    }
  }

  void reset() {
    _recentFaceRects.clear();
    _stopCountdown();
  }

  void _startCountdown() {
    if (_countdownTimer != null) return;

    _remainingMs = countdownDuration;
    remainingSeconds.value = (_remainingMs / 1000).ceil();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _remainingMs -= 100;
      final newSeconds = (_remainingMs / 1000).ceil();
      if (remainingSeconds.value != newSeconds) {
        remainingSeconds.value = newSeconds;
      }

      if (_remainingMs <= 0) {
        timer.cancel();
        _countdownTimer = null;
        onStable();
      }
    });
  }

  void _stopCountdown() {
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
      _countdownTimer = null;
      _remainingMs = 0;
      remainingSeconds.value = 0;
      onUnstable();
    }
  }

  void dispose() {
    _countdownTimer?.cancel();
    remainingSeconds.dispose();
  }
}
