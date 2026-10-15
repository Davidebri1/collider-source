// In-app audio player: real just_audio playback of the stored bytes, with the
// file's own cover art (or its real waveform) as the hero, plus transport,
// scrubbing and volume.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/audio_art.dart';
import '../../../core/files/file_store.dart';
import '../../../core/files/thumb_codec.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/cpane.dart';
import 'audio_source.dart';
import 'thumb_view.dart';

class AudioPlayerView extends StatefulWidget {
  final StoredFile file;
  final Uint8List bytes;

  const AudioPlayerView({super.key, required this.file, required this.bytes});

  @override
  State<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends State<AudioPlayerView> {
  AudioSource? _src;
  Uint8List? _art;
  Float32List? _peaks;
  bool _failed = false;
  double _volume = 1;
  Duration _pos = Duration.zero;
  Duration _total = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _src?.release();
    super.dispose();
  }

  Future<void> _open() async {
    // Cover art first: it is cheap and it is the hero.
    final art = coverArt(widget.bytes, ext: FileStore.extOf(widget.file.name));
    if (art != null && mounted) setState(() => _art = art);
    // No art: fall back to the real waveform rather than a blank panel.
    if (art == null) {
      final wave = await decodedWaveform(widget.bytes, ext: FileStore.extOf(widget.file.name));
      if (wave != null && mounted) setState(() => _peaks = wave.samples);
    }

    final src = await AudioSource.open(widget.file.name, widget.bytes, FileStore.mimeFor(widget.file.name));
    if (!mounted) {
      src?.release();
      return;
    }
    if (src == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() {
      _src = src;
      _total = src.player.duration ?? Duration.zero;
      src.player.positionStream.listen((p) {
        if (mounted) setState(() => _pos = p);
      });
      src.player.playerStateStream.listen((s) {
        if (mounted) setState(() => _playing = s.playing);
      });
    });
    src.player.setVolume(_volume);
  }

  String _time(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final close = VCircleButton(
      icon: Icons.close_rounded,
      tooltip: 'Close',
      floating: true,
      onTap: () => Navigator.of(context).pop(),
    );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.zero, // batch 4: CPane centres on the screen
          child: CPaneWindow(fit: CPaneFit.fill,
            title: f.name,
            leading: close,
            child: Column(
              children: [
                Expanded(child: Center(child: _Hero(art: _art, peaks: _peaks, file: f))),
                const SizedBox(height: VSpace.md),
                if (_failed)
                  Text('This audio file could not be played.', style: VType.footnote())
                else ...[
                  // Scrub.
                  SliderTheme(
                    data: SliderTheme.of(context),
                    child: Slider(
                      value: _total.inMilliseconds <= 0
                          ? 0
                          : (_pos.inMilliseconds.clamp(0, _total.inMilliseconds) / _total.inMilliseconds)
                              .toDouble(),
                      onChanged: _total.inMilliseconds <= 0
                          ? null
                          : (v) => _src?.player.seek(Duration(milliseconds: (v * _total.inMilliseconds).round())),
                    ),
                  ),
                  Row(
                    children: [
                      Text(_time(_pos), style: VType.caption()),
                      const Spacer(),
                      Text(_time(_total), style: VType.caption()),
                    ],
                  ),
                  const SizedBox(height: VSpace.xs),
                  // Transport.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      VCircleButton(
                        icon: Icons.replay_10_rounded,
                        tooltip: 'Back 10 seconds',
                        size: 42,
                        onTap: () {
                          final p = _pos - const Duration(seconds: 10);
                          _src?.player.seek(p.isNegative ? Duration.zero : p);
                        },
                      ),
                      const SizedBox(width: VSpace.lg),
                      VCircleButton(
                        icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        tooltip: _playing ? 'Pause' : 'Play',
                        size: 60,
                        selected: true,
                        onTap: () => _playing ? _src?.player.pause() : _src?.player.play(),
                      ),
                      const SizedBox(width: VSpace.lg),
                      VCircleButton(
                        icon: Icons.forward_30_rounded,
                        tooltip: 'Forward 30 seconds',
                        size: 42,
                        onTap: () => _src?.player.seek(_pos + const Duration(seconds: 30)),
                      ),
                    ],
                  ),
                  const SizedBox(height: VSpace.sm),
                  // Volume.
                  Row(
                    children: [
                      Icon(
                        _volume <= 0.01 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        size: 18,
                        color: VColors.textSecondary,
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context),
                          child: Slider(
                            value: _volume,
                            onChanged: (v) {
                              setState(() => _volume = v);
                              _src?.player.setVolume(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cover art if the file has it, otherwise the real waveform.
class _Hero extends StatelessWidget {
  final Uint8List? art;
  final Float32List? peaks;
  final StoredFile file;

  const _Hero({required this.art, required this.peaks, required this.file});

  @override
  Widget build(BuildContext context) {
    final a = art;
    if (a != null && a.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.lg),
        child: Image.memory(a, fit: BoxFit.contain, gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _wave(file)),
      );
    }
    return _wave(file);
  }

  Widget _wave(StoredFile f) {
    final p = peaks;
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(VRadius.lg),
        border: Border.all(color: VColors.borderLight, width: 0.5),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(VSpace.lg),
      child: p == null || p.isEmpty
          ? Icon(FilePlate.iconFor('Audio'), size: 56, color: VColors.accentGreen)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final v in p.take(60))
                  Container(
                    height: 2 + 90 * v,
                    margin: const EdgeInsets.symmetric(vertical: 0.6),
                    decoration: BoxDecoration(
                      color: VColors.accentGreen.withValues(alpha: 0.35 + 0.5 * v),
                      borderRadius: BorderRadius.circular(VRadius.full),
                    ),
                  ),
              ],
            ),
    );
  }
}