
import 'package:flutter/material.dart';

/// COLLIDER KIT — the single source of truth for every visual primitive.
///
/// The reference material is many different design systems (Vision OS Design
/// System, wechat vision os, Prime Video, Vision Pro Spatial UI Kit, Frosted
/// Micro, Nimo...). We are NOT reproducing each one faithfully and separately.
/// That is how an app ends up looking like fifteen apps. Instead:
///
///   1. For each primitive, one instance was chosen as canonical.
///   2. Its provenance is recorded so a later change can trace back to intent.
///   3. Every surface uses [Kit] values. Where an older local value exists it is
///      a migration, not an exception.
///
/// Provenance shorthand:
///   VOS  = Vision OS Design System
///   WCH  = wechat vision os
///   VPK  = Vision Pro Spatial UI Kit
///   PQ   = Prime Video visionOS
///   FMK  = Frosted Micro UI Kit
///   RN   = Reference Native (already transcribed into this repo)
///
/// PRD anchors: R36 (visionOS glass, wallpaper is the star, specular rim,
/// spring not particles), D8 (same), D11 (type from the visionOS set),
/// R08 (no card chrome on the ticker).
class Kit {
  const Kit._();

  // ─────────────────────────────────────────────────────────── glass planes ──
  /// R36: "blur or tint separates planes, specular rim". One material, used
  /// everywhere, at five elevations. Fill is the RN value that already ships
  /// (FGlass) — visionOS "Windows/Glass" exports as rgba(128,128,128,0.30).
  static const Color glassFill = Color(0x4D808080); // 30%

  /// Hairline rim. Deliberately LOW alpha and never pure white at full
  /// strength: R08 forbids card chrome, and a hard 1px white stroke reads as a
  /// border. Use only where a rim is load-bearing (see [rimHairline]).
  static const Color rim = Color(0x66FFFFFF); // 40%, RN/FRail

  /// The subtle rim for floating planes. Preferred over [rim]; a plane is
  /// separated by blur + tint first, this only catches a specular edge.
  static const Color rimHairline = Color(0x26FFFFFF); // 15%

  /// Backdrop blur, in logical px. RN/FGlass stored CSS `backdrop-blur(Npx)`;
  /// Flutter's ImageFilter.blur takes a sigma, and CSS blur radius ≈ 2×sigma,
  /// so a CSS N maps to sigma N/2. RN already does blur/2 * scale.
  static const double blurWindow = 50; // FGlass default (CSS)
  static const double blurMenu = 20; // GlassMenu (CSS)
  static const double blurOrnament = 28; // VMaterial.elevated / RN

  // ─────────────────────────────────────────────────────── elevation scale ──
  /// RN SpatialDepthPlane, collapsed to the values actually referenced.
  /// index 0..4 = base, resting, elevated, modal, workSurface.
  static const List<Color> elevationFill = <Color>[
    Color(0x00000000), // base — transparent, the wallpaper shows through
    Color(0x1EFFFFFF), // resting
    Color(0x24FFFFFF), // elevated
    Color(0x28FFFFFF), // modal
    Color(0x2CFFFFFF), // workSurface
  ];

  static const List<double> elevationBlur = <double>[0, 24, 28, 32, 36];

  static const List<Color> elevationRim = <Color>[
    Color(0x00000000),
    Color(0x2EFFFFFF), // 18%
    Color(0x3DFFFFFF), // 24%
    Color(0x47FFFFFF), // 28%
    Color(0x52FFFFFF), // 32%
  ];

  /// Ambient occlusion per elevation (RN ambientShadow). Kept as data so a
  /// surface can pick by index instead of re-declaring BoxShadows.
  static List<BoxShadow> shadow(int level) {
    const List<double> opacities = <double>[0, 0.22, 0.28, 0.32, 0.36];
    const List<double> blurs = <double>[0, 32, 40, 48, 56];
    const List<double> offsets = <double>[0, 12, 16, 20, 24];
    if (level <= 0) return const <BoxShadow>[];
    final int i = level < blurs.length ? level : blurs.length - 1;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(opacities[i]),
        blurRadius: blurs[i],
        offset: Offset(0, offsets[i]),
      ),
    ];
  }

  // ──────────────────────────────────────────────────────────────── radii ──
  /// One radius scale. Cards and windows round generously (visionOS), pills
  /// round fully. Never invent a radius inline.
  static const double radiusWindow = 24; // RN GlassMenu window
  static const double radiusCard = 20; // RN cards / alert
  static const double radiusControl = 12; // inputs, list rows
  static const double radiusThumbnail = 10; // RN cover/thumb

  /// Fully-round for any pill or circular control: radius = half the height.
  static BorderRadius get radiusPill => BorderRadius.circular(999);

  /// Circular disc of a given size.
  static BorderRadius radiusCircle(double d) => BorderRadius.circular(d / 2);

  // ───────────────────────────────────────────────────────────── controls ──
  /// Circular glass button. RN PermanentNavBar uses 44; FRail uses 44 with a
  /// 76-wide rail at 69 pitch. 44 is the canonical touch target.
  static const double controlCircle = 44;

  /// Icon size inside a [controlCircle] button.
  static const double controlIcon = 24;

  /// Selected-state disc behind an icon: RN FRail 7% white + #5E5E5E 18%.
  static const Color selectedDisc = Color(0x2EFFFFFF);

  /// Idle opacity for non-active rail/tab icons (RN FRail).
  static const double iconIdleOpacity = 0.4;
  static const double iconActiveOpacity = 1.0;

  /// The dock (R11: Compose, Settings, Apps — three, not five).
  static const int dockItems = 3;
  static const double dockGap = 12;
  static const double dockPad = 6;
  static const double dockInsetBottom = 12;

  /// Dock capsule width, derived — never hardcode the sum at a call site.
  static double get dockWidth =>
      dockItems * controlCircle + (dockItems - 1) * dockGap + 2 * dockPad;

  // ──────────────────────────────────────────────────────────────── input ──
  /// Search / text input. RN market search: 50 tall, radius 12-ish.
  static const double inputHeight = 50;
  static const double inputRadius = 12;
  static const double inputPadX = 16;

  /// Menu row rhythm (RN GlassMenu): 40 tall, 4 between, 16 card padding.
  static const double menuRowHeight = 40;
  static const double menuRowGap = 4;
  static const double menuPad = 16;
  static const double menuIconDisc = 40;

  /// Menu width in Figma px before the frame scale (RN GlassMenu).
  static const double menuWidth = 240;
  static const int menuFrameWidth = 637;

  // ─────────────────────────────────────────────────────────────── motion ──
  /// D8/R36: spring, not particles. Two durations only, so motion reads as one
  /// system. RN values: base + fast.
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionBase = Duration(milliseconds: 280);

  /// Easing: RN uses cubic-bezier(0.4,0,0.2,1) (Flutter's ease) and
  /// cubic-bezier(0.23,1,0.32,1) for the market card transition.
  static const Cubic motionEase = Cubic(0.4, 0, 0.2, 1);
  static const Cubic motionEmphasised = Cubic(0.23, 1, 0.32, 1);

  // ──────────────────────────────────────────────────────────────── type ──
  /// D11: "type comes from the visionOS set". RN FText hardcodes Inter, which
  /// is the working value today; spatial_theme.dart's Cormorant Garamond +
  /// Instrument Sans are the display pair. Both are legal; they must not be
  /// mixed within one surface. Inter = UI. Display pair = headings/hero only.
  static const String uiFont = 'Inter';

  static const double typeTitle = 16;
  static const double typeBody = 13;
  static const double typeCaption = 11;
  static const double typeHero = 28;

  // ──────────────────────────────────────────────────── ticker's frame fit ──
  /// R08 hard contract, so it is expressed as code rather than left to each
  /// surface: the ticker is a bottom window, never more than 40% of screen
  /// height, and never wider than the dock.
  static double tickerMaxHeight(Size screen) => screen.height * 0.40;

  static double tickerWidth(Size screen) =>
      screen.width < dockWidth ? screen.width : dockWidth;
}