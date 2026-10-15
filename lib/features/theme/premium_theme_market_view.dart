import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:flutter/material.dart';
import '../../core/vision/category_nav.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/theme/app_font.dart';
import '../../core/theme/specular_border.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/theme_def.dart';
import '../music/song_wheel.dart';
import 'premium_market_ambient.dart';
import 'theme_living_media.dart';
import 'live_cover_video.dart';
import 'theme_pack_store.dart';

/// Premium Theme Market: line-by-line port of the Builder.io export
/// (briefs/figma-premium-theme-market/builder-export/src/app):
///   App.tsx               layout, header, label form
///   components/CoverFlow.tsx  geometry, transforms, ReflectionComponent
///   components/SearchBar.tsx  search capsule
///   components/SimpleBackgroundVideo.tsx  background (premium_market_ambient.dart)
///   hooks/useResponsive.ts    albumSize (cover size) / isMobile
///
/// Changes on top of the export (David, 2026-09-29; DEVIATIONS.md):
///   1. image / video URLs = Collider theme posters / live wallpaper loops
///   2. the heading shows the wallpaper name
///   3. under it, the theme's real songs (runtime catalog) in the export's
///      label text styles, each with a small play / pause; no list when a
///      theme has no songs
///   4. the Player (play, prev / next, "Now Playing") is removed; the
///      wallpaper loop always autoplays
///   5. the centre cover's top-right dot is removed
///   6. the app shell's bottom bar is shown; its height is reserved
///   7. a Buy / Apply line sits under the songs. The not-owned dim (D5) and
///      the subscription gate (D6) are removed (v8.3): every catalog theme shows
///
/// Rendering (lag fix, 2026-10-03): the CoverFlow is its own widget, so a drag
/// rebuilds only the card poses; cards outside the viewport are not painted;
/// the reflections and the blurred card shadows are rasterised once per poster
/// into images instead of saveLayer + blur every frame; on web the video blur
/// and the header / search backdrop blurs are one platform view.
///
/// All numbers are CSS px from the export (Flutter logical px == CSS px).
class PremiumThemeMarketView extends StatefulWidget {
  final WallpaperTheme currentTheme;
  final ValueChanged<WallpaperTheme> onApplyTheme;
  final ValueChanged<WallpaperTheme> onPreviewTheme;
  final VoidCallback onClose;
  /// v9.1.6: the central tier button switches back to the Free gallery.
  final VoidCallback? onFree;

  const PremiumThemeMarketView({
    super.key,
    required this.currentTheme,
    required this.onApplyTheme,
    required this.onPreviewTheme,
    required this.onClose,
    this.onFree,
  });

  /// Height the market keeps free for the app shell's bottom bar.
  static double bottomBarReserve(BuildContext context) =>
      _kBarBottom + _kBarHeight + _kBarGap + MediaQuery.paddingOf(context).bottom;

  @override
  State<PremiumThemeMarketView> createState() => _PremiumThemeMarketViewState();
}

// ---------------------------------------------------------------------------
// Export constants
// ---------------------------------------------------------------------------

// hooks/useResponsive.ts
const double _kMobileBreakpoint = 768; // width < 768
const double _kCoverSizeMobile = 128;
/// Device portrait aspect (height / width), set from the screen each build.
double kPhoneAspect = 19.5 / 9;
const double _kCoverSizeDesktop = 150;

// CoverFlow.tsx getTransform()
const double _kSpacingMobile = 120;
const double _kSpacingDesktop = 160;
const double _kRotationDeg = 55;
const double _kCenterTranslateZ = 300;
const double _kCenterScale = 1.3;
const double _kSideZPerStep = -80;
const double _kSideScaleBase = 1.15;
const double _kSideScaleStep = 0.04;
const double _kSideScaleMin = 0.8;
const double _kCenterEpsilon = 0.1;
// CoverFlow.tsx container: h-96, perspective 1500px, max-w-7xl
const double _kStageHeight = 384;
const double _kStageMaxWidth = 1280;
const double _kPerspective = 1500;
// transition: all 400ms cubic-bezier(0.23, 1, 0.32, 1)
const Duration _kCardTransition = Duration(milliseconds: 400);
const Cubic _kCardEase = Cubic(0.23, 1, 0.32, 1);
// Drag: offset / 100; threshold 50; velocity 0.5 / 2.0 px per ms
const double _kDragDivisor = 100;
const double _kDragThreshold = 50;
const double _kVelocityThreshold = 0.5;
const double _kHighVelocityThreshold = 2.0;

// Card chrome: rounded-lg = --radius .625rem
const double _kRadius = 10;
// border border-gray-800/30  (#1E2939 @ 30%)
const Color _kCoverBorder = Color(0x00000000); // no outline
// v9.1.7 (#40): the source's CSS cover shadows (and the 1px white ring that
// read as a light outline, #37) were unused hand-made shadows; covers use
// VElev.e6 / e12 (below).

// ReflectionComponent
const double _kReflectionOpacityCenter = 0.9;
const double _kReflectionOpacitySide = 0.75;
const double _kReflectionBlur = 0.5; // blur(0.5px)
const double _kReflectionBrightness = 0.6;
const double _kReflectionContrast = 1.3;
// mask: linear-gradient(to top, rgba(255,255,255,0.75) 0%, 0.4 20%, 0.15 40%, transparent 60%)
const List<Color> _kReflectionMaskColors = [
  Color.fromRGBO(255, 255, 255, 0.75),
  Color.fromRGBO(255, 255, 255, 0.4),
  Color.fromRGBO(255, 255, 255, 0.15),
  Color.fromRGBO(255, 255, 255, 0),
];
const List<double> _kReflectionMaskStops = [0.0, 0.2, 0.4, 0.6];
// transition-all duration-500 (Tailwind default ease cubic-bezier(0.4,0,0.2,1))
const Cubic _kTwEase = Cubic(0.4, 0, 0.2, 1);

// Floor highlight: h-3, translateY(6px), opacity 0.6 / 0.35, duration-1000
const double _kFloorHeight = 12;
const double _kFloorOffset = 6;

// Tailwind v4 grays (oklch -> sRGB)
const Color _kGray400 = Color(0xFF99A1AF);
const Color _kGray500 = Color(0xFF6A7282);
const Color _kGray700 = Color(0xFF364153);

// App.tsx layout
const double _kHeaderHeight = 32; // p-4, empty content
const double _kSearchPad = 16; // p-4 wrapper
const double _kSearchHeight = 50; // py-3 + 24px line + 2px border
const double _kSearchHintGap = 8; // mt-2 (empty hint div)
const double _kSearchMaxWidth = 448; // max-w-md
const double _kMainPadX = 16; // px-4
const double _kLabelsMarginTop = 32; // mt-8

// App shell bottom bar (PermanentNavBar, main.dart PLANE 4): bottom 12,
// 44px buttons + 2 * 6 padding = 56. The market centres its content in the
// space above it (+16 gap) so the bar never overlaps or shifts the content.
const double _kBarBottom = 12;
const double _kBarHeight = 56;
const double _kBarGap = 16;
/// PermanentNavBar width: 3 x 44 circles + 2 x 12 gaps + 2 x 6 padding.
const double _kBarWidth = 3 * 44 + 2 * 12 + 2 * 6.0;
/// VMaterial.elevated blur (S-C11 app glass as used by the bar's VOrnament).
const double _kGlassSigma = 28;

// Label form, fixed height so the stage never moves between themes / states:
// p-2 8 + h2 28 + mb-2 8 + song carousel (3 slots x 44) + mb-4 16 + action 36 + p-2 8
// Rows are 44 px: each carries its own 44 px play button (v8.3, D37).
const double _kSongRowExtent = 44;
const int _kSongSlots = 5;
const double _kSongsBlockHeight = _kSongSlots * _kSongRowExtent;
const double _kActionHeight = 36;
const double _kNoSongsGap = 12;
const double _kCapsuleHeight = 34;
const double _kLabelsBlockHeight =
    8 + 28 + 8 + _kSongsBlockHeight + 16 + _kActionHeight + 8;

// Not-owned dim on covers (DEVIATIONS.md D5): black 45% over the face, the
// reflection multiplied by the same 0.55.
const double _kUnownedCardDim = 0.45;

class _PremiumThemeMarketViewState extends State<PremiumThemeMarketView> {
  // App.tsx state
  List<WallpaperTheme> _themes = const [];
  WallpaperTheme? _selected;
  String _searchQuery = '';

  // CoverFlow.tsx state
  int _currentIndex = 0;

  final ThemePackStore _store = ThemePackStore.instance;

  // SearchBar.tsx
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _keyFocus = FocusNode();
  Timer? _searchTimer;

  /// Every theme in the runtime ThemeCatalog (hosted themes.json), live
  /// themes first, then the stills: no names, counts or gate in the code.
  List<WallpaperTheme> get _catalog => [
        ...WallpaperCatalog.premiumThemes,
      ].where(_inCategory).toList();

  // v8.7 side nav: categories + a search button (popup search with DOF).
  // Categories = the bucket's top-level folders (theme.collection).
  List<String> get _categories => [
        'All',
        // v8.7: the ghost menu filters by tag (most used first).
        ...(() {
          final n = <String, int>{};
          for (final t in [...WallpaperCatalog.premiumThemes]) {
            for (final g in t.tags) {
              n[g] = (n[g] ?? 0) + 1;
            }
          }
          return n.keys.toList()..sort((a, b) => n[b]!.compareTo(n[a]!));
        })(),
      ];
  String _category = '';
  bool _navOpen = false;
  bool _searchOpen = false;
  bool _exploded = false;
  bool _inCategory(WallpaperTheme t) => CategoryTaxonomy.matches(_category, t.tags);
  void _setCategory(String c) {
    if (c == _category) return;
    _category = c;
    _fetchThemes(_searchQuery, keepId: _selected?.id);
  }
  void _openSearch(bool open) {
    setState(() => _searchOpen = open);
    if (open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocus.requestFocus());
    } else {
      _searchFocus.unfocus();
    }
  }

  Widget _sideNav() {
    Widget item(IconData icon, String label, bool on, VoidCallback tap) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: SizedBox(
            width: 56,
            height: 52,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: on ? 1 : 0.55)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: on ? 1 : 0.55))),
            ]),
          ),
        );
    final cats = _categories;
    // v9.1.6: a row above the carousel, so no neighbouring cover peeks
    // under the buttons.
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SuspendedFrost(
        edge: 0.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: ColoredBox(
              color: const Color(0x14FFFFFF),
              child: item(Icons.search_rounded, 'Search', _searchOpen || _searchQuery.isNotEmpty,
                  () => _openSearch(true)),
            ),
          ),
        ),
      ),
    ]);
  }

  /// Exploded asset view: the cover lifted forward, a context menu under it.
  Widget _explodedView(WallpaperTheme t, double w, double h) {
    final cw = math.min(math.min(w * 0.62, 300.0), h * 0.6 / kPhoneAspect);
    final owned = _owned(t);
    // v9.1.6 (Visual Playtest / CONVENTIONS): one action, one centred
    // button: the price to buy, "Set as wallpaper" once owned. Tap outside
    // closes (no Preview / Close rows).
    final price = _store.priceLabelFor(t.id, catalogPrice: t.priceLabel);
    final menu = VPress(
      onTap: () {
        setState(() => _exploded = false);
        owned ? widget.onApplyTheme(t) : _confirmBuy(t, price);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
        child: Text(owned ? 'Set as wallpaper' : price, style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _exploded = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, v, child) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14 * v, sigmaY: 14 * v),
          child: ColoredBox(
            color: Color.fromRGBO(0, 0, 0, 0.25 * v),
            child: Opacity(opacity: v, child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
          ),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: cw,
                height: cw * kPhoneAspect, // phone-shaped
                // Live themes play their own video here (sharp), not the upscaled frame.
                child: t.isLive && t.videoUrl != null
                    ? Stack(fit: StackFit.expand, children: [ThemeImage(t.assetPath, fit: BoxFit.cover, filterQuality: FilterQuality.high), LiveCoverVideo(key: ValueKey('detail-${t.id}'), url: t.videoUrl!)])
                    : ThemeImage(t.assetPath, fit: BoxFit.cover, filterQuality: FilterQuality.high),
              ),
            ),
            const SizedBox(height: 10),
            Text(_displayName(t),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
            const SizedBox(height: 14),
            GestureDetector(onTap: () {}, child: menu),
          ]),
        ),
      ),
    );
  }

  /// A still (not premium) is free: it applies straight away.
  bool _owned(WallpaperTheme t) => !t.isPremium || _store.isUnlocked(t.id);

  void _onCatalogChanged() {
    if (!mounted) return;
    _fetchThemes(_searchQuery, keepId: _selected?.id);
  }

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    ThemeCatalog.instance.addListener(_onCatalogChanged);
    _store.addListener(_onCatalogChanged);
    _store.init();
    _fetchThemes('');
  }

  @override
  void dispose() {
    // Not during finalizeTree: listeners rebuild.
    ThemeCatalog.instance.removeListener(_onCatalogChanged);
    _store.removeListener(_onCatalogChanged);
    _searchTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _keyFocus.dispose();
    super.dispose();
  }

  // App.tsx fetchSongs(): list, then centre on Math.floor(length / 2)
  /// v9.1.6 (root cause of the black cover): the store used to open on the
  /// middle item. With every live loop now premium (117, not 19) the middle
  /// was a near-black sparkle clip (mean luma 16/255), so the cover looked
  /// empty. It opens on a featured, well-lit theme instead.
  static int _heroIndex(List<WallpaperTheme> r) {
    for (final re in [RegExp('neon shopfront', caseSensitive: false), RegExp('neon|alley|sanctuary|lantern', caseSensitive: false)]) {
      final i = r.indexWhere((t) => re.hasMatch(t.name));
      if (i >= 0) return i;
    }
    return r.length ~/ 2;
  }

  void _fetchThemes(String query, {String? keepId}) {
    final q = query.trim().toLowerCase();
    final catalog = _catalog;
    final results = q.isEmpty
        ? catalog
        : catalog.where((t) {
            return t.name.toLowerCase().contains(q) ||
                t.collection.toLowerCase().contains(q) ||
                t.creator.toLowerCase().contains(q) ||
                t.tier.toLowerCase().contains(q) ||
                t.id.toLowerCase().contains(q) ||
                t.tags.any((g) => g.toLowerCase().contains(q));
          }).toList();
    final prevId = _selected?.id;
    setState(() {
      _searchQuery = query;
      _themes = results;
      final kept = keepId == null ? -1 : results.indexWhere((t) => t.id == keepId);
      _currentIndex =
          results.isEmpty ? 0 : (kept >= 0 ? kept : _heroIndex(results));
      _selected = results.isEmpty ? null : results[_currentIndex];
    });
    final s = _selected;
    if (s != null && s.id != prevId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPreviewTheme(s);
      });
    }
  }

  // REQ-20 theme detail (D39), opened from the centre cover or the name.


  // App.tsx handleSongSelect + CoverFlow setCurrentIndex. The CoverFlow
  // loops (map row 4): indexes wrap at both ends.
  void _select(int index) {
    if (_themes.isEmpty) return;
    index %= _themes.length;
    if (index < 0) index += _themes.length;
    final changed = index != _currentIndex;
    if (!changed) return;
    setState(() {
      _currentIndex = index;
      _selected = _themes[index];
    });
    if (changed) widget.onPreviewTheme(_themes[index]);
  }

  // Keyboard navigation (ArrowLeft / ArrowRight / Enter / Space)
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || _themes.isEmpty) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _select(_currentIndex - 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _select(_currentIndex + 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final barReserve = PremiumThemeMarketView.bottomBarReserve(context);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final isMobile = w < _kMobileBreakpoint;
      final selected = _selected;

      // App.tsx main: top = header + search wrapper; the content (stage +
      // label form, fixed height) is centred between it and the bottom bar.
      const mainTop =
          _kHeaderHeight + _kSearchPad + _kSearchHeight + _kSearchHintGap + _kSearchPad;
      // v9.1.7 (#6/#7): docked mode. The shell ends this pane above the
      // ticker band, so the bottom bar is no longer inside it and the stage
      // scales down (as one unit) until the name, song and action still fit.
      final docked = h < MediaQuery.sizeOf(context).height - 1;
      final reserve = docked ? 0.0 : barReserve;
      final mainHeight = math.max(0.0, h - mainTop - reserve);
      const labelsDocked = _kLabelsBlockHeight;
      final stageH = docked
          ? (mainHeight - _kLabelsMarginTop - labelsDocked).clamp(_kStageHeight * 0.55, _kStageHeight).toDouble()
          : _kStageHeight;
      final contentHeight =
          stageH + _kLabelsMarginTop + (docked ? labelsDocked : _kLabelsBlockHeight);
      final contentTop =
          mainTop + math.max(0.0, (mainHeight - contentHeight) / 2);
      final stageTop = contentTop;
      final labelsTop = stageTop + stageH + _kLabelsMarginTop;
      final contentWidth = w - _kMainPadX * 2;
      final searchWidth = math.min(w - _kSearchPad * 2, _kSearchMaxWidth);

      // Search input (backdrop-blur-sm 8px) blur element, hosted by the
      // ambient on web (the empty header strip no longer paints; see below).
      final glass = <AmbientGlass>[
        if (_searchOpen) AmbientGlass(
            Rect.fromLTWH((w - searchWidth) / 2, _kHeaderHeight + _kSearchPad,
                searchWidth, _kSearchHeight),
            _kSearchHeight / 2,
            8),
        // The app shell's bottom bar (PermanentNavBar: VOrnament, elevated
        // glass, 3 x 44 circles) and the Buy / Apply / Subscribe capsule:
        // same material blur, applied to the video behind them.
        if (!docked) AmbientGlass(
            Rect.fromLTWH((w - _kBarWidth) / 2,
                h - _kBarBottom - MediaQuery.paddingOf(context).bottom - _kBarHeight,
                _kBarWidth, _kBarHeight),
            _kBarHeight / 2,
            _kGlassSigma),
        if (_capsuleRect != null)
          AmbientGlass(_capsuleRect!, _capsuleRect!.height / 2, _kGlassSigma),
      ];
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncCapsuleRect());

      return Focus(
        focusNode: _keyFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
            fit: StackFit.expand,
            children: [
              // App root: background linear-gradient(to bottom, #000000 0%, #111111 100%)
              // Tap on the empty room closes the Market (tap outside). The
              // room is near-opaque so the ticker reads through it, blurred.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _exploded ? () => setState(() => _exploded = false) : widget.onClose,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x59000000), Color(0x59111111)], // ticker shows through, blurred
                    ),
                  ),
                ),
              ),
              // Floor: bottom half, linear-gradient(to top, rgba(255,255,255,0.02), transparent),
              // perspective(1000px) rotateX(60deg), transform-origin bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: h / 2,
                child: IgnorePointer(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, -1 / 1000)
                      ..multiply(Matrix4.rotationX(60 * math.pi / 180)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color.fromRGBO(255, 255, 255, 0.02),
                            Color.fromRGBO(255, 255, 255, 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // SimpleBackgroundVideo: fixed 100vw x 100vh, overflow hidden;
              // the media is 200vw x 200vh centred. Always on (autoplay).
              if (selected != null)
                // Ticker under Premium: the full-bleed ambient was opaque and
                // hid the ticker entirely; at 45% the blurred ticker shows.
                Positioned.fill(
                  child: Opacity(opacity: 0.45, child: SimpleBackgroundVideoAmbient(
                    theme: selected,
                    owned: kOwnedBrighterState && _owned(selected),
                    glass: kIsWeb ? glass : const [],
                  )),
                ),

              // No search results: an empty stage, no copy (v8.3, D45).
              if (_themes.isNotEmpty && selected != null) ...[
                // Label form (z 250) sits under the CoverFlow wrapper (z 300)
                Positioned(
                  left: 0,
                  right: 0,
                  top: labelsTop,
                  height: _kLabelsBlockHeight,
                  // Top-aligned: with songs the column fills the block exactly
                  // (as before); without songs it ends under the name.
                  // Hidden under the detail view so the name shows once.
                  child: Opacity(opacity: _exploded ? 0 : 1, child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildLabels(selected, contentWidth),
                  )),
                ),
                // CoverFlow wrapper
                Positioned(
                  // v9.1.6: dead centre; the old side-nav offset (76 px) is gone
                  // with the side nav (now the top category bar).
                  left: _kMainPadX,
                  right: _kMainPadX,
                  top: stageTop,
                  height: stageH,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: math.min(contentWidth, _kStageMaxWidth),
                      height: _kStageHeight,
                      child: _CoverFlow(
                        themes: _themes,
                        currentIndex: _currentIndex,
                        isMobile: isMobile,
                        viewportWidth: w,
                        ownedIds: {
                          for (final t in _themes)
                            if (_owned(t)) t.id,
                        },
                        onSelect: _select,
                        onTapCover: (i) {
                          if (i % _themes.length == _currentIndex) {
                            setState(() => _exploded = true);
                          } else {
                            _select(i);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],

              // v8.7 side nav (categories + search), left edge.
              Positioned(
                left: 12,
                top: MediaQuery.paddingOf(context).top + 12,
                child: _sideNav(),
              ),
              // v9.1.6c: category bar pinned along the top, always visible.
              Positioned(
                left: 12, right: 12,
                top: MediaQuery.paddingOf(context).top + 66,
                child: Builder(builder: (_) {
                  final pool = [...WallpaperCatalog.premiumThemes];
                  return CategoryBar(
                    groups: CategoryTaxonomy.build([for (final t in pool) t.tags]),
                    total: pool.length,
                    selected: _category,
                    onSelected: (k) => setState(() => _setCategory(k)),
                  );
                }),
              ),
              if (widget.onFree != null)
                Positioned(
                  left: 0, right: 0,
                  top: MediaQuery.paddingOf(context).top + 16,
                  child: Center(child: TierSwitchPill(label: 'Premium', onSwitch: widget.onFree!)),
                ),

              // Category sidebar (visionOS browser, Figma 1:101). A temporary
              // panel: tap outside or pick a category to close it.
              if (_navOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _navOpen = false),
                    onHorizontalDragEnd: (_) => setState(() => _navOpen = false),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: const ColoredBox(color: Color(0x47000000)),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: mainTop,
                  child: Builder(builder: (_) {
                    final pool = [...WallpaperCatalog.premiumThemes];
                    return CategorySideNav(
                      width: 200,
                      maxHeight: MediaQuery.of(context).size.height - mainTop - 110,
                      groups: CategoryTaxonomy.build([for (final t in pool) t.tags]),
                      total: pool.length,
                      selected: _category,
                      onSelected: (k) {
                        setState(() => _navOpen = false);
                        _setCategory(k);
                      },
                    );
                  }),
                ),
              ],
              // Search popup (was the always-on SearchBar): DOF blur behind.
              if (_searchOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openSearch(false),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: const ColoredBox(color: Color(0x33000000)),
                    ),
                  ),
                ),
                Positioned(
                  left: _kSearchPad,
                  right: _kSearchPad,
                  top: _kHeaderHeight + _kSearchPad,
                  height: _kSearchHeight,
                  child: Center(
                    child: SizedBox(
                      width: searchWidth,
                      height: _kSearchHeight,
                      child: _buildSearchBar(),
                    ),
                  ),
                ),
              ],

              if (_exploded && selected != null)
                Positioned.fill(child: _explodedView(selected, w, h)),

              // Header (z 500): the export's empty p-4 strip keeps its 32px in
              // the layout (mainTop) but paints nothing. Its bg-black/20 +
              // backdrop-blur-md stacked a second dim and a hard-edged blur on
              // top of the wallpaper's own 0.2 overlay: a dark band across the
              // top once a theme is owned (full brightness).

            ],
          ),
      );
    });
  }

  // ---------------- Label form (App.tsx) -----------------------------------
  String _displayName(WallpaperTheme t) =>
      t.name.replaceAll(RegExp(r'\s*4K$'), '').trim();

  // App.tsx:80 label form. h2 = wallpaper name; under it the theme's real
  // songs from the runtime catalog as a vertical carousel (SongWheel, v8.2,
  // DEVIATIONS.md D11, D37): the selected song centred, a play / pause button
  // in a fixed column on every row, skip at a fixed spot, titles fading with
  // distance; it fades in on each theme
  // change. No carousel at all for a theme without songs: the Buy / Apply /
  // action then sits _kNoSongsGap under the name.
  Widget _buildLabels(WallpaperTheme t, double maxWidth) {
    final tracks = MusicPlayer.themeTracks(t.id);
    final wheelWidth = math.min(maxWidth - 16, 340.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.all(8), // p-2
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // h2 text-xl font-light mb-2 text-white drop-shadow-lg
            SizedBox(
              height: 28,
              child: FittedBox(fit: BoxFit.scaleDown, child: Text( // never truncated
                _displayName(t),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: _inter(TextStyle(
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFFFFFFFF),
                  shadows: [_cssDropShadow(0, 4, 4, const Color(0x26000000))],
                )),
              )),
            ),
            if (tracks.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Cinematic fade-in per theme: a slow ease-out rise from 0, run on
              // every theme change (keyed by theme, so it restarts even when
              // the previous theme had no songs and the wheel was absent).
              TweenAnimationBuilder<double>(
                key: ValueKey('songs-fade-${t.id}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: child),
                ),
                child: SongWheel(
                  key: ValueKey('songs-${t.id}-${tracks.length}'),
                  tracks: tracks,
                  queueId: 'theme:${t.id}',
                  width: wheelWidth,
                  itemExtent: _kSongRowExtent,
                  maxVisible: _kSongSlots,
                  centerStyle: _inter(TextStyle(
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFFFFFFF),
                    shadows: [_cssDropShadow(0, 3, 3, const Color(0x1F000000))],
                  )),
                  sideStyle: _inter(TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w300,
                    color: _kGray400,
                    shadows: [_cssDropShadow(0, 3, 3, const Color(0x1F000000))],
                  )),
                ),
              ),
              const SizedBox(height: 16), // mb-4
            ] else
              // No songs: no reserved rows, the action sits under the name.
              const SizedBox(height: _kNoSongsGap),
            SizedBox(height: _kActionHeight, child: Center(child: _buildAction(t))),
          ],
        ),
      ),
    );
  }

  /// Buy / Apply theme capsule.
  Widget _buildAction(WallpaperTheme t) {
    if (_owned(t)) {
      return _GlassCapsule(
        key: _capsuleKey,
        label: 'Set as wallpaper',
        onTap: () => widget.onApplyTheme(t),
      );
    }
    final price = _store.priceLabelFor(t.id, catalogPrice: t.priceLabel);
    return _GlassCapsule(
      key: _capsuleKey,
      label: price,
      onTap: () => _confirmBuy(t, price),
    );
  }

  // Map row 22: purchases go through the centred alert. There is no store
  // backend yet, so the line says where the unlock lives (D49).
  Future<void> _confirmBuy(WallpaperTheme t, String price) async {
    final i = await showVAlert(
      context,
      icon: Icons.diamond_outlined,
      title: _displayName(t),
      actions: [VAlertChoice('Buy · $price'), const VAlertChoice('Cancel')],
    );
    if (i != 0 || !mounted) return;
    // No store on this link: the purchase fails honestly instead of granting
    // a paid theme for nothing (D66).
    if (!ThemePackStore.purchasesAvailable) {
      await showVAlert(
        context,
        icon: Icons.diamond_outlined,
        title: "Purchases aren't available on this link",
        actions: const [VAlertChoice('OK')],
      );
      return;
    }
    await _store.buyPack(t.id);
  }

  /// Web: the capsule's backdrop blur is a CSS element in the ambient (the
  /// video is DOM content under Flutter), so track the capsule's rect.
  final GlobalKey _capsuleKey = GlobalKey();
  Rect? _capsuleRect;

  void _syncCapsuleRect() {
    if (!mounted) return;
    final box = _capsuleKey.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    Rect? r;
    if (box != null && root != null && box.hasSize && box.attached) {
      r = box.localToGlobal(Offset.zero, ancestor: root) & box.size;
    }
    if (kIsWeb && r != _capsuleRect) setState(() => _capsuleRect = r);
  }

  // Native: Flutter BackdropFilter; web: the ambient's CSS element supplies it.
  Widget _maybeBackdrop({required double sigma, required Widget child}) =>
      kIsWeb
          ? child
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            );

  // ---------------- SearchBar.tsx -----------------------------------------
  void _onSearchChanged(String value) {
    setState(() {}); // clear button visibility
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      if (value.trim().isNotEmpty) _fetchThemes(value);
    });
  }

  Widget _buildSearchBar() {
    final focused = _searchFocus.hasFocus;
    final lightText = _inter(const TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w300,
      color: Color(0xFFFFFFFF),
    ));
    const glyph = SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _SearchGlyphPainter(_kGray400)),
    );
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return Stack(
        fit: StackFit.expand,
        children: [
          // Search icon: absolute inset-y-0 left-0 pl-3, h-4 w-4 text-gray-400.
          // Painted before the input, so the input's backdrop-blur-sm covers it
          // (as in the export). On web the backdrop element now sits in the
          // ambient below Flutter, so the glyph carries the same 8px blur itself.
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: kIsWeb
                  ? ImageFiltered(
                      imageFilter: ImageFilter.blur(
                          sigmaX: 8, sigmaY: 8, tileMode: TileMode.decal),
                      child: glyph,
                    )
                  : glyph,
            ),
          ),
          // input: rounded-full border border-gray-700 (focus: border-gray-500)
          // backdrop-blur-sm (8px), background linear-gradient(145deg, rgba(0,0,0,0.4), rgba(255,255,255,0.02)),
          // boxShadow inset 0 2px 6px rgba(0,0,0,0.7), 0 1px 2px rgba(255,255,255,0.05)
          CustomPaint(
            painter: _CssShadowPainter(const [
              _CssShadow(0, 1, 2, 0, Color.fromRGBO(255, 255, 255, 0.05)),
            ], size.height / 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: _maybeBackdrop(
                sigma: 8,
                child: CustomPaint(
                  foregroundPainter: _InsetShadowPainter(
                    offset: const Offset(0, 2),
                    blur: 6,
                    color: const Color.fromRGBO(0, 0, 0, 0.7),
                    radius: size.height / 2,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999),
                      gradient: _cssLinearGradient(
                        145,
                        size,
                        const [
                          Color.fromRGBO(0, 0, 0, 0.4),
                          Color.fromRGBO(255, 255, 255, 0.02),
                        ],
                        const [0.0, 1.0],
                      ),
                      border: Border.all(
                        color: focused ? _kGray500 : _kGray700,
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      // pl-10 pr-10 py-3
                      padding: const EdgeInsets.fromLTRB(40, 0, 40, 0),
                      child: Center(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          style: lightText,
                          cursorColor: const Color(0xFFFFFFFF),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Search',
                            hintStyle: lightText.copyWith(color: _kGray500),
                          ),
                          onChanged: _onSearchChanged,
                          onSubmitted: (v) {
                            _searchTimer?.cancel();
                            _fetchThemes(v);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Clear button: absolute inset-y-0 right-0 pr-3, h-4 w-4 text-gray-400
          if (_searchController.text.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchTimer?.cancel();
                  _fetchThemes('');
                },
                child: const MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: EdgeInsets.only(right: 12, left: 8),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CustomPaint(painter: _ClearGlyphPainter(_kGray400)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// CoverFlow.tsx
// ---------------------------------------------------------------------------

/// Drag state (handleDragStart / Move / End). Only the CoverFlow listens, so
/// a drag re-poses the cards without rebuilding the rest of the market.
class _DragModel extends ChangeNotifier {
  bool dragging = false;
  double start = 0;
  double offset = 0;
  double velocity = 0; // px per ms
  int lastTime = 0;

  void begin(double x) {
    dragging = true;
    start = x;
    offset = 0;
    velocity = 0;
    lastTime = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  void move(double x) {
    if (!dragging) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final deltaTime = now - lastTime;
    final newOffset = x - start;
    velocity = (newOffset - offset) / math.max(deltaTime, 1);
    offset = newOffset;
    lastTime = now;
    notifyListeners();
  }

  void reset() {
    dragging = false;
    offset = 0;
    velocity = 0;
    notifyListeners();
  }
}

class _CoverFlow extends StatefulWidget {
  final List<WallpaperTheme> themes;
  final int currentIndex;
  final bool isMobile;
  final double viewportWidth;
  final Set<String> ownedIds;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onTapCover;

  const _CoverFlow({
    required this.themes,
    required this.currentIndex,
    required this.isMobile,
    required this.viewportWidth,
    required this.ownedIds,
    required this.onSelect,
    required this.onTapCover,
  });

  @override
  State<_CoverFlow> createState() => _CoverFlowState();
}

class _CoverFlowState extends State<_CoverFlow> {
  final _DragModel _drag = _DragModel();

  /// Card subtrees reused across drag frames (same instance => Flutter skips
  /// rebuilding them); invalidated when what they show changes.
  final Map<String, Widget> _cards = {};

  @override
  void didUpdateWidget(covariant _CoverFlow old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex ||
        old.isMobile != widget.isMobile ||
        !setEquals(old.ownedIds, widget.ownedIds) ||
        !identical(old.themes, widget.themes)) {
      _cards.clear();
    }
    if (!identical(old.themes, widget.themes) || old.isMobile != widget.isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
  }

  @override
  void dispose() {
    _prewarmGen++;
    _drag.dispose();
    super.dispose();
  }

  int _prewarmGen = 0;

  /// Rasterises every card's cover + reflection one at a time between frames
  /// (nearest to the current card first), so the work is done before the
  /// user swipes instead of on the frames where a card enters the screen.
  Future<void> _prewarm() async {
    final gen = ++_prewarmGen;
    final themes = widget.themes;
    final order = List<int>.generate(themes.length, (i) => i)
      ..sort((a, b) => _rel(a).abs().compareTo(_rel(b).abs()));
    final size = widget.isMobile ? _kCoverSizeMobile : _kCoverSizeDesktop;
    for (final i in order) {
      if (!mounted || gen != _prewarmGen) return;
      final scale = _rasterScale(context);
      final t = themes[i];
      final done = Completer<void>();
      var pending = 2;
      void step() {
        if (--pending == 0 && !done.isCompleted) done.complete();
      }
      if (_RasterCache.cover(context, t, size - 2, scale, step) != null) step();
      if (_RasterCache.reflection(context, t, size, scale, step) != null) step();
      await done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      // Never do this work while a finger is down; one card per idle gap.
      while (mounted && gen == _prewarmGen && _drag.dragging) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  void _dragEnd() {
    final d = _drag;
    if (!d.dragging) return;
    var targetIndex = widget.currentIndex;
    final dragDistance = d.offset.abs();
    final dragVelocity = d.velocity.abs();
    if (dragDistance > _kDragThreshold || dragVelocity > _kVelocityThreshold) {
      var jumpCount = 1;
      if (dragVelocity > _kHighVelocityThreshold) {
        jumpCount = math.min(2, (dragVelocity / 1.5).ceil());
      }
      if (dragDistance > _kDragThreshold * 2) {
        jumpCount =
            math.max(jumpCount, (dragDistance / (_kDragThreshold * 1.5)).floor());
      }
      // Loops (map row 4): no stop at the first or last theme.
      final n = widget.themes.length;
      if (d.offset < 0 || d.velocity < -_kVelocityThreshold) {
        targetIndex = (widget.currentIndex + jumpCount) % n;
      } else if (d.offset > 0 || d.velocity > _kVelocityThreshold) {
        targetIndex = ((widget.currentIndex - jumpCount) % n + n) % n;
      }
    }
    d.reset();
    widget.onSelect(targetIndex);
  }

  /// Position relative to the centre cover on the loop: -n/2 .. n/2.
  int _rel(int index) {
    final n = widget.themes.length;
    if (n == 0) return 0;
    var d = (index - widget.currentIndex) % n;
    if (d < 0) d += n;
    if (d > n ~/ 2) d -= n;
    return d;
  }

  // getTransform / getOpacity
  _CardPose _poseFor(int index) {
    final baseOffset = _rel(index).toDouble();
    final offset =
        baseOffset + (_drag.dragging ? _drag.offset / _kDragDivisor : 0.0);
    final spacing = widget.isMobile ? _kSpacingMobile : _kSpacingDesktop;
    double tx, tz, ry, s;
    if (offset.abs() < _kCenterEpsilon) {
      tx = 0;
      tz = _kCenterTranslateZ;
      ry = 0;
      s = _kCenterScale;
    } else {
      final distance = offset.abs();
      tx = (offset < 0 ? -spacing : spacing) * distance;
      tz = _kSideZPerStep * distance;
      ry = offset < 0 ? _kRotationDeg : -_kRotationDeg;
      s = math.max(_kSideScaleMin, _kSideScaleBase - (distance * _kSideScaleStep));
    }
    return _CardPose(tx, tz, ry, s, _opacityFor(offset.abs()));
  }

  double _opacityFor(double offset) {
    if (offset < 0.1) return 1;
    if (offset <= 1) return 1;
    if (offset <= 2) return 1;
    if (offset <= 3) return 0.95;
    if (offset <= 4) return 0.9;
    return math.max(0.8, 0.9 - ((offset - 4) * 0.05));
  }

  int _zIndexFor(int index) {
    final offset = _rel(index).abs();
    if (offset == 0) return 1000;
    if (offset == 1) return 100;
    if (offset == 2) return 50;
    if (offset == 3) return 25;
    if (offset == 4) return 15;
    return math.max(1, 10 - offset);
  }

  /// Whether any of the card's paint (cover, reflection, shadow spill) lands
  /// inside the viewport for [pose]. Off-screen cards are not painted at all
  /// (they were fully outside the screen before as well).
  bool _onScreen(_CardPose pose, double size, double originX) {
    final o = size / 2; // transform-origin: centre of the cover box
    final m = Matrix4.translationValues(o, o, 0)
      ..multiply(pose.matrix())
      ..multiply(Matrix4.translationValues(-o, -o, 0));
    final st = m.storage;
    const pad = 110.0;
    var minX = double.infinity, maxX = double.negativeInfinity;
    for (final x in const [-pad, 1.0]) {
      for (final y in const [-pad, 1.0]) {
        final px = x == 1.0 ? size + pad : x;
        final py = y == 1.0 ? size * 2 + pad : y;
        final w = st[3] * px + st[7] * py + st[15];
        if (w <= 0.01) return true;
        final sx = originX + (st[0] * px + st[4] * py + st[12]) / w;
        minX = math.min(minX, sx);
        maxX = math.max(maxX, sx);
      }
    }
    return maxX > 0 && minX < widget.viewportWidth;
  }

  Widget _card(int i, double size) {
    final t = widget.themes[i];
    final isCurrent = i == widget.currentIndex;
    // Not-owned dim only behind kOwnedBrighterState (D5, off): covers are
    // fully lit (map row 4).
    final dimmed = kOwnedBrighterState && !widget.ownedIds.contains(t.id);
    // The centre cover and its two neighbours play their live wallpaper;
    // the rest show the poster until they come near the centre.
    final live = t.isLive && _rel(i).abs() <= 1;
    return _cards.putIfAbsent(
      '${t.id}|$isCurrent|$dimmed|$size|$live',
      () => RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            if (!_drag.dragging) widget.onTapCover(i);
          },
          child: _CoverCard(
            theme: t,
            isCurrent: isCurrent,
            dimmed: dimmed,
            live: live,
            size: size,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ms = MediaQuery.sizeOf(context);
    kPhoneAspect = (ms.height / ms.width).clamp(1.78, 2.17);
    // Phone-shaped cover sized to the stage height so it never overlaps the
    // category bar or the title.
    final coverSize = math.min(widget.isMobile ? _kCoverSizeMobile : _kCoverSizeDesktop, 250 / kPhoneAspect);
    final themes = widget.themes;
    // Paint order = CSS z-index (getZIndex + 1000), ties in DOM order.
    final visible = <int>[
      for (int i = 0; i < themes.length; i++)
        if (_rel(i).abs() <= 6) i,
    ]..sort((a, b) {
        final za = _zIndexFor(a), zb = _zIndexFor(b);
        if (za != zb) return za.compareTo(zb);
        return a.compareTo(b);
      });
    // Cards are flex-centred in the stage, the stage in the viewport.
    final originX = (widget.viewportWidth - coverSize) / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) => _drag.begin(d.globalPosition.dx),
      onHorizontalDragUpdate: (d) => _drag.move(d.globalPosition.dx),
      onHorizontalDragEnd: (_) => _dragEnd(),
      onHorizontalDragCancel: _dragEnd,
      child: LayoutBuilder(builder: (context, c) {
        final left = (c.maxWidth - coverSize) / 2;
        final top = (c.maxHeight - coverSize * kPhoneAspect) / 2;
        return ListenableBuilder(
          listenable: _drag,
          builder: (context, _) => MouseRegion(
            cursor: _drag.dragging
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final i in visible)
                  Positioned(
                    key: ValueKey('card-${themes[i].id}'),
                    left: left,
                    top: top,
                    width: coverSize,
                    height: coverSize * kPhoneAspect * 2, // cover + ReflectionComponent (top-full, h-full)
                    child: TweenAnimationBuilder<_CardPose>(
                      tween: _CardPoseTween(end: _poseFor(i)),
                      duration: _drag.dragging ? Duration.zero : _kCardTransition,
                      curve: _kCardEase,
                      builder: (context, pose, child) {
                        if (!_onScreen(pose, coverSize, originX)) {
                          return const SizedBox.shrink();
                        }
                        return Opacity(
                          opacity: pose.opacity.clamp(0.0, 1.0),
                          child: Transform(
                            // transform-origin: centre of the cover box
                            alignment: const Alignment(0, -0.5),
                            transform: pose.matrix(),
                            child: child,
                          ),
                        );
                      },
                      child: _card(i, coverSize),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// One CoverFlow card: <img> + glass reflection + ReflectionComponent + floor
/// highlight (+ centre border / top glow). The blurred box-shadows, the
/// reflection (blur / brightness / contrast / mask) and the top glow are
/// rasterised once into images (_RasterCache) with the same geometry and
/// filters, then drawn as plain images every frame.
class _CoverCard extends StatelessWidget {
  final WallpaperTheme theme;
  final bool isCurrent;
  final bool dimmed;
  final bool live;
  final double size;

  const _CoverCard({
    required this.theme,
    required this.isCurrent,
    required this.dimmed,
    required this.size,
    this.live = false,
  });

  static const double _shadowPad = 100;
  static const double _glowPad = 24;

  @override
  Widget build(BuildContext context) {
    // David: covers are phone-shaped (device portrait aspect), never square.
    final h = size * kPhoneAspect;
    // ReflectionComponent opacity: index === currentIndex ? 0.9 : 0.75
    final reflectionOpacity =
        isCurrent ? _kReflectionOpacityCenter : _kReflectionOpacitySide;
    return SizedBox(
      width: size,
      height: h * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Elevation level 6 (floating), downward Material shadow, no halo.
          Positioned(
            left: 0, top: 0, width: size, height: h,
            child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(_kRadius), boxShadow: VElev.e6)),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: h,
            child: const SizedBox.shrink(), // no light outline round the cover
          ),
          // <img> object-cover rounded-lg border border-gray-800/30
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(1),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_kRadius - 1),
                    child: live
                        ? Stack(fit: StackFit.expand, children: [
                            _CoverPoster(theme: theme, inner: size - 2),
                            LiveCoverVideo(key: ValueKey('live-${theme.id}'), url: theme.videoUrl!),
                          ])
                        : _CoverPoster(theme: theme, inner: size - 2),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_kRadius),
                    border: Border.all(color: _kCoverBorder, width: 1),
                  ),
                ),
              ],
            ),
          ),
          // Glass reflection: linear-gradient(135deg, rgba(255,255,255,0.12) 0%,
          // rgba(255,255,255,0.04) 25%, transparent 50%, rgba(0,0,0,0.02) 75%, rgba(0,0,0,0.08) 100%)
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kRadius),
                gradient: _cssLinearGradient(
                  135,
                  Size(size, h),
                  const [
                    Color.fromRGBO(255, 255, 255, 0.12),
                    Color.fromRGBO(255, 255, 255, 0.04),
                    Color.fromRGBO(255, 255, 255, 0),
                    Color.fromRGBO(0, 0, 0, 0),
                    Color.fromRGBO(0, 0, 0, 0.02),
                    Color.fromRGBO(0, 0, 0, 0.08),
                  ],
                  const [0.0, 0.25, 0.5, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // Not-owned dim (DEVIATIONS.md D5)
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: h,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: dimmed ? _kUnownedCardDim : 0),
              duration: Duration.zero, // v8.6: no per-item animation
              curve: _kTwEase,
              builder: (context, a, _) => a <= 0.001
                  ? const SizedBox.shrink()
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_kRadius),
                        color: Color.fromRGBO(0, 0, 0, a),
                      ),
                    ),
            ),
          ),
          // Builder ReflectionComponent: absolute top-full, w-full h-full, rounded-lg,
          // background cover, scaleY(-1), opacity 0.9/0.75 (duration-500), mask
          // to-top, filter blur(0.5px) brightness(0.6) contrast(1.3) — cached image.
          Positioned(
            left: 0,
            top: h,
            width: size,
            height: h * 0.32, // ends above the title
            child: ClipRect(child: OverflowBox(alignment: Alignment.topCenter, minHeight: h, maxHeight: h, child: _Reflection(
              theme: theme,
              size: size,
              opacity: reflectionOpacity,
              dim: dimmed ? _kUnownedCardDim : 0,
            ))),
          ),
          // Floor highlight: top-full h-3 rounded-lg translateY(6px), opacity 0.6 / 0.35 (duration-1000)
          // linear-gradient(to bottom, rgba(255,255,255,0.06) 0%, 0.12 40%, transparent 100%)
          Positioned(
            left: 0,
            top: h + _kFloorOffset,
            width: size,
            height: _kFloorHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isCurrent ? 0.6 : 0.35),
              duration: Duration.zero, // v8.6: no per-item animation
              curve: _kTwEase,
              builder: (context, o, _) => CustomPaint(painter: _FloorPainter(o)),
            ),
          ),
          if (isCurrent) ...[
            // Centre cover: elevation 12 (modal level), downward only.
            Positioned(left: 0, top: 0, width: size, height: h, child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(_kRadius), boxShadow: VElev.e12))),
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kRadius),
                  // no light outline round the cover
                ),
              ),
            ),
            // (top glow removed: elevation only, per shadows-fix-collider-app.md)
          ],
        ],
      ),
    );
  }
}

/// Rasterised paint results, shared by all cards (key + device pixel ratio).
class _RasterCache {
  _RasterCache._();
  static final Map<String, ui.Image> _images = {};
  static final Map<String, List<VoidCallback>> _waiting = {};

  static ui.Image record(String key, Size logical, double scale,
      void Function(Canvas canvas) paint) {
    final hit = _images[key];
    if (hit != null) return hit;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(scale);
    paint(canvas);
    final pic = rec.endRecording();
    final img = pic.toImageSync(
      math.max(1, (logical.width * scale).ceil()),
      math.max(1, (logical.height * scale).ceil()),
    );
    pic.dispose();
    _images[key] = img;
    return img;
  }

  /// Reflection image for [theme]'s poster; null until the poster is decoded.
  static ui.Image? reflection(BuildContext context, WallpaperTheme theme,
          double size, double scale, VoidCallback onReady) =>
      _fromPoster(context, 'refl|${theme.posterUrl}|$size|$scale', theme,
          Size(size, size), scale, (c, img) => _paintReflection(c, img, size), onReady);

  /// The cover's poster pixels (object-cover into the card's inner box,
  /// FilterQuality.medium), rasterised once. On web the decoded <img> poster
  /// is a lazy texture that CanvasKit re-uploads (720x1280) whenever a card
  /// re-enters the screen; this pixel image is uploaded once and stays cached.
  static ui.Image? cover(BuildContext context, WallpaperTheme theme,
          double inner, double scale, VoidCallback onReady) =>
      _fromPoster(context, 'cover|${theme.posterUrl}|$inner|$scale', theme,
          Size(inner, inner), scale, (c, img) => paintImage(
                canvas: c,
                rect: Offset.zero & Size(inner, inner),
                image: img,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ), onReady);

  static ui.Image? _fromPoster(BuildContext context, String key, WallpaperTheme theme,
      Size logical, double scale, void Function(Canvas c, ui.Image poster) paint,
      VoidCallback onReady) {
    final hit = _images[key];
    if (hit != null) return hit;
    final waiting = _waiting[key];
    if (waiting != null) {
      waiting.add(onReady);
      return null;
    }
    _waiting[key] = [onReady];
    final stream = ThemeMedia.provider(theme.posterUrl)
        .resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      stream.removeListener(l);
      record(key, logical, scale, (c) => paint(c, info.image));
      for (final cb in _waiting.remove(key) ?? const <VoidCallback>[]) {
        cb();
      }
    }, onError: (_, __) {
      stream.removeListener(l);
      _waiting.remove(key);
    });
    stream.addListener(l);
    return null;
  }

  // Same operations as the widget version: ClipRRect(poster, cover) ->
  // ImageFiltered blur(0.5px) -> ColorFiltered brightness(0.6) contrast(1.3)
  // -> ClipRect -> ShaderMask(dstIn, to-top mask) -> scaleY(-1).
  static void _paintReflection(Canvas canvas, ui.Image poster, double size) {
    final rect = Offset.zero & Size(size, size);
    // brightness(0.6) then contrast(1.3): 1.3 * 0.6x + (0.5 - 0.65) = 0.78x - 0.15
    const s = _kReflectionContrast * _kReflectionBrightness;
    const t = (0.5 - 0.5 * _kReflectionContrast) * 255.0;
    const reflectionFilter = ColorFilter.matrix(<double>[
      s, 0, 0, 0, t,
      0, s, 0, 0, t,
      0, 0, s, 0, t,
      0, 0, 0, 1, 0,
    ]);
    canvas.save();
    canvas.translate(0, size);
    canvas.scale(1, -1); // scaleY(-1) about the centre
    canvas.clipRect(rect);
    canvas.saveLayer(rect, Paint()); // ShaderMask layer
    canvas.saveLayer(rect, Paint()..colorFilter = reflectionFilter);
    canvas.saveLayer(
        rect,
        Paint()
          ..imageFilter = ImageFilter.blur(
              sigmaX: _kReflectionBlur,
              sigmaY: _kReflectionBlur,
              tileMode: TileMode.decal));
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_kRadius)));
    paintImage(
      canvas: canvas,
      rect: rect,
      image: poster,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
    canvas.restore();
    canvas.restore();
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter, // "to top": 0% at bottom
          end: Alignment.topCenter,
          colors: _kReflectionMaskColors,
          stops: _kReflectionMaskStops,
        ).createShader(rect),
    );
    canvas.restore();
    canvas.restore();
  }
}

double _rasterScale(BuildContext context) =>
    MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);

/// Draws [painter] once into a cached image at the device pixel ratio.
class _CachedPaint extends StatelessWidget {
  final String cacheKey;
  final Size size;
  final CustomPainter painter;
  const _CachedPaint({required this.cacheKey, required this.size, required this.painter});

  @override
  Widget build(BuildContext context) {
    final scale = _rasterScale(context);
    final img = _RasterCache.record('$cacheKey|$scale', size, scale,
        (c) => painter.paint(c, size));
    return RawImage(
      image: img,
      width: size.width,
      height: size.height,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// The cover poster from [_RasterCache.cover]; the regular poster widget
/// is shown until the raster copy exists (same pixels, no visual change).
class _CoverPoster extends StatefulWidget {
  final WallpaperTheme theme;
  final double inner;
  const _CoverPoster({required this.theme, required this.inner});

  @override
  State<_CoverPoster> createState() => _CoverPosterState();
}

class _CoverPosterState extends State<_CoverPoster> {
  @override
  Widget build(BuildContext context) {
    final img = _RasterCache.cover(context, widget.theme, widget.inner,
        _rasterScale(context), () {
      if (mounted) setState(() {});
    });
    if (img == null) {
      return ThemePosterImage(
        theme: widget.theme,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }
    return RawImage(
      image: img,
      width: widget.inner,
      height: widget.inner,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
  }
}

class _Reflection extends StatefulWidget {
  final WallpaperTheme theme;
  final double size;
  final double opacity;
  final double dim;
  const _Reflection({required this.theme, required this.size, required this.opacity, required this.dim});

  @override
  State<_Reflection> createState() => _ReflectionState();
}

class _ReflectionState extends State<_Reflection> {
  @override
  Widget build(BuildContext context) {
    final img = _RasterCache.reflection(context, widget.theme, widget.size,
        _rasterScale(context), () {
      if (mounted) setState(() {});
    });
    // The raster path can't read cross-origin / first-frame posters on web, so
    // the reflection was empty. Fall back to the cover's own image widget,
    // mirrored and faded (same look: flipped poster under a fading mask).
    if (img == null) {
      return IgnorePointer(
        child: Opacity(
          opacity: (widget.opacity * (1 - widget.dim)).clamp(0.0, 1.0),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
              stops: [0.0, 0.6],
            ).createShader(r),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1, -1, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kRadius),
                child: SizedBox(width: widget.size, height: widget.size, child: ThemePosterImage(theme: widget.theme, fit: BoxFit.cover)),
              ),
            ),
          ),
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.opacity),
      duration: Duration.zero, // v8.6: no per-item animation
      curve: _kTwEase,
      builder: (context, o, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.dim),
        duration: Duration.zero, // v8.6: no per-item animation
        curve: _kTwEase,
        builder: (context, d, _) {
          final k = (255 * (1 - d)).round();
          return RawImage(
            image: img,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            opacity: AlwaysStoppedAnimation<double>(o),
            color: d > 0 ? Color.fromARGB(255, k, k, k) : null,
            colorBlendMode: d > 0 ? BlendMode.modulate : null,
          );
        },
      ),
    );
  }
}

/// Paints [inner] at [offset] with [innerSize] (for padded cache images).
class _OffsetPainter extends CustomPainter {
  final Offset offset;
  final Size innerSize;
  final CustomPainter inner;
  const _OffsetPainter(this.offset, this.innerSize, this.inner);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    inner.paint(canvas, innerSize);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// box-shadow `0 0 0 <spread>px <color>`: a crisp ring outside the border box.
class _RingPainter extends CustomPainter {
  final double radius;
  final double spread;
  final Color color;
  const _RingPainter(this.radius, this.spread, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final inner = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final outer = RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(spread), Radius.circular(radius + spread));
    canvas.drawDRRect(outer, inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.radius != radius || old.spread != spread || old.color != color;
}

/// blur-sm (8px) white/20 pill, padded by [pad].
class _GlowPainter extends CustomPainter {
  final double pad;
  final Size pill;
  const _GlowPainter(this.pad, this.pill);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..imageFilter =
              ImageFilter.blur(sigmaX: 8, sigmaY: 8, tileMode: TileMode.decal));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset(pad, pad) & pill, const Radius.circular(9999)),
      Paint()..color = const Color.fromRGBO(255, 255, 255, 0.2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => false;
}

/// Floor highlight gradient at [opacity] (no saveLayer).
class _FloorPainter extends CustomPainter {
  final double opacity;
  const _FloorPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_kRadius)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(255, 255, 255, 0.06 * opacity),
            Color.fromRGBO(255, 255, 255, 0.12 * opacity),
            const Color.fromRGBO(255, 255, 255, 0),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.opacity != opacity;
}

TextStyle _actionTextStyle(Color color, FontWeight weight) => _inter(TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: weight,
      letterSpacing: 14 * 0.025,
      color: color,
    ));

/// Tappable capsule in the app's glass (VMaterial.elevated, the bottom bar's
/// VOrnament material): fill, 0.5px rim, specular rim, VPress physics. Native
/// blurs with a BackdropFilter; web gets the blur from the ambient's CSS
/// element at the same rect (the video is DOM content under Flutter).
class _GlassCapsule extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool small;
  const _GlassCapsule({super.key, required this.label, required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final h = small ? 28.0 : _kCapsuleHeight;
    final r = BorderRadius.circular(h / 2);
    const material = VMaterial.elevated;
    Widget body = CustomPaint(
      foregroundPainter: SpecularRimPainter(borderRadius: h / 2, strokeWidth: 0.6),
      child: Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 20),
        decoration: BoxDecoration(
          color: material.fill,
          borderRadius: r,
          border: Border.all(color: material.rim, width: 0.5),
        ),
        // widthFactor 1: the capsule hugs its label instead of filling the row.
        child: Align(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            style: _actionTextStyle(
                const Color(0xFFFFFFFF), small ? FontWeight.w400 : FontWeight.w500)
                .copyWith(fontSize: small ? 13 : 14),
          ),
        ),
      ),
    );
    body = ClipRRect(
      borderRadius: r,
      child: kIsWeb
          ? body
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: material.blur, sigmaY: material.blur),
              child: body,
            ),
    );
    return Semantics(
      button: true,
      label: label,
      child: VPress(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: r, boxShadow: material.shadow),
          child: body,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// CSS transform list: perspective(1500px) [container] then
/// translateX(tx) translateZ(tz) rotateY(ry) scale(s). CSS z points at the viewer,
/// so the perspective term is -1/d (w = 1 - z/d), matching CSS numerically.
class _CardPose {
  final double tx, tz, ryDeg, scale, opacity;
  const _CardPose(this.tx, this.tz, this.ryDeg, this.scale, this.opacity);

  Matrix4 matrix() {
    final m = Matrix4.identity()..setEntry(3, 2, -1 / _kPerspective);
    m.multiply(Matrix4.translationValues(tx, 0, tz));
    m.multiply(Matrix4.rotationY(ryDeg * math.pi / 180));
    m.multiply(Matrix4.diagonal3Values(scale, scale, 1));
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is _CardPose &&
      other.tx == tx &&
      other.tz == tz &&
      other.ryDeg == ryDeg &&
      other.scale == scale &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(tx, tz, ryDeg, scale, opacity);

  static _CardPose lerp(_CardPose a, _CardPose b, double t) => _CardPose(
        a.tx + (b.tx - a.tx) * t,
        a.tz + (b.tz - a.tz) * t,
        a.ryDeg + (b.ryDeg - a.ryDeg) * t,
        a.scale + (b.scale - a.scale) * t,
        a.opacity + (b.opacity - a.opacity) * t,
      );
}

/// CSS transitions interpolate matching transform functions component-wise.
class _CardPoseTween extends Tween<_CardPose> {
  _CardPoseTween({super.end});

  @override
  _CardPose lerp(double t) => _CardPose.lerp(begin ?? end!, end!, t);
}

class _CssShadow {
  final double dx, dy, blur, spread;
  final Color color;
  const _CssShadow(this.dx, this.dy, this.blur, this.spread, this.color);
}

/// CSS box-shadow: outer shadows only (clipped out of the border box),
/// Gaussian sigma = blur / 2.
class _CssShadowPainter extends CustomPainter {
  final List<_CssShadow> shadows;
  final double radius;
  const _CssShadowPainter(this.shadows, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(400))
      ..addRRect(box));
    for (final s in shadows.reversed) {
      final rect = (Offset(s.dx, s.dy) & size).inflate(s.spread);
      final r = math.max(0.0, radius + s.spread);
      final paint = Paint()..color = s.color;
      if (s.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      }
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CssShadowPainter old) =>
      old.shadows != shadows || old.radius != radius;
}

/// CSS inset box-shadow (0 blur spread), painted inside the padding box.
class _InsetShadowPainter extends CustomPainter {
  final Offset offset;
  final double blur;
  final Color color;
  final double radius;
  const _InsetShadowPainter({
    required this.offset,
    required this.blur,
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(box);
    final hole = box.shift(offset);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(blur * 4 + 20))
      ..addRRect(hole);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InsetShadowPainter old) =>
      old.offset != offset || old.blur != blur || old.color != color || old.radius != radius;
}

/// CSS `linear-gradient(<angle>deg, ...)` mapped to Flutter begin/end for [size].
LinearGradient _cssLinearGradient(
    double angleDeg, Size size, List<Color> colors, List<double> stops) {
  final a = angleDeg * math.pi / 180;
  final dx = math.sin(a), dy = -math.cos(a);
  final len = (size.width * dx.abs() + size.height * dy.abs()) / 2;
  final hx = size.width / 2, hy = size.height / 2;
  return LinearGradient(
    begin: Alignment(-dx * len / hx, -dy * len / hy),
    end: Alignment(dx * len / hx, dy * len / hy),
    colors: colors,
    stops: stops,
  );
}

/// Export font is `ui-sans-serif, system-ui, sans-serif`; the platform
/// substitute on web/Android/Windows is Inter (AUTHORITY S-C13).
TextStyle _inter(TextStyle s) => appFont(textStyle: s, fontSize: s.fontSize, fontWeight: s.fontWeight, color: s.color, height: s.height, letterSpacing: s.letterSpacing ?? (s.fontSize != null && s.fontSize! <= 17 ? -0.4 : null));

/// CSS drop-shadow(x y blur color): sigma = blur / 2.
Shadow _cssDropShadow(double x, double y, double blur, Color color) {
  final r = math.max(0.0, (blur / 2 - 0.5) / 0.57735);
  return Shadow(offset: Offset(x, y), blurRadius: r, color: color);
}

/// SearchBar icon: `M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z`, stroke-width 2, round.
class _SearchGlyphPainter extends CustomPainter {
  final Color color;
  const _SearchGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(Offset(10 * k, 10 * k), 7 * k, p);
    canvas.drawLine(Offset(21 * k, 21 * k), Offset(15 * k, 15 * k), p);
  }

  @override
  bool shouldRepaint(covariant _SearchGlyphPainter old) => old.color != color;
}

/// SearchBar clear icon: `M6 18L18 6M6 6l12 12`, stroke-width 2, round.
class _ClearGlyphPainter extends CustomPainter {
  final Color color;
  const _ClearGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(6 * k, 18 * k), Offset(18 * k, 6 * k), p);
    canvas.drawLine(Offset(6 * k, 6 * k), Offset(18 * k, 18 * k), p);
  }

  @override
  bool shouldRepaint(covariant _ClearGlyphPainter old) => old.color != color;
}
