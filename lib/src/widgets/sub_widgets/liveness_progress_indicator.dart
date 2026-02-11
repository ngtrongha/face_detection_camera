import 'package:flutter/material.dart';

/// Progress indicator for the liveness flow.
/// Overall progress = (completed steps + current step progress) / total steps.
/// E.g. 3 steps: after 1 done → 33%, after 2 done → 66%, all done → 100%.
/// Chỉ báo tiến trình tổng: (số bước đã xong + tiến trình bước hiện tại) / tổng bước.
class LivenessProgressIndicator extends StatelessWidget {
  /// Total number of challenges.
  final int totalChallenges;

  /// Index of the current challenge (0-based).
  final int currentChallengeIndex;

  /// Progress of the current challenge (0.0 to 1.0).
  final double progress;

  /// Fill color for the progress bar.
  final Color activeColor;

  /// Background / track color.
  final Color inactiveColor;

  /// Height of the bar.
  final double barHeight;

  /// Whether to show vertical dividers between steps.
  final bool showStepDividers;

  const LivenessProgressIndicator({
    super.key,
    required this.totalChallenges,
    required this.currentChallengeIndex,
    required this.progress,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.barHeight = 10.0,
    this.showStepDividers = true,
  });

  /// Overall progress 0.0..1.0: (completedCount + currentProgress) / total.
  double get _overallProgress {
    if (totalChallenges <= 0) return 0.0;
    final completed = currentChallengeIndex.clamp(0, totalChallenges);
    final current = (completed < totalChallenges) ? progress.clamp(0.0, 1.0) : 1.0;
    return (completed + current) / totalChallenges;
  }

  @override
  Widget build(BuildContext context) {
    if (totalChallenges <= 0) return const SizedBox.shrink();

    final overall = _overallProgress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fillWidth = width * overall.clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Track
            Container(
              width: width,
              height: barHeight,
              decoration: BoxDecoration(
                color: inactiveColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(barHeight / 2),
              ),
            ),
            // Step dividers (e.g. at 33%, 66% for 3 steps)
            if (showStepDividers && totalChallenges > 1)
              ...List.generate(totalChallenges - 1, (i) {
                final left = (i + 1) / totalChallenges * width - 1;
                return Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                );
              }),
            // Fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              width: fillWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(barHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.45),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
