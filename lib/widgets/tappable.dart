import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Consistent tap feedback for cards/buttons across the app: a real
/// Material ripple (so it matches the rest of Flutter's touch feedback)
/// plus a very subtle press-scale, with light haptics. Swapping
/// GestureDetector for this wherever something is "tappable" is most of
/// what makes the UI feel like a native, premium app instead of a
/// static mockup.
class Tappable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? splashColor;
  final bool haptic;

  const Tappable({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.splashColor,
    this.haptic = true,
  });

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            onTap: widget.onTap == null
                ? null
                : () {
                    if (widget.haptic) HapticFeedback.selectionClick();
                    widget.onTap!();
                  },
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            borderRadius: widget.borderRadius,
            splashColor: widget.splashColor,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
