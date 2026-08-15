import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A consistent "nothing here yet" placeholder — replaces the various
/// bare `Text('No X yet.')` lines that were scattered across tabs with
/// no icon, no breathing room, and inconsistent fonts.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(vertical: 36),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline),
              ),
              child: Icon(icon, color: Colors.white24, size: 26),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.cardSubtitle(color: Colors.white38, size: 13),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppText.cardSubtitle(color: Colors.white24, size: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
