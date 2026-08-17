import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Slow-drifting blurred glow blobs behind the main screens.
///
/// Performance note: the blur is baked into each blob via
/// `Paint.maskFilter` (a canvas-level Gaussian blur), NOT
/// `BackdropFilter`. BackdropFilter re-samples and blurs everything
/// behind it on every frame — expensive, and it would blur the glass
/// cards sitting on top of this, not just the background. A
/// maskFilter-blurred circle only costs what it costs to draw that one
/// shape. The whole thing is also wrapped in a RepaintBoundary so the
/// animation only ever repaints this one layer, never the tab content
/// stacked on top of it.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  // Long, slow loop — this should read as "drifting", not "animating".
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ColoredBox(
          color: AppColors.background,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AuroraPainter(_controller.value),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final angle = t * 2 * math.pi;

    _blob(
      canvas,
      center: Offset(
        w * (0.22 + 0.10 * math.sin(angle)),
        h * (0.20 + 0.06 * math.cos(angle * 0.8)),
      ),
      radius: w * 0.5,
      color: AppColors.cyan400.withValues(alpha: 0.14),
    );

    _blob(
      canvas,
      center: Offset(
        w * (0.82 + 0.08 * math.cos(angle * 0.6 + 1.5)),
        h * (0.32 + 0.08 * math.sin(angle * 0.9 + 1.0)),
      ),
      radius: w * 0.45,
      color: AppColors.blue600.withValues(alpha: 0.13),
    );

    _blob(
      canvas,
      center: Offset(
        w * (0.38 + 0.12 * math.sin(angle * 0.5 + 3.0)),
        h * (0.88 + 0.05 * math.cos(angle * 0.7 + 2.0)),
      ),
      radius: w * 0.4,
      color: AppColors.cyan500.withValues(alpha: 0.10),
    );
  }

  void _blob(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.t != t;
}
