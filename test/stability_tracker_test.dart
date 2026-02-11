import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:face_detection_camera/src/services/stability_tracker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

void main() {
  group('StabilityTracker', () {
    test('should start with 0 remaining seconds', () {
      final tracker = StabilityTracker(
        countdownDuration: 3000,
        onStable: () {},
        onUnstable: () {},
      );
      expect(tracker.remainingSeconds.value, 0);
    });

    test('should detect stability and trigger onStable', () async {
      bool isStable = false;
      final tracker = StabilityTracker(
        windowSize: 3,
        movementThreshold: 10.0,
        countdownDuration: 300,
        onStable: () => isStable = true,
        onUnstable: () {},
      );

      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
      );

      // Add 3 identical faces to reach windowSize and trigger stability
      tracker.checkStability(face);
      tracker.checkStability(face);
      tracker.checkStability(face);

      expect(tracker.remainingSeconds.value, 1);

      await Future.delayed(const Duration(milliseconds: 400));
      expect(isStable, true);
    });

    test('should detect instability and trigger onUnstable', () {
      bool isUnstable = false;
      final tracker = StabilityTracker(
        windowSize: 3,
        movementThreshold: 10.0,
        countdownDuration: 1000,
        onStable: () {},
        onUnstable: () => isUnstable = true,
      );

      final face1 = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
        landmarks: {},
        contours: {},
      );
      final face2 = Face(
        boundingBox: const Rect.fromLTWH(50, 50, 100, 100), // Significant movement
        landmarks: {},
        contours: {},
      );

      // Trigger stability first
      tracker.checkStability(face1);
      tracker.checkStability(face1);
      tracker.checkStability(face1);
      expect(tracker.remainingSeconds.value, 1);

      // Now move face to trigger instability
      tracker.checkStability(face2);
      expect(isUnstable, true);
      expect(tracker.remainingSeconds.value, 0);
    });
  });
}
