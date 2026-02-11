import 'package:flutter/material.dart';
import '../../models/liveness_types.dart';

/// An overlay widget that displays instructions for the current liveness challenge.
/// Một widget lớp phủ hiển thị các hướng dẫn cho thử thách liveness hiện tại.
class LivenessChallengeOverlay extends StatelessWidget {
  /// The current active challenge.
  /// Thử thách hiện đang hoạt động.
  final LivenessChallenge challenge;

  /// The current state of the challenge.
  /// Trạng thái hiện tại của thử thách.
  final LivenessChallengeState state;

  /// Custom instruction text to override the default.
  /// Văn bản hướng dẫn tùy chỉnh để ghi đè mặc định.
  final String? customInstruction;

  /// Color of the overlay background.
  /// Màu của nền lớp phủ.
  final Color backgroundColor;

  /// Color of the instruction text.
  /// Màu của văn bản hướng dẫn.
  final Color textColor;

  /// Icon for blink challenge.
  final IconData blinkIcon;

  /// Icon for smile challenge.
  final IconData smileIcon;

  /// Icon for turn left challenge.
  final IconData turnLeftIcon;

  /// Icon for turn right challenge.
  final IconData turnRightIcon;

  /// Icon for nod up challenge.
  final IconData nodUpIcon;

  /// Icon for nod down challenge.
  final IconData nodDownIcon;

  const LivenessChallengeOverlay({
    super.key,
    required this.challenge,
    required this.state,
    this.customInstruction,
    this.backgroundColor = Colors.black54,
    this.textColor = Colors.white,
    this.blinkIcon = Icons.remove_red_eye,
    this.smileIcon = Icons.sentiment_very_satisfied,
    this.turnLeftIcon = Icons.arrow_back,
    this.turnRightIcon = Icons.arrow_forward,
    this.nodUpIcon = Icons.arrow_upward,
    this.nodDownIcon = Icons.arrow_downward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          const SizedBox(height: 16),
          Text(
            _getInstruction(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (state == LivenessChallengeState.timeout)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Timed out! Please try again.',
                style: TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color iconColor = Colors.blue;

    if (state == LivenessChallengeState.success) {
      iconData = Icons.check_circle;
      iconColor = Colors.green;
    } else {
      switch (challenge) {
        case LivenessChallenge.blink:
          iconData = blinkIcon;
          break;
        case LivenessChallenge.smile:
          iconData = smileIcon;
          break;
        case LivenessChallenge.turnLeft:
          iconData = turnLeftIcon;
          break;
        case LivenessChallenge.turnRight:
          iconData = turnRightIcon;
          break;
        case LivenessChallenge.nodUp:
          iconData = nodUpIcon;
          break;
        case LivenessChallenge.nodDown:
          iconData = nodDownIcon;
          break;
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Icon(
        iconData,
        key: ValueKey(iconData),
        size: 64,
        color: iconColor,
      ),
    );
  }

  String _getInstruction() {
    if (state == LivenessChallengeState.success) return 'Success!';
    if (customInstruction != null) return customInstruction!;

    switch (challenge) {
      case LivenessChallenge.blink:
        return 'Blink your eyes';
      case LivenessChallenge.smile:
        return 'Smile for the camera';
      case LivenessChallenge.turnLeft:
        return 'Turn your head left';
      case LivenessChallenge.turnRight:
        return 'Turn your head right';
      case LivenessChallenge.nodUp:
        return 'Nod your head up';
      case LivenessChallenge.nodDown:
        return 'Nod your head down';
    }
  }
}
