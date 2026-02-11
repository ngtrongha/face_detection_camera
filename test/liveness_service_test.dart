import 'package:flutter_test/flutter_test.dart';
import 'package:face_detection_camera/face_detection_camera.dart';
import 'package:face_detection_camera/src/services/liveness_service.dart';
import 'package:flutter/widgets.dart';

void main() {
  final service = LivenessService();

  group('LivenessService - Individual Challenges', () {
    test('detectBlink should return true when eyes are closed', () {
      final face = Face(
        boundingBox: Rect.zero,
        landmarks: {},
        contours: {},
        leftEyeOpenProbability: 0.1,
        rightEyeOpenProbability: 0.1,
      );
      expect(service.detectBlink(face, 0.2), isTrue);
    });

    test('detectBlink should return false when eyes are open', () {
      final face = Face(
        boundingBox: Rect.zero,
        landmarks: {},
        contours: {},
        leftEyeOpenProbability: 0.8,
        rightEyeOpenProbability: 0.8,
      );
      expect(service.detectBlink(face, 0.2), isFalse);
    });

    test('detectSmile should return true when smiling', () {
      final face = Face(
        boundingBox: Rect.zero,
        landmarks: {},
        contours: {},
        smilingProbability: 0.9,
      );
      expect(service.detectSmile(face, 0.5), isTrue);
    });

    test('detectTurnLeft should return true when yaw > threshold', () {
      final face = Face(
        boundingBox: Rect.zero,
        landmarks: {},
        contours: {},
        headEulerAngleY: 30.0,
      );
      expect(service.detectTurnLeft(face, 20.0), isTrue);
    });

    test('detectTurnRight should return true when yaw < -threshold', () {
      final face = Face(
        boundingBox: Rect.zero,
        landmarks: {},
        contours: {},
        headEulerAngleY: -30.0,
      );
      expect(service.detectTurnRight(face, 20.0), isTrue);
    });
  });

  group('LivenessService - Challenge Configuration', () {
    test('isChallengeMet should correctly route requests', () {
      final face = Face(
        boundingBox: Rect.zero,
        landmarks: {},
        contours: {},
        smilingProbability: 0.9,
      );
      const config = LivenessChallengeConfig(
        challenge: LivenessChallenge.smile,
        threshold: 0.5,
      );
      expect(service.isChallengeMet(face, config), isTrue);
    });
  });
}
