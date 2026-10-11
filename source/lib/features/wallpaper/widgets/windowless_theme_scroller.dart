import 'dart:ui';

import 'package:flutter/material.dart';
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

  List<WallpaperTheme> get _themes {
    final store = ThemePackStore.instance;
    return [
      ...WallpaperCatalog.freeThemes,
      for (final t in WallpaperCatalog.premiumThemes)
        if (store.storeOpen && store.isUnlocked(t.id)) t,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final winW = (size.width - 32).clamp(240.0, 440.0);
    final winH = (winW * 1.3).clamp(240.0, size.height - pad.top - 84 - 150);
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
                    key: ValueKey('room-${_previewed.id}-$_expanded'),
                    child: _expanded
                        ? GestureDetector(
                            onTap: () => setState(() => _expanded = false),
                            child: ThemePosterImage(theme: _previewed, fit: BoxFit.cover, fullBleed: true),
                          )
                        : ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(Color(0x55000000), BlendMode.darken),
                              child: ThemePosterImage(theme: _previewed, fit: BoxFit.cover, fullBleed: true),
                            ),
                          ),
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
              if (!_expanded)
                Positioned(
                  left: 0,
                  right: 0,
                  top: pad.top,
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
                        SizedBox(
                          width: winW,
                          height: 60,
                          child: EdgeFadeHorizontal(
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
                                      child: ThemePosterImage(theme: t, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                stops: [0, 0.2, 0.6, 1],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Row(
              children: [
                VCircleButton(icon: Icons.chevron_left_rounded, size: 32, floating: true, tooltip: 'Back', onTap: widget.onBack),
                const Spacer(),
                VPress(
                  onTap: widget.onExpand,
                  tooltip: 'Expand View',
                  child: _capsule(Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.open_in_full_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text('Expand View', style: VType.footnote(color: Colors.white, weight: FontWeight.w600)),
                  ])),
                ),
                const Spacer(),
                VCircleButton(icon: Icons.check_rounded, size: 32, floating: true, tooltip: 'Set Wallpaper', onTap: widget.onSet),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 14,
            bottom: ready ? 8 : 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, maxLines: 2, style: VType.title2(color: Colors.white).copyWith(shadows: _WindowlessThemeScrollerState._shadow)),
                if (ready)
                  Row(children: [
                    VPress(
                      onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                      tooltip: c.value.isPlaying ? 'Pause' : 'Play',
                      child: SizedBox(width: 32, height: 40, child: Icon(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 4,
                          activeTrackColor: Colors.white.withValues(alpha: 0.9),
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0, elevation: 0, pressedElevation: 0),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: frac.clamp(0.0, 1.0),
                          onChanged: (v) => setState(() => _scrub = v),
                          onChangeEnd: (v) {
                            c.seekTo(Duration(milliseconds: (dur * v).round()));
                            setState(() => _scrub = null);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ]),
              ],
            ),
          ),
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
