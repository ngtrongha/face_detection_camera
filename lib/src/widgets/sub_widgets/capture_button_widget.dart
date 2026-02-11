import 'package:flutter/material.dart';

/// A button widget used to trigger manual image capture.
/// Widget nút được sử dụng để kích hoạt việc chụp ảnh thủ công.
class CaptureButtonWidget extends StatelessWidget {
  /// Callback when the capture button is tapped.
  /// Gọi lại khi nhấn nút chụp.
  final VoidCallback onTap;

  /// Optional custom builder for the capture button.
  /// Hàm xây dựng tùy chỉnh tùy chọn cho nút chụp.
  final Widget Function(VoidCallback onCapture)? builder;

  /// Size of the default capture button.
  /// Kích thước của nút chụp mặc định.
  final double size;

  /// Color of the default capture button.
  /// Màu của nút chụp mặc định.
  final Color color;

  const CaptureButtonWidget({
    super.key,
    required this.onTap,
    this.builder,
    this.size = 70.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: builder != null
            ? builder!(onTap)
            : GestureDetector(
                onTap: onTap,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
