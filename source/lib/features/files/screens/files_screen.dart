import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/files/file_blobs.dart';
import '../../../core/audio/music_player.dart';
import '../../../core/files/file_store.dart';
import '../../../core/media/theme_catalog.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/work_surface.dart';
import '../../music/song_row_parts.dart';
import '../../theme/theme_living_media.dart';
import '../widgets/video_player_view.dart';

/// REQ-11 Spatial Files (Vision Pro Spatial UI Kit 71:7502 "Albums"): a tile
/// grid with name and meta beneath each tile, and a segmented type ornament.
/// v8.2 fix pass (DEVIATIONS.md D22): only real files the user added
/// (FileStore: Files +, composer and model-pill attachments); no sample
/// files and no hard-coded model filter list. Music lists the catalog songs.
/// v8.2 round 3 (D32, D33): files keep their contents (IndexedDB on web) and
/// open again after a reload (images and text in a viewer, PDF in a new tab,
/// anything else downloads); All is the union of files and songs.
class FilesScreen extends StatefulWidget {
  final VoidCallback onClose;

  const FilesScreen({super.key, required this.onClose});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FileStore _store = FileStore.instance;
  String _q = '';
  int _type = 0;

  // v8.2: 'Music' lists the catalog's songs (MusicPlayer.library: every
  // theme's tracks under that theme, then ambientTracks), the same songs the
  // theme screen carousel and the floating widget play (DEVIATIONS.md D13).
  // Second, so it is in view without scrolling the tab ornament.
  static const _types = ['All', 'Music', 'Document', 'Writing', 'Image', 'Video', 'Data'];
  // Tab labels: short so all six fit the 430 px tab row (D27).
  static const _labels = ['All', 'Music', 'Docs', 'Text', 'Image', 'Video', 'Data'];
  static const int _musicTab = 1;

  /// Tabs on show: no Music tab while the catalog has no songs (v8.3, D46).
  List<int> get _tabIdx => [
        for (var i = 0; i < _types.length; i++)
          if (i != _musicTab || MusicPlayer.library.isNotEmpty) i,
      ];

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

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    return ListenableBuilder(
      listenable: ThemeCatalog.instance,
      builder: (context, _) {
        final idx = _tabIdx;
        if (!idx.contains(_type)) _type = 0;
        return VWorkSurface(
      title: 'Files',
      onClose: widget.onClose,
      toolbarActions: [VCircleButton(icon: Icons.add_rounded, tooltip: 'Add files', onTap: _pickFile)],
      search: VSearchField(
        controller: _searchCtrl,
        hint: 'Search',
        onChanged: (v) => setState(() => _q = v.trim()),
      ),
      tabs: [for (final i in idx) _labels[i]],
      denseTabs: true,
      activeTab: idx.indexOf(_type),
      onTab: (k) => setState(() => _type = idx[k]),
      child: AnimatedBuilder(
        animation: Listenable.merge([_store, ThemeCatalog.instance, MusicPlayer.instance]),
        builder: (context, _) => LayoutBuilder(builder: (context, c) => _body(q, c.maxWidth)),
      ),
    );
      },
    );
  }

  // One scroll view per tab: files (grid) and / or songs (rows). All is the
  // union, so its empty state shows only with no files and no songs (D33).
  Widget _body(String q, double width) {
    final isMusic = _type == _musicTab;
    final type = _types[_type];
    final allFiles = _store.files;
    final files = isMusic
        ? const <StoredFile>[]
        : allFiles.where((f) => (q.isEmpty || f.name.toLowerCase().contains(q)) && (type == 'All' || f.type == type)).toList();
    final lib = (isMusic || type == 'All') ? MusicPlayer.library : const <MusicTrack>[];
    final songs = [
      for (var i = 0; i < lib.length; i++)
        if (q.isEmpty || lib[i].title.toLowerCase().contains(q) || lib[i].subtitle.toLowerCase().contains(q)) i,
    ];
    // Nothing to show: nothing shown (v8.3, D45); no "No files yet" copy.
    if (files.isEmpty && songs.isEmpty) {
      return const SizedBox.expand();
    }
    final cols = width < 420 ? 2 : (width < 700 ? 3 : 4);
    final p = MusicPlayer.instance;
    final cur = p.current;
    return EdgeFade(
      fadeHeight: 14,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (files.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.xs),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.78),
                delegate: SliverChildBuilderDelegate((_, i) => _tile(files[i]), childCount: files.length),
              ),
            ),
          if (songs.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.md),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, k) {
                  final i = songs[k];
                  final t = lib[i];
                  // Same song + same theme: a song in two packs is two rows.
                  final isCur = cur != null && cur.key == t.key && cur.themeId == t.themeId;
                  return _songRow(t, isCur, isCur && p.playing, () {
                    if (isCur) {
                      p.toggle();
                    } else {
                      p.playQueue(lib, i, id: 'library');
                    }
                  });
                }, childCount: songs.length),
              ),
            ),
        ],
      ),
    );
  }

  // Figma library row (417:6219 "Your Library", D40) with its own button.
  Widget _songRow(MusicTrack t, bool isCur, bool playingThis, VoidCallback onPlay) => LibrarySongRow(
        art: ThemeImage(t.art, fit: BoxFit.cover),
        title: t.title,
        subtitle: t.subtitle,
        current: isCur,
        playing: playingThis,
        onPlay: t.playable ? onPlay : null,
      );

  Widget _tile(StoredFile f) {
    final meta = [FileStore.sizeLabel(f.sizeBytes), FileStore.ago(f.addedAt)].where((s) => s.isNotEmpty).join(' · ');
    return VTile(
      title: f.name,
      subtitle: meta,
      onTap: () => _open(f),
      media: Container(
        color: VColors.fillCell,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (FileStore.isImage(f.name))
              _Thumb(id: f.id, fallback: _icon(f.type))
            else
              Center(child: Icon(_icon(f.type), size: 34, color: VColors.textSecondary)),
            Positioned(
              top: VSpace.xxs,
              right: VSpace.xxs,
              child: VCircleButton(icon: Icons.close_rounded, size: 24, tooltip: 'Remove', onTap: () => _confirmRemove(f)),
            ),
          ],
        ),
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
