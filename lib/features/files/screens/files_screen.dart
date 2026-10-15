import '../../../core/vision/cpane.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/files/file_blobs.dart';
import '../../../core/audio/music_player.dart';
import '../../../core/files/file_store.dart';
import '../../../core/media/theme_catalog.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/figma/figma_stage.dart';
import '../../music/song_row_parts.dart';
import '../../theme/theme_living_media.dart';
import '../widgets/video_player_view.dart';

/// Map row 7 — Files. v8.4: a straight copy of Vision Pro Spatial UI Kit
/// 71:7502 ("Albums", group 1336 x 835) at its own size, scaled as one unit
/// (FigmaStage). Sidebar 4253 (295 x 740), main panel 3004 (946 x 740) with
/// the 5-column 170 x 217 tile grid, segmented ornament 3231 and window
/// controls 2686 (dot = close). Only the user's real files (FileStore, kept
/// with their contents) and the catalog songs replace the sample albums.
class FilesScreen extends StatefulWidget {
  final VoidCallback onClose;
  /// Rail selection (source filter / 'music' / 'search').
  final String category;

  const FilesScreen({super.key, required this.onClose, this.category = 'all'});

  static const frame = Size(1336.4, 835.2);
  // David (Oct 15): the window (sidebar 95.4 .. main panel right 1336.4) is
  // centred on the screen with 8 pt each side, never full width; the frame's
  // own rail column (0 .. 95.4) is left out because the shell's side nav sits
  // clear of the pane (placeSideNav). 1241 + 2 x 8 x (1241 / 374) = 1294.1.
  static const cropWidth = 1294.1;
  static const center = Offset(715.9, 420.6);

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FileStore _store = FileStore.instance;
  String _q = '';
  // Sidebar type filter.
  String _type = 'All';
  // Segmented ornament (Years / Months / Days / All Photos -> time added).
  int _span = 3;
  static const _spans = ['Year', 'Month', 'Today', 'All Files'];

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (res == null || res.files.isEmpty) return;
      final note = await _store.addPicked(res.files, 'files');
      if (note != null && mounted) await _alert(note);
    } catch (_) {}
  }

  IconData _icon(String type) => switch (type) {
        'Image' => Icons.image_rounded,
        'Video' => Icons.movie_outlined,
        'Data' => Icons.table_chart_outlined,
        'Writing' => Icons.notes_rounded,
        _ => Icons.description_outlined,
      };

  bool _inSpan(StoredFile f) {
    final now = DateTime.now();
    final t = f.addedAt;
    return switch (_span) {
      0 => t.year == now.year,
      1 => t.year == now.year && t.month == now.month,
      2 => t.year == now.year && t.month == now.month && t.day == now.day,
      _ => true,
    };
  }

  static const _typeLabel = {'All': 'Recently Added', 'Image': 'Images', 'Video': 'Videos', 'Document': 'Documents', 'Writing': 'Text', 'Data': 'Data'};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_store, ThemeCatalog.instance, MusicPlayer.instance]),
      builder: (context, _) {
        final cat = widget.category;
        final q = _q.toLowerCase();
        final all = _store.files.reversed.toList();
        final files = cat == 'music'
            ? const <StoredFile>[]
            : all
                .where((f) =>
                    (cat == 'all' || cat == 'search' || f.source == cat) &&
                    (_type == 'All' || f.type == _type) &&
                    _inSpan(f) &&
                    (q.isEmpty || f.name.toLowerCase().contains(q)))
                .toList();
        final title = cat == 'music' ? 'Music' : (_typeLabel[_type] ?? _type);
        return _portrait(title, all, files, cat);
      },
    );
  }

  // David (Oct 15): a landscape window scaled to 0.30 is unreadable on a
  // portrait phone. The same v8.4 widgets (sidebar, header, tiles, segmented
  // control, glass) laid out for portrait at 1.0 inside the shared CPane:
  // the sidebar is a collapsible section under the header, the grid has
  // three columns of real tiles at normal text size.
  bool _menuOpen = false;

  Widget _portrait(String title, List<StoredFile> all, List<StoredFile> files, String cat) {
    final lib = cat == 'music' || (cat == 'all' && _type == 'All') ? MusicPlayer.library : const <MusicTrack>[];
    final p = MusicPlayer.instance;
    final cur = p.current;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
      child: SizedBox(
        height: 36,
        child: Row(children: [
          Expanded(
            child: cat == 'search'
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _q = v.trim()),
                    cursorColor: Colors.white,
                    style: FTextStyle.of(size: 22, weight: FontWeight.w700),
                    decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: 'Search', hintStyle: FTextStyle.of(size: 22, weight: FontWeight.w700, color: const Color(0x66FFFFFF))),
                  )
                : Semantics(
                    button: true,
                    label: _menuOpen ? 'Hide sections' : 'Show sections',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = !_menuOpen),
                      child: Row(children: [
                        Flexible(child: FText(title, size: 22, weight: FontWeight.w700, color: const Color(0xFFFAF9F5))),
                        const SizedBox(width: 4),
                        Icon(_menuOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 24, color: const Color(0xE6FAF9F5)),
                      ]),
                    ),
                  ),
          ),
          Semantics(
            button: true,
            label: 'Add files',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickFile,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4DFFFFFF)),
                child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
    final grid = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFFFF), Colors.white, Colors.white, Color(0x00FFFFFF)],
        stops: [0, 0.03, 0.9, 1],
      ).createShader(r),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
          if (files.isEmpty && lib.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
                child: FText('Files you add show here', size: 15, weight: FontWeight.w500, opacity: 0.6, align: TextAlign.center),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 10, childAspectRatio: 0.76),
              delegate: SliverChildBuilderDelegate((_, i) => _tile(files[i]), childCount: files.length),
            ),
          ),
          if (lib.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final t = lib[i];
                  final isCur = cur != null && cur.key == t.key && cur.themeId == t.themeId;
                  return LibrarySongRow(
                    art: ThemeImage(t.art, fit: BoxFit.cover),
                    title: t.title,
                    subtitle: t.subtitle,
                    current: isCur,
                    playing: isCur && p.playing,
                    onPlay: t.playable ? () => isCur ? p.toggle() : p.playQueue(lib, i, id: 'library') : null,
                  );
                }, childCount: lib.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 64)),
        ],
      ),
    );
    return CPane(
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          AnimatedSize(
            duration: VMotion.base,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _menuOpen ? Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: _sections(all)) : const SizedBox(width: double.infinity),
          ),
          Expanded(child: grid),
        ]),
        // Segmented ornament (v8.4 3231), pinned at the pane's foot.
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(child: SizedBox(height: 44, child: FittedBox(child: _segments()))),
        ),
      ]),
    );
  }

  /// The v8.4 sidebar (4253) as a portrait section: the same rows, glass and
  /// type, at 1.0.
  Widget _sections(List<StoredFile> all) {
    Widget menuRow(String type, IconData icon) {
      final on = _type == type;
      return Semantics(
        button: true,
        selected: on,
        label: _typeLabel[type],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _type = type;
            _menuOpen = false;
          }),
          child: SizedBox(
            height: 38,
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: on ? const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)) : null,
                child: Icon(icon, size: 18, color: const Color(0xFFDDDBD6)),
              ),
              const SizedBox(width: 10),
              Expanded(child: FText(_typeLabel[type]!, size: 15, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xFFDDDBD6))),
            ]),
          ),
        ),
      );
    }

    Widget section(String type, {bool open = false}) {
      final on = _type == type;
      return Semantics(
        button: true,
        selected: on,
        label: _typeLabel[type],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _type = type;
            _menuOpen = false;
          }),
          child: SizedBox(
            height: 38,
            child: Row(children: [
              const SizedBox(width: 4),
              Expanded(child: FText(_typeLabel[type]!, size: 17, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xE6FAF9F5))),
              Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, size: 22, color: const Color(0xE6FAF9F5)),
            ]),
          ),
        ),
      );
    }

    final recent = all.take(3).toList();
    return FGlass(
      radius: BorderRadius.circular(20),
      blur: 24.5,
      gradient: const LinearGradient(begin: Alignment(-0.9, -1), end: Alignment(0.9, 1), colors: [Color(0x99393939), Color(0x99616161)]),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // The v8.4 rows, one per line so every label reads in full at 1.0.
        menuRow('All', Icons.schedule_rounded),
        menuRow('Image', Icons.image_outlined),
        menuRow('Video', Icons.movie_outlined),
        menuRow('Document', Icons.description_outlined),
        Row(children: [Expanded(child: section('Writing')), const SizedBox(width: 12), Expanded(child: section('Data'))]),
        const SizedBox(
          height: 34,
          child: Row(children: [
            SizedBox(width: 4),
            Expanded(child: FText('Recent', size: 17, weight: FontWeight.w600, color: Color(0xE6FAF9F5))),
            Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Color(0xE6FAF9F5)),
          ]),
        ),
        for (var k = 0; k < recent.length; k++)
          GestureDetector(
            onTap: () => _open(recent[k]),
            child: Container(
              height: 38,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: k == 0 ? BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(14)) : null,
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 28,
                    height: 28,
                    color: const Color(0x33FFFFFF),
                    child: FileStore.isImage(recent[k].name)
                        ? _Thumb(id: recent[k].id, fallback: _icon(recent[k].type))
                        : Icon(_icon(recent[k].type), size: 16, color: const Color(0xFFDDDBD6)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: FText(recent[k].name, size: 14, weight: FontWeight.w600, color: const Color(0xFFDDDBD6))),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _segments() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(765),
          boxShadow: const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 1.53), blurRadius: 36.7)],
        ),
        child: FGlass(
          radius: BorderRadius.circular(765),
          blur: 18.4,
          stroke: Colors.white,
          strokeWidth: 1.53,
          gradient: const LinearGradient(
            begin: Alignment(-0.3, -1),
            end: Alignment(0.3, 1),
            colors: [Color(0x80FFFFFF), Color(0x5EEBEBEB), Color(0x36D4D4D4), Color(0x24CACACA), Color(0x1AC4C4C4)],
          ),
          padding: const EdgeInsets.all(12.24 - 1.53),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < _spans.length; i++)
              Semantics(
                button: true,
                selected: _span == i,
                label: _spans[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _span = i),
                  child: Container(
                    height: 35.32,
                    padding: const EdgeInsets.symmetric(horizontal: 17.9),
                    alignment: Alignment.center,
                    decoration: _span == i ? BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(35.8)) : null,
                    child: FText(_spans[i], size: 17.9, height: 21.5, weight: FontWeight.w600),
                  ),
                ),
              ),
          ]),
        ),
      );

  Widget _tile(StoredFile f) {
    final meta = [FileStore.sizeLabel(f.sizeBytes), FileStore.ago(f.addedAt)].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      label: f.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(f),
        onLongPress: () => _confirmRemove(f),
        onSecondaryTap: () => _confirmRemove(f),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: const Color(0x33FFFFFF),
                child: FileStore.isImage(f.name)
                    ? _Thumb(id: f.id, fallback: _icon(f.type))
                    : Icon(_icon(f.type), size: 34, color: const Color(0xCCFFFFFF)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FText(f.name.replaceAll(RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false), ''), size: 13, weight: FontWeight.w600),
          FText(meta, size: 11, opacity: 0.6, weight: FontWeight.w500),
        ]),
      ),
    );
  }

  // Map row 22: problems show in the centred alert (D49).
  Future<void> _alert(String text) =>
      showVAlert(context, icon: Icons.error_outline_rounded, title: text, actions: const [VAlertChoice('OK')]);

  Future<void> _confirmRemove(StoredFile f) async {
    final ok = await showVAlert(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Remove file?',
      message: f.name,
      actions: const [VAlertChoice('Remove', destructive: true), VAlertChoice('Cancel')],
    );
    if (ok == 0) await _store.remove(f.id);
  }

  Future<void> _open(StoredFile f) async {
    final bytes = await _store.bytesOf(f.id);
    if (!mounted) return;
    if (bytes == null) {
      await _alert('${f.name} could not be opened');
      return;
    }
    if (FileStore.isVideo(f.name)) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Close',
        barrierColor: Colors.black.withValues(alpha: 0.55),
        pageBuilder: (context, _, __) => Material(type: MaterialType.transparency, child: VideoPlayerView(file: f, bytes: bytes)),
      );
      return;
    }
    if (FileStore.isImage(f.name) || FileStore.isText(f.name)) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close',
        barrierColor: Colors.black54,
        pageBuilder: (context, _, __) => Material(type: MaterialType.transparency, child: _FileViewer(file: f, bytes: bytes)),
      );
      return;
    }
    // Web: PDF in a new tab, anything else downloaded under its own name.
    // iOS / Android: opened in the app the user has for that type.
    final mime = FileStore.mimeFor(f.name);
    final ok = await FileBlobs.openExternal(f.name, bytes, mime, newTab: mime == 'application/pdf');
    if (!ok && mounted) await _alert('${f.name} could not be opened');
  }
}

/// Image tile thumbnail from the stored bytes.
class _Thumb extends StatefulWidget {
  final String id;
  final IconData fallback;
  const _Thumb({required this.id, required this.fallback});

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  static final Map<String, Uint8List> _cache = {};
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _cache[widget.id];
    if (_bytes == null) {
      FileStore.instance.bytesOf(widget.id).then((b) {
        if (b == null || !mounted) return;
        _cache[widget.id] = b;
        setState(() => _bytes = b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b == null) return Center(child: Icon(widget.fallback, size: 34, color: VColors.textSecondary));
    return Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 360,
        errorBuilder: (_, __, ___) => Center(child: Icon(widget.fallback, size: 34, color: VColors.textSecondary)));
  }
}

/// In-app viewer for a stored image or text file.
class _FileViewer extends StatelessWidget {
  final StoredFile file;
  final Uint8List bytes;
  const _FileViewer({required this.file, required this.bytes});

  static const int _maxChars = 200000;

  @override
  Widget build(BuildContext context) {
    final close = VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: () => Navigator.of(context).pop());
    final Widget content;
    if (FileStore.isImage(file.name)) {
      content = InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image.memory(bytes, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 40, color: VColors.textTertiary)),
        ),
      );
    } else {
      var text = utf8.decode(bytes, allowMalformed: true);
      final cut = text.length > _maxChars;
      if (cut) text = text.substring(0, _maxChars);
      content = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.xs, VSpace.md, VSpace.md),
        child: SelectableText(
          cut ? '$text\n…' : text,
          style: VType.callout(weight: FontWeight.w400).copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.45),
        ),
      );
    }
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.md, 40, VSpace.md, 96),
          child: VWindow(
            title: file.name,
            centerTitle: true,
            maxWidth: VOverlay.toolWidth(context),
            maxHeight: VOverlay.toolMaxHeight(context),
            leading: close,
            child: content,
          ),
        ),
      ),
    );
  }
}
