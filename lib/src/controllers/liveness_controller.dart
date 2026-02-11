import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/liveness_types.dart';
import '../services/liveness_service.dart';

/// Controller to manage the liveness detection flow.
/// Bộ điều khiển để quản lý luồng phát hiện tính liveness.
class LivenessController extends ChangeNotifier {
  /// Sequence of challenges to perform.
  /// Chuỗi các thử thách cần thực hiện.
  final List<LivenessChallengeConfig> challenges;

  /// Whether to capture an image upon successful completion of all challenges.
  /// Có chụp ảnh khi hoàn thành thành công tất cả các thử thách hay không.
  final bool captureOnComplete;

  final LivenessService _livenessService = LivenessService();

  /// Notifier for the overall state of the liveness flow.
  /// Thông báo cho trạng thái tổng thể của luồng liveness.
  final ValueNotifier<LivenessState> livenessState = ValueNotifier(LivenessState.idle);

  /// Notifier for the index of the current active challenge.
  /// Thông báo cho chỉ số của thử thách hiện đang hoạt động.
  final ValueNotifier<int> currentChallengeIndex = ValueNotifier(0);

  /// Notifier for the state of the current active challenge.
  /// Thông báo cho trạng thái của thử thách hiện đang hoạt động.
  final ValueNotifier<LivenessChallengeState> currentChallengeState = ValueNotifier(LivenessChallengeState.pending);

  /// Notifier for the progress of the current challenge (0.0 to 1.0).
  /// Thông báo cho tiến trình của thử thách hiện tại (0.0 đến 1.0).
  final ValueNotifier<double> challengeProgress = ValueNotifier(0.0);

  final List<LivenessChallengeResult> _results = [];
  DateTime? _challengeStartTime;
  DateTime? _flowStartTime;
  Timer? _timeoutTimer;
  Timer? _holdTimer;
  int? _lastTrackingId;

  /// Callback when a new challenge starts.
  /// Gọi lại khi một thử thách mới bắt đầu.
  void Function(LivenessChallengeConfig config, int index)? onChallengeStart;

  /// Callback when a challenge is successfully completed.
  /// Gọi lại khi một thử thách được hoàn thành thành công.
  void Function(LivenessChallengeConfig config, int index)? onChallengeComplete;

  /// Callback when a challenge fails or times out.
  /// Gọi lại khi một thử thách thất bại hoặc hết thời gian.
  void Function(LivenessChallengeConfig config, int index)? onChallengeFailed;

  /// Final callback when the entire liveness flow completes.
  /// Gọi lại cuối cùng khi toàn bộ luồng liveness hoàn tất.
  void Function(LivenessResult result)? onLivenessComplete;

  LivenessController({
    required this.challenges,
    this.captureOnComplete = true,
    this.onChallengeStart,
    this.onChallengeComplete,
    this.onChallengeFailed,
    this.onLivenessComplete,
  }) {
    if (challenges.isEmpty) {
      throw ArgumentError('At least one challenge must be provided.');
    }
  }

  /// Starts the liveness detection flow.
  /// Bắt đầu luồng phát hiện tính liveness.
  void start() {
    if (livenessState.value != LivenessState.idle) return;

    _flowStartTime = DateTime.now();
    livenessState.value = LivenessState.detecting;
    _startChallenge(0);
  }

  void _startChallenge(int index) {
    if (index >= challenges.length) {
      _completeFlow();
      return;
    }

    currentChallengeIndex.value = index;
    currentChallengeState.value = LivenessChallengeState.active;
    challengeProgress.value = 0.0;
    _challengeStartTime = DateTime.now();

    final config = challenges[index];
    onChallengeStart?.call(config, index);

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(config.timeout, () {
      _failChallenge(index, LivenessChallengeState.timeout);
    });

    notifyListeners();
  }

  /// Processes a face frame from the camera stream to check challenge criteria.
  /// Xử lý một khung hình khuôn mặt từ luồng camera để kiểm tra các tiêu chí thử thách.
  void processFace(Face face) {
    if (livenessState.value != LivenessState.detecting) return;
    if (currentChallengeState.value != LivenessChallengeState.active) return;

    // Anti-spoofing check
    if (!_livenessService.verifyTrackingConsistency(face, _lastTrackingId)) {
      _failChallenge(currentChallengeIndex.value, LivenessChallengeState.failed);
      return;
    }
    _lastTrackingId = face.trackingId;

    final config = challenges[currentChallengeIndex.value];
    final isMet = _livenessService.isChallengeMet(face, config);

    if (isMet) {
      _handleChallengeMet();
    } else {
      _handleChallengeUnmet();
    }
  }

  void _handleChallengeMet() {
    if (_holdTimer != null) return;

    final config = challenges[currentChallengeIndex.value];
    final holdMs = config.holdDuration.inMilliseconds;

    DateTime holdStart = DateTime.now();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final elapsed = DateTime.now().difference(holdStart).inMilliseconds;
      challengeProgress.value = (elapsed / holdMs).clamp(0.0, 1.0);

      if (elapsed >= holdMs) {
        timer.cancel();
        _holdTimer = null;
        _successChallenge(currentChallengeIndex.value);
      }
    });
  }

  void _handleChallengeUnmet() {
    if (_holdTimer != null) {
      _holdTimer!.cancel();
      _holdTimer = null;
      challengeProgress.value = 0.0;
    }
  }

  void _successChallenge(int index) {
    _timeoutTimer?.cancel();

    final config = challenges[index];
    final duration = DateTime.now().difference(_challengeStartTime!);

    _results.add(LivenessChallengeResult(
      challenge: config.challenge,
      state: LivenessChallengeState.success,
      duration: duration,
    ));

    currentChallengeState.value = LivenessChallengeState.success;
    onChallengeComplete?.call(config, index);
    notifyListeners();

    // Short delay before next challenge for UX
    Future.delayed(const Duration(milliseconds: 500), () {
      _startChallenge(index + 1);
    });
  }

  void _failChallenge(int index, LivenessChallengeState reason) {
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();

    final config = challenges[index];
    final duration = DateTime.now().difference(_challengeStartTime!);

    _results.add(LivenessChallengeResult(
      challenge: config.challenge,
      state: reason,
      duration: duration,
    ));

    currentChallengeState.value = reason;
    livenessState.value = LivenessState.failed;
    onChallengeFailed?.call(config, index);

    _completeFlow(passed: false);
  }

  void _completeFlow({bool passed = true}) {
    livenessState.value = passed ? LivenessState.completed : LivenessState.failed;

    final totalDuration = DateTime.now().difference(_flowStartTime!);
    final result = LivenessResult(
      passed: passed,
      challengeResults: List.from(_results),
      totalDuration: totalDuration,
    );

    onLivenessComplete?.call(result);
    notifyListeners();
  }

  /// Resets the controller and clears all progress.
  /// Đặt lại bộ điều khiển và xóa tất cả tiến trình.
  void reset() {
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    _results.clear();
    livenessState.value = LivenessState.idle;
    currentChallengeIndex.value = 0;
    currentChallengeState.value = LivenessChallengeState.pending;
    challengeProgress.value = 0.0;
    _lastTrackingId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    livenessState.dispose();
    currentChallengeIndex.dispose();
    currentChallengeState.dispose();
    challengeProgress.dispose();
    super.dispose();
  }
}
