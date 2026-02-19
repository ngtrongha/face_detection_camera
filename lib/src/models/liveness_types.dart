import 'dart:typed_data';

/// Available challenge types for liveness detection.
enum LivenessChallenge { blink, smile, turnLeft, turnRight, nodUp, nodDown }

/// State of an individual liveness challenge.
enum LivenessChallengeState { pending, active, success, failed, timeout }

/// Overall state of the liveness detection process.
enum LivenessState { idle, detecting, completed, failed }

/// Configuration for a single liveness challenge.
class LivenessChallengeConfig {
  final LivenessChallenge challenge;

  /// Threshold for detection.
  /// - For blink/smile: probability threshold (0.0 to 1.0), default 0.5.
  /// - For turn/nod: angle in degrees, default 20.0.
  /// If null, a sensible default is chosen based on the challenge type.
  final double? _threshold;

  /// Returns the effective threshold, using a sensible default if not specified.
  double get threshold => _threshold ?? _defaultThreshold;

  double get _defaultThreshold {
    switch (challenge) {
      case LivenessChallenge.blink:
      case LivenessChallenge.smile:
        return 0.5; // probability
      case LivenessChallenge.turnLeft:
      case LivenessChallenge.turnRight:
      case LivenessChallenge.nodUp:
      case LivenessChallenge.nodDown:
        return 20.0; // degrees
    }
  }

  /// Maximum time allowed to complete the challenge.
  final Duration timeout;

  /// How long the action must be held to be considered successful.
  final Duration holdDuration;

  /// Custom instruction text for the user.
  final String? instructionText;

  /// Custom success text shown after completion.
  final String? successText;

  const LivenessChallengeConfig({
    required this.challenge,
    double? threshold,
    this.timeout = const Duration(seconds: 10),
    this.holdDuration = const Duration(milliseconds: 500),
    this.instructionText,
    this.successText,
  }) : _threshold = threshold;
}

/// Progress info for custom progress indicator.
/// [overallProgress] = (completed steps + current step progress) / total, e.g. 33% after 1 of 3.
class LivenessProgressInfo {
  /// Current challenge index (0-based).
  final int currentIndex;

  /// Total number of challenges.
  final int total;

  /// Progress of the current challenge only (0.0 to 1.0).
  final double currentStepProgress;

  /// Overall progress of the whole flow (0.0 to 1.0).
  /// E.g. 3 steps: 1 done → 0.33, 2 done → 0.66, all done → 1.0.
  final double overallProgress;

  const LivenessProgressInfo({
    required this.currentIndex,
    required this.total,
    required this.currentStepProgress,
    required this.overallProgress,
  });
}

/// Result of a single liveness challenge.
class LivenessChallengeResult {
  final LivenessChallenge challenge;
  final LivenessChallengeState state;
  final Duration duration;

  /// The captured image at the moment this challenge completed (or failed).
  /// Ảnh được chụp tại thời điểm challenge này hoàn thành (hoặc thất bại).
  final Uint8List? capturedImage;

  LivenessChallengeResult({
    required this.challenge,
    required this.state,
    required this.duration,
    this.capturedImage,
  });
}

/// Final result of the entire liveness detection flow.
class LivenessResult {
  final bool passed;
  final List<LivenessChallengeResult> challengeResults;
  final Duration totalDuration;
  final Uint8List? capturedImage;

  const LivenessResult({
    required this.passed,
    required this.challengeResults,
    required this.totalDuration,
    this.capturedImage,
  });
}
