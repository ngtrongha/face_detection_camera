import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/liveness_types.dart';

class LivenessService {
  /// Detects if a blink is occurring.
  bool detectBlink(Face face, double threshold) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    if (leftEye == null || rightEye == null) return false;

    // Both eyes should be more closed than the threshold
    return leftEye < threshold && rightEye < threshold;
  }

  /// Detects if a smile is occurring.
  bool detectSmile(Face face, double threshold) {
    final smile = face.smilingProbability;
    if (smile == null) return false;
    return smile > threshold;
  }

  /// Detects if the head is turned left.
  bool detectTurnLeft(Face face, double thresholdDegrees) {
    final yaw = face.headEulerAngleY; // Degrees
    if (yaw == null) return false;
    return yaw > thresholdDegrees;
  }

  /// Detects if the head is turned right.
  bool detectTurnRight(Face face, double thresholdDegrees) {
    final yaw = face.headEulerAngleY;
    if (yaw == null) return false;
    return yaw < -thresholdDegrees;
  }

  /// Detects if the head is nodding up.
  bool detectNodUp(Face face, double thresholdDegrees) {
    final pitch = face.headEulerAngleX;
    if (pitch == null) return false;
    return pitch > thresholdDegrees;
  }

  /// Detects if the head is nodding down.
  bool detectNodDown(Face face, double thresholdDegrees) {
    final pitch = face.headEulerAngleX;
    if (pitch == null) return false;
    return pitch < -thresholdDegrees;
  }

  /// Anti-spoofing check: ensures the face tracking ID is consistent.
  bool verifyTrackingConsistency(Face face, int? previousTrackingId) {
    if (face.trackingId == null || previousTrackingId == null) return true;
    return face.trackingId == previousTrackingId;
  }

  /// Checks if a specific challenge is met based on face data.
  bool isChallengeMet(Face face, LivenessChallengeConfig config) {
    switch (config.challenge) {
      case LivenessChallenge.blink:
        return detectBlink(face, config.threshold);
      case LivenessChallenge.smile:
        return detectSmile(face, config.threshold);
      case LivenessChallenge.turnLeft:
        return detectTurnLeft(face, config.threshold); // Uses threshold as degrees here
      case LivenessChallenge.turnRight:
        return detectTurnRight(face, config.threshold);
      case LivenessChallenge.nodUp:
        return detectNodUp(face, config.threshold);
      case LivenessChallenge.nodDown:
        return detectNodDown(face, config.threshold);
    }
  }
}
