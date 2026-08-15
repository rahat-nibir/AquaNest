import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for AquaNest's dark glassmorphic UI.
///
/// These values are pulled directly from the aquanest_fixed.html mockup
/// (the same palette Login and Home were already built against). Every
/// other screen now reads from here too, instead of keeping its own
/// slightly-different copy — that mismatch was the root cause of the
/// visible background/accent-color seam when swiping between tabs.
/// The hex values themselves are unchanged from the mockup; only the
/// single-source-of-truth part is new.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF030712);
  static const Color card = Color(0xFF131C2E);
  static const Color chatSurface = Color(0xFF161F30);
  static const Color navBar = Color(0xFF111827);
  static const Color sheet = Color(0xFF0B182B);

  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color amber400 = Color(0xFFFBBF24);

  // Back-compat aliases — most of the app was already written against
  // these names, so keep them pointed at the mockup-accurate tones
  // above rather than doing a mechanical find/replace everywhere.
  static const Color neonCyan = cyan400;
  static const Color gradientBlue = blue600;
  static const Color statusGreen = Color(0xFF00E676);
  static const Color statusRed = Colors.redAccent;

  /// Hairline border used on every glass surface. Kept as one constant
  /// so "how visible should a card edge be" is a single decision.
  static const Color hairline = Color(0x14FFFFFF); // white @ 8%

  static const LinearGradient accentGradient = LinearGradient(
    colors: [cyan400, blue600],
  );
}

/// Shared spacing scale so padding/margins stop being ad-hoc per screen.
/// Loosely: xs=4 chip gaps, sm=8 inline gaps, md=12 related-item gaps,
/// lg=16 card padding, xl=20 section padding, xxl=24 page gutters.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 999;
}

/// Shared text styles so every tab title, section label, and body line
/// uses the same font, weight, and tracking instead of drifting between
/// the platform default (Roboto) and Outfit depending on which screen
/// happened to import google_fonts.
class AppText {
  AppText._();

  static TextStyle pageTitle({Color color = Colors.white}) =>
      GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle pageSubtitle({Color color = Colors.white54}) =>
      GoogleFonts.outfit(fontSize: 14, color: color);

  static TextStyle sectionLabel({Color color = Colors.white38}) =>
      GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      );

  static TextStyle cardTitle({Color color = Colors.white, double size = 15}) =>
      GoogleFonts.outfit(
          fontSize: size, fontWeight: FontWeight.w600, color: color);

  static TextStyle cardSubtitle(
          {Color color = Colors.white54, double size = 12}) =>
      GoogleFonts.outfit(fontSize: size, color: color);

  static TextStyle body({Color color = Colors.white, double size = 14}) =>
      GoogleFonts.outfit(fontSize: size, color: color);

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.white,
  }) =>
      GoogleFonts.jetBrainsMono(
          fontSize: size, fontWeight: weight, color: color);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan400,
        secondary: AppColors.blue600,
        surface: AppColors.card,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      splashColor: AppColors.cyan400.withValues(alpha: 0.12),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.cyan400
              : Colors.white38,
        ),
      ),
    );
  }
}
