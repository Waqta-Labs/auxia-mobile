import 'package:flutter/material.dart';

/// Color tokens of the AuxIA Design System (report 6.1.1).
///
/// The brand palette comes from the style guide. The surface tones are the
/// ones used by the approved mobile mockups (A_01 to A_10), sampled from them.
/// No widget should use a color literal: always one of these tokens.
abstract final class AppColors {
  // Brand palette (6.1.1 Colors).
  static const Color nightBlue = Color(0xFF212161);
  static const Color royalBlue = Color(0xFF4750DD);
  static const Color skyBlue = Color(0xFF85D5F6);
  static const Color forestGreen = Color(0xFF094542);
  static const Color emerald = Color(0xFF05C274);
  static const Color lime = Color(0xFFBCFB89);

  // Base colors (6.1.1 Base Color).
  static const Color coral = Color(0xFFFF4D4D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Surfaces of the dark mobile theme.
  static const Color background = Color(0xFF1A1E36);
  static const Color surface = nightBlue;
  static const Color surfaceHigh = Color(0xFF282967);
  static const Color surfaceDeep = Color(0xFF0D1127);
  static const Color outline = Color(0xFF2E3370);
  static const Color neutralFill = Color(0xFF363B56);
  static const Color track = Color(0xFF2A2F4C);

  // Tinted containers for selected and status cards.
  static const Color limeContainer = Color(0xFF324043);
  static const Color emeraldContainer = Color(0xFF17373F);
  static const Color skyContainer = Color(0xFF243A6B);
  static const Color royalContainer = Color(0xFF2C3290);
  static const Color coralContainer = Color(0xFF3C263A);

  // Text.
  static const Color textPrimary = white;
  static const Color textSecondary = Color(0xFFA0A4BF);
  static const Color textMuted = Color(0xFF6E7392);
  static const Color onAccent = surfaceDeep;
}
