import 'dart:math' as math;
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
///
/// The preview window carries two controls and nothing else: Back, and Set
/// Wallpaper. Bug 2 (owner, repeated): every overlay is off the theme asset —
/// no dimming scrim over the artwork, no playback or scrub bar, no centred
/// title watermark, no expand / fullscreen affordance. The artwork shows
/// itself (R32, R36); the name and transport lived in Figma on chrome that
/// this app does not draw.
/// The gallery holds the free themes and the live ones you own; swipe up for
/// the Premium market.
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

  String _category = 'All';
  List<String> get _categories => [
        'All',
        // v9.1: the ghost menu filters by tag (most used first).
        ...(() {
          final n = <String, int>{};
          for (final t in WallpaperCatalog.freeThemes) {
            for (final g in t.tags) {
              n[g] = (n[g] ?? 0) + 1;
            }
          }
          return n.keys.toList()..sort((a, b) => n[b]!.compareTo(n[a]!));
        })(),
      ];

  List<WallpaperTheme> get _themes {
    final store = ThemePackStore.instance;
    final all = <WallpaperTheme>[
      ...WallpaperCatalog.freeThemes,
      for (final t in WallpaperCatalog.premiumThemes)
        if (store.storeOpen && store.isUnlocked(t.id)) t,
    ];
    return _category == 'All' ? all : all.where((t) => t.tags.contains(_category)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    // Figma reference proportions: a 317 x 470 window inside a 393 x 852
    // frame, i.e. ~80.7% of the width at a 1.48 aspect. The window used to
    // take width - 32, which is 92.5% of a 430pt phone â€” effectively
    // full-bleed, and it read as a fullscreen app rather than a floating
    // window. Nothing in this app is allowed to touch the edges.
    final winW = (size.width * 0.807 - 112).clamp(200.0, 380.0); // v9.1: ghost menu column on the left
    final winH = (winW * 1.4827).clamp(240.0, size.height - pad.top - 84 - 150);
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
              // There is no expanded full-screen state: nothing in this app is
              // allowed to go edge to edge, so the blurred room is always the
              // backdrop and the window always floats over it.
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0x55000000), BlendMode.darken),
                    // v8.3.1: the room stays the current wallpaper while browsing.
                    child: ThemePosterImage(theme: widget.currentTheme, fit: BoxFit.cover, fullBleed: true),
                  ),
                ),
              ),
              // v8.7 floating ghost category menu.
                Positioned(
                  left: 4,
                  top: pad.top + 120,
                  child: Builder(builder: (_) {
                    final cats = _categories;
                    return GhostMenu(
                      width: 104,
                      visible: 5,
                      items: cats,
                      selected: math.max(0, cats.indexOf(_category)),
                      onSelected: (i) => setState(() => _category = cats[i]),
                    );
                  }),
                ),
              Positioned(
                  left: 112,
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
                                      child: ThemePosterImage(theme: t, fit: BoxFit.cover),
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
  final VoidCallback onSet;
  const _PreviewWindow({super.key, required this.theme, required this.onBack, required this.onSet});

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
      c.initialize().then((_) {
        if (!mounted) return;
        c.play();
        setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    // The artwork is the asset and nothing else (bug 2, R32 / R36): no
    // gradient scrim over the poster, no playback or scrub bar, no expand
    // affordance, no centred title watermark. The only thing drawn on top of
    // it is the one control that belongs there, Set Wallpaper.
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
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Row(
              children: [
                VCircleButton(icon: Icons.chevron_left_rounded, size: 32, floating: true, tooltip: 'Back', onTap: widget.onBack),
                const Spacer(),
                // Expand View is gone: it opened a full-bleed preview, and
                // nothing in this app goes edge to edge. The two window exits
                // are Back and Set Wallpaper (R37).
                // v9.1 (David): an obvious, labelled Set control.
                Semantics(
                  button: true,
                  label: 'Set as wallpaper',
                  child: GestureDetector(
                    onTap: widget.onSet,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(17)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.wallpaper_rounded, size: 17, color: Color(0xFF111111)),
                        SizedBox(width: 6),
                        Text('Set', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111111))),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A silent looping wallpaper, played inside the floating preview window.
class _LoopVideo extends StatefulWidget {
  final String url;
  const _LoopVideo({required this.url});
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
