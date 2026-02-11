import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Widget that displays camera controls like lens switch and flash toggle.
/// Widget hiển thị các bộ điều khiển camera như chuyển đổi ống kính và bật/tắt đèn flash.
class CameraControlsWidget extends StatelessWidget {
  /// Whether to show the camera lens switching button.
  /// Có hiển thị nút chuyển đổi ống kính camera hay không.
  final bool showControls;

  /// Whether to show the flash toggle button.
  /// Có hiển thị nút chuyển đổi đèn flash hay không.
  final bool showFlashButton;

  /// Current camera flash mode.
  /// Chế độ đèn flash camera hiện tại.
  final FlashMode flashMode;

  /// Callback when the camera lens switching button is tapped.
  /// Gọi lại khi nhấn nút chuyển đổi ống kính camera.
  final VoidCallback onSwitchCamera;

  /// Callback when the flash toggle button is tapped.
  /// Gọi lại khi nhấn nút chuyển đổi đèn flash.
  final VoidCallback onToggleFlash;

  /// Optional icon for camera switching.
  /// Biểu tượng tùy chọn cho việc chuyển đổi camera.
  final IconData? switchCameraIcon;

  /// Optional icon for flash on.
  /// Biểu tượng tùy chọn cho khi đèn flash bật.
  final IconData? flashOnIcon;

  /// Optional icon for flash off.
  /// Biểu tượng tùy chọn cho khi đèn flash tắt.
  final IconData? flashOffIcon;

  const CameraControlsWidget({
    super.key,
    required this.showControls,
    required this.showFlashButton,
    required this.flashMode,
    required this.onSwitchCamera,
    required this.onToggleFlash,
    this.switchCameraIcon,
    this.flashOnIcon,
    this.flashOffIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      right: 20,
      child: Column(
        children: [
          if (showControls)
            _ControlTile(
              onTap: onSwitchCamera,
              icon: switchCameraIcon ?? Icons.switch_camera,
            ),
          if (showFlashButton) ...[
            const SizedBox(height: 12),
            _ControlTile(
              onTap: onToggleFlash,
              icon: flashMode == FlashMode.off
                  ? (flashOffIcon ?? Icons.flash_off)
                  : (flashOnIcon ?? Icons.flash_on),
              iconColor: flashMode == FlashMode.off ? Colors.white : Colors.yellow,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;

  const _ControlTile({
    required this.onTap,
    required this.icon,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 30,
        ),
      ),
    );
  }
}
