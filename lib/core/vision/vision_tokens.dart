import '../theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Collider Vision design tokens.
///
/// Sources:
///  - Type scale, radii, spacing, blur, shadows, text/border/overlay colours and
///    accents: `visionOS copilot kit.tsx` (DS tokens, dark theme).
///  - Glass materials per depth plane: `lib/core/theme/spatial_theme.dart`.
///  - Cell / active fills: the shipping Collider widgets (0x14 rest, 0x38 active).
class VColors {
  VColors._();

  // Text (kit dark theme)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xF2FFFFFF); // dense glass: near-full white // rgba(255,255,255,0.70)
  static const Color textTertiary = Color(0xD9FFFFFF); // rgba(255,255,255,0.45)

  // Borders (kit dark theme)
  static const Color borderLight = Color(0x1FFFFFFF); // 0.12
  static const Color borderHeavy = Color(0x3DFFFFFF); // 0.24

  // Overlays (kit)
  static const Color overlayLight = Color(0x2EFFFFFF); // 0.18
  static const Color overlayDark = Color(0x59000000); // 0.35

  // Kit glass (opaque-leaning fallback surfaces)
  static const Color glassDark = Color(0xBF14141E); // rgba(20,20,30,0.75)
  static const Color glassDarkHeavy = Color(0x8C14141E); // rgba(20,20,30,0.55)

  // Materials per depth plane (spatial_theme.dart)
  static const Color glassPrompt = Color(0x18FFFFFF);
  static const Color glassResting = Color(0x1EFFFFFF);
  static const Color glassElevated = Color(0x24FFFFFF);
  static const Color glassModal = Color(0x28FFFFFF);
  static const Color glassWork = Color(0x2CFFFFFF);

  // Cell fills (shipping widgets)
  static const Color fillCell = Color(0x14FFFFFF);
  static const Color fillActive = Color(0x38FFFFFF);
  static const Color fillRecessed = overlayDark;

  // Accents (kit)
  static const Color accentBlue = Color(0xFF0A84FF);
  static const Color accentGreen = Color(0xFF30D158);
  static const Color accentRed = Color(0xFFFF453A);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color accentPurple = Color(0xFFBF5AF2);
  static const Color accentTeal = Color(0xFF64D2FF);
}

class VRadius {
  VRadius._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 22;
  static const double xl = 32;
  static const double card = 24;
  static const double sheet = 32;
  static const double full = 999;
}

class VSpace {
  VSpace._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

/// v9.1.4 (playtest #3): the one depth convention. Everything behind a
/// temporary panel gets exactly this blur and this dim; panels themselves
/// use VFrost glass. Three tokens, every screen.
class VDepth {
  VDepth._();
  static const double blur = 16;
  static const Color dim = Color(0x47000000);
}

class VBlur {
  VBlur._();
  static const double light = 12;
  static const double medium = 20;
  static const double heavy = 32;
  static const double sheet = 40;
}

/// Elevation: downward Flutter (Material) shadows in four levels by layer:
/// base 0, panel 2, floating 6, modal 12. One constant per layer depth.
class VElev {
  VElev._();
  // Material elevation geometry (kElevationToShadow 2/6/12), alpha doubled
  // because every surface here sits on a dark scene. All fall downward.
  static const List<BoxShadow> e0 = [];
  static const List<BoxShadow> e2 = [
    BoxShadow(offset: Offset(0, 3), blurRadius: 1, spreadRadius: -2, color: Color(0x66000000)),
    BoxShadow(offset: Offset(0, 2), blurRadius: 2, color: Color(0x48000000)),
    BoxShadow(offset: Offset(0, 1), blurRadius: 5, color: Color(0x3E000000)),
  ];
  static const List<BoxShadow> e6 = [
    BoxShadow(offset: Offset(0, 3), blurRadius: 5, spreadRadius: -1, color: Color(0x66000000)),
    BoxShadow(offset: Offset(0, 6), blurRadius: 10, color: Color(0x48000000)),
    BoxShadow(offset: Offset(0, 1), blurRadius: 18, color: Color(0x3E000000)),
  ];
  static const List<BoxShadow> e12 = [
    BoxShadow(offset: Offset(0, 7), blurRadius: 8, spreadRadius: -4, color: Color(0x66000000)),
    BoxShadow(offset: Offset(0, 12), blurRadius: 17, spreadRadius: 2, color: Color(0x48000000)),
    BoxShadow(offset: Offset(0, 5), blurRadius: 22, spreadRadius: 4, color: Color(0x3E000000)),
  ];
}

class VShadow {
  VShadow._();
  static const List<BoxShadow> subtle = VElev.e2;
  static const List<BoxShadow> medium = VElev.e6;
  static const List<BoxShadow> heavy = VElev.e12;
  static const List<BoxShadow> recessed = VElev.e6;
}

/// Figma type. Body 17/22 −0.4, Note 15/20 −0.4. Window titles match the
/// visionOS "Albums" token (29/34 bold). Section titles match "My Albums" (22).
/// Nothing on a surface uses a display size above that.
class VType {
  VType._();
  static const double xs = 11;
  static const double sm = 13;
  static const double md = 17;
  static const double lg = 17;
  static const double xl = 22;
  static const double xxl = 29;
  static const double displaySm = 29;
  static const double displayMd = 29;
  static const double displayLg = 29;

  static const double tight = 34 / 29;
  static const double normal = 22 / 17;
  static const double relaxed = 22 / 17;

  static TextStyle _t(double size, FontWeight w, Color c, double h, {double tracking = 0}) =>
      appFont(fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: tracking);

  static TextStyle display({Color color = VColors.textPrimary}) => _t(29, FontWeight.w700, color, 34 / 29);
  static TextStyle title({Color color = VColors.textPrimary}) => _t(29, FontWeight.w700, color, 34 / 29);
  static TextStyle title2({Color color = VColors.textPrimary}) => _t(22, FontWeight.w700, color, 26 / 22);
  static TextStyle headline({Color color = VColors.textPrimary}) => _t(17, FontWeight.w600, color, 22 / 17, tracking: -0.4);
  static TextStyle body({Color color = VColors.textPrimary, FontWeight weight = FontWeight.w500}) => _t(17, weight, color, 22 / 17, tracking: -0.4);
  static TextStyle callout({Color color = VColors.textPrimary, FontWeight weight = FontWeight.w500}) => _t(15, weight, color, 20 / 15, tracking: -0.4);
  static TextStyle footnote({Color color = VColors.textSecondary, FontWeight weight = FontWeight.w500}) => _t(15, weight, color, 20 / 15, tracking: -0.4);
  static TextStyle caption({Color color = VColors.textTertiary, FontWeight weight = FontWeight.w500}) => _t(13, weight, color, 16 / 13, tracking: -0.2);
}

/// Overlay law: an overlay is a pause menu — small, temporary, content-hugging.
/// The wallpaper and the resting content stay visible and sharp around it;
/// the dim is light and never blurred. Nothing an overlay shows is full width.
class VOverlay {
  VOverlay._();

  /// Light, unblurred dim behind any overlay.
  static const Color scrim = Color(0x33000000); // black 20%

  static bool _phone(BuildContext c) => MediaQuery.sizeOf(c).width < 768;

  /// Menus: settings, history, models, skills, tiers, zoom, alert.
  static double menuWidth(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return _phone(c) ? (w - 104).clamp(240.0, 300.0) : 340.0;
  }

  static double menuMaxHeight(BuildContext c) => MediaQuery.sizeOf(c).height * 0.46;

  /// Tools: Smart Gen, Discover, Files, Browser, Consensus.
  static double toolWidth(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return _phone(c) ? (w - 104).clamp(260.0, 300.0) : (w * 0.46).clamp(480.0, 640.0);
  }

  static double toolMaxHeight(BuildContext c) => MediaQuery.sizeOf(c).height * (_phone(c) ? 0.56 : 0.6);
}

class VMotion {
  VMotion._();
  static const double pressedScale = 0.97;
  static const double pressedOpacity = 0.9;
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
}
