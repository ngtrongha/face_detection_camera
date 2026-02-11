import 'package:flutter/material.dart';

class CaptureButtonWidget extends StatelessWidget {
  final VoidCallback onTap;
  final Widget Function(VoidCallback onCapture)? builder;

  const CaptureButtonWidget({
    super.key,
    required this.onTap,
    this.builder,
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
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
