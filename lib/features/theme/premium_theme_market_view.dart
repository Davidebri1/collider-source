import '../../core/theme/app_font.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/theme/specular_border.dart';
import '../../core/vision/vision_kit.dart';
import '../../core/vision/materialize.dart';
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

  const PremiumThemeMarketView({
    super.key,
    required this.currentTheme,
    required this.onApplyTheme,
    required this.onPreviewTheme,
    required this.onClose,
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
const double _kCoverSizeMobile = 170;
const double _kCoverSizeDesktop = 200;

// The Premium carousel.
//
// The carousel is the animated object. The whole strip slides as one rigid
// body and every cover rides along inside it, upright and un-rotated. Nothing
// rotates, nothing tilts, no cover is individually scaled or clipped, and no
// cover animates on its own timer.
//
// Figma reference proportions (map row 1, "CoverFlow photo carousel", node
// 1-3). A page is one slot: cover + gap, not the full stage. That is the whole
// difference between a strip and one card in a void. On the phone that
// matters — 430x932 — the stage is 398 wide, the centre cover is 170 (43% of
// the stage, the reference's share) and 54px of each neighbour (32% of a cover)
// is on screen at either side, so 1.37 pages are visible at rest.
const double _kSpacingMobile = 120;
const double _kSpacingDesktop = 160;

// The stage box the carousel is laid out in. The label form below is
// positioned off the stage height, so these stay.
const double _kStageHeight = 384;
const double _kStageMaxWidth = 1280;

// Chevrons at the two ends of the strip. No scrollbar (the owner's constraint):
// the edge fades say "more this way", the chevrons move it.
const double _kChevronSize = 34;

// transition: 400ms cubic-bezier(0.23, 1, 0.32, 1)
const Duration _kCardTransition = Duration(milliseconds: 400);
const Cubic _kCardEase = Cubic(0.23, 1, 0.32, 1);

// Card chrome: rounded-lg = --radius .625rem
const double _kRadius = 10;
// border border-gray-800/30  (#1E2939 @ 30%)
const Color _kCoverBorder = Color.fromRGBO(30, 41, 57, 0.3);
// img boxShadow: 0 25px 50px -12px rgba(0,0,0,0.9), 0 8px 32px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.1)
const List<_CssShadow> _kCoverShadows = [
  _CssShadow(0, 25, 50, -12, Color.fromRGBO(0, 0, 0, 0.9)),
  _CssShadow(0, 8, 32, 0, Color.fromRGBO(0, 0, 0, 0.6)),
  _CssShadow(0, 0, 0, 1, Color.fromRGBO(255, 255, 255, 0.1)),
];
// The two blurred layers (cached as one image) and the crisp 1px ring.
const List<_CssShadow> _kCoverShadowsBlurred = [
  _CssShadow(0, 25, 50, -12, Color.fromRGBO(0, 0, 0, 0.9)),
  _CssShadow(0, 8, 32, 0, Color.fromRGBO(0, 0, 0, 0.6)),
];
// center border overlay: border-white/30 shadow-2xl (0 25px 50px -12px #00000040)
const List<_CssShadow> _kShadow2xl = [
  _CssShadow(0, 25, 50, -12, Color.fromRGBO(0, 0, 0, 0.25)),
];

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
const int _kSongSlots = 3;
const double _kSongsBlockHeight = _kSongSlots * _kSongRowExtent;
const double _kActionHeight = 36;
const double _kNoSongsGap = 12;
const double _kCapsuleHeight = 34;
const double _kLabelsBlockHeight =
    8 + 28 + 8 + _kSongsBlockHeight + 16 + _kActionHeight + 8;

// The not-owned dim over a cover (DEVIATIONS.md D5) is gone with the rest of
// the overlays (bug 2): a black 45% sheet over the face is exactly the "dimming
// scrim" the owner keeps asking to be removed, and the apply control on the
// cover now says owned or not without hiding the artwork behind it.

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
        ...WallpaperCatalog.freeThemes,
      ].where(_inCategory).toList();

  // v8.7 side nav: categories + a search button (popup search with DOF).
  // Categories = the bucket's top-level folders (theme.collection).
  List<String> get _categories => [
        'All',
        // v8.7: the ghost menu filters by tag (most used first).
        ...(() {
          final n = <String, int>{};
          for (final t in [...WallpaperCatalog.premiumThemes, ...WallpaperCatalog.freeThemes]) {
            // v9.1.4 (playtest #15): file formats aren't categories.
            for (final g in t.tags) { // NEXT-v87 #9: every tag, incl. file type, is a filter
              n[g] = (n[g] ?? 0) + 1;
            }
          }
          return n.keys.toList()..sort((a, b) => n[b]!.compareTo(n[a]!));
        })(),
      ];
  String _category = 'All';
  bool _searchOpen = false;
  bool _exploded = false;
  bool _inCategory(WallpaperTheme t) => _category == 'All' || t.tags.contains(_category);
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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SuspendedFrost(
        edge: 0.15,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: VFrost.blur, sigmaY: VFrost.blur),
            child: ColoredBox(
              color: VFrost.tint,
              child: item(Icons.search_rounded, 'Search', _searchOpen || _searchQuery.isNotEmpty,
                  () => _openSearch(true)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      GhostMenu(
        width: 96,
        items: cats,
        selected: math.max(0, cats.indexOf(_category)),
        onSelected: (i) => _setCategory(cats[i]),
      ),
    ]);
  }

  /// Exploded asset view: the cover lifted forward, a context menu under it.
  Widget _explodedView(WallpaperTheme t, double w, double h) {
    final cw = math.min(w * 0.62, 300.0);
    final owned = _owned(t);
    final menu = GlassMenu(rows: [
      GlassMenuRow(
          icon: owned ? Icons.check_rounded : Icons.shopping_bag_outlined,
          label: owned ? 'Apply' : 'Buy · ${_store.priceLabelFor(t.id, catalogPrice: t.priceLabel)}',
          on: true,
          toggle: false,
          onTap: () {
            setState(() => _exploded = false);
            owned ? widget.onApplyTheme(t) : _confirmBuy(t, _store.priceLabelFor(t.id, catalogPrice: t.priceLabel));
          }),
      GlassMenuRow(
          icon: Icons.visibility_outlined,
          label: 'Preview',
          toggle: false,
          onTap: () {
            setState(() => _exploded = false);
            widget.onPreviewTheme(t);
          }),
      GlassMenuRow(
          icon: Icons.close_rounded, label: 'Close', toggle: false,
          onTap: () => setState(() => _exploded = false)),
    ]);
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
                height: cw * 16 / 9,
                child: ThemeImage(t.assetPath, fit: BoxFit.cover, filterQuality: FilterQuality.high),
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
                t.id.toLowerCase().contains(q);
          }).toList();
    final prevId = _selected?.id;
    setState(() {
      _searchQuery = query;
      _themes = results;
      final kept = keepId == null ? -1 : results.indexWhere((t) => t.id == keepId);
      _currentIndex =
          results.isEmpty ? 0 : (kept >= 0 ? kept : results.length ~/ 2);
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
      final mainHeight = math.max(0.0, h - mainTop - barReserve);
      const contentHeight =
          _kStageHeight + _kLabelsMarginTop + _kLabelsBlockHeight;
      final contentTop =
          mainTop + math.max(0.0, (mainHeight - contentHeight) / 2);
      final stageTop = contentTop;
      final labelsTop = stageTop + _kStageHeight + _kLabelsMarginTop;
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
        AmbientGlass(
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
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF000000), Color(0xFF111111)],
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
                Positioned.fill(
                  child: SimpleBackgroundVideoAmbient(
                    theme: selected,
                    owned: kOwnedBrighterState && _owned(selected),
                    glass: kIsWeb ? glass : const [],
                  ),
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
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildLabels(selected, contentWidth),
                  ),
                ),
                // CoverFlow wrapper
                Positioned(
                  // Approved v9 geometry: the stage is centred on the screen.
                  left: _kMainPadX,
                  right: _kMainPadX,
                  top: stageTop,
                  height: _kStageHeight,
                  child: Center(
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
                        onApplyCover: _applyAt,
                      ),
                    ),
                  ),
                ),
              ],

              // v8.7 side nav (categories + search), left edge.
              // Side nav with categories + search (user ask, v8.7).
              Positioned(left: 8, top: mainTop, child: _sideNav()),

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
                  child: Materialize(origin: Alignment.topCenter, child: Center(child: SizedBox(width: searchWidth, height: _kSearchHeight, child: _buildSearchBar()))),
                ),
              ],

              if (_exploded && _selected != null)
                Positioned.fill(child: Materialize(child: _explodedView(_selected!, w, h))),

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
              child: Text(
                _displayName(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _inter(TextStyle(
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFFFFFFFF),
                  shadows: [_cssDropShadow(0, 4, 4, const Color(0x26000000))],
                )),
              ),
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
        icon: Icons.wallpaper_rounded,
        onTap: () => widget.onApplyTheme(t),
      );
    }
    final price = _store.priceLabelFor(t.id, catalogPrice: t.priceLabel);
    return _GlassCapsule(
      key: _capsuleKey,
      label: 'Buy · $price',
      onTap: () => _confirmBuy(t, price),
    );
  }

  /// The apply control on a cover (bug 3) runs the same two paths as the
  /// capsule, so the button and the word below it never disagree.
  void _applyAt(int index) {
    if (_themes.isEmpty) return;
    final t = _themes[index.clamp(0, _themes.length - 1)];
    if (_owned(t)) {
      widget.onApplyTheme(t);
      return;
    }
    _confirmBuy(t, _store.priceLabelFor(t.id, catalogPrice: t.priceLabel));
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
          // input: rounded-full border border-gray-700 (focus: border-gray-500)
          // backdrop-blur-sm (8px), background linear-gradient(145deg, rgba(0,0,0,0.4), rgba(255,255,255,0.02))
          //
          // Bug 6: this capsule used to carry four sheets at once — a backdrop
          // blur, an inset 0 2px 6px black shadow, a black-to-white gradient
          // and a rim. The inset shadow is a second darkening layer painted
          // over a fill that already starts at 40% black, and it is what made
          // the field look grey and heavy. The gradient does that job. What is
          // left is one blur + one fill + one rim, which is still glass.
          CustomPaint(
            painter: _CssShadowPainter(const [
              _CssShadow(0, 1, 2, 0, Color.fromRGBO(255, 255, 255, 0.05)),
            ], size.height / 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: _maybeBackdrop(
                sigma: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    gradient: _cssLinearGradient(
                      145,
                      size,
                      const [
                        Color.fromRGBO(0, 0, 0, 0.34),
                        Color.fromRGBO(255, 255, 255, 0.04),
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
          // Search icon: absolute inset-y-0 left-0 pl-3, h-4 w-4 text-gray-400.
          //
          // Painted on top of the field and left sharp. It used to be painted
          // underneath and then blurred by 8px on web to fake the field's
          // backdrop-filter, which turned a 16px glyph into a grey smear
          // (bug 5). An icon should never be blurred by a decoration that is
          // not behind it.
          const Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(child: glyph),
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

  /// Bug 3: the apply / set control on the centred cover. Buys through the
  /// same path the capsule uses when the theme is not owned yet.
  final void Function(int index) onApplyCover;

  const _CoverFlow({
    required this.themes,
    required this.currentIndex,
    required this.isMobile,
    required this.viewportWidth,
    required this.ownedIds,
    required this.onSelect,
    required this.onTapCover,
    required this.onApplyCover,
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
    // Selection can change from outside (search, tap, arrows, a chevron).
    // Follow it, but never fight a drag the user is in the middle of.
    if (old.currentIndex != widget.currentIndex && !_drag.dragging && _pager.hasClients) {
      final target = widget.currentIndex.clamp(0, widget.themes.length - 1);
      if ((_pager.page ?? target.toDouble()).round() != target) _goTo(target);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One page is one slot (cover + gap). Sizing the page to the slot rather
    // than to the viewport is what puts the neighbours on screen beside the
    // centre cover; full-width pages hide them off-stage, which is what made
    // this a single card floating in a void.
    final f = (_slotWidth / _stageWidth(context)).clamp(0.12, 1.0);
    if (_fraction == f) return;
    _fraction = f;
    final current = _pager.hasClients
        ? (_pager.page ?? widget.currentIndex.toDouble()).round()
        : widget.currentIndex;
    final page = current.clamp(0, widget.themes.length - 1);
    if (!_pager.hasClients && _pager.initialPage == page) {
      // First build: the controller already has the right page, only the
      // viewport fraction is wrong, so it has to be replaced.
      _pager.dispose();
      _pager = PageController(initialPage: page, viewportFraction: f);
      return;
    }
    // Already scrolled: replace it after the frame, once the PageView that
    // still holds the old controller has been torn down.
    final old = _pager;
    _pager = PageController(initialPage: page, viewportFraction: f);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void initState() {
    super.initState();
    _pager = PageController(initialPage: widget.currentIndex, viewportFraction: 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prewarm());
  }

  @override
  void dispose() {
    _prewarmGen++;
    _drag.dispose();
    _pager.dispose();
    super.dispose();
  }

  int _prewarmGen = 0;

  /// Real paging controller: drag, fling and snap for free, including with a
  /// mouse, because PageView takes the platform's drag devices.
  late PageController _pager;

  /// The slot fraction the current [_pager] was built with.
  double _fraction = -1;

  double get _slotWidth {
    final cover = widget.isMobile ? _kCoverSizeMobile : _kCoverSizeDesktop;
    final gap = widget.isMobile ? _kSpacingMobile : _kSpacingDesktop;
    return cover + gap;
  }

  /// The width the strip is laid out in: the same box the PageView gets, so
  /// the fraction is the page size over the viewport size.
  double _stageWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return math.min(w - _kMainPadX * 2, _kStageMaxWidth);
  }

  /// Animate to [index] on the strip. The single way the carousel moves,
  /// whichever input asked for it (chevron, tap, keyboard, external selection).
  void _goTo(int index) {
    if (widget.themes.isEmpty) return;
    final target = index.clamp(0, widget.themes.length - 1);
    if (!_pager.hasClients) {
      widget.onSelect(target);
      return;
    }
    _pager.animateToPage(target, duration: _kCardTransition, curve: _kCardEase);
  }

  /// Chevrons wrap (map row 4: no stop at the first or last theme). Drag
  /// stops at the ends, which the chevrons make obvious by disabling.
  void _step(int delta) {
    final n = widget.themes.length;
    if (n == 0) return;
    _goTo(((widget.currentIndex + delta) % n + n) % n);
  }

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

  /// Position relative to the centre cover on the loop: -n/2 .. n/2. Still
  /// used to decide which covers play their live wallpaper near the centre.
  int _rel(int index) {
    final n = widget.themes.length;
    if (n == 0) return 0;
    var d = (index - widget.currentIndex) % n;
    if (d < 0) d += n;
    if (d > n ~/ 2) d -= n;
    return d;
  }

  Widget _card(int i, double size) {
    final t = widget.themes[i];
    final isCurrent = i == widget.currentIndex;
    final owned = widget.ownedIds.contains(t.id);
    // The centre cover and its two neighbours play their live wallpaper;
    // the rest show the poster until they come near the centre.
    // v9.1: no per-thumbnail motion; only the centred cover plays live.
    final live = t.isLive && _rel(i).abs() < 0.5;
    return _cards.putIfAbsent(
      '${t.id}|$isCurrent|$owned|$size|$live',
      () => RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            if (!_drag.dragging) widget.onTapCover(i);
          },
          child: _CoverCard(
            theme: t,
            isCurrent: isCurrent,
            owned: owned,
            onApply: () => widget.onApplyCover(i),
            size: size,
            live: live,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverSize = widget.isMobile ? _kCoverSizeMobile : _kCoverSizeDesktop;
    final themes = widget.themes;
    final spacing = widget.isMobile ? _kSpacingMobile : _kSpacingDesktop;
    if (themes.isEmpty) return const SizedBox.shrink();
    final n = themes.length;
    final atStart = widget.currentIndex <= 0;
    final atEnd = widget.currentIndex >= n - 1;

    final strip = MouseRegion(
      cursor: _drag.dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      child: PageView(
        controller: _pager,
        // Real scroll physics: drag, fling and snap, with a mouse as well as
        // a finger. A hand-rolled tween cannot fling, and a tween fed a value
        // that is always 0 does not move at all — which is what this replaced.
        physics: const ClampingScrollPhysics(),
        // padEnds: true gives the first and last slot a matching half-gap at
        // each end, so whichever cover is centred sits on the frame's centre
        // line. With padEnds: false page 0 sits flush to the leading edge and
        // the centre cover is a half-slot left of centre.
        padEnds: true,
        onPageChanged: (i) {
          if (!_drag.dragging) widget.onSelect(i);
        },
        // Tapping a neighbour selects it. Hit testing works because each page
        // is the full slot, so the peeking strip is a real tap target.
        children: [
          for (var i = 0; i < themes.length; i++)
            _cards.putIfAbsent(
              'page|$i|${themes[i].id}',
              () => Padding(
                // Half the gap either side of the cover inside its own slot.
                padding: EdgeInsets.symmetric(horizontal: spacing / 2),
                child: Center(child: _card(i, coverSize)),
              ),
            ),
        ],
      ),
    );

    // No scrollbar (the owner's constraint): the edge fades say there is more,
    // the chevrons move it. scrollbars: false is set here rather than relying
    // on the app-wide behaviour, so the rule holds wherever this is mounted.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // No extra inset here: the strip takes the stage box exactly, because
          // [_fraction] is computed from that same width. An inset would make
          // the real page narrower than the slot the carousel was laid out for.
          // The edge fade below is what softens the ends.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) {
              final f = r.width <= 0 ? 0.1 : (14 / r.width).clamp(0.0, 0.28);
              return LinearGradient(
                colors: const [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
                stops: [0, f, 1 - f, 1],
              ).createShader(r);
            },
            child: strip,
          ),
        ],
      ),
    );
  }
}

/// The chevron at one end of the carousel. A single floating glass circle:
/// one layer of tint and one rim, not a stack of translucent sheets (bug 6).
class _StripChevron extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _StripChevron({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.28,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: VCircleButton(
          icon: icon,
          size: _kChevronSize,
          floating: true,
          tooltip: tooltip,
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}

/// One CoverFlow card: <img> + glass reflection + ReflectionComponent + floor
/// highlight (+ centre border / top glow). The blurred box-shadows, the
/// reflection (blur / brightness / contrast / mask) and the top glow are
/// rasterised once into images (_RasterCache) with the same geometry and
/// filters, then drawn as plain images every frame.
///
/// Bug 2 (owner, repeated): nothing is laid over the artwork itself. The
/// export's glass sheen gradient and the not-owned dim scrim are gone — a
/// second translucent sheet on top of a picture the user is judging, on a
/// stack that already carries three (bug 6). The ring, the centre lift and
/// the reflection below the cover stay: those are edges and a separate plane,
/// not a veil over the picture.
class _CoverCard extends StatelessWidget {
  final WallpaperTheme theme;
  final bool isCurrent;
  final bool owned;
  final VoidCallback onApply;
  final bool live;
  final double size;

  const _CoverCard({
    required this.theme,
    required this.isCurrent,
    required this.owned,
    required this.onApply,
    required this.live,
    required this.size,
  });

  static const double _shadowPad = 100;
  static const double _glowPad = 24;

  @override
  Widget build(BuildContext context) {
    // ReflectionComponent opacity: index === currentIndex ? 0.9 : 0.75
    final reflectionOpacity =
        isCurrent ? _kReflectionOpacityCenter : _kReflectionOpacitySide;
    return SizedBox(
      width: size,
      height: size * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // img boxShadow (two blurred layers, cached) + the 1px white ring
          Positioned(
            left: -_shadowPad,
            top: -_shadowPad,
            width: size + _shadowPad * 2,
            height: size + _shadowPad * 2,
            child: _CachedPaint(
              cacheKey: 'cover-shadow|$size',
              size: Size(size + _shadowPad * 2, size + _shadowPad * 2),
              painter: _OffsetPainter(
                const Offset(_shadowPad, _shadowPad),
                Size(size, size),
                const _CssShadowPainter(_kCoverShadowsBlurred, _kRadius),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: size,
            child: CustomPaint(painter: _RingPainter(_kRadius, 1, _kCoverShadows[2].color)),
          ),
          // <img> object-cover rounded-lg border border-gray-800/30
          Positioned(
            left: 0,
            top: 0,
            width: size,
            height: size,
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
              ],
            ),
          ),
          // Builder ReflectionComponent: absolute top-full, w-full h-full, rounded-lg,
          // background cover, scaleY(-1), opacity 0.9/0.75 (duration-500), mask
          // to-top, filter blur(0.5px) brightness(0.6) contrast(1.3) Ã¢â‚¬â€ cached image.
          Positioned(
            left: 0,
            top: size,
            width: size,
            height: size,
            child: _Reflection(
              theme: theme,
              size: size,
              opacity: reflectionOpacity,
            ),
          ),
          // Floor highlight: top-full h-3 rounded-lg translateY(6px), opacity 0.6 / 0.35 (duration-1000)
          // linear-gradient(to bottom, rgba(255,255,255,0.06) 0%, 0.12 40%, transparent 100%)
          Positioned(
            left: 0,
            top: size + _kFloorOffset,
            width: size,
            height: _kFloorHeight,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isCurrent ? 0.6 : 0.35),
              duration: const Duration(milliseconds: 1000),
              curve: _kTwEase,
              builder: (context, o, _) => CustomPaint(painter: _FloorPainter(o)),
            ),
          ),
          if (isCurrent) ...[
            // absolute inset-0 rounded-lg border border-white/30 shadow-2xl
            Positioned(
              left: -_shadowPad,
              top: -_shadowPad,
              width: size + _shadowPad * 2,
              height: size + _shadowPad * 2,
              child: _CachedPaint(
                cacheKey: 'center-shadow|$size',
                size: Size(size + _shadowPad * 2, size + _shadowPad * 2),
                painter: _OffsetPainter(
                  const Offset(_shadowPad, _shadowPad),
                  Size(size, size),
                  const _CssShadowPainter(_kShadow2xl, _kRadius),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kRadius),
                ),
              ),
            ),
            // top-0 left-1/4 right-1/4 h-1 bg-white/20 rounded-full blur-sm (8px)
            Positioned(
              top: -_glowPad,
              left: size / 4 - _glowPad,
              width: size / 2 + _glowPad * 2,
              height: 4 + _glowPad * 2,
              child: _CachedPaint(
                cacheKey: 'center-glow|$size',
                size: Size(size / 2 + _glowPad * 2, 4 + _glowPad * 2),
                painter: _GlowPainter(_glowPad, Size(size / 2, 4)),
              ),
            ),
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

  /// The cover's poster pixels (object-cover into the card's inner box),
  /// rasterised once. On web the decoded <img> poster is a lazy texture that
  /// CanvasKit re-uploads (720x1280) whenever a card re-enters the screen;
  /// this pixel image is uploaded once and stays cached.
  ///
  /// Bug 5: the record canvas is already scaled to the device ratio by
  /// [record], so `high` here is a proper downsample of a large poster into a
  /// card-sized box. `medium` was the box filter that made the covers look
  /// soft-edged.
  static ui.Image? cover(BuildContext context, WallpaperTheme theme,
          double inner, double scale, VoidCallback onReady) =>
      _fromPoster(context, 'cover|${theme.posterUrl}|$inner|$scale', theme,
          Size(inner, inner), scale, (c, img) => paintImage(
                canvas: c,
                rect: Offset.zero & Size(inner, inner),
                image: img,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
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
      filterQuality: FilterQuality.high,
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

/// Bug 5: raster scale for the cached card paints.
///
/// The raster cache records a picture once and then blits it every frame, so
/// the scale it records at is the resolution the UI is stuck with for the life
/// of the cache. It used to clamp the device pixel ratio into [1, 3], which
/// quietly downsampled on a 3x phone and made every edge and icon soft. There
/// is no reason to cap below the real ratio: the cache is a handful of cards,
/// each recorded once. Where the platform reports a ratio below 2 (a desktop
/// browser at 1x, or CanvasKit reporting 1), floor it at 2 so the artwork is
/// rasterised above the logical size and stays sharp when the window scales.
double _rasterScale(BuildContext context) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (dpr < 2 ? 2.0 : dpr).clamp(2.0, 4.0);
}

/// Draws [painter] once into a cached image at [_rasterScale].
///
/// The blit is [FilterQuality.none] because the image is recorded at exactly
/// the device resolution of the box it fills: there is no resampling to do, and
/// asking the sampler for a filtered result here is what was producing the
/// visibly pixelated icons and cover edges.
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
      filterQuality: FilterQuality.none,
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
        filterQuality: FilterQuality.high,
      );
    }
    // The cache image is recorded at exactly this box's device resolution, so
    // the blit is 1:1 and must not be resampled (bug 5).
    return RawImage(
      image: img,
      width: widget.inner,
      height: widget.inner,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    );
  }
}

class _Reflection extends StatefulWidget {
  final WallpaperTheme theme;
  final double size;
  final double opacity;
  const _Reflection({required this.theme, required this.size, required this.opacity});

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
    if (img == null) return const SizedBox.shrink();
    // v9.1: no per-thumbnail fade; the reflection follows the scroll directly.
    return RawImage(
      image: img,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      opacity: AlwaysStoppedAnimation<double>(widget.opacity),
    );
  }
}

/// Bug 3: the apply / set control for a theme preview. One small circular
/// glass button, bottom-right of the centred cover: a check when the theme is
/// already the one on the wall, a plus when it is not. Not an overlay on the
/// picture's face — it sits in its own corner and takes a tap away from the
/// cover only in that corner.
class _CoverApplyButton extends StatelessWidget {
  final bool owned;
  final VoidCallback onTap;

  const _CoverApplyButton({required this.owned, required this.onTap});

  static const double _d = 30;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: owned ? 'Set Wallpaper' : 'Buy this theme',
      child: VPress(
        onTap: onTap,
        child: Container(
          width: _d,
          height: _d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // One glass layer, not a stack: the artwork behind is already
            // blurred ambient, so a tint plus a specular rim reads as glass
            // without adding a second translucent sheet (bug 6).
            color: const Color(0x4DFFFFFF),
            border: Border.all(color: const Color(0x66FFFFFF), width: 0.5),
          ),
          child: Icon(
            owned ? Icons.check_rounded : Icons.add_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
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
/// VOrnament material): fill, rim, VPress physics. Native blurs with a
/// BackdropFilter; web gets the blur from the ambient's CSS element at the same
/// rect (the video is DOM content under Flutter).
///
/// Bug 6: the rim was painted twice — a 0.5px `Border.all` and a 0.6px
/// [SpecularRimPainter] on top of it. Two half-pixel rims at two alphas read as
/// a soft grey band rather than a crisp edge, which is the muddy look the
/// stacked layers were causing. One rim does the job: the specular one, which
/// carries the visionOS highlight (R36).
class _GlassCapsule extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const _GlassCapsule({super.key, required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    const h = _kCapsuleHeight;
    final r = BorderRadius.circular(h / 2);
    const material = VMaterial.elevated;
    Widget body = CustomPaint(
      foregroundPainter:
          const SpecularRimPainter(borderRadius: _kCapsuleHeight / 2, strokeWidth: 0.6),
      child: Container(
        height: h,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: material.fill,
          borderRadius: r,
        ),
        // widthFactor 1: the capsule hugs its label instead of filling the row.
        child: Align(
          widthFactor: 1,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 17, color: Colors.white), const SizedBox(width: 6)],
            Text(
              label,
              maxLines: 1,
              style: _actionTextStyle(
                  const Color(0xFFFFFFFF), FontWeight.w600)
                  .copyWith(fontSize: 14),
            ),
          ]),
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

// The per-card CoverFlow pose (perspective / rotateY / translateZ / scale /
// opacity) and its tween were removed. The track carries the only transform now,
// so there is nothing left for them to describe.

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

/// The Figma export declares `ui-sans-serif, system-ui, sans-serif`, which the
/// platform substitutes with Inter (AUTHORITY S-C13). v9 stops doing that:
/// Inter was never bundled, so this helper pulled a second family off the CDN
/// at runtime and the Theme Gallery / Settings surfaces rendered in a different
/// face from everything around them. It now uses the one bundled family.
TextStyle _inter(TextStyle s) => appFont(textStyle: s);

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
