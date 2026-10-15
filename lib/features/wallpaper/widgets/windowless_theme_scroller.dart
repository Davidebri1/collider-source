import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../core/figma/figma_stage.dart';
import 'package:video_player/video_player.dart';
import '../../../models/theme_def.dart';
import '../../../core/vision/vision_kit.dart';
import '../../theme/theme_living_media.dart';
import '../../theme/theme_pack_store.dart';

/// REQ-06 Theme Gallery (map row 6, Vision Pro Spatial UI Kit 69-1926): the
/// previewed wallpaper in a rounded window over the live room, a
/// thumbnail strip under it whose selected frame widens.
/// v8.3 (D53): the window's top row is Figma's: back (close, nothing
/// changed) on the left, Expand View in the middle (the wallpaper full
/// screen; tap to come back) and, where Figma has ⋯, Set Wallpaper (a check).
/// Bottom: the name; a live wallpaper also gets Figma's playback bar (play /
/// pause and scrub; no volume, the loops are silent). Figma's date line is
/// left out. The gallery holds the free themes and the live ones you own;
/// swipe up for the Premium market.
class WindowlessThemeScroller extends StatefulWidget {
  final WallpaperTheme currentTheme;
  final ValueChanged<WallpaperTheme> onLivePreview;
  final ValueChanged<WallpaperTheme> onConfirmTheme;
  final VoidCallback onCancel;
  final VoidCallback onUpgradeTier;

  const WindowlessThemeScroller({
    super.key,
    required this.currentTheme,
    required this.onLivePreview,
    required this.onConfirmTheme,
    required this.onCancel,
    required this.onUpgradeTier,
  });

  @override
  State<WindowlessThemeScroller> createState() => _WindowlessThemeScrollerState();
}

/// Which shelf the gallery is showing. Free themes apply directly; premium
/// packs only appear here once the store says they are yours.
enum ThemeShelf { free, premium }

class _WindowlessThemeScrollerState extends State<WindowlessThemeScroller> {
  late WallpaperTheme _previewed;
  bool _expanded = false;
  ThemeShelf _shelf = ThemeShelf.free;

  @override
  void initState() {
    super.initState();
    _previewed = widget.currentTheme;
    // Open on the shelf that actually holds the current wallpaper, so the
    // strip never starts on an empty list.
    _shelf = _premiumShelf.any((x) => x.id == widget.currentTheme.id)
        ? ThemeShelf.premium
        : ThemeShelf.free;
    ThemePackStore.instance.init();
  }

  List<WallpaperTheme> get _freeShelf => WallpaperCatalog.freeThemes;

  /// Every premium pack is browsable here. Ownership is the market's call,
  /// not the gallery's: hiding the packs until the store is open left this
  /// shelf empty and the strip with nothing to show.
  List<WallpaperTheme> get _premiumShelf => WallpaperCatalog.premiumThemes;

  /// Browsing never touches the applied wallpaper. The preview moves inside
  /// the gallery; the room behind it and the app's own background stay on the
  /// wallpaper that is actually set until Set Wallpaper is pressed.
  void _select(WallpaperTheme t) {
    if (t.id == _previewed.id) return;
    setState(() => _previewed = t);
  }

  void _setShelf(ThemeShelf s) {
    if (_shelf == s) return;
    final list = s == ThemeShelf.free ? _freeShelf : _premiumShelf;
    setState(() {
      _shelf = s;
      // Keep the selection inside the shelf the user just switched to.
      if (!list.any((x) => x.id == _previewed.id)) {
        if (list.isNotEmpty) _previewed = list.first;
      }
    });
  }

  List<WallpaperTheme> get _themes => _shelf == ThemeShelf.free ? _freeShelf : _premiumShelf;

  /// 2670_group: the selected theme 86 x 86 at x 921.6, five 50 x 86
  /// neighbours each side 60 apart (614.6 .. 904.6 / 1024.6 .. 1314.6),
  /// fading toward the ends.
  List<Widget> _strip(List<WallpaperTheme> themes) {
    if (themes.isEmpty) return const [];
    // A preview that is not on this shelf (the shelf just switched, or the
    // catalog changed under us) must still draw a strip: fall back to the
    // head of the list instead of rendering nothing at all.
    var sel = themes.indexWhere((t) => t.id == _previewed.id);
    if (sel < 0) sel = 0;
    final out = <Widget>[];
    for (var k = -5; k <= 5; k++) {
      final i = sel + k;
      if (i < 0 || i >= themes.length) continue;
      final t = themes[i];
      final left = k == 0 ? 921.6 : (k < 0 ? 904.6 - 50 - (-k - 1) * 60 : 1024.6 + (k - 1) * 60);
      final w = k == 0 ? 86.0 : 50.0;
      // Blur is applied in Figma px, then the whole stage scales down to the
      // phone (~0.4). Sigmas are sized so the outer tiles stay visibly soft
      // after that scale, and the fade never drops them out of view.
      final fade = k.abs() <= 2 ? 1.0 : (k.abs() == 3 ? 0.82 : (k.abs() == 4 ? 0.58 : 0.36));
      final blur = k.abs() >= 5 ? 22.0 : (k.abs() == 4 ? 12.0 : (k.abs() == 3 ? 5.0 : 0.0));
      Widget tile = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x33FFFFFF)),
            ThemePosterImage(theme: t, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
          ],
        ),
      );
      if (blur > 0) {
        tile = ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: tile);
      }
      out.add(Positioned(
        left: left,
        top: 845,
        width: w,
        height: 86,
        child: Semantics(
          button: true,
          selected: k == 0,
          label: t.name,
          child: GestureDetector(
            onTap: () => _select(t),
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() < 100) return;
              final j = (sel + (v < 0 ? 1 : -1)).clamp(0, themes.length - 1);
              _select(themes[j]);
            },
            child: Opacity(opacity: fade, child: tile),
          ),
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return ListenableBuilder(
      listenable: ThemePackStore.instance,
      builder: (context, _) {
        final themes = _themes;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -300) widget.onUpgradeTier();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The room stays the live wallpaper (R32: browsing does not blur it).
              // Expand still fills the screen with the preview. Looking around
              // must not repaint the applied wallpaper.
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: VMotion.base,
                  child: KeyedSubtree(
                    key: ValueKey('room-${widget.currentTheme.id}-$_expanded'),
                    child: _expanded
                        ? GestureDetector(
                            onTap: () => setState(() => _expanded = false),
                            child: ThemePosterImage(theme: widget.currentTheme, fit: BoxFit.cover, fullBleed: true),
                          )
                        : const SizedBox.expand(),
                  ),
                ),
              ),
              if (_expanded && _previewed.isLive)
                Positioned.fill(child: IgnorePointer(child: _LoopVideo(key: ValueKey('full-${_previewed.id}'), url: _previewed.videoUrl!))),
              if (_expanded)
                Positioned(
                  left: VSpace.md,
                  top: pad.top + VSpace.sm,
                  child: VCircleButton(icon: Icons.fullscreen_exit_rounded, floating: true, tooltip: 'Back', onTap: () => setState(() => _expanded = false)),
                ),
              // v8.4: Photos - Memories 69:1926 (1920 x 1080) at its own
              // geometry, scaled as one unit: window 725 x 730 at (597.5, 95),
              // thumbnail strip at y 845, window controls at (855.6, 971);
              // crop = the window's own width (725), centred, no margin.
              if (!_expanded)
                Positioned.fill(
                  child: FigmaStage(
                    frame: const Size(1920, 1080),
                    cropWidth: 725,
                    center: const Offset(960, 540),
                    // Everything this screen owns: shelf switch (x 358) through the
                    // rightmost strip tile (x 1314.6) and down to the window
                    // controls (y 991), so any aspect ratio scales the whole
                    // gallery down instead of cropping one edge off it.
                    contentSize: const Size(957, 896),
                    contentCenter: const Offset(836, 543),
                    children: [
                      Positioned(
                        left: 597.5,
                        top: 95,
                        width: 725,
                        height: 730,
                        child: _PreviewWindow(
                          key: ValueKey('win-${_previewed.id}'),
                          theme: _previewed,
                          onBack: widget.onCancel,
                          onExpand: () => setState(() => _expanded = true),
                          onSet: () => widget.onConfirmTheme(_previewed),
                        ),
                      ),
                      Positioned(
                        left: 392,
                        top: 862,
                        width: 210,
                        height: 52,
                        child: _ShelfPill(shelf: _shelf, onChanged: _setShelf),
                      ),
                      ..._strip(themes),
                      // Window controls: dot = close, bar = swipe down to close.
                      Positioned(
                        left: 855.6,
                        top: 966,
                        width: 181,
                        height: 24,
                        child: Row(children: [
                          Semantics(
                            button: true,
                            label: 'Close',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onCancel,
                              child: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.centerLeft,
                                child: Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onVerticalDragEnd: (d) {
                              if ((d.primaryVelocity ?? 0) > 200) widget.onCancel();
                            },
                            child: Container(width: 143, height: 12, decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(6))),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One embedded glass pill, in line with the carousel: Free / Premium.
class _ShelfPill extends StatelessWidget {
  final ThemeShelf shelf;
  final ValueChanged<ThemeShelf> onChanged;
  const _ShelfPill({required this.shelf, required this.onChanged});

  Widget _half(ThemeShelf s, String label) {
    final on = shelf == s;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(s),
          child: AnimatedContainer(
            duration: VMotion.base,
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? const Color(0xF2F7F4EF) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(22),
            ),
            child: FText(label, size: 15, height: 20, weight: FontWeight.w600, letterSpacing: -0.4, color: on ? const Color(0xFF1C1B19) : Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x4D808080),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x99FFFFFF), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(children: [
              _half(ThemeShelf.free, 'Free'),
              _half(ThemeShelf.premium, 'Premium'),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The rounded preview window: wallpaper, top controls, name and, for a
/// live wallpaper, the playback bar.
class _PreviewWindow extends StatefulWidget {
  final WallpaperTheme theme;
  final VoidCallback onBack;
  final VoidCallback onExpand;
  final VoidCallback onSet;
  const _PreviewWindow({super.key, required this.theme, required this.onBack, required this.onExpand, required this.onSet});

  @override
  State<_PreviewWindow> createState() => _PreviewWindowState();
}

class _PreviewWindowState extends State<_PreviewWindow> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    final url = widget.theme.videoUrl;
    if (widget.theme.isLive && url != null) {
      final c = VideoPlayerController.networkUrl(Uri.parse(url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _c = c;
      c.setLooping(true);
      c.setVolume(0);
      c.addListener(_tick);
      c.initialize().then((_) {
        if (!mounted) return;
        c.play();
        setState(() {});
      }).catchError((_) {});
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  Widget _capsule(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: const Color(0x66808080), borderRadius: BorderRadius.circular(VRadius.full)),
            child: child,
          ),
        ),
      );

  Widget _circle(IconData icon, String label, VoidCallback onTap, {double iconSize = 24}) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x4D808080),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: Colors.white),
          ),
        ),
      );

  // Window 725 x 730 (radius 46); header (27.1, 29.5): back 50 / Expand View
  // 180 x 46 at x 275.1 / right 50 at x 653.1; title (45.1, 594) + date line
  // at +33; player at (45.1, 673): play 21 x 22, bar at +60 (524), volume.
  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return ClipRRect(
      borderRadius: BorderRadius.circular(46),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ThemePosterImage(theme: t, fit: BoxFit.cover, fullBleed: true),
          if (ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)),
            ),
          Positioned(left: 27.1, top: 29.5, child: _circle(Icons.chevron_left_rounded, 'Back', widget.onBack, iconSize: 28)),
          Positioned(
            left: 275.1,
            top: 31.5,
            width: 180,
            height: 46,
            child: Semantics(
              button: true,
              label: 'Expand View',
              child: GestureDetector(
                onTap: widget.onExpand,
                child: Container(
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: const Color(0x4D808080),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(children: const [
                    SizedBox(width: 12),
                    Icon(Icons.open_in_full_rounded, size: 20, color: Colors.white),
                    SizedBox(width: 12),
                    FText('Expand View', size: 16, height: 20, weight: FontWeight.w600),
                  ]),
                ),
              ),
            ),
          ),
          Positioned(left: 653.1, top: 29.5, child: _circle(Icons.check_rounded, 'Set Wallpaper', widget.onSet)),
        ],
      ),
    );
  }
}

/// A silent looping wallpaper (Expand View of a live theme).
class _LoopVideo extends StatefulWidget {
  final String url;
  const _LoopVideo({super.key, required this.url});
  @override
  State<_LoopVideo> createState() => _LoopVideoState();
}

class _LoopVideoState extends State<_LoopVideo> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));

  @override
  void initState() {
    super.initState();
    _c.setLooping(true);
    _c.setVolume(0);
    _c.initialize().then((_) {
      if (!mounted) return;
      _c.play();
      setState(() {});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.value.isInitialized) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(width: _c.value.size.width, height: _c.value.size.height, child: VideoPlayer(_c)),
    );
  }
}

/// Horizontal edge fade for thumbnail strips.
class EdgeFadeHorizontal extends StatelessWidget {
  final Widget child;
  const EdgeFadeHorizontal({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) {
        final f = (16 / (r.width <= 0 ? 1 : r.width)).clamp(0.0, 0.3);
        return LinearGradient(
          colors: const [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
          stops: [0, f, 1 - f, 1],
        ).createShader(r);
      },
      child: child,
    );
  }
}
