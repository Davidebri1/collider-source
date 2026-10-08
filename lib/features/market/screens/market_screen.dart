import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../models/theme_def.dart';
import '../../mediagen/media_view.dart';
import '../../theme/theme_living_media.dart';

/// Discover Market.
///
/// The source is the Figma Reference Map, row 21: "Video Platforms on visionOS",
/// node 203-5891. That design is a *floating window* over the dimmed world — a
/// hero with a scrim, a title, two pill buttons, a section label over a
/// horizontal shelf, the kind capsule floating below the window, and the
/// dot + grab bar. That is the primary surface and it is reproduced here.
///
/// Portrait and proportional: built at [frame] (393 x 852, iPhone logical) and
/// handed to [FigmaViewport], which lays it out at that width, rescales
/// MediaQuery with it and scales the result as one unit. Gutters, radii, type
/// and touch targets therefore keep their proportion to the screen on every
/// device instead of reflowing, which is the same method the rest of the app
/// uses for its Figma frames.
///
/// The masonry is not thrown away — it is the window's browse view. The source
/// puts a chevron at the base of the hero; here that chevron opens a full grid
/// inside the same window. Catalog stills and this session's own generations
/// are both browsable that way, and your own carry the seed mark.
class MarketScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String prompt) onUsePrompt;

  /// One quiet line (e.g. a generation that cannot run on this link).
  final void Function(String text)? onNotice;

  /// Remix: the title goes into the app composer as an image prompt.
  final ValueChanged<String>? onRemix;

  /// Rail selection: 'discover' | 'search' | 'mine'.
  final String view;

  /// The session's finished image generations as (prompt, url).
  final List<(String, String)> generated;

  const MarketScreen({
    super.key,
    required this.onClose,
    required this.onUsePrompt,
    this.onNotice,
    this.onRemix,
    this.view = 'discover',
    this.generated = const [],
  });

  /// Portrait design frame. Everything inside is expressed in these units.
  static const frame = Size(393, 852);

  /// The window is inset to clear the side rail (which ends at x 16) and to
  /// keep a matching air on the right.
  static const windowLeft = 20.0;
  static const windowRight = 20.0;
  /// A literal rather than frame.width, so this stays a const expression.
  static const windowWidth = 393.0 - windowLeft - windowRight;

  static const windowRadius = 28.0;
  static const contentInset = 20.0;

  /// Space between the window and the ornaments below it.
  static const capsuleGap = 14.0;
  static const capsuleHeight = 36.0;
  static const controlsGap = 10.0;
  static const controlsHeight = 14.0;

  /// Clearance for PermanentNavBar (12 + 44 + 12) plus its SafeArea.
  static const dockReserve = 84.0;

  /// Shelf geometry. Covers are stills, so they stand a little tall.
  static const shelfLabelHeight = 24.0;
  static const shelfGap = 10.0;
  static const leadCoverWidth = 92.0;
  static const leadCoverHeight = 124.0;
  static const coverWidth = 80.0;
  static const coverHeight = 108.0;

  /// Browse view (the masonry inside the window).
  static const gridGutter = 12.0;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

enum _Window { featured, browse }

class _Tile {
  final String id;
  final String title;
  final String src;
  final bool generated;

  /// Height as a multiple of width, for the masonry only. Stable per tile.
  final double ratio;

  const _Tile(this.id, this.title, this.src, {this.generated = false, this.ratio = 1});
}

// ---------------------------------------------------------------- palette --

const _void = Color(0xFF0A0A0A);
const _graphite = Color(0xFF161616);
const _chalk = Color(0xFFFFFFFF);
const _ash = Color(0xFF8A8A8E);
const _dim = Color(0xFF5A5A5E);
const _stroke = Color(0x33FFFFFF);

/// Height ratios the masonry draws from. Catalog stills are mostly 16:9
/// wallpapers, so the set leans tall and only occasionally breaks wide.
const _ratios = <double>[1.0, 1.34, 0.78, 1.18, 0.62, 1.06, 0.9, 1.46];

/// FNV-1a over code units: identical on every run and platform, unlike
/// String.hashCode. The masonry depends on this for a stable layout.
int _stableHash(String s) {
  var h = 0x811c9dc5;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

TextStyle _sans(double size, FontWeight weight, Color color, {double? ls, double? h}) => GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: ls,
      height: h,
      decoration: TextDecoration.none,
    );

TextStyle _mono(double size, FontWeight weight, Color color, {double? ls}) => GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: ls,
      decoration: TextDecoration.none,
    );

class _MarketScreenState extends State<MarketScreen> with SingleTickerProviderStateMixin {
  static const _kinds = <String>['Stills', 'Templates', 'Cinematic', 'Night'];

  _Window _window = _Window.featured;
  int _kind = 0;
  String _query = '';
  _Tile? _open;

  late final AnimationController _entrance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  final _queryCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  /// Searching or My generations are ways of looking at the list, so they open
  /// the browse view directly; the hero is only for Discover.
  bool get _browsing => _window == _Window.browse || widget.view != 'discover';
  bool get _inMine => widget.view == 'mine';
  bool get _searching => widget.view == 'search';

  @override
  void initState() {
    super.initState();
    if (_searching) _entrance.forward();
  }

  @override
  void didUpdateWidget(covariant MarketScreen old) {
    super.didUpdateWidget(old);
    if (old.view == widget.view) return;
    // The rail moves between Discover / Search / My generations behind us.
    // Coming back to Discover returns the window to its featured state, and
    // leaving Search drops the query, so nothing leaks between the views.
    _queryCtrl.clear();
    setState(() {
      _query = '';
      if (widget.view == 'discover') _window = _Window.featured;
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _queryCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- content --

  List<_Tile> get _generated => [
        for (var i = 0; i < widget.generated.length; i++)
          _Tile('gen_$i', widget.generated[i].$1, widget.generated[i].$2,
              generated: true, ratio: _ratios[_stableHash(widget.generated[i].$1) % _ratios.length]),
      ];

  /// The catalog's stills, in the source's preferred order (v8.3 PHOTO_SEED).
  List<_Tile> _seed() {
    const prefer = ['twilight', 'sanctuary', 'blade', 'cabin', 'transit', 'alley4', 'alley3', 'ocean', 'garden', 'neoncity', 'observatory', 'rainfall', 'dunehall', 'starbridge', 'twinsuns', 'deck'];
    final themes = WallpaperCatalog.freeThemes;
    final ids = <String>[];
    final seen = <String>{};
    for (final id in prefer) {
      for (final t in themes) {
        if (t.id.toLowerCase().contains(id) && seen.add(t.id)) ids.add(t.id);
      }
    }
    for (final t in themes) {
      if (ids.length >= 22) break;
      if (seen.add(t.id)) ids.add(t.id);
    }
    return [
      for (final id in ids)
        for (final t in themes)
          if (t.id == id) _Tile('photo-${t.id}', t.name, t.stillPath ?? t.assetPath),
    ];
  }

  /// Kind filter, search and view folded together, in reading order.
  List<_Tile> _shortlist() {
    if (_inMine) return _generated;

    final merged = [..._generated, ..._seed()];
    final byKind = switch (_kinds[_kind]) {
      'Templates' => merged.take(10).toList(),
      'Cinematic' => [for (var i = 0; i < merged.length; i++) if (i.isEven) merged[i]],
      'Night' => [for (var i = 0; i < merged.length; i++) if (i % 3 != 1) merged[i]],
      _ => merged,
    };
    if (!_searching) return byKind;

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return byKind;
    return byKind.where((t) => t.title.toLowerCase().contains(q)).toList();
  }

  /// The hero tile, and the shelf under it.
  ({_Tile hero, List<_Tile> shelf}) _featured() {
    final list = _shortlist();
    if (list.isEmpty) return (hero: const _Tile('', '', ''), shelf: const <_Tile>[]);
    final hero = list.first;
    return (hero: hero, shelf: list.skip(1).toList());
  }

  Widget _img(_Tile t, {BoxFit fit = BoxFit.cover}) =>
      t.generated ? GenMediaView(url: t.src, kind: 'image', fit: fit) : ThemeImage(t.src, fit: fit);

  void _remix(_Tile t) {
    setState(() => _open = null);
    widget.onRemix?.call(t.title);
  }

  // --------------------------------------------------------------- window --

  Widget _windowFrame(Widget child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MarketScreen.windowRadius),
          border: Border.all(color: _stroke),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MarketScreen.windowRadius),
          child: ColoredBox(color: _void, child: child),
        ),
      );

  // -------------------------------------------------------------- chrome --

  Widget _icon(IconData icon, String label, VoidCallback? onTap, {double size = 22, Color? color}) => Semantics(
        button: true,
        label: label,
        child: VPress(
          onTap: onTap,
          tooltip: label,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: size, color: color ?? _chalk)),
        ),
      );

  /// The two pill buttons from the source: a filled primary and an outlined
  /// secondary, side by side at the foot of the hero.
  Widget _pill(String label, IconData icon, VoidCallback onTap, {bool filled = true, bool wide = false}) =>
      Semantics(
        button: true,
        label: label,
        child: VPress(
          onTap: onTap,
          child: Container(
            height: 40,
            width: wide ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? _chalk : _chalk.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: filled ? Colors.transparent : _stroke),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: filled ? _void : _chalk),
              const SizedBox(width: 7),
              Text(label, style: _sans(14, FontWeight.w600, filled ? _void : _chalk)),
            ]),
          ),
        ),
      );

  // --------------------------------------------------------- featured view --

  Widget _featuredView(_Tile hero, List<_Tile> shelf) {
    if (hero.id.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      Expanded(child: _hero(hero)),
      _shelf(shelf),
    ]);
  }

  /// Hero: the cover fills it, with the source's scrims, the title, the
  /// subtitle, the two pills, and the chevron at its base.
  Widget _hero(_Tile t) {
    return Stack(fit: StackFit.expand, children: [
      _img(t),
      // gradientCover_left / gradientCover_right, and a bottom wash so the
      // title and pills always sit on something dark enough to read.
      const Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 220,
        child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xB3000000), Color(0x00000000)]))),
      ),
      const Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: 120,
        child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x00000000), Color(0x4D000000)]))),
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 240,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xE6000000), Color(0x73000000), Color(0x00000000)],
            ),
          ),
        ),
      ),
      Padding(
        // Clears the chevron that sits at the hero's base.
        padding: const EdgeInsets.fromLTRB(MarketScreen.contentInset, 0, MarketScreen.contentInset, 46),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 108),
              child: Text(
                t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _sans(32, FontWeight.w800, _chalk, ls: -0.8, h: 1.1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.generated ? 'Your generation' : 'Featured still',
              style: _mono(11, FontWeight.w500, _chalk.withValues(alpha: 0.7), ls: 0.6),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _pill('Open', Icons.play_arrow_rounded, () => setState(() => _open = t), wide: true)),
              const SizedBox(width: 10),
              Expanded(
                child: _pill('Remix', Icons.auto_awesome_rounded, () => _remix(t), filled: false, wide: true),
              ),
            ]),
          ],
        ),
      ),
      // The source's chevron at the foot of the hero: this is where the grid
      // lives.
      Positioned(
        left: 0,
        right: 0,
        bottom: 10,
        child: Center(
          child: Semantics(
            button: true,
            label: 'Browse all',
            child: VPress(
              onTap: () => setState(() => _window = _Window.browse),
              child: Container(
                width: 40,
                height: 28,
                alignment: Alignment.center,
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: _chalk),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  /// The source's section label over a horizontal shelf of covers, the first
  /// one presented larger than the rest.
  Widget _shelf(List<_Tile> shelf) {
    if (shelf.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xF00A0A0A),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: MarketScreen.shelfLabelHeight + 8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(MarketScreen.contentInset, 10, MarketScreen.contentInset, 0),
              child: Row(children: [
                Text(_kinds[_kind], style: _sans(15, FontWeight.w600, _chalk)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text('${shelf.length}', style: _mono(11, FontWeight.w500, _dim, ls: 0.4)),
                ),
              ]),
            ),
          ),
          SizedBox(
            height: MarketScreen.leadCoverHeight + 4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: MarketScreen.contentInset),
              itemCount: shelf.length,
              separatorBuilder: (_, __) => const SizedBox(width: MarketScreen.shelfGap),
              itemBuilder: (_, i) {
                final lead = i == 0;
                return Align(
                  alignment: Alignment.bottomLeft,
                  child: Semantics(
                    button: true,
                    label: shelf[i].title,
                    image: true,
                    excludeSemantics: true,
                    child: VPress(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _open = shelf[i]);
                      },
                      child: Container(
                        width: lead ? MarketScreen.leadCoverWidth : MarketScreen.coverWidth,
                        height: lead ? MarketScreen.leadCoverHeight : MarketScreen.coverHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: lead ? _chalk : _stroke),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(lead ? 9 : 9),
                          child: Stack(fit: StackFit.expand, children: [
                            _img(shelf[i]),
                            if (shelf[i].generated)
                              Positioned(left: 6, bottom: 6, child: CustomPaint(size: const Size(16, 16), painter: _SeedMarkPainter())),
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- browse view --

  Widget _browseView(List<_Tile> tiles) {
    // The header stays even with nothing to show, so the window still says
    // which view you are in and keeps a way back.
    if (tiles.isEmpty) {
      return Column(children: [
        _browseHeader(0),
        Expanded(child: _empty()),
      ]);
    }
    const g = MarketScreen.gridGutter;
    const w = (MarketScreen.windowWidth - 2 * MarketScreen.contentInset - g) / 2;
    final (a, b) = _split(tiles, w);

    Widget col(List<_Tile> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var i = 0; i < list.length; i++) _tile(list[i], w, g, i)],
        );

    return Column(children: [
      _browseHeader(tiles.length),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(MarketScreen.contentInset, 4, MarketScreen.contentInset, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: col(a)),
              const SizedBox(width: g),
              Expanded(child: col(b)),
            ]),
          ],
        ),
      ),
    ]);
  }

  /// A slim bar inside the window: back to the featured view when the rail is
  /// on Discover, otherwise the view's name or the search field.
  Widget _browseHeader(int count) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: MarketScreen.contentInset - 8),
      child: Row(children: [
        if (widget.view == 'discover')
          _icon(Icons.keyboard_arrow_up_rounded, 'Featured', () => setState(() => _window = _Window.featured))
        else
          const SizedBox(width: 40),
        Expanded(
          child: Center(
            child: _searching ? _searchField() : Text(
              _inMine ? 'My generations' : _searching ? 'Search' : 'Browse',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _sans(16, FontWeight.w600, _chalk, ls: -0.2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('$count', style: _mono(11, FontWeight.w500, _dim, ls: 0.4)),
        ),
      ]),
    );
  }

  Widget _searchField() => Container(
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _graphite, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _queryCtrl,
              focusNode: _searchFocus,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              cursorColor: _chalk,
              cursorWidth: 1.4,
              style: _sans(14, FontWeight.w400, _chalk),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search stills',
                hintStyle: _sans(14, FontWeight.w400, _dim),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _queryCtrl.clear();
                setState(() => _query = '');
              },
              child: const Icon(Icons.cancel_rounded, size: 14, color: _dim),
            ),
        ]),
      );

  /// Shortest column first, so the two stay level instead of one running far
  /// past the other.
  (List<_Tile>, List<_Tile>) _split(List<_Tile> tiles, double w) {
    final a = <_Tile>[];
    final b = <_Tile>[];
    var ha = 0.0;
    var hb = 0.0;
    for (final t in tiles) {
      if (ha <= hb) {
        a.add(t);
        ha += t.ratio * w + MarketScreen.gridGutter;
      } else {
        b.add(t);
        hb += t.ratio * w + MarketScreen.gridGutter;
      }
    }
    return (a, b);
  }

  Widget _tile(_Tile t, double w, double gutter, int order) => Semantics(
        button: true,
        label: t.generated ? '${t.title}, generated this session' : t.title,
        image: true,
        excludeSemantics: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: gutter),
          child: SizedBox(
            height: t.ratio * w,
            child: VPress(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _open = t);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(fit: StackFit.expand, children: [
                  _img(t),
                  if (t.generated)
                    Positioned(left: 7, bottom: 7, child: CustomPaint(size: const Size(18, 18), painter: _SeedMarkPainter())),
                ]),
              ),
            ),
          ),
        ),
      );

  /// Empty states sit in the middle of the window, where an invitation to act
/// belongs, rather than stranded at the top.
Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_inMine ? 'Nothing here yet' : 'No matches', style: _sans(17, FontWeight.w600, _chalk)),
            const SizedBox(height: 8),
            Text(
              _inMine ? 'Images you generate this session collect here.' : 'Try a different word, or clear the search.',
              textAlign: TextAlign.center,
              style: _sans(14, FontWeight.w400, _ash, h: 1.35),
            ),
          ]),
        ),
      );

  // ------------------------------------------------------------ ornaments --

  /// The kind capsule, floating below the window as in the source.
  Widget _capsule() => SizedBox(
        height: MarketScreen.capsuleHeight,
        child: Center(
          child: FGlass(
            radius: BorderRadius.circular(999),
            stroke: const Color(0x33FFFFFF),
            padding: const EdgeInsets.all(3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < _kinds.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Semantics(
                    button: true,
                    selected: _kind == i,
                    label: _kinds[i],
                    child: VPress(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _kind = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _kind == i ? const Color(0x2EFFFFFF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(_kinds[i], style: _sans(13, _kind == i ? FontWeight.w600 : FontWeight.w500, _kind == i ? _chalk : _ash)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );

  /// The source's window controls: a dot that closes, a bar you drag down.
  Widget _controls() => SizedBox(
        height: MarketScreen.controlsHeight,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Semantics(
            button: true,
            label: 'Close',
            child: VPress(
              onTap: widget.onClose,
              child: Container(
                width: MarketScreen.controlsHeight,
                height: MarketScreen.controlsHeight,
                alignment: Alignment.center,
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
              ),
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 200) widget.onClose();
            },
            child: Container(
              width: 96,
              height: 4,
              decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ]),
      );

  // ---------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _void,
      child: FigmaViewport(
        width: MarketScreen.frame.width,
        child: Builder(builder: (context) {
          final mq = MediaQuery.of(context);
          final insetTop = mq.padding.top;
          final insetBottom = mq.padding.bottom;
          final found = _featured();
          final list = _shortlist();

          return Stack(children: [
            Positioned.fill(
              child: Column(children: [
                SizedBox(height: insetTop + 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MarketScreen.windowLeft - 4),
                    child: _windowFrame(
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        child: _browsing
                            ? _browseView(list)
                            : _featuredView(found.hero, found.shelf),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MarketScreen.capsuleGap),
                _capsule(),
                const SizedBox(height: MarketScreen.controlsGap),
                _controls(),
                SizedBox(height: MarketScreen.dockReserve + insetBottom),
              ]),
            ),
            if (_open != null) Positioned.fill(child: _exploder(_open!, insetTop, insetBottom)),
          ]);
        }),
      ),
    );
  }

  /// The opened tile: the asset on the void, its origin underneath, and the
  /// one action that matters for it. Opaque, so the window does not ghost
  /// through behind the image.
  Widget _exploder(_Tile t, double insetTop, double insetBottom) {
    return ColoredBox(
      color: _void,
      child: Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: () => setState(() => _open = null), behavior: HitTestBehavior.opaque)),
        Padding(
          padding: EdgeInsets.fromLTRB(MarketScreen.windowLeft, insetTop + 4, MarketScreen.windowRight, MarketScreen.dockReserve + insetBottom),
          child: Column(children: [
            Row(children: [
              const Spacer(),
              if (t.generated) const Padding(padding: EdgeInsets.only(right: 4), child: _SeedLegend()) else const SizedBox.shrink(),
              _icon(Icons.close_rounded, 'Close', () => setState(() => _open = null)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MarketScreen.windowRadius),
                  child: _img(t, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: _sans(17, FontWeight.w600, _chalk, h: 1.25)),
            const SizedBox(height: 6),
            Text(
              t.generated ? 'Generated this session' : 'Catalog still',
              style: _mono(11, FontWeight.w500, _dim, ls: 0.4),
            ),
            const SizedBox(height: 18),
            Semantics(
              button: true,
              label: 'Remix',
              child: VPress(
                onTap: () => _remix(t),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _chalk, borderRadius: BorderRadius.circular(999)),
                  child: Text('Remix in composer', style: _sans(15, FontWeight.w600, _void)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Two hairline strokes: the mark that says this image is yours. Nothing else
/// on this surface wears one.
class _SeedMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _chalk
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 1.0;
    const len = 10.0;
    canvas.drawLine(const Offset(inset, inset + len), const Offset(inset, inset), p);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset + len, inset), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The same bracket, inline, beside a legend. Only shown on your own work.
class _SeedLegend extends StatelessWidget {
  const _SeedLegend();

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(size: const Size(14, 14), painter: _SeedMarkPainter()),
      const SizedBox(width: 5),
      Text('YOURS', style: _mono(10, FontWeight.w500, _dim, ls: 0.6)),
    ]);
  }
}