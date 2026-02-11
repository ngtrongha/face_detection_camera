import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraControlsWidget extends StatelessWidget {
  final bool showControls;
  final bool showFlashButton;
  final FlashMode flashMode;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleFlash;

  const CameraControlsWidget({
    super.key,
    required this.showControls,
    required this.showFlashButton,
    required this.flashMode,
    required this.onSwitchCamera,
    required this.onToggleFlash,
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
              icon: Icons.switch_camera,
            ),
          if (showFlashButton) ...[
            const SizedBox(height: 12),
            _ControlTile(
              onTap: onToggleFlash,
              icon: flashMode == FlashMode.off ? Icons.flash_off : Icons.flash_on,
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
