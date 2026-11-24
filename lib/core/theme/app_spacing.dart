/// 8 pt spatial system of the AuxIA Design System (report 6.1.1 Espaciado).
///
/// Every margin, padding and gap is a multiple of 8; 4 is used only for
/// micro adjustments.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;

  /// Horizontal padding of every screen.
  static const double screen = 20;

  /// Minimum touch target (report 6.1.2 B): 48 x 48.
  static const double minTouchTarget = 48;

  /// Height of the primary actions placed in the thumb zone.
  static const double actionHeight = 60;
}

/// Corner radii used by the mockups.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}
