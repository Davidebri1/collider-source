import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/app_font.dart';
import 'sg_model.dart';

class SgScroll extends ScrollBehavior {
  const SgScroll();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

Widget sgScroll({required Widget child, Axis axis = Axis.vertical}) {
  return ScrollConfiguration(
    behavior: const SgScroll(),
    child: SingleChildScrollView(scrollDirection: axis, child: child),
  );
}

class SgClock extends StatefulWidget {
  const SgClock({super.key, required this.dueMs});
  final int dueMs;
  @override
  State<SgClock> createState() => _SgClockState();
}

class _SgClockState extends State<SgClock> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.dueMs - DateTime.now().millisecondsSinceEpoch;
    final overdue = left <= 0;
    final d = Duration(milliseconds: left.abs());
    final h = d.inHours.remainder(100).toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0xFF1A120F), borderRadius: BorderRadius.circular(4)),
      child: Text(
        overdue ? 'OVERDUE' : '$h:$m:$s',
        style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFF5A4A), letterSpacing: 0.6).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class SgPulse extends StatefulWidget {
  const SgPulse({super.key, required this.child});
  final Widget Function() child;
  @override
  State<SgPulse> createState() => _SgPulseState();
}

class _SgPulseState extends State<SgPulse> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: c, builder: (_, __) => widget.child());
}

/// A real photo, not the 10×10 seed that only exists so album cards have bytes.
bool _hasPhoto(SgCard card) {
  if (card.files.isEmpty) return false;
  return card.files.first.dataUrl != kSeedPng;
}

/// The card cover. A photo fills the band. A colour-only cover is a solid
/// banner of the card colour, so it reads as a cover rather than an empty box.
class SgCover extends StatelessWidget {
  const SgCover({super.key, required this.card, this.height = 96});
  final SgCard card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    if (!_hasPhoto(card)) return _banner(radius);
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        _bytes(card.files.first.dataUrl),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _banner(radius),
      ),
    );
  }

  Widget _banner(BorderRadius radius) {
    if (card.color == 0) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: const Color(0xFF2A2D35),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
      );
    }
    final color = Color(card.color);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.18), color),
            color,
          ],
        ),
      ),
    );
  }
}

class SgFace extends StatelessWidget {
  const SgFace({super.key, required this.card, required this.board, this.compact = false, this.back = false});
  final SgCard card;
  final SgBoard board;
  final bool compact;
  final bool back;

  static const Color _glass = Color(0xFF2A2D35);
  static const Color _ink = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xB3FFFFFF);
  static const Color _line = Color(0x33FFFFFF);

  @override
  Widget build(BuildContext context) {
    final tinted = card.color != 0;
    final wash = tinted ? Color.alphaBlend(Color(card.color).withValues(alpha: 0.40), _glass) : _glass;
    if (back) {
      final hidden = [
        if (card.hiddenNotes.isNotEmpty) card.hiddenNotes,
        for (final k in card.hiddenKeys) '$k (hidden)',
      ];
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
        child: Text(hidden.isEmpty ? 'Hidden fields' : hidden.join('\n'), style: appFont(fontSize: 12, color: const Color(0xFFB0B0B0))),
      );
    }
    final labels = card.attrHidden('labels') ? <SgLabel>[] : [for (final id in card.labelIds) ...board.labels.where((l) => l.id == id)];
    final doneChecks = card.checks.where((k) => k.done).length;
    final hasDesc = !card.attrHidden('description') && card.description.trim().isNotEmpty;
    final showDue = !card.attrHidden('due');
    final showChecks = !card.attrHidden('checklist');
    final showFiles = !card.attrHidden('attachments');
    final showMembers = !card.attrHidden('members');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: wash, borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (tinted)
          Container(height: compact ? 8 : 12, width: double.infinity, color: Color(card.color)),
        if (_hasPhoto(card))
          Image.memory(_bytes(card.files.first.dataUrl), height: compact ? 48 : 72, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (labels.isNotEmpty) ...[
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (final l in labels)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Color(l.color), borderRadius: BorderRadius.circular(999)),
                    child: Text(l.title, style: appFont(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 6),
            ],
            Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
            if (!compact && hasDesc) ...[
              const SizedBox(height: 4),
              Text(card.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, color: _muted)),
            ],
            if (card.type == SgType.job && card.company.isNotEmpty)
              Text('${card.company} · ${card.positionTitle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 10, color: _muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (showDue && card.urgent && card.dueMs != null) SgClock(dueMs: card.dueMs!),
              if (showDue && !card.urgent && card.dueMs != null) _dueChip(card.dueMs!),
              if (showDue && card.urgent && card.dueMs == null) _pulse(),
              if (showChecks && card.checks.isNotEmpty) _meta(Icons.check_box_outlined, '$doneChecks/${card.checks.length}'),
              if (showFiles && card.files.isNotEmpty) _meta(Icons.attach_file, '${card.files.length}'),
              if (hasDesc) const Icon(Icons.notes_rounded, size: 14, color: _muted),
              for (final k in card.hiddenKeys)
                Text(k, style: appFont(fontSize: 10, color: const Color(0x66FFFFFF), decoration: TextDecoration.lineThrough)),
              if (showMembers)
              for (final m in card.members.take(3))
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(9), border: Border.all(color: _line)),
                  child: Text(m.isEmpty ? '?' : m[0].toUpperCase(), style: appFont(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _muted),
        const SizedBox(width: 3),
        Text(text, style: appFont(fontSize: 10, fontWeight: FontWeight.w600, color: _ink)),
      ]),
    );
  }

  Widget _dueChip(int dueMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(dueMs);
    final label = '${d.month}/${d.day}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule, size: 12, color: _muted),
        const SizedBox(width: 3),
        Text(label, style: appFont(fontSize: 10, fontWeight: FontWeight.w600, color: _ink)),
      ]),
    );
  }

  Widget _pulse() {
    return SgPulse(child: () {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Color(0xFFFF5A4A), shape: BoxShape.circle),
      );
    });
  }
}

Uint8List _bytes(String dataUrl) {
  final i = dataUrl.indexOf(',');
  final raw = i < 0 ? dataUrl : dataUrl.substring(i + 1);
  try {
    return Uint8List.fromList(base64Decode(raw));
  } catch (_) {
    return Uint8List(0);
  }
}

bool _isImageFile(SgFile f) {
  final n = f.name.toLowerCase();
  return n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.webp') || n.endsWith('.gif') || f.dataUrl.startsWith('data:image');
}

SgFile? _firstImage(SgCard c) {
  for (final f in c.files) {
    if (_isImageFile(f)) return f;
  }
  return null;
}

class _WoodPainter extends CustomPainter {
  const _WoodPainter({this.tint = const Color(0xFF8B5E3C)});
  final Color tint;
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = tint;
    canvas.drawRect(Offset.zero & size, base);
    final dark = Paint()
      ..color = Color.lerp(tint, Colors.black, 0.22)!
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final light = Paint()
      ..color = Color.lerp(tint, const Color(0xFFF0D9B5), 0.35)!
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < size.height.toInt(); i += 7) {
      final path = Path();
      path.moveTo(0, i.toDouble());
      for (var x = 0.0; x <= size.width; x += 18) {
        final wobble = math.sin((x + i) * 0.045) * 2.4 + math.sin((x - i) * 0.02) * 1.2;
        path.lineTo(x, i + wobble);
      }
      canvas.drawPath(path, i % 14 == 0 ? dark : light);
    }
    // Knots
    final knot = Paint()..color = Color.lerp(tint, Colors.black, 0.28)!;
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.22, size.height * 0.35), width: 28, height: 18), knot);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * 0.72, size.height * 0.62), width: 22, height: 14), knot..color = Color.lerp(tint, Colors.black, 0.2)!);
  }
  @override
  bool shouldRepaint(covariant _WoodPainter old) => old.tint != tint;
}

class _CorkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFC9A66B));
    final rnd = math.Random(7);
    for (var i = 0; i < 180; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 1.0 + rnd.nextDouble() * 3.5;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Color.fromRGBO(120 + rnd.nextInt(60), 80 + rnd.nextInt(40), 40 + rnd.nextInt(30), 0.35 + rnd.nextDouble() * 0.35));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MapOceanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A3A5C), Color(0xFF0E2438)]).createShader(rect));
    final wave = Paint()
      ..color = const Color(0x2239A0D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = 12.0; y < size.height; y += 18) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 16) {
        path.lineTo(x, y + math.sin(x * 0.08 + y) * 2);
      }
      canvas.drawPath(path, wave);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}


class SgKanban extends StatefulWidget {
  const SgKanban({super.key, required this.store, required this.onOpen, this.multi = false, this.selected = const {}, this.onSelect, this.initialPage = 0, this.forceHotListId, this.liftCardId});
  final SgStore store;
  final void Function(SgCard) onOpen;
  final bool multi;
  final Set<String> selected;
  final void Function(SgCard)? onSelect;
  /// Capture hook. 0 is the first list. A fraction such as 0.5 rests between
  /// two snap points. `orderedLists.length` is the "+ Add list" column.
  final double initialPage;
  final String? forceHotListId;
  final String? liftCardId;

  /// The column takes this share of the pane, so about 18% of the next list
  /// stays on screen. (1 - 0.85) / 0.85 ≈ 0.18.
  static const double listFraction = 0.85;

  @override
  State<SgKanban> createState() => _SgKanbanState();
}

class _SgKanbanState extends State<SgKanban> {
  late final PageController _pages = PageController(viewportFraction: SgKanban.listFraction);
  int _pageTries = 0;
  int _stable = 0;

  @override
  void initState() {
    super.initState();
    _schedulePage();
  }

  @override
  void didUpdateWidget(SgKanban old) {
    super.didUpdateWidget(old);
    if (old.initialPage != widget.initialPage) {
      _pageTries = 0;
      _stable = 0;
      _schedulePage();
    }
  }

  void _schedulePage() {
    if (widget.initialPage == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPage());
  }

  /// A capture such as 0.5 must stay between snap points. [PageController.jumpTo]
  /// ends in a ballistic settle, and page physics round 0.5 up to the next list.
  bool get _holdBetween => (widget.initialPage - widget.initialPage.round()).abs() > 0.001;

  /// The pane's width settles a frame or two after the first layout. Keep
  /// placing the page until that width has held still, or a fractional page
  /// drifts onto the next list.
  void _showPage() {
    if (!mounted || widget.initialPage == 0 || _pageTries > 12) return;
    _pageTries++;
    if (_pages.hasClients && _pages.position.hasContentDimensions && _pages.position.viewportDimension > 0) {
      final pos = _pages.position;
      final target = (widget.initialPage * pos.viewportDimension * _pages.viewportFraction).clamp(0.0, pos.maxScrollExtent);
      if ((pos.pixels - target).abs() <= 0.5) {
        _stable++;
      } else {
        _stable = 0;
        pos.jumpTo(target);
      }
    }
    if (_stable < 3) _schedulePage();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.store.board!;
    final lists = b.orderedLists;
    final count = lists.length + 1;
    final lift = widget.liftCardId == null ? null : widget.store.byId(widget.liftCardId);
    return LayoutBuilder(builder: (context, box) {
      return SizedBox(
        height: box.maxHeight,
        width: box.maxWidth,
        child: Stack(children: [
          ScrollConfiguration(
            behavior: const SgScroll(),
            child: PageView.builder(
              controller: _pages,
              padEnds: false,
              pageSnapping: !_holdBetween,
              itemCount: count,
              itemBuilder: (context, i) => i == lists.length ? _addList() : _column(b, lists[i]),
            ),
          ),
          if (lift != null)
            Positioned(
              left: box.maxWidth * 0.28,
              top: box.maxHeight * 0.28,
              child: Material(
                elevation: 16,
                color: Colors.transparent,
                shadowColor: Colors.black87,
                child: SizedBox(
                  width: box.maxWidth * 0.55,
                  child: Transform.scale(scale: 1.08, child: SgFace(card: lift, board: b, compact: true)),
                ),
              ),
            ),
        ]),
      );
    });
  }

  Widget _column(SgBoard b, SgList list) {
    final cards = b.cardsIn(list.id);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => widget.store.byId(d.data) != null,
      onAcceptWithDetails: (d) => widget.store.moveCard(d.data, list.id),
      builder: (context, candidate, _) {
        final hot = candidate.isNotEmpty || widget.forceHotListId == list.id;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: hot ? const Color(0xE62A2D35) : const Color(0xCC2A2D35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: hot ? const Color(0xFF7AD4B8) : const Color(0x33FFFFFF), width: hot ? 1.5 : 1),
            ),
            child: _KanbanColumn(store: widget.store, board: b, list: list, cards: cards, multi: widget.multi, selected: widget.selected, onOpen: widget.onOpen, onSelect: widget.onSelect),
          ),
        );
      },
    );
  }

  Widget _addList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Align(
        alignment: Alignment.topCenter,
        child: TextButton(
          onPressed: () => widget.store.addList('List ${widget.store.board!.lists.length + 1}'),
          child: Text('+ Add list', style: appFont(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }
}

/// One Trello list: a title with "…", the cards, and a pinned "+ Add a card".
class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({required this.store, required this.board, required this.list, required this.cards, required this.multi, required this.selected, required this.onOpen, required this.onSelect});
  final SgStore store;
  final SgBoard board;
  final SgList list;
  final List<SgCard> cards;
  final bool multi;
  final Set<String> selected;
  final void Function(SgCard) onOpen;
  final void Function(SgCard)? onSelect;
  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  bool _menu = false;

  void _add() {
    final made = widget.store.addCard(SgType.task);
    if (made == null) return;
    widget.store.touch(() {
      made.listId = widget.list.id;
      made.status = widget.list.title;
    });
    setState(() => _menu = false);
    widget.onOpen(made);
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFFFFFFF);
    const muted = Color(0xB3FFFFFF);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
        child: Row(children: [
          Expanded(child: Text(widget.list.title, style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: ink))),
          IconButton(
            tooltip: 'List menu',
            onPressed: () => setState(() => _menu = !_menu),
            icon: const Icon(Icons.more_horiz, color: muted, size: 22),
          ),
        ]),
      ),
      if (_menu)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: TextButton(
            style: TextButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(double.infinity, 40)),
            onPressed: _add,
            child: Text('Add a card', style: appFont(fontSize: 15, color: ink)),
          ),
        ),
      Expanded(
        child: ScrollConfiguration(
          behavior: const SgScroll(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            children: [for (final c in widget.cards) _tile(c)],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: TextButton(
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(double.infinity, 44)),
          onPressed: _add,
          child: Text('+ Add a card', style: appFont(fontSize: 15, color: muted)),
        ),
      ),
    ]);
  }

  Widget _tile(SgCard c) {
    final on = widget.selected.contains(c.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LongPressDraggable<String>(
        data: c.id,
        feedback: Material(
          elevation: 12,
          color: Colors.transparent,
          shadowColor: Colors.black54,
          child: SizedBox(width: 150, child: Transform.scale(scale: 1.06, child: SgFace(card: c, board: widget.board, compact: true))),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: SgFace(card: c, board: widget.board, compact: true)),
        child: GestureDetector(
          onTap: () => widget.multi ? widget.onSelect?.call(c) : widget.onOpen(c),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? Colors.white : Colors.transparent, width: 1.5)),
            child: SgFlip(card: c, board: widget.board, compact: true),
          ),
        ),
      ),
    );
  }
}

class SgFlip extends StatefulWidget {
  const SgFlip({super.key, required this.card, required this.board, this.compact = false, this.forceBack = false});
  final SgCard card;
  final SgBoard board;
  final bool compact;
  final bool forceBack;
  @override
  State<SgFlip> createState() => _SgFlipState();
}

class _SgFlipState extends State<SgFlip> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 280), value: widget.forceBack ? 1 : 0);
  late bool _back = widget.forceBack;

  @override
  void didUpdateWidget(SgFlip old) {
    super.didUpdateWidget(old);
    if (widget.forceBack == _back) return;
    _back = widget.forceBack;
    _turn.value = _back ? 1 : 0;
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _back = !_back);
    if (_back) {
      _turn.forward();
    } else {
      _turn.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedBuilder(
        animation: _turn,
        builder: (context, _) {
          final angle = _turn.value * math.pi;
          final front = SgFace(card: widget.card, board: widget.board, compact: widget.compact);
          // A resting front has no transform. The old switcher left every
          // front at rotateY(pi), which mirrors the title.
          if (angle < 0.001) return front;
          final showBack = angle > math.pi / 2;
          final face = showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: SgFace(card: widget.card, board: widget.board, compact: widget.compact, back: true),
                )
              : front;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: face,
          );
        },
      ),
      if (widget.card.hasHidden && !widget.compact)
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: _back ? 'Flip back' : 'Hidden fields',
            child: IconButton(
              onPressed: _toggle,
              icon: Icon(_back ? Icons.flip_to_front_rounded : Icons.flip_rounded, size: 16, color: const Color(0xFF5C6570)),
            ),
          ),
        ),
    ]);
  }
}

class SgCalendar extends StatefulWidget {
  const SgCalendar({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  State<SgCalendar> createState() => _SgCalendarState();
}

class _SgCalendarState extends State<SgCalendar> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? picked;
  @override
  Widget build(BuildContext context) {
    final b = widget.store.board!;
    final first = DateTime(month.year, month.month);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = first.weekday % 7;
    final today = DateTime.now();
    return sgScroll(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Tooltip(message: 'Previous month', child: IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left, color: Colors.white))),
            Expanded(child: Text('${_months[month.month - 1]} ${month.year}', textAlign: TextAlign.center, style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
            Tooltip(message: 'Next month', child: IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right, color: Colors.white))),
          ]),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 64),
            itemCount: 7 + lead + days,
            itemBuilder: (context, i) {
              const names = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
              if (i < 7) return Center(child: Text(names[i], style: appFont(fontSize: 10, color: Colors.white70)));
              if (i < 7 + lead) return const SizedBox.shrink();
              final d = i - 6 - lead;
              return _day(b, DateTime(month.year, month.month, d), today);
            },
          ),
          if (picked != null) _dayPanel(b, picked!),
        ]),
      ),
    );
  }

  Widget _day(SgBoard b, DateTime day, DateTime today) {
    final cards = [
      for (final c in b.cards)
        if (_onDay(c, day, b)) c,
    ];
    final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
    return GestureDetector(
      onTap: () => setState(() => picked = day),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(color: isToday ? const Color(0x33FFFFFF) : const Color(0x11000000), borderRadius: BorderRadius.circular(4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${day.day}', style: appFont(fontSize: 10, color: Colors.white)),
          for (final c in cards.take(2))
            GestureDetector(
              onTap: () => widget.onOpen(c),
              child: Container(
                margin: const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(color: Color(c.color), borderRadius: BorderRadius.circular(3)),
                child: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }

  bool _onDay(SgCard c, DateTime day, SgBoard b) {
    if (c.dueMs != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(c.dueMs!);
      if (d.year == day.year && d.month == day.month && d.day == day.day) return true;
    }
    final today = DateTime.now();
    if (b.urgentAutoCalendar && c.urgent && c.dueMs == null && day.year == today.year && day.month == today.month && day.day == today.day) return true;
    return false;
  }

  Widget _dayPanel(SgBoard b, DateTime day) {
    final cards = [for (final c in b.cards) if (_onDay(c, day, b)) c];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${day.month}/${day.day}', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      for (final c in cards)
        ListTile(
          dense: true,
          title: Text(c.title, style: appFont(fontSize: 13, color: Colors.white)),
          onTap: () => widget.onOpen(c),
        ),
      if (cards.isEmpty) Text('Nothing due', style: appFont(fontSize: 12, color: Colors.white70)),
    ]);
  }
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

class SgNotebook extends StatefulWidget {
  const SgNotebook({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  State<SgNotebook> createState() => _SgNotebookState();
}

class _SgNotebookState extends State<SgNotebook> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.store.board!.cards.where((c) => c.type == SgType.memory || c.type == SgType.journal || c.notebook.contains('---') || c.pages.isNotEmpty).toList();
    final sheets = <(SgCard, String)>[
      for (final c in cards)
        for (final p in (c.pages.isEmpty ? [c.description.isEmpty ? c.title : c.description] : c.pages)) (c, p),
    ];
    if (sheets.isEmpty) {
      return Center(child: Text('No notebook pages yet', style: appFont(color: Colors.white70, fontSize: 13)));
    }
    final title = sheets[_index.clamp(0, sheets.length - 1)].$1.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 8),
        Expanded(
          child: Stack(children: [
            Positioned(left: 10, right: 0, top: 8, bottom: 0, child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFFE4D3B4), borderRadius: BorderRadius.circular(4)))),
            Positioned(left: 6, right: 4, top: 4, bottom: 4, child: DecoratedBox(decoration: BoxDecoration(color: const Color(0xFFEFE0C4), borderRadius: BorderRadius.circular(4)))),
            Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 22,
                decoration: const BoxDecoration(color: Color(0xFF6B3A2A), borderRadius: BorderRadius.horizontal(left: Radius.circular(6))),
                child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (var i = 0; i < 7; i++) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFC4A574), shape: BoxShape.circle)),
                ]),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFF6EBD4), borderRadius: BorderRadius.horizontal(right: Radius.circular(4))),
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      for (final sheet in sheets)
                        GestureDetector(
                          onTap: () => widget.onOpen(sheet.$1),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
                            child: Text(sheet.$2, style: appFont(fontSize: 16, height: 1.45, color: const Color(0xFF3A2A1A))),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < sheets.length; i++)
            Container(
              width: i == _index ? 8 : 5,
              height: i == _index ? 8 : 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: i == _index ? Colors.white : const Color(0x88FFFFFF), shape: BoxShape.circle),
            ),
        ]),
      ]),
    );
  }
}

class SgAlbum extends StatefulWidget {
  const SgAlbum({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  State<SgAlbum> createState() => _SgAlbumState();
}

class _SgAlbumState extends State<SgAlbum> {
  String? _tapped;
  bool _seeded = false;
  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final c in widget.store.board!.cards)
        if (_firstImage(c) != null) c,
    ];
    if (!_seeded && cards.isNotEmpty) {
      _seeded = true;
      _tapped = cards.first.id; // show title on first tile for review captures
    }
    return ColoredBox(
      color: const Color(0xFF12141A),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text('Photo album', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.92),
            itemCount: cards.length,
            itemBuilder: (_, i) {
              final c = cards[i];
              final img = _firstImage(c)!;
              final showTitle = _tapped == c.id;
              return GestureDetector(
                onTap: () {
                  setState(() => _tapped = showTitle ? null : c.id);
                  if (showTitle) widget.onOpen(c);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.memory(_bytes(img.dataUrl), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: Color(c.color | 0xFF000000))),
                    if (showTitle)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xCC000000),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class SgStory extends StatefulWidget {
  const SgStory({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  /// Same peek math as kanban lists: ~85% frame, next frame peeks.
  static const double frameFraction = 0.85;
  @override
  State<SgStory> createState() => _SgStoryState();
}

class _SgStoryState extends State<SgStory> {
  late final PageController _pages = PageController(viewportFraction: SgStory.frameFraction);
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final cards = widget.store.board!.cards;
    return ColoredBox(
      color: const Color(0xFF0E1016),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            const Icon(Icons.movie_filter_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text('Storyboard', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
          ]),
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: const SgScroll(),
            child: PageView.builder(
              controller: _pages,
              itemCount: cards.length,
              padEnds: false,
              itemBuilder: (_, i) {
                final c = cards[i];
                // Same inset as kanban columns so the next frame peeks ~15%.
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: GestureDetector(
                    onTap: () => widget.onOpen(c),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC2A2D35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(
                          height: 32,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Color(c.color | 0xFF000000),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Text('Frame ${i + 1}', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                              const SizedBox(height: 10),
                              Text(c.description.isEmpty ? 'Beat notes…' : c.description, maxLines: 12, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 13, color: Colors.white70)),
                              const Spacer(),
                              Text('SHOT ${i + 1}', style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0x99FFFFFF), letterSpacing: 1.4)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class SgVision extends StatelessWidget {
  const SgVision({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final cards = store.board!.cards;
    return ColoredBox(
      color: const Color(0xFF141018),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            const Icon(Icons.auto_awesome_mosaic_rounded, size: 16, color: Color(0xFFFFD56A)),
            const SizedBox(width: 6),
            Text('Vision board', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            // Two-column masonry: alternate tall / short tiles, image bg when available.
            final gap = 8.0;
            final colW = (box.maxWidth - 20 - gap) / 2;
            final left = <Widget>[];
            final right = <Widget>[];
            for (var i = 0; i < cards.length; i++) {
              final tall = i.isEven;
              final h = tall ? colW * 1.35 : colW * 0.92;
              final tile = _visionTile(cards[i], colW, h);
              (i.isEven ? left : right).add(Padding(padding: EdgeInsets.only(bottom: gap), child: tile));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: colW, child: Column(children: left)),
                  SizedBox(width: gap),
                  SizedBox(width: colW, child: Column(children: [
                    SizedBox(height: gap * 1.5), // stagger short column
                    ...right,
                  ])),
                ],
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _visionTile(SgCard c, double w, double h) {
    final img = _firstImage(c);
    return GestureDetector(
      onTap: () => onOpen(c),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(fit: StackFit.expand, children: [
            if (img != null)
              Image.memory(_bytes(img.dataUrl), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => ColoredBox(color: Color(c.color | 0xFF000000)))
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(c.color | 0xFF000000), Color.lerp(Color(c.color | 0xFF000000), Colors.black, 0.45)!],
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x22000000), Color(0xAA000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 4, width: 28, decoration: BoxDecoration(color: Color(c.color | 0xFF000000), borderRadius: BorderRadius.circular(2))),
                const Spacer(),
                Text(c.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class SgSwim extends StatelessWidget {
  const SgSwim({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final b = store.board!;
    final types = [for (final t in SgType.values) if (b.cards.any((c) => c.type == t)) t];
    final lanes = types.isEmpty ? SgType.values.take(3).toList() : types;
    return ColoredBox(
      color: const Color(0xFF0E1016),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text('Swimlanes', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            itemCount: lanes.length,
            itemBuilder: (_, li) {
              final t = lanes[li];
              final cards = [for (final list in b.orderedLists) for (final c in b.cardsIn(list.id)) if (c.type == t) c];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: const Color(0x18FFFFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x22FFFFFF))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Text(t.label, style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  SizedBox(
                    height: 108,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                      children: [
                        for (final c in cards)
                          GestureDetector(
                            onTap: () => onOpen(c),
                            child: Container(
                              width: 148,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(8), border: Border(top: BorderSide(color: Color(c.color | 0xFF000000), width: 4))),
                              child: Text(c.title, maxLines: 4, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          ),
                        if (cards.isEmpty)
                          Padding(padding: const EdgeInsets.all(12), child: Text('Empty lane', style: appFont(fontSize: 12, color: Colors.white54))),
                      ],
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class SgDesk extends StatelessWidget {
  const SgDesk({super.key, required this.store, required this.onOpen, this.wood = const Color(0xFF8B5E3C)});
  final SgStore store;
  final void Function(SgCard) onOpen;
  final Color wood;
  @override
  Widget build(BuildContext context) {
    final cards = store.board!.cards;
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _WoodPainter(tint: wood), child: const SizedBox.expand()),
        // subtle glass vignette so desk sits in the pane
        DecoratedBox(decoration: BoxDecoration(border: Border.all(color: const Color(0x33000000)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.12), Colors.transparent, Colors.black.withValues(alpha: 0.18)]))),
        LayoutBuilder(builder: (context, box) {
          final positions = <(double, double)>[
            (10, 16), (178, 28), (24, 150), (188, 168), (16, 290), (170, 310),
            (40, 430), (200, 450),
          ];
          return Stack(clipBehavior: Clip.hardEdge, children: [
            for (var i = 0; i < cards.length; i++)
              Positioned(
                left: positions[i % positions.length].$1,
                top: positions[i % positions.length].$2.clamp(0, math.max(0, box.maxHeight - 120)),
                child: GestureDetector(
                  onTap: () => onOpen(cards[i]),
                  child: Transform.rotate(
                    angle: i.isEven ? -0.03 : 0.035,
                    child: Container(
                      width: 152,
                      constraints: const BoxConstraints(minHeight: 100),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F1E4),
                        borderRadius: BorderRadius.circular(3),
                        border: Border(top: BorderSide(color: Color(cards[i].color | 0xFF000000), width: 7)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(2, 5)),
                          BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(cards[i].title, style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF2C2416))),
                        if (cards[i].type == SgType.job) ...[
                          const SizedBox(height: 6),
                          Text(cards[i].company, style: appFont(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF5A4A38))),
                          Text(cards[i].positionTitle, style: appFont(fontSize: 11, color: const Color(0xFF6A5A48))),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class SgPlaces extends StatelessWidget {
  const SgPlaces({super.key, required this.store, required this.onOpen, required this.world});
  final SgStore store;
  final void Function(SgCard) onOpen;
  final bool world;
  @override
  Widget build(BuildContext context) {
    final names = world ? kWorldCountries : [for (final s in kUsStates) s.$1];
    final extra = world ? const <String, String>{} : {for (final s in kUsStates) s.$1: s.$2};
    var hit = 0;
    final tiles = <Widget>[];
    for (final name in names) {
      SgCard? match;
      for (final c in store.board!.cards) {
        if (c.matchesPlace(name)) {
          match = c;
          break;
        }
      }
      if (match != null) hit++;
      final card = match;
      tiles.add(GestureDetector(
        onTap: card == null ? null : () => onOpen(card),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: card == null ? const Color(0x22101828) : const Color(0xFF3F6AA0),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: card == null ? const Color(0x2239A0D0) : const Color(0x88FFFFFF)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            if (!world) Text(extra[name] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 8, color: const Color(0xCCFFFFFF))),
            if (card != null) Text(card.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 8, color: const Color(0xFFFFD56A))),
          ]),
        ),
      ));
    }
    return Stack(fit: StackFit.expand, children: [
      CustomPaint(painter: _MapOceanPainter()),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(world ? 'World map · $hit / ${names.length} mapped' : 'US map · $hit / 50 states', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        Expanded(child: GridView.count(crossAxisCount: world ? 3 : 3, padding: const EdgeInsets.fromLTRB(8, 0, 8, 10), mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: world ? 1.7 : 1.9, children: tiles)),
      ]),
    ]);
  }
}

class SgFiles extends StatelessWidget {
  const SgFiles({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final pairs = <(SgFile, SgCard)>[
      for (final c in store.board!.cards)
        for (final f in c.files) (f, c),
    ];
    return ColoredBox(
      color: const Color(0xFF12141A),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            const Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFFFFD56A)),
            const SizedBox(width: 6),
            Text('Files', style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
            const Spacer(),
            Text('${pairs.length}', style: appFont(fontSize: 12, color: Colors.white54)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            itemCount: pairs.isEmpty ? 1 : pairs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (pairs.isEmpty) {
                return Padding(padding: const EdgeInsets.all(24), child: Text('No files yet', textAlign: TextAlign.center, style: appFont(color: Colors.white70)));
              }
              final (f, c) = pairs[i];
              return Material(
                color: const Color(0x18FFFFFF),
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  dense: true,
                  onTap: () => onOpen(c),
                  leading: _fileLeading(f),
                  title: Text(f.name, style: appFont(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  subtitle: Text(c.title, style: appFont(fontSize: 11, color: Colors.white70)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _fileLeading(SgFile f) {
    if (_isImageFile(f)) {
      try {
        return ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.memory(_bytes(f.dataUrl), width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: Colors.white)));
      } catch (_) {
        return const Icon(Icons.image_outlined, color: Colors.white);
      }
    }
    final lower = f.name.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.webm') || f.dataUrl.startsWith('data:video')) {
      return const Icon(Icons.videocam_outlined, color: Colors.white);
    }
    return const Icon(Icons.insert_drive_file_outlined, color: Colors.white);
  }
}

class SgCork extends StatelessWidget {
  const SgCork({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final cards = store.board!.cards;
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _CorkPainter(), child: const SizedBox.expand()),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 10, runSpacing: 12, children: [
            for (var i = 0; i < cards.length; i++)
              GestureDetector(
                onTap: () => onOpen(cards[i]),
                child: Transform.rotate(
                  angle: i.isEven ? -0.05 : 0.06,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 132,
                      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E7),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(1, 3))],
                      ),
                      child: Text(cards[i].title, style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2C2416))),
                    ),
                    Positioned(top: -4, left: 56, child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFFC0392B), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 2)]))),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class SgClipboard extends StatelessWidget {
  const SgClipboard({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF4EFE4), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(height: 18, margin: const EdgeInsets.only(top: 6), width: 64, decoration: BoxDecoration(color: const Color(0xFFB0B6BE), borderRadius: BorderRadius.circular(8))),
        Expanded(
          child: sgScroll(
            child: Column(children: [
              for (final c in store.board!.cards)
                ListTile(
                  dense: true,
                  title: Text(c.title, style: appFont(fontSize: 13, color: const Color(0xFF2C2416))),
                  onTap: () => onOpen(c),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class SgLedger extends StatelessWidget {
  const SgLedger({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F1DE),
      child: sgScroll(
        child: Column(children: [
          for (final c in store.board!.cards)
            InkWell(
              onTap: () => onOpen(c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFD7CBAA)))),
                child: Row(children: [
                  Expanded(child: Text(c.title, style: appFont(fontSize: 12, color: const Color(0xFF2C2416)))),
                  Text(c.status, style: appFont(fontSize: 11, color: const Color(0xFF6A5A40))),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

class SgBinder extends StatelessWidget {
  const SgBinder({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E3A5F),
      child: Row(children: [
        Container(width: 14, color: const Color(0xFF0E2238)),
        Expanded(
          child: sgScroll(
            child: Column(children: [
              for (final c in store.board!.cards)
                GestureDetector(
                  onTap: () => onOpen(c),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 6, 8, 0),
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFF4EFE4), borderRadius: BorderRadius.horizontal(right: Radius.circular(6))),
                    child: Text(c.title, style: appFont(fontSize: 12, color: const Color(0xFF2C2416), fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class SgSlate extends StatelessWidget {
  const SgSlate({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2C3338),
      child: sgScroll(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final c in store.board!.cards)
              GestureDetector(onTap: () => onOpen(c), child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• ${c.title}', style: appFont(fontSize: 14, color: const Color(0xFFE7E2D1))))),
          ]),
        ),
      ),
    );
  }
}

class SgCanvasBoard extends StatelessWidget {
  const SgCanvasBoard({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final b = store.board!;
    if (b.canvases.isEmpty) {
      return ColoredBox(
        color: const Color(0xFF12141A),
        child: Center(child: Text('Add a canvas from the board menu', style: appFont(fontSize: 13, color: Colors.white70))),
      );
    }
    final canvas = b.canvases[b.canvasIndex.clamp(0, b.canvases.length - 1)];
    final cards = b.cards.where((c) => c.canvasId.isEmpty || c.canvasId == canvas.id).take(8).toList();
    // Seed freeform positions so the pane looks filled on first open.
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].dx == 0 && cards[i].dy == 0) {
        cards[i].dx = 12.0 + (i % 2) * 150.0;
        cards[i].dy = 24.0 + (i ~/ 2) * 110.0;
        cards[i].canvasId = canvas.id;
      }
    }
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200 && b.canvasIndex < b.canvases.length - 1) {
          store.touch(() => b.canvasIndex++);
        } else if (v > 200 && b.canvasIndex > 0) {
          store.touch(() => b.canvasIndex--);
        }
      },
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: Color(canvas.color).withValues(alpha: 0.28)),
        // glass grid
        CustomPaint(painter: _CanvasGridPainter()),
        Positioned(
          left: 12,
          top: 8,
          child: Text(canvas.name, style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
        ),
        for (var i = 0; i < cards.length; i++)
          Positioned(
            left: cards[i].dx,
            top: cards[i].dy,
            child: GestureDetector(
              onTap: () => onOpen(cards[i]),
              onPanUpdate: (d) => store.touch(() {
                cards[i].canvasId = canvas.id;
                cards[i].dx = (cards[i].dx + d.delta.dx).clamp(0, 260);
                cards[i].dy = (cards[i].dy + d.delta.dy).clamp(0, 520);
              }),
              child: SizedBox(width: 128, child: SgFace(card: cards[i], board: b, compact: true)),
            ),
          ),
      ]),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class SgSurfaceView extends StatelessWidget {
  const SgSurfaceView({super.key, required this.store, required this.onOpen, this.multi = false, this.selected = const {}, this.onSelect, this.forceFlip = false, this.kanbanPage = 0, this.forceHotListId, this.liftCardId});
  final SgStore store;
  final void Function(SgCard) onOpen;
  final bool multi;
  final Set<String> selected;
  final void Function(SgCard)? onSelect;
  final bool forceFlip;
  final double kanbanPage;
  final String? forceHotListId;
  final String? liftCardId;

  @override
  Widget build(BuildContext context) {
    if (forceFlip) {
      final c = store.board!.cards.where((c) => c.hasHidden).firstOrNull ?? store.board!.cards.first;
      return Padding(padding: const EdgeInsets.all(12), child: SgFlip(card: c, board: store.board!, forceBack: true));
    }
    final s = store.board!.surface;
    return switch (s) {
      SgSurface.kanban => SgKanban(store: store, onOpen: onOpen, multi: multi, selected: selected, onSelect: onSelect, initialPage: kanbanPage, forceHotListId: forceHotListId, liftCardId: liftCardId),
      SgSurface.calendar => SgCalendar(store: store, onOpen: onOpen),
      SgSurface.notebook => SgNotebook(store: store, onOpen: onOpen),
      SgSurface.album => SgAlbum(store: store, onOpen: onOpen),
      SgSurface.storyboard => SgStory(store: store, onOpen: onOpen),
      SgSurface.vision => SgVision(store: store, onOpen: onOpen),
      SgSurface.swimlane => SgSwim(store: store, onOpen: onOpen),
      SgSurface.portfolio || SgSurface.desk => SgDesk(store: store, onOpen: onOpen, wood: s == SgSurface.desk ? const Color(0xFF6E4428) : const Color(0xFF8B5E3C)),
      SgSurface.usMap => SgPlaces(store: store, onOpen: onOpen, world: false),
      SgSurface.worldMap => SgPlaces(store: store, onOpen: onOpen, world: true),
      SgSurface.files => SgFiles(store: store, onOpen: onOpen),
      SgSurface.corkboard => SgCork(store: store, onOpen: onOpen),
      SgSurface.clipboard => SgClipboard(store: store, onOpen: onOpen),
      SgSurface.ledger => SgLedger(store: store, onOpen: onOpen),
      SgSurface.binder => SgBinder(store: store, onOpen: onOpen),
      SgSurface.slate => SgSlate(store: store, onOpen: onOpen),
      SgSurface.whiteboard => Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Color(0xFFF4F5F2)),
        Positioned(left: 0, right: 0, top: 0, child: Container(height: 28, color: const Color(0xFFE4E6E0), child: Row(children: [
          const SizedBox(width: 10),
          for (final c in [0xFFE74C3C, 0xFF2ECC71, 0xFF3498DB, 0xFF2C3E50])
            Container(width: 14, height: 14, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle)),
          const Spacer(),
          Text('Whiteboard', style: appFont(fontSize: 11, color: Color(0xFF5A5A5A))),
          const SizedBox(width: 10),
        ]))),
        Padding(padding: const EdgeInsets.only(top: 28), child: SgKanban(store: store, onOpen: onOpen)),
      ]),
      SgSurface.canvas => SgCanvasBoard(store: store, onOpen: onOpen),
    };
  }
}
