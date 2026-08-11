import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AquaBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AquaBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.home_outlined,
    Icons.access_time_rounded,
    Icons.camera_alt_outlined,
    Icons.smart_toy_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.navBar.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_icons.length, (i) {
                final isSelected = currentIndex == i;
                return GestureDetector(
                  onTap: () => onTap(i),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: isSelected
                        ? const BoxDecoration(
                            color: AppColors.neonCyan,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonCyan,
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          )
                        : null,
                    child: Icon(
                      _icons[i],
                      color: isSelected ? Colors.black : Colors.white38,
                      size: 22,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
