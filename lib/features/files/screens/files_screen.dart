import 'dart:ui' as ui;
import '../../../core/theme/edge_fade.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/files/file_blobs.dart';
import '../../../core/audio/music_player.dart';
import '../../../core/files/file_store.dart';
import '../../../core/media/theme_catalog.dart';
import '../../../models/theme_def.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/selection.dart';
import '../../../core/figma/figma_stage.dart';
import '../../music/song_row_parts.dart';
import '../../theme/theme_living_media.dart';
import '../widgets/video_player_view.dart';
import '../../../core/vision/cpane.dart';

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

  /// v9.1.7 (#24): the type picked on the overlaying side nav.
  final String? type;
  const FilesScreen({super.key, required this.onClose, this.category = 'all', this.type});

  static const frame = Size(1336.4, 835.2);
  // The group's own width (rail at 0 .. main panel right 1336.4), no margin.
  static const cropWidth = 1336.4;
  static const center = Offset(668.2, 417.6);
  /// v9.1.6: portrait composition width (Figma px) on phones.
  // v9.1.7 (CPane): composed 420 wide so it reads at ~0.68x inside the
  // shared pane width (it was 560 scaled to the full phone width).
  static const double phoneWidth = 420;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FileStore _store = FileStore.instance;
  String _q = '';
  // Sidebar type filter.
  String _type = Uri.base.queryParameters['ftype'] ?? 'All';
  static const _railTypes = {'all': 'All', 'image': 'Image', 'video': 'Video', 'document': 'Document', 'writing': 'Writing', 'data': 'Data'};
  @override
  void didUpdateWidget(covariant FilesScreen old) {
    super.didUpdateWidget(old);
    if (widget.type != old.type && widget.type != null) _type = _railTypes[widget.type] ?? _type;
  }
  // Segmented ornament (Years / Months / Days / All Photos -> time added).
  int _span = 3;
  static const _spans = ['Year', 'Month', 'Today', 'All Files'];
  /// R33 names the surface by what it holds: generated files. The window
  /// heading is that, not the word Files.
  static const _heading = 'Generated';

  @override
  void initState() {
    super.initState();
    _store.init();
    if (widget.type != null && Uri.base.queryParameters['ftype'] == null) _type = _railTypes[widget.type] ?? _type;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  final Selection<String> _sel = Selection<String>();
  void _tapFile(StoredFile f) => _sel.active ? _sel.toggle(f.id) : _open(f);

  Widget _selBar(List<StoredFile> files) => SelectionBar(
        count: _sel.count,
        onSelectAll: () => _sel.all(files.map((f) => f.id)),
        onDone: _sel.clear,
        actions: [
          SelectionAction(Icons.edit_rounded, 'Rename', () async {
            final t = await askName(context, title: 'Rename ${_sel.count} files');
            if (t != null) await _store.renameMany(_sel.ids.toList(), t);
            _sel.clear();
          }),
          SelectionAction(Icons.delete_outline_rounded, 'Delete', () async {
            await _store.removeMany(_sel.ids);
            _sel.clear();
          }, destructive: true),
        ],
      );

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
      animation: Listenable.merge([_store, ThemeCatalog.instance, MusicPlayer.instance, _sel]),
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
        return Stack(children: [
          Positioned.fill(child: LayoutBuilder(builder: (context, c) {
            // v9.1.6: on a phone the same Figma parts (main panel 3004, sidebar
            // 4253, ornament 3231, built at Figma px) are composed in a
            // portrait frame 560 px wide and scaled as one unit to the phone
            // width (~0.7x, readable), instead of shrinking the whole 1336 px
            // landscape window to 0.29x. The sidebar slides in from its button.
            if (c.maxWidth >= 768) {
              return FigmaStage(
                frame: FilesScreen.frame,
                cropWidth: FilesScreen.cropWidth,
                center: FilesScreen.center,
                children: [
                  Positioned(left: 95.4, top: 0, width: 295, height: 740, child: _sidebar(all)),
                  Positioned(left: 390.4, top: 0, width: 946, height: 740, child: _main(title, files, cat)),
                  Positioned(left: 518.8, top: 721, width: 394.1, height: 60.2, child: _segments()),
                ],
              );
            }
            // Portrait keeps the v8.4 sidebar, grid and pill. Only the column
            // count (5 → 2 or 3) and the thumbnail size come down, so the
            // same content fits the centred pane without a hidden drawer.
            return CPane(child: _phoneBody(title, files, all, cat));
          })),
          if (_sel.active) Positioned(left: 0, right: 0, bottom: 40, child: Center(child: _selBar(files))),
          Positioned(top: MediaQuery.paddingOf(context).top + 8, right: 8, child: VCloseButton(onTap: widget.onClose)),
        ]);
      },
    );
  }

  /// Portrait: the v8.4 sidebar stays on screen beside a 2- or 3-column grid
  /// of small thumbnails. The pill sits under both, scaled to the pane.
  Widget _phoneBody(String title, List<StoredFile> files, List<StoredFile> all, String cat) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 124, child: _phoneRail(all)),
              Expanded(child: _phoneGrid(title, files, cat)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: FittedBox(fit: BoxFit.scaleDown, child: _segments()),
        ),
      ],
    );
  }

  Widget _phoneRail(List<StoredFile> all) {
    Widget item(String label, IconData icon, {required bool on, VoidCallback? onTap}) {
      return Semantics(
        button: onTap != null,
        selected: on,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 30,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: on ? BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(10)) : null,
            child: Row(children: [
              Icon(icon, size: 16, color: const Color(0xFFDDDBD6)),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: FText(label, size: 15, height: 18, weight: on ? FontWeight.w600 : FontWeight.w500, color: on ? Colors.white : const Color(0xFFDDDBD6), ellipsis: false),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final recent = all.take(3).toList();
    final seedRecent = recent.isEmpty && Uri.base.queryParameters['fseed'] == '1'
        ? WallpaperCatalog.freeThemes.take(3).map((t) => '${t.name.replaceAll(RegExp(r'\s*4K$'), '').trim()}.jpg').toList()
        : const <String>[];
    return ColoredBox(
      color: const Color(0x14FFFFFF),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(6, 10, 4, 8),
          children: [
            const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: FText(_heading, size: 22, height: 26, weight: FontWeight.w700, color: Color(0xFFFAF9F5))),
            const SizedBox(height: 8),
            item('Recently Added', Icons.schedule_rounded, on: _type == 'All', onTap: () => setState(() => _type = 'All')),
            item('Images', Icons.image_outlined, on: _type == 'Image', onTap: () => setState(() => _type = 'Image')),
            item('Videos', Icons.movie_outlined, on: _type == 'Video', onTap: () => setState(() => _type = 'Video')),
            item('Documents', Icons.description_outlined, on: _type == 'Document', onTap: () => setState(() => _type = 'Document')),
            const SizedBox(height: 8),
            item('Text', Icons.chevron_right_rounded, on: _type == 'Writing', onTap: () => setState(() => _type = 'Writing')),
            item('Data', Icons.chevron_right_rounded, on: _type == 'Data', onTap: () => setState(() => _type = 'Data')),
            item('Recent', Icons.keyboard_arrow_down_rounded, on: false),
            for (final f in recent)
              GestureDetector(
                onTap: () => _open(f),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                  child: Row(children: [
                    Icon(_icon(f.type), size: 14, color: const Color(0xFFDDDBD6)),
                    const SizedBox(width: 6),
                    Expanded(child: FText(f.name, size: 12, height: 16, weight: FontWeight.w500, color: const Color(0xFFDDDBD6))),
                  ]),
                ),
              ),
            for (final name in seedRecent)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                child: Row(children: [
                  const Icon(Icons.image_outlined, size: 14, color: Color(0xFFDDDBD6)),
                  const SizedBox(width: 6),
                  Expanded(child: FText(name, size: 12, height: 16, weight: FontWeight.w500, color: const Color(0xFFDDDBD6))),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _phoneGrid(String title, List<StoredFile> files, String cat) {
    final seeded = files.isEmpty && cat != 'music' && Uri.base.queryParameters['fseed'] == '1';
    final themes = seeded ? WallpaperCatalog.freeThemes.take(6).toList() : const <WallpaperTheme>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: FText(title, size: 22, height: 26, weight: FontWeight.w700, color: const Color(0xFFFAF9F5)),
              ),
            ),
            Semantics(
              button: true,
              label: 'Add files',
              child: GestureDetector(
                onTap: _pickFile,
                child: const SizedBox(width: 28, height: 28, child: Icon(Icons.add_rounded, size: 22, color: Colors.white)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final count = files.isNotEmpty ? files.length : themes.length;
              if (count == 0 && cat != 'music') {
                return Center(child: FText(files.isEmpty ? 'No files yet' : title, size: 15, height: 20, weight: FontWeight.w500, color: const Color(0xB3FAF9F5)));
              }
              // Portrait keeps the v8.4 tile, only smaller: 3 columns, each
              // thumb capped near the Figma tile, name and size on their own
              // lines underneath. Never stretch a tile to fill the pane.
              const gap = 6.0;
              const labelH = 32.0;
              final cols = box.maxWidth >= 132 ? 3 : 2;
              final cellW = (box.maxWidth - gap * (cols - 1)) / cols;
              final aspect = cellW / (cellW + labelH);
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: gap, crossAxisSpacing: gap, childAspectRatio: aspect),
                  itemCount: count,
                  itemBuilder: (_, i) {
                    if (files.isNotEmpty) {
                      final f = files[i];
                      return _smallTile(
                        art: FileStore.isImage(f.name) ? _Thumb(id: f.id, fallback: _icon(f.type)) : Icon(_icon(f.type), size: 18, color: const Color(0xCCFFFFFF)),
                        name: f.name,
                        meta: FileStore.sizeLabel(f.sizeBytes),
                        onTap: () => _tapFile(f),
                      );
                    }
                    final t = themes[i];
                    final name = t.name.replaceAll(RegExp(r'\s*4K$'), '').trim();
                    final kb = 18 + (i * 23) % 160;
                    return _smallTile(
                      art: ThemePosterImage(theme: t, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                      name: name,
                      meta: '$kb KB',
                      onTap: () {},
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _smallTile({required Widget art, required String name, required String meta, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(color: const Color(0x22FFFFFF), child: SizedBox.expand(child: art)),
            ),
          ),
          const SizedBox(height: 2),
          FText(name, size: 12, height: 15, weight: FontWeight.w500, letterSpacing: -0.2),
          FText(meta, size: 11, height: 13, opacity: 0.62, weight: FontWeight.w500, letterSpacing: -0.2),
        ],
      ),
    );
  }

  Widget _sidebar(List<StoredFile> all, {VoidCallback? onPicked}) {
    Widget menuRow(String type, IconData icon, double top) {
      final on = _type == type;
      return Positioned(
        left: 13,
        top: 84 + top,
        child: Semantics(
          button: true,
          selected: on,
          label: _typeLabel[type],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () { setState(() => _type = type); onPicked?.call(); },
            child: Row(children: [
              Container(
                width: 42.24,
                height: 42.24,
                decoration: on ? const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)) : null,
                child: Icon(icon, size: 21, color: const Color(0xFFDDDBD6)),
              ),
              const SizedBox(width: 11.52),
              FText(_typeLabel[type]!, size: 17.28, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xFFDDDBD6)),
            ]),
          ),
        ),
      );
    }

    Widget section(String type, double top, {bool open = false}) {
      final on = _type == type;
      return Positioned(
        left: 21,
        top: 332 + top,
        width: 273,
        height: 28,
        child: Semantics(
          button: true,
          selected: on,
          label: _typeLabel[type],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () { setState(() => _type = type); onPicked?.call(); },
            child: Row(children: [
              FText(_typeLabel[type]!, size: 23.17, weight: FontWeight.w600, color: on ? Colors.white : const Color(0xE6FAF9F5)),
              const Spacer(),
              Icon(open ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded, size: 28, color: const Color(0xE6FAF9F5)),
              const SizedBox(width: 22),
            ]),
          ),
        ),
      );
    }

    // "All Albums" highlight + album rows -> the newest files.
    final recent = all.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: onPicked != null ? const BorderRadius.all(Radius.circular(52.8)) : const BorderRadius.only(topLeft: Radius.circular(52.8), bottomLeft: Radius.circular(52.8)),
        boxShadow: VElev.e6,
      ),
      child: FGlass(
        radius: onPicked != null ? const BorderRadius.all(Radius.circular(52.8)) : const BorderRadius.only(topLeft: Radius.circular(52.8), bottomLeft: Radius.circular(52.8)),
        blur: 6,
        fill: const Color(0x6618181E),
        child: Stack(children: [
          const Positioned(left: 25, top: 23, child: FText(_heading, size: 29, height: 34, weight: FontWeight.w700, color: Color(0xFFFAF9F5))),
          menuRow('All', Icons.schedule_rounded, 0),
          menuRow('Image', Icons.image_outlined, 57.24),
          menuRow('Video', Icons.movie_outlined, 114.48),
          menuRow('Document', Icons.description_outlined, 171.72),
          section('Writing', 0),
          section('Data', 55),
          Positioned(
            left: 21,
            top: 442,
            width: 273,
            height: 28,
            child: Row(children: const [
              FText('Recent', size: 23.17, weight: FontWeight.w600, color: Color(0xE6FAF9F5)),
              Spacer(),
              Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: Color(0xE6FAF9F5)),
              SizedBox(width: 22),
            ]),
          ),
          if (recent.isNotEmpty)
            Positioned(
              left: 18,
              top: 484,
              width: 255,
              height: 54,
              child: GestureDetector(
                onTap: () => _open(recent.first),
                child: Container(
                  decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    SizedBox(width: 47, height: 47, child: Icon(_icon(recent.first.type), size: 26, color: const Color(0xFFDDDBD6))),
                    const SizedBox(width: 1.84),
                    Expanded(child: FText(recent.first.name, size: 16.56, weight: FontWeight.w600, color: const Color(0xFFDDDBD6))),
                    const SizedBox(width: 12),
                  ]),
                ),
              ),
            ),
          for (var k = 1; k < recent.length; k++)
            Positioned(
              left: 29,
              top: 553 + 57.0 * (k - 1),
              width: 240,
              height: 32,
              child: GestureDetector(
                onTap: () => _open(recent[k]),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.035),
                    child: Container(
                      width: 34,
                      height: 32,
                      color: const Color(0x33FFFFFF),
                      child: FileStore.isImage(recent[k].name)
                          ? _Thumb(id: recent[k].id, fallback: _icon(recent[k].type))
                          : Icon(_icon(recent[k].type), size: 18, color: const Color(0xFFDDDBD6)),
                    ),
                  ),
                  const SizedBox(width: 17.48),
                  Expanded(child: FText(recent[k].name, size: 18, weight: FontWeight.w600, color: const Color(0xFFDDDBD6))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _main(String title, List<StoredFile> files, String cat, {bool phone = false}) {
    final mw = phone ? FilesScreen.phoneWidth : 946.0;
    final tl = phone ? 96.0 : 40.0;
    final lib = cat == 'music' ? MusicPlayer.library : const <MusicTrack>[];
    final p = MusicPlayer.instance;
    final cur = p.current;
    // v9.1.7: on a phone the surface is the CPane around it (one glass).
    Widget surface({required BorderRadius radius, required double blur, required Color fill, required Widget child}) =>
        phone ? child : FGlass(radius: radius, blur: blur, fill: fill, child: child);
    return surface(
      radius: phone ? const BorderRadius.all(Radius.circular(52.8)) : const BorderRadius.only(topRight: Radius.circular(52.8), bottomRight: Radius.circular(52.8)),
      blur: 6, // ticker stays visible, blurred, behind Files
      fill: const Color(0x6618181E),
      // overlay-ok: panel chrome; the thumbnails sit in the grid below, nothing over them
      child: Stack(children: [
        // Title 3120_text at (40, 22), 146 x 34 (search field when searching).
        Positioned(
          left: tl,
          top: 22,
          width: mw - tl - 136,
          height: 34,
          child: cat == 'search'
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v.trim()),
                  cursorColor: Colors.white,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: 'Search', hintStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Color(0x66FFFFFF))),
                )
              : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: FText(title, size: 28.6, weight: FontWeight.w700, color: const Color(0xFFFAF9F5))), // never cut off in the pane
        ),
        // Adding files is the real storage path (D22/D32); Figma has no add
        // control, so it sits on the title row's end (v8.4 note in D22).
        Positioned(
          left: mw - 128,
          top: 19,
          width: 100,
          height: 40,
          child: Semantics(
            button: true,
            label: 'Add files',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickFile,
              child: Container(
                // Playtest: a clear, labelled standard action, not a bare +.
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0x4DFFFFFF)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.upload_rounded, size: 20, color: Colors.white), SizedBox(width: 6), Text('Upload', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))]),
              ),
            ),
          ),
        ),
        // Grid 3011/3047/3083: rows at y 75 + 230 i, tiles 170 x 217, 174 apart.
        Positioned(
          left: phone ? 24 : 40,
          top: 75,
          width: mw - (phone ? 48 : 80),
          bottom: 0,
          child: EdgeFade(fadeHeight: 24, child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: phone ? 2 : 5, mainAxisSpacing: 13, crossAxisSpacing: 4, childAspectRatio: 170 / 217),
                delegate: SliverChildBuilderDelegate((_, i) => _tile(files[i]), childCount: files.length),
              ),
              if (lib.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 13, bottom: 60),
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
              // v9.1.7: an empty pane says so, once, instead of bare glass.
              if (files.isEmpty && lib.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 90),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_q.isNotEmpty ? Icons.search_off_rounded : Icons.folder_open_rounded, size: 44, color: const Color(0xB3FFFFFF)),
                      const SizedBox(height: 12),
                      FText(_q.isNotEmpty ? 'No matches' : 'No files yet', size: 22, weight: FontWeight.w700, color: const Color(0xFFFAF9F5)),
                      const SizedBox(height: 6),
                      FText(_q.isNotEmpty ? 'Try another name' : 'Upload adds photos, videos and documents', size: 16, weight: FontWeight.w500, color: const Color(0xB3FAF9F5)),
                    ])),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          )),
        ),
      ]),
    );
  }

  Widget _segments() => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(765),
          boxShadow: VElev.e12,
        ),
        child: FGlass(
          radius: BorderRadius.circular(765),
          blur: 18.4,
          fill: const Color(0x33FFFFFF),
          stroke: Colors.white,
          strokeWidth: 1,
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
        onTap: () => _tapFile(f),
        onLongPress: () => _sel.toggle(f.id),
        onSecondaryTap: () => _confirmRemove(f),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.02),
              child: Container(
                width: 152,
                height: 153,
                color: const Color(0x33FFFFFF),
                child: FileStore.isImage(f.name)
                    ? _Thumb(id: f.id, fallback: _icon(f.type))
                    : Icon(_icon(f.type), size: 52, color: const Color(0xCCFFFFFF)),
              ),
            ),
            if (_sel.has(f.id)) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle_rounded, color: Color(0xFF0A84FF), size: 34)),
            const SizedBox(height: 3),
            FText(f.name, size: 22, weight: FontWeight.w500),
            FText(meta, size: 16, opacity: 0.6, weight: FontWeight.w500),
          ]),
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
        barrierColor: Colors.transparent,
        // A proper child layer: the Files pane and its controls are blurred
        // out behind the Player, not merely dimmed.
        pageBuilder: (context, _, __) => Material(type: MaterialType.transparency, child: Stack(fit: StackFit.expand, children: [
          // v9.1.7: the wallpaper video is a DOM layer, so a Flutter blur cannot reach the
          // Files pane drawn over it; a 75% dim makes the Files controls recede.
          ClipRect(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: const ColoredBox(color: Color(0xBF000000)))),
          VideoPlayerView(file: f, bytes: bytes),
        ])),
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
      content = EdgeFade(fadeHeight: 24, child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.xs, VSpace.md, VSpace.md),
        child: SelectableText(
          cut ? '$text\n…' : text,
          style: VType.callout(weight: FontWeight.w400).copyWith(fontFamily: 'monospace', fontSize: 13, height: 1.45),
        ),
      ));
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
