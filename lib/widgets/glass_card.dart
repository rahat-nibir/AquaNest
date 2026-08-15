import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tappable.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.onTap,
    this.radius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    // The glow lives on this OUTER Container, not inside the ClipRRect
    // below — a BoxShadow on a clipped widget gets clipped away with
    // everything else, which would silently kill the "glowing border"
    // effect. Clipping only wraps the actual card content.
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan400.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? AppColors.cyan400.withValues(alpha: 0.14),
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return card;

    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: card,
    );
  }
}
