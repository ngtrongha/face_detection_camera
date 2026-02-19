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

  /// Whether to capture an image upon completion of each challenge.
  /// Có chụp ảnh khi hoàn thành mỗi thử thách hay không.
  final bool captureOnComplete;

  /// Callback to capture an image from the camera.
  /// Gọi lại để chụp ảnh từ camera.
  final Future<Uint8List?> Function()? captureCallback;

  /// Maximum number of tracking ID changes allowed before failing (anti-spoofing).
  /// Số lần thay đổi tracking ID tối đa cho phép trước khi fail (chống giả mạo).
  final int maxTrackingIdChanges;

  /// Delay between challenges for UX transition.
  /// Thời gian chờ giữa các thử thách để chuyển đổi UX.
  final Duration challengeDelay;

  final LivenessService _livenessService = LivenessService();

  /// Notifier for the overall state of the liveness flow.
  /// Thông báo cho trạng thái tổng thể của luồng liveness.
  final ValueNotifier<LivenessState> livenessState = ValueNotifier(
    LivenessState.idle,
  );

  /// Notifier for the index of the current active challenge.
  /// Thông báo cho chỉ số của thử thách hiện đang hoạt động.
  final ValueNotifier<int> currentChallengeIndex = ValueNotifier(0);

  /// Notifier for the state of the current active challenge.
  /// Thông báo cho trạng thái của thử thách hiện đang hoạt động.
  final ValueNotifier<LivenessChallengeState> currentChallengeState =
      ValueNotifier(LivenessChallengeState.pending);

  /// Notifier for the progress of the current challenge (0.0 to 1.0).
  /// Thông báo cho tiến trình của thử thách hiện tại (0.0 đến 1.0).
  final ValueNotifier<double> challengeProgress = ValueNotifier(0.0);

  final List<LivenessChallengeResult> _results = [];
  DateTime? _challengeStartTime;
  DateTime? _flowStartTime;
  Timer? _timeoutTimer;
  Timer? _holdTimer;
  int? _lastTrackingId;
  int _trackingIdChangeCount = 0;
  bool _isDisposed = false;

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
    this.captureCallback,
    this.maxTrackingIdChanges = 3,
    this.challengeDelay = const Duration(milliseconds: 500),
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
    if (_isDisposed) return;

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
      if (!_isDisposed) {
        _failChallenge(index, LivenessChallengeState.timeout);
      }
    });

    notifyListeners();
  }

  /// Processes a face frame from the camera stream to check challenge criteria.
  /// Xử lý một khung hình khuôn mặt từ luồng camera để kiểm tra các tiêu chí thử thách.
  void processFace(Face face) {
    if (_isDisposed) return;
    if (livenessState.value != LivenessState.detecting) return;
    if (currentChallengeState.value != LivenessChallengeState.active) return;

    // Anti-spoofing check: allow a limited number of tracking ID changes
    // to tolerate momentary face loss and re-detection.
    if (face.trackingId != null &&
        _lastTrackingId != null &&
        face.trackingId != _lastTrackingId) {
      _trackingIdChangeCount++;
      if (_trackingIdChangeCount > maxTrackingIdChanges) {
        _failChallenge(
          currentChallengeIndex.value,
          LivenessChallengeState.failed,
        );
        return;
      }
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

  /// Called when face is lost (no face detected).
  /// Cancel hold timer to prevent challenge from passing without a face.
  /// Gọi khi mất khuôn mặt (không phát hiện khuôn mặt).
  /// Hủy hold timer để ngăn challenge tự pass khi không có mặt.
  void onFaceLost() {
    _handleChallengeUnmet();
  }

  void _handleChallengeMet() {
    if (_holdTimer != null) return;

    final config = challenges[currentChallengeIndex.value];
    final holdMs = config.holdDuration.inMilliseconds;

    DateTime holdStart = DateTime.now();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

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

  /// Captures an image for the current challenge result.
  /// Returns null if capture is disabled or fails.
  Future<Uint8List?> _captureForChallenge() async {
    if (!captureOnComplete || captureCallback == null) return null;
    try {
      return await captureCallback!();
    } catch (e) {
      debugPrint('Error capturing image for challenge: $e');
      return null;
    }
  }

  Future<void> _successChallenge(int index) async {
    _timeoutTimer?.cancel();

    final config = challenges[index];
    final duration = DateTime.now().difference(_challengeStartTime!);

    // Capture image for this specific challenge
    final Uint8List? challengeImage = await _captureForChallenge();
    if (_isDisposed) return;

    _results.add(
      LivenessChallengeResult(
        challenge: config.challenge,
        state: LivenessChallengeState.success,
        duration: duration,
        capturedImage: challengeImage,
      ),
    );

    currentChallengeState.value = LivenessChallengeState.success;
    onChallengeComplete?.call(config, index);
    notifyListeners();

    // Configurable delay before next challenge for UX
    // Guard against disposed state to prevent crash.
    Future.delayed(challengeDelay, () {
      if (!_isDisposed && livenessState.value == LivenessState.detecting) {
        _startChallenge(index + 1);
      }
    });
  }

  Future<void> _failChallenge(int index, LivenessChallengeState reason) async {
    if (_isDisposed) return;

    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    _holdTimer = null;

    final config = challenges[index];
    final duration = DateTime.now().difference(_challengeStartTime!);

    // Capture image even on failure for audit/review
    final Uint8List? challengeImage = await _captureForChallenge();
    if (_isDisposed) return;

    _results.add(
      LivenessChallengeResult(
        challenge: config.challenge,
        state: reason,
        duration: duration,
        capturedImage: challengeImage,
      ),
    );

    currentChallengeState.value = reason;
    livenessState.value = LivenessState.failed;
    onChallengeFailed?.call(config, index);

    _completeFlow(passed: false);
  }

  Future<void> _completeFlow({bool passed = true}) async {
    if (_isDisposed) return;

    livenessState.value = passed
        ? LivenessState.completed
        : LivenessState.failed;

    // Use the last challenge's captured image as the overall result image.
    // This avoids an extra capture call since we already captured per-challenge.
    final Uint8List? lastCapturedImage = _results.isNotEmpty
        ? _results.last.capturedImage
        : null;

    final totalDuration = DateTime.now().difference(_flowStartTime!);
    final result = LivenessResult(
      passed: passed,
      challengeResults: List.from(_results),
      totalDuration: totalDuration,
      capturedImage: lastCapturedImage,
    );

    onLivenessComplete?.call(result);
    notifyListeners();
  }

  /// Resets the controller and clears all progress.
  /// Đặt lại bộ điều khiển và xóa tất cả tiến trình.
  void reset() {
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    _holdTimer = null;
    _results.clear();
    livenessState.value = LivenessState.idle;
    currentChallengeIndex.value = 0;
    currentChallengeState.value = LivenessChallengeState.pending;
    challengeProgress.value = 0.0;
    _lastTrackingId = null;
    _trackingIdChangeCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timeoutTimer?.cancel();
    _holdTimer?.cancel();
    livenessState.dispose();
    currentChallengeIndex.dispose();
    currentChallengeState.dispose();
    challengeProgress.dispose();
    super.dispose();
  }
}
