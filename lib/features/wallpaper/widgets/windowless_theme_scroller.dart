import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../core/vision/category_nav.dart';
import 'package:video_player/video_player.dart';
import '../../../models/theme_def.dart';
import '../../../core/vision/vision_kit.dart';
import '../../theme/theme_living_media.dart';
import '../../theme/theme_pack_store.dart';

/// REQ-06 Theme Gallery (map row 6, Vision Pro Spatial UI Kit 69-1926): the
/// previewed wallpaper in a rounded window over the blurred room, a
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

class _WindowlessThemeScrollerState extends State<WindowlessThemeScroller> {
  late WallpaperTheme _previewed;
  bool _expanded = false;

  static const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 16)];

  @override
  void initState() {
    super.initState();
    _previewed = widget.currentTheme;
    ThemePackStore.instance.init();
  }

  void _select(WallpaperTheme t) {
    setState(() => _previewed = t);
    widget.onLivePreview(t);
  }

  @override
  void didUpdateWidget(covariant WindowlessThemeScroller old) {
    super.didUpdateWidget(old);
    // The theme list arrives after start-up: follow the real current theme.
    if (old.currentTheme.id != widget.currentTheme.id && _previewed.id == old.currentTheme.id) {
      _previewed = widget.currentTheme;
    }
  }

  String _category = '';
  bool _navOpen = false;
  List<WallpaperTheme> get _themes {
    final store = ThemePackStore.instance;
    final all = <WallpaperTheme>[
      ...WallpaperCatalog.freeThemes,
      for (final t in WallpaperCatalog.premiumThemes)
        if (store.isUnlocked(t.id)) t,
    ];
    return all.where((t) => CategoryTaxonomy.matches(_category, t.tags)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    // David: previews are phone-shaped (device portrait aspect), centred;
    // narrowed to fit rather than shifted.
    final aspect = (size.height / size.width).clamp(1.78, 2.17);
    final maxH = (size.height - pad.top - 84 - 112 - 90 - 52).clamp(240.0, 900.0);
    final winW = math.min((size.width - 120).clamp(160.0, 440.0), maxH / aspect);
    final winH = winW * aspect;
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
              // The room, blurred (Figma: the environment behind the window).
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: VMotion.base,
                  child: KeyedSubtree(
                    key: ValueKey('room-${_expanded ? _previewed.id : widget.currentTheme.id}-$_expanded'),
                    child: _expanded
                        ? GestureDetector(
                            onTap: () => setState(() => _expanded = false),
                            child: ThemePosterImage(theme: _previewed, fit: BoxFit.cover, fullBleed: true),
                          )
                        // David: no blur, dim or change to the wallpaper until one is set;
                        // the real wallpaper behind shows through untouched.
                        : const SizedBox.expand(),
                  ),
                ),
              ),
              if (_expanded && _previewed.isLive)
                Positioned.fill(child: IgnorePointer(child: _LoopVideo(key: ValueKey('full-${_previewed.id}'), url: _previewed.videoUrl!))),
              if (!_expanded)
                Positioned(
                  left: 0,
                  right: 0,
                  top: pad.top + 112,
                  bottom: 84,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: winW,
                          height: winH,
                          child: _PreviewWindow(
                            key: ValueKey('win-${_previewed.id}'),
                            theme: _previewed,
                            onBack: widget.onCancel,
                            onExpand: () => setState(() => _expanded = true),
                            onSet: () => widget.onConfirmTheme(_previewed),
                          ),
                        ),
                        const SizedBox(height: VSpace.sm),
                        // One control below the image: the name and Set.
                        SizedBox(
                          width: winW,
                          child: Row(children: [
                            Expanded(child: Text(_previewed.name, maxLines: 2, softWrap: true, style: VType.headline(color: Colors.white))), // never truncated
                            VPress(
                              key: const ValueKey('gallery-set'),
                              onTap: () => widget.onConfirmTheme(_previewed),
                              tooltip: 'Set wallpaper',
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                                child: Text('Set wallpaper', style: VType.footnote(color: Colors.black, weight: FontWeight.w600)),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: VSpace.sm),
                        SizedBox(
                          width: winW,
                          height: 60,
                          child: ClipRect( // David: no carousel edge blur
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: themes.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 4),
                              itemBuilder: (_, i) {
                                final t = themes[i];
                                final sel = t.id == _previewed.id;
                                return VPress(
                                  onTap: () => _select(t),
                                  tooltip: t.name,
                                  child: AnimatedContainer(
                                    duration: VMotion.base,
                                    curve: Curves.easeOutCubic,
                                    width: sel ? 60 : 36,
                                    margin: EdgeInsets.symmetric(vertical: sel ? 0 : 6, horizontal: sel ? 4 : 0),
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: VShadow.medium),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                                      child: Stack(fit: StackFit.expand, children: [
                                        ThemePosterImage(theme: t, fit: BoxFit.cover, filterQuality: FilterQuality.high),
                                      ]),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // v9.1.6c: catalog selector (Free/Premium switch) centred at the
              // top; the category nav is a bar pinned under it, always visible.
              if (!_expanded)
                Positioned(
                  left: 0, right: 0,
                  top: pad.top + 10,
                  child: Center(child: TierSwitchPill(label: 'Free', onSwitch: widget.onUpgradeTier)),
                ),
              if (!_expanded)
                Positioned(
                  left: 12, right: 12,
                  top: pad.top + 62,
                  child: Builder(builder: (_) {
                    final store = ThemePackStore.instance;
                    final pool = [
                      ...WallpaperCatalog.freeThemes,
                      for (final t in WallpaperCatalog.premiumThemes)
                        if (store.isUnlocked(t.id)) t,
                    ];
                    return CategoryBar(
                      groups: CategoryTaxonomy.build([for (final t in pool) t.tags]),
                      total: pool.length,
                      selected: _category,
                      onSelected: (k) => setState(() => _category = k),
                    );
                  }),
                ),
            ],
          ),
        );
      },
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
  double? _scrub;

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

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final dur = ready ? c.value.duration.inMilliseconds : 0;
    final frac = _scrub ?? (dur > 0 ? c!.value.position.inMilliseconds / dur : 0.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(VRadius.xl),
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
          // David (repeatedly): nothing sits on top of a theme image or video.
          // The back / Expand View / Set / title / scrubber overlays came back
          // from the v9-final import and the v8.7 restore (50a61a7); they are
          // gone here and media_check.py fails if any widget overlaps the image.
          // Tap the image to view it full screen; Set lives below.
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onExpand)),
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


/// Floating 'Browse' button (opens the category overlay).
class TierlessBrowseButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const TierlessBrowseButton({super.key, required this.label, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: on ? const Color(0x55FFFFFF) : const Color(0xB318181E),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.view_sidebar_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 90), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
              ]),
            ),
          ),
        ),
      );
}
