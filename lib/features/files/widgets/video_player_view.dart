import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/files/file_store.dart';
import '../../../core/vision/vision_kit.dart';
import 'video_source.dart';

/// Video playback (map row 19, Figma YEuK4CL2uyECUhvGEcgCNS 417-8630): the
/// video in a rounded window over the dimmed room; a back circle top left
/// (closes), a volume capsule top right, and a playback capsule across the
/// window's bottom edge: back 10 s, play / pause, forward 10 s, scrub, time.
/// Figma's ⋯ button is the time readout here (no menu actions to offer; D55).
class VideoPlayerView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;
  const VideoPlayerView({super.key, required this.file, required this.bytes});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoSource? _src;
  bool _failed = false;
  double? _scrub; // 0..1 while dragging

  VideoPlayerController? get _c => _src?.controller;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final s = await VideoSource.open(widget.file.name, widget.bytes, FileStore.mimeFor(widget.file.name));
    if (!mounted) {
      await s?.release();
      return;
    }
    if (s == null) {
      setState(() => _failed = true);
      return;
    }
    _src = s;
    s.controller.addListener(_tick);
    try {
      await s.controller.initialize();
      if (!mounted) return;
      await s.controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() {});
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _src?.controller.removeListener(_tick);
    unawaited(_src?.release());
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _skip(int s) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    var t = c.value.position + Duration(seconds: s);
    if (t < Duration.zero) t = Duration.zero;
    if (t > c.value.duration) t = c.value.duration;
    c.seekTo(t);
  }

  static String _fmt(Duration d) {
    final s = d.inSeconds;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = s % 60;
    final two = ss.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$two' : '$m:$two';
  }

  Widget _capsule({required Widget child, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12)}) => ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.full),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0x8C5E5E5E),
              borderRadius: BorderRadius.circular(VRadius.full),
              border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
            ),
            child: child,
          ),
        ),
      );

  Widget _icon(IconData i, String tip, VoidCallback onTap, {double size = 22}) => VPress(
        onTap: onTap,
        tooltip: tip,
        child: SizedBox(width: 40, height: 44, child: Icon(i, size: size, color: Colors.white)),
      );

  Widget _track(double v, ValueChanged<double>? onChanged, {ValueChanged<double>? onEnd}) => SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          // Player's own progress bar (PRD): visible scrub track; no other bars on this view.
          activeTrackColor: Colors.white,
          inactiveTrackColor: const Color(0x55FFFFFF),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 0, pressedElevation: 0),
          overlayShape: SliderComponentShape.noOverlay,
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(value: v.clamp(0.0, 1.0), onChanged: onChanged, onChangeEnd: onEnd),
      );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final dur = ready ? c.value.duration : Duration.zero;
    final pos = ready ? c.value.position : Duration.zero;
    final frac = _scrub ?? (dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0);
    final shown = _scrub != null ? Duration(milliseconds: (dur.inMilliseconds * _scrub!).round()) : pos;
    final aspect = ready && c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    final close = VCircleButton(icon: Icons.close_rounded, size: 32, floating: true, tooltip: 'Close', onTap: () => Navigator.of(context).pop());

    final Widget picture = _failed
        ? const Center(child: Icon(Icons.videocam_off_outlined, size: 40, color: VColors.textTertiary))
        : ready
            ? GestureDetector(onTap: _toggle, child: VideoPlayer(c))
            : const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70)));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _toggle,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _skip(-10),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _skip(10),
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 2 * VSpace.md).clamp(200.0, 1100.0);
            var vw = w, vh = w / aspect;
            final maxH = box.maxHeight - 200;
            if (vh > maxH) {
              vh = maxH;
              vw = vh * aspect;
            }
            // David: nothing sits on top of a video. Picture first; title,
            // volume and transport live below it.
            return Center(
              child: SizedBox(
                width: vw,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    height: vh,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(VRadius.xl),
                      child: ColoredBox(color: Colors.black, child: picture),
                    ),
                  ),
                  const SizedBox(height: VSpace.sm),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.file.name, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(FileStore.ago(widget.file.addedAt), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
                    if (ready) _icon(c.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, 'Mute', () => c.setVolume(c.value.volume == 0 ? 1 : 0), size: 20),
                  ]),
                  const SizedBox(height: VSpace.sm),
                  SizedBox(
                    height: 44,
                    child: VOrnament(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(children: [
                        _icon(Icons.replay_10_rounded, 'Back 10 seconds', () => _skip(-10), size: 20),
                        _icon(ready && c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, ready && c.value.isPlaying ? 'Pause' : 'Play', _toggle, size: 24),
                        _icon(Icons.forward_10_rounded, 'Forward 10 seconds', () => _skip(10), size: 20),
                        Expanded(
                          child: _track(
                            frac,
                            ready ? (v) => setState(() => _scrub = v) : null,
                            onEnd: (v) {
                              if (ready) c.seekTo(Duration(milliseconds: (dur.inMilliseconds * v).round()));
                              setState(() => _scrub = null);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_fmt(shown), style: VType.caption(color: Colors.white).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}
