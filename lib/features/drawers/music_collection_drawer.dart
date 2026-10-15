import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';
import '../../core/audio/music_player.dart';
import '../music/song_row_parts.dart';
import '../theme/theme_living_media.dart';

/// Music drawer (v8.3, DEVIATIONS.md D40): ported from the Figma music app
/// (file YEuK4CL2uyECUhvGEcgCNS) instead of an own design:
///   panel     417:6037 "Your Library": radius 10, black 30 % over white 10 %,
///             specular inset; header icon 28 + title 20 Bold; "Liked Songs"
///             row -> Play all; song rows with each row's play / pause (D37)
///   transport 417:6218 "Mini_player": art, title / subtitle, shuffle,
///             previous, white play circle, next, repeat
/// Scaled by 398 / 524 (Figma panel width -> phone). The whole catalog
/// library: theme songs (grouped by theme) and ambient tracks.
class MusicCollectionDrawer extends StatelessWidget {
  final VoidCallback onClose;
  const MusicCollectionDrawer({super.key, required this.onClose});

  static const double s = LibrarySongRow.scale;

  @override
  Widget build(BuildContext context) {
    final p = MusicPlayer.instance;
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final width = (size.width - 96).clamp(280.0, 460.0); // a pane, not full width
    return Stack(
      fit: StackFit.expand,
      children: [
        // v9.1.6: the shared depth scrim behind already blurs; tap-out only.
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
        Positioned(
          left: (size.width - width) / 2,
          width: width,
          top: pad.top + VSpace.xl,
          bottom: pad.bottom + 84,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x2618181E), // lighter than workTint: the ticker reads through
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedBuilder(animation: p, builder: (context, _) => _body(p)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(MusicPlayer p) {
    final lib = MusicPlayer.library;
    final cur = p.current;
    final libActive = p.queueId == 'library' && p.index != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header (417:6045): library icon 28, gap 16, title 20 Bold; close
        // where Figma has its + / -> icons.
        Padding(
          padding: const EdgeInsets.fromLTRB(31 * s, 13 * s, 8, 8 * s),
          child: Row(
            children: [
              const Icon(Icons.library_music_rounded, size: 28 * s, color: Colors.white),
              const SizedBox(width: 16 * s),
              Expanded(child: Text('Music', style: VType.headline().copyWith(fontSize: 20 * s))),
              SongPlayButton(playing: false, icon: Icons.close_rounded, tooltip: 'Close', onTap: onClose),
            ],
          ),
        ),
        Expanded(
          // Opened only when the catalog has songs (v8.3, D46).
          // v9.1: cinematic edges (rows fade out top and bottom), no scrollbar.
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (b) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], stops: [0, 0.08, 0.88, 1]).createShader(b),
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(17 * s, 0, 4, 8),
                  children: [
                    LibrarySongRow(
                      art: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFC900DB), Color(0xFF02738C)],
                          ),
                        ),
                        child: Icon(libActive && p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                      ),
                      title: 'Play all',
                      playing: libActive && p.playing,
                      tooltip: libActive && p.playing ? 'Pause' : 'Play all',
                      onPlay: () => libActive ? p.toggle() : p.playQueue(lib, 0, id: 'library'),
                    ),
                    for (var i = 0; i < lib.length; i++)
                      LibrarySongRow(
                        art: ThemeImage(lib[i].art, fit: BoxFit.cover),
                        title: lib[i].title,
                        // v9.1: hide raw file ids (hex hashes) as subtitles.
                        subtitle: RegExp(r'^[0-9a-f]{6,}\b', caseSensitive: false).hasMatch(lib[i].subtitle ?? '') ? null : lib[i].subtitle,
                        current: cur != null && cur.key == lib[i].key && cur.themeId == lib[i].themeId,
                        playing: libActive && p.index == i && p.playing,
                        onPlay: lib[i].playable
                            ? () => libActive && p.index == i ? p.toggle() : p.playQueue(lib, i, id: 'library')
                            : null,
                      ),
                  ],
                ))),
        ),
        if (cur != null) _miniPlayer(p, cur),
      ],
    );
  }

  // 417:6218 Mini_player: art 48, title 14 / subtitle 11, shuffle, previous,
  // play in a white 52 px circle, next, repeat (volume and the progress bar
  // need what the engine does not report, so they are not ported).
  Widget _miniPlayer(MusicPlayer p, MusicTrack t) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1C),
          border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xs, VSpace.xs, VSpace.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(3), child: ThemeImage(t.art, width: 40, height: 40, fit: BoxFit.cover)),
                const SizedBox(width: VSpace.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 18, child: FadeTitle(t.title, style: VType.callout(weight: FontWeight.w600))),
                      SizedBox(height: 16, child: FadeTitle(t.subtitle, style: VType.caption(color: const Color(0xFFBDBDBD)))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSpace.xxs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _icon(Icons.shuffle_rounded, p.shuffle ? const Color(0xFF1ED760) : Colors.white, p.shuffle ? 'Shuffle on' : 'Shuffle off', p.toggleShuffle),
                _icon(Icons.skip_previous_rounded, Colors.white, 'Previous', p.previous),
                Semantics(
                  button: true,
                  label: p.playing ? 'Pause' : 'Play',
                  child: VPress(
                    onTap: p.toggle,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: Colors.black),
                    ),
                  ),
                ),
                _icon(Icons.skip_next_rounded, Colors.white, 'Next', p.next),
                _icon(
                  p.repeat == MusicRepeat.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  p.repeat != MusicRepeat.off ? const Color(0xFF1ED760) : Colors.white,
                  switch (p.repeat) {
                    MusicRepeat.off => 'Repeat off',
                    MusicRepeat.all => 'Repeat all',
                    MusicRepeat.one => 'Repeat one',
                  },
                  p.cycleRepeat,
                ),
              ],
            ),
          ],
        ),
      );

  Widget _icon(IconData i, Color c, String tip, VoidCallback onTap) => Semantics(
        button: true,
        label: tip,
        child: VPress(
          onTap: onTap,
          tooltip: tip,
          child: SizedBox(width: 44, height: 44, child: Icon(i, size: 26, color: c)),
        ),
      );
}
