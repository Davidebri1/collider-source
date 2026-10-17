// The one thumbnail widget: it asks FileThumbs what a file really has and
// draws that. A file with no extractable picture gets a designed plate, not a
// generic icon on grey — the plate says what the file is.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_store.dart';
import '../../../core/files/file_thumbs.dart';
import '../../../core/vision/vision_kit.dart';

/// Draws a real thumbnail for [file] once FileThumbs has one.
class ThumbView extends StatefulWidget {
  final StoredFile file;
  /// Keeps text thumbnails legible when the box is small.
  final double fontSize;

  const ThumbView({super.key, required this.file, this.fontSize = 11});

  @override
  State<ThumbView> createState() => _ThumbViewState();
}

class _ThumbViewState extends State<ThumbView> {
  ThumbResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ThumbView old) {
    super.didUpdateWidget(old);
    // A recycled tile can point at a different file; rebuild if it did.
    if (old.file.id != widget.file.id) _load();
  }

  void _load() {
    final current = FileThumbs.of(widget.file);
    current.then((r) {
      if (mounted && _result != r) setState(() => _result = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null) return const _Pending();
    return switch (r) {
      ThumbImage(:final bytes) => Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 360,
          errorBuilder: (_, __, ___) => FilePlate(file: widget.file),
        ),
      ThumbLines(:final lines) => _LinesPlate(lines: lines, fontSize: widget.fontSize),
      ThumbWave(:final peaks) => _WavePlate(peaks: peaks),
      ThumbKind(:final family) => FilePlate(file: widget.file, family: family),
    };
  }
}

class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) => Container(color: VColors.fillCell);
}

/// The first real lines of a text, office or PDF file.
class _LinesPlate extends StatelessWidget {
  final List<String> lines;
  final double fontSize;

  const _LinesPlate({required this.lines, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final shown = lines.take(6).toList();
    return Container(
      color: const Color(0xFF1C1C22),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      child: EdgeFade(
        fadeHeight: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final line in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  line.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VType.caption().copyWith(fontSize: fontSize, color: VColors.textSecondary),
                ),
              ),
            if (lines.length > shown.length)
              Text(
                '+${lines.length - shown.length}',
                style: VType.caption().copyWith(fontSize: fontSize - 1, color: VColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A real decoded waveform: the peaks of the actual audio.
class _WavePlate extends StatelessWidget {
  final Float32List peaks;

  const _WavePlate({required this.peaks});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16161C),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final p in peaks.take(28))
            Expanded(
              child: Container(
                height: 6 + 46 * p,
                margin: const EdgeInsets.symmetric(horizontal: 0.6),
                decoration: BoxDecoration(
                  color: VColors.accentTeal.withValues(alpha: 0.35 + 0.5 * p),
                  borderRadius: BorderRadius.circular(VRadius.full),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How a plate is tinted, per type family.
enum PlateLook { image, video, audio, document, data, text, generic }

/// The designed plate for a file with no picture to show: the extension set in
/// the type's own colour, and the icon for the family. Never an error state.
class FilePlate extends StatelessWidget {
  final StoredFile file;
  /// Overrides the family when the dispatcher already knows it.
  final String? family;

  const FilePlate({super.key, required this.file, this.family});

  static IconData iconFor(String family) => switch (family) {
        'Image' => Icons.image_rounded,
        'Video' => Icons.movie_rounded,
        'Audio' => Icons.graphic_eq_rounded,
        'PDF' => Icons.picture_as_pdf_rounded,
        'Text' => Icons.notes_rounded,
        'Data' => Icons.table_chart_rounded,
        'Document' => Icons.description_rounded,
        _ => Icons.insert_drive_file_rounded,
      };

  static (Color bg, Color fg) colorsFor(PlateLook look) => switch (look) {
        PlateLook.image => (const Color(0xFF1B2430), VColors.accentTeal),
        PlateLook.video => (const Color(0xFF221C2E), VColors.accentPurple),
        PlateLook.audio => (const Color(0xFF1A2330), VColors.accentGreen),
        PlateLook.data => (const Color(0xFF1B2A22), VColors.accentGreen),
        PlateLook.text => (const Color(0xFF232027), VColors.accentOrange),
        PlateLook.document => (const Color(0xFF26232A), VColors.accentOrange),
        PlateLook.generic => (const Color(0xFF232326), VColors.textSecondary),
      };

  static PlateLook lookFor(StoredFile f, [String? family]) {
    final fam = family ?? f.type;
    if (FileStore.isImage(f.name) || fam == 'Image') return PlateLook.image;
    if (FileStore.isVideo(f.name) || fam == 'Video') return PlateLook.video;
    if (FileStore.isAudio(f.name) || fam == 'Audio') return PlateLook.audio;
    if (FileStore.isPdf(f.name) || fam == 'PDF') return PlateLook.document;
    if (fam == 'Data') return PlateLook.data;
    if (fam == 'Text' || fam == 'Writing') return PlateLook.text;
    return PlateLook.document;
  }

  @override
  Widget build(BuildContext context) {
    final look = lookFor(file, family);
    final (bg, fg) = colorsFor(look);
    final ext = FileStore.extOf(file.name).toUpperCase();
    return Container(
      color: bg,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconFor(family ?? file.type), size: 34, color: fg),
          const SizedBox(height: VSpace.xs),
          if (ext.isNotEmpty)
            Text(
              ext,
              style: VType.caption().copyWith(color: fg, fontWeight: FontWeight.w700, letterSpacing: 0.6),
            ),
        ],
      ),
    );
  }
}