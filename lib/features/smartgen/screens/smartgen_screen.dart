import '../../../core/theme/edge_fade.dart';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../../core/vision/cpane.dart';
import '../../../core/api/media_gen.dart';
import '../../../core/vision/vision_kit.dart';
import '../kanban_store.dart';
import '../../../core/vision/selection.dart';

/// Parses the Smart Gen agent's reply into the derived need, how the cards
/// serve it, and the proposed cards. Kept out of the widget so it can be
/// tested against the shapes a model actually returns.
({String need, String serve, List<(String title, String note)> cards})
    parseSmartGen(String out) {
  final need = RegExp(r'NEED:\s*(.+)').firstMatch(out)?.group(1)?.trim() ?? '';
  final serve =
      RegExp(r'SERVE:\s*(.+)').firstMatch(out)?.group(1)?.trim() ?? '';
  final block = RegExp(r'CARDS:\s*([\s\S]+)').firstMatch(out)?.group(1) ?? '';
  final cards = <(String, String)>[];
  for (final line in const LineSplitter().convert(block)) {
    final t = line.trimLeft();
    if (!t.startsWith('-')) continue;
    final parts = t.substring(1).trim().split('|');
    final title = parts.first.trim();
    if (title.isEmpty) continue;
    cards.add(
        (title, parts.length > 1 ? parts.sublist(1).join('|').trim() : ''));
    if (cards.length == 6) break;
  }
  return (need: need, serve: serve, cards: cards);
}

/// REQ-10 Smart Gen (map rows 23-25, v8.3, D54): the board as a media market.
/// Layout from the visionOS Smart Gen surface: one floating glass window inset
/// from all four screen edges, the newest generation as a large hero picture
/// with a compact control strip over it, a horizontal strip of smaller
/// pictures beneath, and a thin icon-only rail floating at the left over the
/// scene. The window is the picture plane, so the cards are pictures and text
/// is reduced to one short name each; the note a card carries lives on in the
/// card's detail sheet rather than on its face.
class SmartGenScreen extends StatefulWidget {
  final VoidCallback onClose;

  /// v9.1.7 (#24): the tool picked on the overlaying side nav.
  final String section;

  const SmartGenScreen(
      {super.key, required this.onClose, this.section = 'tasks'});

  @override
  State<SmartGenScreen> createState() => _SmartGenScreenState();
}

class _SmartGenScreenState extends State<SmartGenScreen> {
  final KanbanStore _store = KanbanStore.instance;
  final Selection<String> _sel = Selection<String>();
  void _tapCard(KanbanCard c) =>
      _sel.active ? _sel.toggle(c.id) : _openDetail(c);
  final ScrollController _strip = ScrollController();
  int _col = 0;
  bool _generating = false;
  double _stripMax = 0;
  double _stripAt = 0;

  // Nimo widget card fills (light), with their accent for the card's picture
  // and its header mark.
  static const List<Color> palette = [
    Color(0xFFDDE8FB),
    Color(0xFFF6DEE7),
    Color(0xFFDAF1E4),
    Color(0xFFF5EDD8)
  ];
  static const List<Color> accents = [
    Color(0xFF2F6FE4),
    Color(0xFFD9466F),
    Color(0xFF1F9D63),
    Color(0xFFC08A12)
  ];
  static const List<IconData> colIcons = [
    Icons.radio_button_unchecked_rounded,
    Icons.timelapse_rounded,
    Icons.check_circle_outline_rounded
  ];

  // The strip is the only scroller on the screen; its height is fixed so the
  // rail can be centred over the hero above it.
  static const double _stripH = 148;

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  void _add() {
    final c = _store.add(_col);
    _openDetail(c, editing: true);
  }

  /// Smart Gen agent. Same framing as the Consensus Agent: derive the need
  /// from what is in front of you, then say how you serve it. Here the board is
  /// the input and the output is cards, so the agent proposes the next actions
  /// rather than summarizing what is already there.
  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);
    final board = [
      for (var i = 0; i < KanbanStore.columns.length; i++)
        for (final c in _store.inColumn(i))
          if (c.title.isNotEmpty || c.notes.isNotEmpty)
            '[${KanbanStore.columns[i]}] ${c.title}${c.notes.isEmpty ? '' : ' - ${c.notes}'}',
    ];
    try {
      final out = await MediaGen.instance.consensus([
        {
          'role': 'system',
          'content': 'What is the derived need, and how can you serve it?\n\n'
              'Derive the need from the board: the work these cards imply but do not yet '
              'name. Read the board against that need, then propose the smallest set of '
              'cards that serves it. A card is one concrete next action. Never restate a '
              'card that is already on the board, and never write a card that only '
              'describes the board.\n\n'
              'Reply in exactly this format, nothing else:\n'
              'NEED: <the derived need, one line>\n'
              'SERVE: <how these cards serve it, one line>\n'
              'CARDS:\n'
              '- <title> | <one note>'
        },
        {
          'role': 'user',
          'content': board.isEmpty
              ? 'The board is empty.'
              : 'Board:\n${board.join('\n')}'
        },
      ]);

      final parsed = parseSmartGen(out);

      var made = 0;
      for (final (title, note) in parsed.cards) {
        await _store.edit(_store.add(_col), title: title, notes: note);
        made++;
      }
      if (!mounted) return;
      setState(() => _generating = false);
      await showVAlert(
        context,
        icon: made > 0
            ? Icons.check_circle_outline_rounded
            : Icons.error_outline_rounded,
        title: made > 0
            ? '$made card${made == 1 ? '' : 's'} added'
            : 'No cards to add',
        message: [
          if (parsed.need.isNotEmpty) 'Need: ${parsed.need}',
          if (parsed.serve.isNotEmpty) 'Serve: ${parsed.serve}',
          if (made == 0)
            'The agent returned no usable cards. Add a card or two first so it has something to read.',
        ].join('\n\n'),
        actions: const [VAlertChoice('OK')],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      await showVAlert(
        context,
        icon: Icons.error_outline_rounded,
        title: 'Smart Gen could not run',
        message: friendlyErrorMessage(e),
        actions: const [VAlertChoice('OK')],
      );
    }
  }

  /// A card opens as a sheet over the window: the picture large at the top,
  /// then the title and the note the face does not carry.
  Future<void> _openDetail(KanbanCard c, {bool editing = false}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (_, a, __, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => _CardSheet(
          card: c,
          accent: accents[c.color % accents.length],
          startEditing: editing),
    );
  }

  Future<void> _menu(KanbanCard c, Rect anchor) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screen = overlay.size;
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      pageBuilder: (ctx, _, __) {
        const w = 220.0;
        final left = (anchor.right - w).clamp(8.0, screen.width - w - 8);
        final below = anchor.bottom + 6;
        final top = below + 260 > screen.height
            ? (anchor.top - 266).clamp(8.0, screen.height)
            : below;
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              type: MaterialType.transparency,
              child: GlassMenu(width: w, rows: [
                GlassMenuRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () => Navigator.of(ctx).pop('edit')),
                GlassMenuRow(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Select',
                    onTap: () => Navigator.of(ctx).pop('select')),
                for (var i = 0; i < KanbanStore.columns.length; i++)
                  if (i != c.column)
                    GlassMenuRow(
                        icon: colIcons[i],
                        label: 'Move to ${KanbanStore.columns[i]}',
                        onTap: () => Navigator.of(ctx).pop('move$i')),
                GlassMenuRow(
                    icon: Icons.palette_outlined,
                    label: 'Colour',
                    onTap: () => Navigator.of(ctx).pop('color')),
                GlassMenuRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    onTap: () => Navigator.of(ctx).pop('delete')),
              ]),
            ),
          ),
        ]);
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'select') {
      _sel.toggle(c.id);
    } else if (choice == 'edit') {
      await _openDetail(c, editing: true);
    } else if (choice.startsWith('move')) {
      await _store.move(c, int.parse(choice.substring(4)));
    } else if (choice == 'color') {
      await _store.recolor(c, (c.color + 1) % palette.length);
    } else if (choice == 'delete') {
      final i = await showVAlert(
        context,
        icon: Icons.delete_outline_rounded,
        title: 'Delete card?',
        message: c.title.isEmpty ? null : c.title,
        actions: const [
          VAlertChoice('Delete', destructive: true),
          VAlertChoice('Cancel')
        ],
      );
      if (i == 0) await _store.remove(c);
    }
  }

  // Figma smartgen.png: a light frosted pane (the scene shows through),
  // "Smart Gen Workspace" + search on top, the section's content, and the
  // section ornament under the pane. Sections are the PRD's five tools
  // (functional-spec.txt line 21). No close button: swipe or tap outside.
  static const _sections = [
    'Tasks & Kanban',
    'Projects',
    'Reminders',
    'Memories',
    'Artifacts'
  ];
  static const _sectionIcons = [
    Icons.view_kanban_outlined,
    Icons.folder_outlined,
    Icons.alarm_rounded,
    Icons.psychology_outlined,
    Icons.description_outlined
  ];
  static const _sectionKeys = [
    'tasks',
    'projects',
    'reminders',
    'memories',
    'artifacts'
  ];
  int get _section =>
      _sectionKeys.indexOf(widget.section).clamp(0, _sectionKeys.length - 1);
  String _q = '';

  @override
  Widget build(BuildContext context) {
    // v9.1.7: on CPane (centred, one glass, layer elevation, shell reserve).
    return CPane(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              VSpace.md, VSpace.md, VSpace.md, VSpace.sm),
          child: Text('Smart Gen Workspace',
              style: VType.headline(color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search workspace',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 15)),
              )),
            ]),
          ),
        ),
        const SizedBox(height: VSpace.sm),
        Expanded(
            child: _section == 0
                ? _tasks()
                : Center(
                    child: Text('Nothing yet',
                        style: VType.callout(color: Colors.white70)))),
      ]),
    );
  }

  /// Tasks & Kanban: the status row (To Do / Doing / Done, drop targets),
  /// then the board.
  Widget _tasks() {
    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: VSpace.xs),
            child: FittedBox(
                fit: BoxFit.scaleDown, child: _rail())), // never clipped
        Expanded(
            child: ListenableBuilder(
                listenable: _sel, builder: (_, __) => _board())),
      ]),
      ListenableBuilder(
        listenable: _sel,
        builder: (context, _) => !_sel.active
            ? const SizedBox.shrink()
            : Positioned(
                left: 0,
                right: 0,
                bottom: _stripH + VSpace.lg,
                child: Center(
                  child: SelectionBar(
                    count: _sel.count,
                    onSelectAll: () =>
                        _sel.all(_store.allCards.map((c) => c.id)),
                    onDone: _sel.clear,
                    actions: [
                      SelectionAction(Icons.drive_file_move_outline, 'Move',
                          () async {
                        final ids = _sel.ids;
                        final col = (_store.allCards
                                    .firstWhere((c) => ids.contains(c.id))
                                    .column +
                                1) %
                            KanbanStore.columns.length;
                        await _store.modifyMany(ids, column: col);
                      }),
                      SelectionAction(Icons.palette_outlined, 'Colour',
                          () async {
                        final ids = _sel.ids;
                        final col = (_store.allCards
                                    .firstWhere((c) => ids.contains(c.id))
                                    .color +
                                1) %
                            palette.length;
                        await _store.modifyMany(ids, color: col);
                      }),
                      SelectionAction(Icons.delete_outline_rounded, 'Delete',
                          () async {
                        await _store.removeMany(_sel.ids);
                        _sel.clear();
                      }, destructive: true),
                    ],
                  ),
                ),
              ),
      ),
    ]);
  }

  // The three columns as icon-only circles, floating over the scene, and a
  // drop target each: long-press a card and drop it on a column to move it.
  Widget _rail() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < KanbanStore.columns.length; i++) ...[
            if (i > 0) const SizedBox(width: VSpace.xxs),
            DragTarget<KanbanCard>(
              onWillAcceptWithDetails: (d) => d.data.column != i,
              onAcceptWithDetails: (d) => _store.move(d.data, i),
              // v9.1.4 (playtest #8): each column says its name.
              builder: (context, cand, _) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _col = i),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: i == _col
                          ? const Color(0xE6FFFFFF)
                          : const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(colIcons[i],
                        size: 16,
                        color: cand.isNotEmpty
                            ? VColors.accentBlue
                            : (i == _col
                                ? const Color(0xFF111111)
                                : Colors.white)),
                    const SizedBox(width: 6),
                    Text(KanbanStore.columns[i],
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: i == _col
                                ? const Color(0xFF111111)
                                : Colors.white)),
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _board() {
    if (!_store.loaded) return const SizedBox.shrink();
    final cards = _store
        .inColumn(_col)
        .where((c) => _q.isEmpty || c.title.toLowerCase().contains(_q))
        .toList();
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(VSpace.xs, VSpace.sm, VSpace.xs, VSpace.xs),
      child: Column(
        children: [
          Expanded(child: _hero(cards.isEmpty ? null : cards.first)),
          // v9.1.7: an empty column says so once (the hero's empty state); the
          // strip's second "nothing here" and second add button are dropped.
          if (cards.isNotEmpty) ...[
            const SizedBox(height: VSpace.sm),
            SizedBox(height: _stripH, child: _stripRow(cards.skip(1).toList())),
          ],
        ],
      ),
    );
  }

  /// The newest card: a large picture filling a floating rounded panel, one
  /// short name over it, and the compact control strip.
  Widget _hero(KanbanCard? c) {
    final controls = _controlStrip(c);
    if (c == null) {
      return VPress(
        onTap: _add,
        tooltip: 'New card',
        child: _Panel(
          shadow: VShadow.heavy,
          // v9.1.6: a real empty state: what this board is, and one clear
          // way to start (no blank tinted plate).
          child: ColoredBox(
              color: const Color(0x14FFFFFF),
              child: Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: VSpace.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                              color: Color(0x26FFFFFF), shape: BoxShape.circle),
                          child: const Icon(Icons.auto_awesome_rounded,
                              size: 30, color: Colors.white),
                        ),
                        const SizedBox(height: VSpace.md),
                        Text(
                            _col == 0
                                ? 'Nothing to do yet'
                                : (_col == 1
                                    ? 'Nothing in progress'
                                    : 'Nothing finished yet'),
                            textAlign: TextAlign.center,
                            style: VType.headline()),
                        const SizedBox(height: VSpace.xs),
                        Text(
                          _col == 0
                              ? 'Add a task and Smart Gen turns it into a card with a picture and next steps.'
                              : 'Cards move here when you drag them or mark them from the card menu.',
                          textAlign: TextAlign.center,
                          style: VType.callout(color: const Color(0xD9FFFFFF)),
                        ),
                        if (_col == 0) ...[
                          const SizedBox(height: VSpace.lg),
                          VPress(
                            onTap: _add,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 12),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999)),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 20, color: Color(0xFF111111)),
                                    SizedBox(width: 6),
                                    Text('New card',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111111))),
                                  ]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ])),
        ),
      );
    }
    final accent = accents[c.color % accents.length];
    return LongPressDraggable<KanbanCard>(
      data: c,
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
            width: 240,
            height: 300,
            child: _HeroView(
                card: c,
                accent: accent,
                onOpen: () => _openDetail(c),
                dragging: true)),
      ),
      childWhenDragging: Opacity(
          opacity: 0.4,
          child:
              _HeroView(card: c, accent: accent, onOpen: () => _openDetail(c))),
      child: _HeroView(
          card: c,
          accent: accent,
          onOpen: () => _tapCard(c),
          controls: controls),
    );
  }

  /// The compact strip over the hero: menu, agent, add.
  Widget _controlStrip(KanbanCard? c) {
    return VOrnament(
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c != null)
            VCircleButton(
              icon: Icons.more_horiz_rounded,
              size: 32,
              tooltip: 'More',
              onTap: () => _menu(c, _controlRect),
            ),
          if (_generating)
            const SizedBox(width: 32, height: 32, child: Center(child: _Busy()))
          else
            VCircleButton(
                icon: Icons.psychology_alt_outlined,
                size: 32,
                tooltip: 'Smart Gen agent',
                onTap: _generate),
          VCircleButton(
              icon: Icons.add_rounded,
              size: 32,
              tooltip: 'New card',
              onTap: _add),
        ],
      ),
    );
  }

  // The ⋯ target is the strip's left end; anchoring the menu to the whole
  // strip keeps the anchor valid wherever the hero sits on screen.
  Rect get _controlRect {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero & const Size(32, 32);
    final size = box.size;
    return (box.localToGlobal(Offset(size.width - 96, size.height - 44))) &
        const Size(32, 32);
  }

  /// The rest of the column as a horizontal strip: pictures, edge fades,
  /// chevrons. No scrollbar, ever.
  Widget _stripRow(List<KanbanCard> rest) {
    final empty = SizedBox(
      height: _stripH,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Nothing in ${KanbanStore.columns[_col]} yet.\nTap to add a card.',
            style: const TextStyle(
                fontSize: 15, color: Colors.white, height: 1.35)),
        const SizedBox(width: 14),
        VPress(
          onTap: _add,
          tooltip: 'New card',
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(VRadius.lg),
                boxShadow: VShadow.medium),
            child: _Plate(
              seed: 11,
              accent: accents[_col % accents.length],
              center: const Icon(Icons.add_rounded,
                  size: 26, color: VColors.textSecondary),
            ),
          ),
        ),
      ]),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final m = n.metrics;
        if (m.maxScrollExtent == _stripMax && m.pixels == _stripAt)
          return false;
        // Metrics can arrive mid-layout; move the rebuild past the frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              (m.maxScrollExtent == _stripMax && m.pixels == _stripAt)) return;
          setState(() {
            _stripMax = m.maxScrollExtent;
            _stripAt = m.pixels;
          });
        });
        return false;
      },
      child: Row(
        children: [
          Expanded(child: rest.isEmpty ? empty : _stripStrip(rest)),
        ],
      ),
    );
  }

  Widget _stripStrip(List<KanbanCard> rest) {
    return VFadeScroll(
      axis: Axis.horizontal,
      fade: 22,
      child: SizedBox(
        height: _stripH,
        child: EdgeFade(
            fadeHeight: 24,
            child: ListView.separated(
              controller: _strip,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
              itemBuilder: (_, i) {
                final c = rest[i];
                return _CardFace(
                  card: c,
                  accent: accents[c.color % accents.length],
                  onOpen: () => _tapCard(c),
                  selected: _sel.has(c.id),
                  onMenu: _menu,
                );
              },
            )),
      ),
    );
  }

  void _nudge(double dir) {
    if (!_strip.hasClients) return;
    final p = _strip.position;
    p.animateTo((p.pixels + dir * (_stripH - 24)).clamp(0.0, p.maxScrollExtent),
        duration: VMotion.base, curve: Curves.easeOutCubic);
  }
}

/// A small card picture in the strip: the visual first, one short name over
/// its foot, and a ⋯ over its corner. Long-press it and drop it on a column in
/// the rail to move it.
class _CardFace extends StatelessWidget {
  const _CardFace(
      {required this.card,
      required this.accent,
      required this.onOpen,
      required this.onMenu,
      this.selected = false});

  final bool selected;

  final KanbanCard card;
  final Color accent;
  final VoidCallback onOpen;
  final void Function(KanbanCard, Rect) onMenu;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<KanbanCard>(
      data: card,
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
            width: 116,
            height: 116,
            child:
                Opacity(opacity: 0.92, child: _face(context, dragging: true))),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: _face(context)),
      child: _face(context),
    );
  }

  Widget _face(BuildContext context, {bool dragging = false}) {
    // Nothing on the picture: selection is a ring, name and More sit below.
    return SizedBox(
      width: 116,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(VRadius.md + 2),
                    border:
                        Border.all(color: const Color(0xFF0A84FF), width: 2))
                : null,
            child: _Panel(
              shadow: dragging ? VShadow.heavy : VShadow.medium,
              child: VPress(
                  onTap: onOpen,
                  child: _Plate(
                      seed: card.id.hashCode,
                      accent: accent,
                      overlay: const SizedBox.shrink())),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
              child: Text(card.title,
                  maxLines: 2,
                  softWrap: true,
                  style: VType.footnote(
                      color: Colors.white, weight: FontWeight.w600))),
          if (!dragging)
            Builder(
              builder: (more) => VPress(
                tooltip: 'More',
                onTap: () {
                  final b = more.findRenderObject() as RenderBox?;
                  if (b == null) return;
                  onMenu(card, b.localToGlobal(Offset.zero) & b.size);
                },
                child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.more_horiz_rounded,
                        size: 18, color: Colors.white)),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// The hero card: a picture filling the panel, one short name over its foot,
/// and the control strip if the screen passed one in.
class _HeroView extends StatelessWidget {
  const _HeroView(
      {required this.card,
      required this.accent,
      required this.onOpen,
      this.controls,
      this.dragging = false});

  final KanbanCard card;
  final Color accent;
  final VoidCallback onOpen;
  final Widget? controls;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    // David: nothing on top of a picture. The name and the controls sit
    // under the card's image.
    return SizedBox(
      width: 240,
      child: Column(children: [
        Expanded(
          child: _Panel(
            shadow: VShadow.heavy,
            child: VPress(
                onTap: onOpen,
                child: _Plate(
                    seed: card.id.hashCode,
                    accent: accent,
                    overlay: const SizedBox.shrink())),
          ),
        ),
        const SizedBox(height: VSpace.xs),
        Row(children: [
          Expanded(
              child: Text(card.title,
                  maxLines: 2,
                  softWrap: true,
                  style: VType.callout(
                      color: Colors.white, weight: FontWeight.w600))),
          if (controls != null) controls!,
        ]),
      ]),
    );
  }
}

/// Text that sits over a picture needs its own shadow, not the panel's.
const List<Shadow> _textShadow = [
  Shadow(color: Color(0x99000000), blurRadius: 12)
];

/// A floating rounded surface with a real drop shadow. The picture planes are
/// opaque, so the shadow is what lifts them off the scene.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.shadow = VShadow.medium});

  final Widget child;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VRadius.lg), boxShadow: shadow),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.lg), child: child),
    );
  }
}

/// A card's visual. A card carries no image file, so the picture is generated
/// from the card's id and colour: soft overlapping fields, so a card is never
/// a blank box. [center] is the empty state's small mark.
class _Plate extends StatelessWidget {
  const _Plate(
      {required this.seed,
      required this.accent,
      this.overlay = const SizedBox.shrink(),
      this.center});

  final int seed;
  final Color accent;
  final Widget overlay;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _PlatePainter(seed: seed, accent: accent)),
        // Reads as depth rather than as a star field: a broad falloff only.
        const DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(
                0x00000000), // v9.1: flat frost, no painted gradient
          ),
        ),
        if (center != null) Center(child: center!),
        overlay,
      ],
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.seed, required this.accent});

  final int seed;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final deep = Color.lerp(accent, const Color(0xFF14141E), 0.62)!;
    final bright = Color.lerp(accent, Colors.white, 0.34)!;
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deep, Color.lerp(deep, bright, 0.45)!, bright],
        ).createShader(r),
    );
    final s = size.shortestSide;
    for (var i = 0; i < 3; i++) {
      final c = Offset(_n(i) * size.width, _n(i + 7) * size.height);
      canvas.drawCircle(
        c,
        s * (0.32 + _n(i + 13) * 0.45),
        Paint()
          ..color = (i.isEven ? Colors.white : bright)
              .withValues(alpha: 0.14 + _n(i + 19) * 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
      );
    }
  }

  /// Deterministic per card, so a card keeps the same picture every rebuild.
  double _n(int salt) {
    final x = (seed * 1103515245 + salt * 12345) & 0x7FFFFFFF;
    return (x % 1024) / 1024.0;
  }

  @override
  bool shouldRepaint(covariant _PlatePainter old) =>
      old.seed != seed || old.accent != accent;
}

/// The agent's own progress mark: a plain ring, no sparkle.
class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
          strokeWidth: 1.6, color: VColors.textSecondary),
    );
  }
}

/// The card's detail sheet: the picture large, then the title and the note
/// that the card face deliberately does not carry. Opened over the window as
/// an overlay surface, so it is its own glass, not glass inside glass.
class _CardSheet extends StatefulWidget {
  const _CardSheet(
      {required this.card, required this.accent, this.startEditing = false});

  final KanbanCard card;
  final Color accent;
  final bool startEditing;

  @override
  State<_CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends State<_CardSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.card.title);
  late final TextEditingController _notes =
      TextEditingController(text: widget.card.notes);
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  bool _editing = false;
  bool _notesFirst = false;

  static const _ink2 = Color(0xB3FFFFFF);

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_focusChanged);
    _notesFocus.addListener(_focusChanged);
    if (widget.startEditing)
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEdit());
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _startEdit() {
    if (!mounted) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_notesFirst ? _notesFocus : _titleFocus).requestFocus();
      _notesFirst = false;
    });
  }

  // Editing ends when focus leaves both fields.
  void _focusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      if (!_titleFocus.hasFocus && !_notesFocus.hasFocus) _commit();
    });
  }

  void _commit() {
    if (!mounted) return;
    setState(() => _editing = false);
    KanbanStore.instance
        .edit(widget.card, title: _title.text, notes: _notes.text);
    // A card with neither a title nor a note is dropped by the store, so the
    // sheet has nothing left to show.
    if (_title.text.trim().isEmpty && _notes.text.trim().isEmpty)
      _close(commit: false);
  }

  void _close({bool commit = true}) {
    if (commit && _editing) {
      setState(() => _editing = false);
      KanbanStore.instance
          .edit(widget.card, title: _title.text, notes: _notes.text);
    }
    Navigator.of(context).pop();
  }

  Widget _field(TextEditingController c, FocusNode f,
      {int maxLines = 1,
      TextInputAction action = TextInputAction.next,
      VoidCallback? onDone}) {
    return TextField(
      controller: c,
      focusNode: f,
      maxLines: maxLines,
      minLines: 1,
      cursorColor: widget.accent,
      textInputAction: action,
      onSubmitted: (_) => onDone?.call(),
      style: maxLines == 1
          ? VType.callout(color: VColors.textPrimary, weight: FontWeight.w600)
              .copyWith(height: 1.3)
          : VType.footnote(color: _ink2, weight: FontWeight.w400)
              .copyWith(height: 1.4),
      decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final picture = _Panel(
      shadow: VShadow.heavy,
      child: SizedBox(
        height: 200,
        child: _Plate(
          seed: c.id.hashCode,
          accent: widget.accent,
          center: c.title.isEmpty
              ? const Icon(Icons.image_outlined,
                  size: 28, color: VColors.textTertiary)
              : null,
          overlay: const SizedBox.shrink(),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: VScrim(onTap: _close, blur: true)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(VSpace.md),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 620),
                child: VGlass(
                  material: VMaterial.modal,
                  radius: VRadius.xl,
                  padding: const EdgeInsets.fromLTRB(
                      VSpace.md, VSpace.sm, VSpace.md, VSpace.md),
                  child: EdgeFade(
                      fadeHeight: 24,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            picture,
                            const SizedBox(height: VSpace.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: VCircleButton(
                                  icon: Icons.close_rounded,
                                  tooltip: 'Close',
                                  onTap: _close),
                            ),
                            if (_editing)
                              _field(_title, _titleFocus,
                                  maxLines: 2,
                                  onDone: () => _notesFocus.requestFocus())
                            else
                              GestureDetector(
                                onTap: _startEdit,
                                child: Text(
                                    c.title.isEmpty ? 'Untitled' : c.title,
                                    style: VType.title2(
                                        color: c.title.isEmpty
                                            ? VColors.textTertiary
                                            : VColors.textPrimary)),
                              ),
                            const SizedBox(height: VSpace.xxs),
                            if (_editing)
                              _field(_notes, _notesFocus,
                                  maxLines: 5,
                                  action: TextInputAction.done,
                                  onDone: () =>
                                      FocusScope.of(context).unfocus())
                            else
                              GestureDetector(
                                onTap: () {
                                  _notesFirst = true;
                                  _startEdit();
                                },
                                child: Text(
                                    c.notes.isEmpty ? 'Add a note' : c.notes,
                                    style: VType.footnote(
                                            color: c.notes.isEmpty
                                                ? VColors.textTertiary
                                                : _ink2)
                                        .copyWith(height: 1.4)),
                              ),
                          ],
                        ),
                      )),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
