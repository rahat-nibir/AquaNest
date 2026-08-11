import 'package:flutter/material.dart';

/// Central design tokens for AquaNest's dark glassmorphic UI.
/// Keeping these in one place means every screen/tab stays visually
/// consistent and a palette change is a one-file edit.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF090E17);
  static const Color card = Color(0xFF131C2E);
  static const Color chatSurface = Color(0xFF161F30);
  static const Color navBar = Color(0xFF111827);

  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color gradientBlue = Color(0xFF3B82F6);
  static const Color statusGreen = Color(0xFF00E676);
  static const Color statusRed = Colors.redAccent;

  static const LinearGradient accentGradient = LinearGradient(
    colors: [neonCyan, gradientBlue],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonCyan,
        secondary: AppColors.gradientBlue,
        surface: AppColors.card,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.neonCyan
              : Colors.white38,
        ),
      ),
    );
  }
}
