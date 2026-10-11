import 'package:flutter/material.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/work_surface.dart';
import '../kanban_store.dart';

/// REQ-10 Smart Gen (map rows 23-25, v8.3, D54): a real local Kanban board.
/// Layout from Vision Pro UI Kit 30-75 (Keynote window): the columns are the
/// left sidebar (Keynote's slide list), the open column fills the window
/// with a toolbar on top. Cards and their colours from Nimo Spatial OS
/// 2012-201531 (the light widget cards: header with source and ⋯, bold
/// title, one note). Editing from Spatial UI UX 59-170: tap a title or note
/// to edit it in place; ⋯ opens the glass menu (Move to, Colour, Delete).
/// Long-press a card and drop it on a column to move it. No sample cards:
/// an empty column shows only the add tile.
class SmartGenScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SmartGenScreen({super.key, required this.onClose});

  @override
  State<SmartGenScreen> createState() => _SmartGenScreenState();
}

class _SmartGenScreenState extends State<SmartGenScreen> {
  final KanbanStore _store = KanbanStore.instance;
  int _col = 0;
  String? _editingId;

  // Nimo widget card fills (light), with their accent for the header mark.
  static const List<Color> palette = [Color(0xFFDDE8FB), Color(0xFFF6DEE7), Color(0xFFDAF1E4), Color(0xFFF5EDD8)];
  static const List<Color> accents = [Color(0xFF2F6FE4), Color(0xFFD9466F), Color(0xFF1F9D63), Color(0xFFC08A12)];
  static const List<IconData> colIcons = [Icons.radio_button_unchecked_rounded, Icons.timelapse_rounded, Icons.check_circle_outline_rounded];

  @override
  void initState() {
    super.initState();
    _store.init();
  }

  void _add() {
    final c = _store.add(_col);
    setState(() => _editingId = c.id);
  }

  Future<void> _menu(KanbanCard c, Rect anchor) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screen = overlay.size;
    final choice = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      pageBuilder: (ctx, _, __) {
        const w = 220.0;
        final left = (anchor.right - w).clamp(8.0, screen.width - w - 8);
        final below = anchor.bottom + 6;
        final top = below + 260 > screen.height ? (anchor.top - 266).clamp(8.0, screen.height) : below;
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              type: MaterialType.transparency,
              child: GlassMenu(width: w, rows: [
                GlassMenuRow(icon: Icons.edit_outlined, label: 'Edit', onTap: () => Navigator.of(ctx).pop('edit')),
                for (var i = 0; i < KanbanStore.columns.length; i++)
                  if (i != c.column)
                    GlassMenuRow(icon: colIcons[i], label: 'Move to ${KanbanStore.columns[i]}', onTap: () => Navigator.of(ctx).pop('move$i')),
                GlassMenuRow(icon: Icons.palette_outlined, label: 'Colour', onTap: () => Navigator.of(ctx).pop('color')),
                GlassMenuRow(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: () => Navigator.of(ctx).pop('delete')),
              ]),
            ),
          ),
        ]);
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'edit') {
      setState(() => _editingId = c.id);
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
        actions: const [VAlertChoice('Delete', destructive: true), VAlertChoice('Cancel')],
      );
      if (i == 0) await _store.remove(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return VWorkSurface(
      onClose: widget.onClose,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebar(isMobile ? 104 : 168),
            Expanded(child: _board()),
          ],
        ),
      ),
    );
  }

  // Keynote's slide list (30-75): one tile per column, numbered, with its
  // card count; a drop target for dragged cards.
  Widget _sidebar(double w) {
    return Container(
      width: w,
      color: Colors.black.withValues(alpha: 0.16),
      padding: const EdgeInsets.fromLTRB(8, 60, 8, 8),
      child: Column(
        children: [
          for (var i = 0; i < KanbanStore.columns.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            DragTarget<KanbanCard>(
              onWillAcceptWithDetails: (d) => d.data.column != i,
              onAcceptWithDetails: (d) => _store.move(d.data, i),
              builder: (context, cand, _) {
                final sel = i == _col;
                final hover = cand.isNotEmpty;
                return VPress(
                  onTap: () => setState(() {
                    _col = i;
                    _editingId = null;
                  }),
                  tooltip: KanbanStore.columns[i],
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 14,
                        child: Text('${i + 1}', style: VType.caption(color: sel ? VColors.textPrimary : VColors.textTertiary, weight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: AnimatedContainer(
                          duration: VMotion.fast,
                          height: 64,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                          decoration: BoxDecoration(
                            color: hover ? Colors.white.withValues(alpha: 0.30) : (sel ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.07)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sel || hover ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.12), width: sel || hover ? 1.5 : 0.6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(colIcons[i], size: 16, color: VColors.textSecondary),
                              Row(children: [
                                Expanded(
                                  child: Text(KanbanStore.columns[i], maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: VType.footnote(color: VColors.textPrimary, weight: FontWeight.w600)),
                                ),
                                Text('${_store.count(i)}', style: VType.caption(color: VColors.textSecondary)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _board() {
    final cards = _store.inColumn(_col);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar (30-75): the open column's name, and add.
        Padding(
          padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.xs),
          child: Row(children: [
            Expanded(child: Text(KanbanStore.columns[_col], maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.headline())),
            VCircleButton(icon: Icons.add_rounded, tooltip: 'New card', onTap: _add),
          ]),
        ),
        Expanded(
          child: !_store.loaded
              ? const SizedBox.shrink()
              : VFadeScroll(
                  padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.xxs, VSpace.sm, VSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in cards) ...[
                        _KanbanCardView(
                          key: ValueKey(c.id),
                          card: c,
                          fill: palette[c.color % palette.length],
                          accent: accents[c.color % accents.length],
                          columnIcon: colIcons[c.column],
                          editing: _editingId == c.id,
                          onStartEdit: () => setState(() => _editingId = c.id),
                          onEndEdit: (title, notes) {
                            setState(() => _editingId = null);
                            _store.edit(c, title: title, notes: notes);
                          },
                          onMenu: (r) => _menu(c, r),
                        ),
                        const SizedBox(height: VSpace.xs),
                      ],
                      if (cards.isEmpty) _AddTile(onTap: _add),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// The empty column's one affordance: a dashed add tile.
class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return VPress(
      onTap: onTap,
      tooltip: 'New card',
      child: CustomPaint(
        painter: _DashedRRect(),
        child: const SizedBox(height: 88, child: Center(child: Icon(Icons.add_rounded, size: 28, color: VColors.textSecondary))),
      ),
    );
  }
}

class _DashedRRect extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 10) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A Nimo widget card: header (column mark, age, ⋯), bold title, a note.
/// Title and note edit in place.
class _KanbanCardView extends StatefulWidget {
  final KanbanCard card;
  final Color fill;
  final Color accent;
  final IconData columnIcon;
  final bool editing;
  final VoidCallback onStartEdit;
  final void Function(String title, String notes) onEndEdit;
  final ValueChanged<Rect> onMenu;

  const _KanbanCardView({
    super.key,
    required this.card,
    required this.fill,
    required this.accent,
    required this.columnIcon,
    required this.editing,
    required this.onStartEdit,
    required this.onEndEdit,
    required this.onMenu,
  });

  @override
  State<_KanbanCardView> createState() => _KanbanCardViewState();
}

class _KanbanCardViewState extends State<_KanbanCardView> {
  late final TextEditingController _title = TextEditingController(text: widget.card.title);
  late final TextEditingController _notes = TextEditingController(text: widget.card.notes);
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  final GlobalKey _moreKey = GlobalKey();
  bool _notesFirst = false;

  static const _ink = Color(0xFF1C1C1E);
  static const _ink2 = Color(0xFF5B5B60);

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_focusChanged);
    _notesFocus.addListener(_focusChanged);
    if (widget.editing) _focusSoon();
  }

  @override
  void didUpdateWidget(covariant _KanbanCardView old) {
    super.didUpdateWidget(old);
    if (widget.editing && !old.editing) {
      _title.text = widget.card.title;
      _notes.text = widget.card.notes;
      _focusSoon();
    }
  }

  void _focusSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        (_notesFirst ? _notesFocus : _titleFocus).requestFocus();
        _notesFirst = false;
      });

  // Editing ends when focus leaves both fields.
  void _focusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.editing) return;
      if (!_titleFocus.hasFocus && !_notesFocus.hasFocus) widget.onEndEdit(_title.text, _notes.text);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  String _age() {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(widget.card.updatedMs));
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  Widget _field(TextEditingController c, FocusNode f, TextStyle style, {int? maxLines, TextInputAction action = TextInputAction.next, VoidCallback? onDone}) =>
      TextField(
        controller: c,
        focusNode: f,
        style: style,
        maxLines: maxLines,
        minLines: 1,
        cursorColor: widget.accent,
        textInputAction: action,
        onSubmitted: (_) => onDone?.call(),
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      );

  Widget _body(TextStyle titleStyle, TextStyle noteStyle) {
    final c = widget.card;
    if (widget.editing) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _field(_title, _titleFocus, titleStyle, maxLines: 3, onDone: () => _notesFocus.requestFocus()),
        const SizedBox(height: 4),
        _field(_notes, _notesFocus, noteStyle, maxLines: 6, action: TextInputAction.done, onDone: () => FocusScope.of(context).unfocus()),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.title.isNotEmpty)
        GestureDetector(onTap: widget.onStartEdit, child: Text(c.title, style: titleStyle)),
      if (c.notes.isNotEmpty) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            _notesFirst = true;
            widget.onStartEdit();
          },
          child: Text(c.notes, maxLines: 4, overflow: TextOverflow.ellipsis, style: noteStyle),
        ),
      ],
    ]);
  }

  Widget _card(BuildContext context, {bool feedback = false}) {
    final titleStyle = VType.callout(color: _ink, weight: FontWeight.w700).copyWith(height: 1.3);
    final noteStyle = VType.footnote(color: _ink2, weight: FontWeight.w400).copyWith(height: 1.35);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
      decoration: BoxDecoration(
        color: widget.fill,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: feedback ? 0.35 : 0.18), blurRadius: feedback ? 24 : 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: widget.accent, borderRadius: BorderRadius.circular(5)),
              child: Icon(widget.columnIcon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(KanbanStore.columns[widget.card.column], style: VType.caption(color: _ink2, weight: FontWeight.w600))),
            Text(_age(), style: VType.caption(color: _ink2)),
            if (!feedback)
              VPress(
                key: _moreKey,
                tooltip: 'More',
                onTap: () {
                  final b = _moreKey.currentContext?.findRenderObject() as RenderBox?;
                  if (b == null) return;
                  widget.onMenu(b.localToGlobal(Offset.zero) & b.size);
                },
                child: const SizedBox(width: 32, height: 28, child: Icon(Icons.more_horiz_rounded, size: 18, color: _ink2)),
              )
            else
              const SizedBox(width: 32, height: 28),
          ]),
          const SizedBox(height: 4),
          _body(titleStyle, noteStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.editing) return _card(context);
    return LayoutBuilder(
      builder: (context, box) => LongPressDraggable<KanbanCard>(
        data: widget.card,
        feedback: Material(type: MaterialType.transparency, child: SizedBox(width: box.maxWidth, child: Opacity(opacity: 0.92, child: _card(context, feedback: true)))),
        childWhenDragging: Opacity(opacity: 0.35, child: _card(context)),
        child: _card(context),
      ),
    );
  }
}
