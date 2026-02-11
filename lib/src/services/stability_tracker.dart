import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Service to track face stability and handle capture countdown.
/// Dịch vụ theo dõi độ ổn định của khuôn mặt và xử lý đếm ngược khi chụp.
class StabilityTracker {
  final List<Rect> _recentFaceRects = [];

  /// Number of frames to check for stability.
  /// Số lượng khung hình để kiểm tra độ ổn định.
  final int windowSize;

  /// Maximum variance allowed in pixels to consider face "stable".
  /// Độ biến động tối đa cho phép (pixel) để coi khuôn mặt là "ổn định".
  final double movementThreshold;

  /// Total duration of the countdown in milliseconds.
  /// Tổng thời gian đếm ngược tính bằng mili giây.
  final int countdownDuration;

  Timer? _countdownTimer;
  int _remainingMs = 0;

  /// Notifier for the remaining seconds in countdown.
  /// Thông báo số giây còn lại trong quá trình đếm ngược.
  final ValueNotifier<int> remainingSeconds = ValueNotifier<int>(0);

  /// Callback when the face has been stable for the required duration.
  /// Gọi lại khi khuôn mặt đã ổn định trong thời gian yêu cầu.
  final VoidCallback onStable;

  /// Callback when the face becomes unstable during countdown.
  /// Gọi lại khi khuôn mặt trở nên không ổn định trong khi đếm ngược.
  final VoidCallback onUnstable;

  StabilityTracker({
    this.windowSize = 10,
    this.movementThreshold = 15.0,
    required this.countdownDuration,
    required this.onStable,
    required this.onUnstable,
  });

  /// Processes a new face frame to update stability status.
  /// Xử lý khung hình khuôn mặt mới để cập nhật trạng thái ổn định.
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

  /// Resets the tracker state and cancels any active countdown.
  /// Đặt lại trạng thái bộ theo dõi và hủy mọi đếm ngược đang hoạt động.
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

  /// Disposes the tracker and releases resources.
  /// Giải phóng bộ theo dõi và các tài nguyên.
  void dispose() {
    _countdownTimer?.cancel();
    remainingSeconds.dispose();
  }
}
