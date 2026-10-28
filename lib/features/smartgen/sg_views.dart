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

/// The card's cover image, full width, when a file is attached.
class SgCover extends StatelessWidget {
  const SgCover({super.key, required this.card});
  final SgCard card;
  @override
  Widget build(BuildContext context) {
    if (card.files.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        _bytes(card.files.first.dataUrl),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFFAF7F2);
    const ink = Color(0xFF1C1B19);
    final accent = Color(card.color);
    final wash = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(accent.withValues(alpha: 0.22), paper), paper]);
    if (back) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4DDD4))),
        child: Text(card.hiddenNotes.isEmpty ? 'Hidden fields' : card.hiddenNotes, style: appFont(fontSize: 12, color: ink)),
      );
    }
    final labels = [for (final id in card.labelIds) ...board.labels.where((l) => l.id == id)];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(gradient: wash, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4DDD4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (card.files.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(_bytes(card.files.first.dataUrl), height: compact ? 36 : 56, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 36)),
          ),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 4, children: [for (final l in labels) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Color(l.color), borderRadius: BorderRadius.circular(4)), child: Text(l.title, style: appFont(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)))]),
        ],
        const SizedBox(height: 4),
        Text(card.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: ink)),
        if (!compact && card.description.isNotEmpty)
          Text(card.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, color: const Color(0xFF4A453E))),
        if (card.type == SgType.job && card.company.isNotEmpty)
          Text('${card.company} · ${card.positionTitle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 10, color: const Color(0xFF4A453E))),
        const SizedBox(height: 4),
        Row(children: [
          if (card.urgent && card.dueMs != null) SgClock(dueMs: card.dueMs!),
          if (card.urgent && card.dueMs == null) _pulse(),
          const Spacer(),
          for (final m in card.members.take(3))
            Container(
              margin: const EdgeInsets.only(left: 2),
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(8)),
              child: Text(m.isEmpty ? '?' : m[0], style: appFont(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ]),
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

class SgKanban extends StatefulWidget {
  const SgKanban({super.key, required this.store, required this.onOpen, this.multi = false, this.selected = const {}, this.onSelect, this.initialPage = 0});
  final SgStore store;
  final void Function(SgCard) onOpen;
  final bool multi;
  final Set<String> selected;
  final void Function(SgCard)? onSelect;
  /// Capture hook. 0 is the first list. A fraction such as 0.5 rests between
  /// two snap points. `orderedLists.length` is the "+ Add list" column.
  final double initialPage;

  /// The column takes this share of the pane, so about 19% of the next list
  /// stays on screen. (1 - 0.84) / 0.84 = 0.19.
  static const double listFraction = 0.84;

  @override
  State<SgKanban> createState() => _SgKanbanState();
}

class _SgKanbanState extends State<SgKanban> {
  late final PageController _pages = PageController(viewportFraction: SgKanban.listFraction);
  int _pageTries = 0;
  int _stable = 0;
  final List<GlobalKey> _sampleKeys = [];
  double? _slot;

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

  void _readSamples() {
    if (!mounted) return;
    var maxH = 0.0;
    for (final key in _sampleKeys) {
      final box = key.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && box.size.height > maxH) maxH = box.size.height;
    }
    if (maxH <= 0) return;
    if (_slot != null && (maxH - _slot!).abs() < 0.5) return;
    setState(() => _slot = maxH);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.store.board!;
    final lists = b.orderedLists;
    final count = lists.length + 1;
    while (_sampleKeys.length < count) {
      _sampleKeys.add(GlobalKey());
    }
    if (_sampleKeys.length > count) _sampleKeys.removeRange(count, _sampleKeys.length);
    return LayoutBuilder(builder: (context, box) {
      final pageW = box.maxWidth * SgKanban.listFraction;
      final cap = box.maxHeight.isFinite ? box.maxHeight : 2000.0;
      final h = _slot == null ? 0.0 : math.min(_slot!, cap);
      WidgetsBinding.instance.addPostFrameCallback((_) => _readSamples());
      return Stack(children: [
        Offstage(
          child: OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            alignment: Alignment.topLeft,
            minWidth: 0,
            maxWidth: pageW * count,
            minHeight: 0,
            maxHeight: 4000,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(
                    width: pageW,
                    child: KeyedSubtree(
                      key: _sampleKeys[i],
                      child: i == lists.length ? _addList() : _column(b, lists[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_slot != null)
          SizedBox(
            height: h,
            width: box.maxWidth,
            child: ScrollConfiguration(
              behavior: const SgScroll(),
              child: PageView.builder(
                controller: _pages,
                padEnds: false,
                pageSnapping: !_holdBetween,
                itemCount: count,
                itemBuilder: (context, i) => i == lists.length ? _addList() : _column(b, lists[i]),
              ),
            ),
          ),
      ]);
    });
  }

  Widget _column(SgBoard b, SgList list) {
    final cards = b.cardsIn(list.id);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => widget.store.byId(d.data) != null,
      onAcceptWithDetails: (d) => widget.store.moveCard(d.data, list.id),
      builder: (context, candidate, _) {
        final hot = candidate.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Align(
            alignment: Alignment.topCenter,
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: hot ? const Color(0xFFFFFFFF) : const Color(0xF7FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: hot ? const Color(0xFF3D7A6A) : const Color(0x14000000), width: hot ? 1.5 : 1),
              ),
              child: _KanbanColumn(store: widget.store, board: b, list: list, cards: cards, multi: widget.multi, selected: widget.selected, onOpen: widget.onOpen, onSelect: widget.onSelect),
            ),
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
        widthFactor: 1,
        heightFactor: 1,
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
    const ink = Color(0xFF1C1B19);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
        child: Row(children: [
          Expanded(child: Text(widget.list.title, style: appFont(fontSize: 17, fontWeight: FontWeight.w700, color: ink))),
          IconButton(
            tooltip: 'List menu',
            onPressed: () => setState(() => _menu = !_menu),
            icon: const Icon(Icons.more_horiz, color: ink, size: 22),
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
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final c in widget.cards) _tile(c)],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: TextButton(
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(double.infinity, 44)),
          onPressed: _add,
          child: Text('+ Add a card', style: appFont(fontSize: 16, color: const Color(0xFF5C564E))),
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
        feedback: SizedBox(width: 150, child: Transform.scale(scale: 1.04, child: SgFace(card: c, board: widget.board, compact: true))),
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
              icon: Icon(_back ? Icons.flip_to_front_rounded : Icons.flip_rounded, size: 16, color: const Color(0xFF5C564E)),
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

class SgAlbum extends StatelessWidget {
  const SgAlbum({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final cards = store.board!.cards.where((c) => c.files.isNotEmpty).toList();
    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final c in cards)
          GestureDetector(
            onTap: () => onOpen(c),
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_bytes(c.files.first.dataUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: Color(c.color)))),
              Align(alignment: Alignment.bottomCenter, child: Container(color: const Color(0x88000000), padding: const EdgeInsets.all(4), child: Text(c.title, style: appFont(fontSize: 11, color: Colors.white)))),
            ]),
          ),
      ],
    );
  }
}

class SgStory extends StatelessWidget {
  const SgStory({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final cards = store.board!.cards;
    return sgScroll(
      axis: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < cards.length; i++)
          GestureDetector(
            onTap: () => onOpen(cards[i]),
            child: Container(
              width: 120,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(height: 8, decoration: BoxDecoration(color: Color(cards[i].color), borderRadius: const BorderRadius.vertical(top: Radius.circular(8)))),
                Padding(padding: const EdgeInsets.all(8), child: Text('${i + 1}. ${cards[i].title}', style: appFont(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
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
    return sgScroll(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < cards.length; i++)
            GestureDetector(
              onTap: () => onOpen(cards[i]),
              child: SizedBox(width: i.isEven ? 140 : 100, height: i.isEven ? 120 : 78, child: SgFace(card: cards[i], board: store.board!, compact: true)),
            ),
        ]),
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
    return sgScroll(
      child: Column(children: [
        for (final t in types)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.label, style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              SizedBox(
                height: 92,
                child: sgScroll(
                  axis: Axis.horizontal,
                  child: Row(children: [
                    for (final list in b.orderedLists)
                      for (final c in b.cardsIn(list.id).where((c) => c.type == t))
                        GestureDetector(onTap: () => onOpen(c), child: SizedBox(width: 140, child: Padding(padding: const EdgeInsets.only(right: 6), child: SgFace(card: c, board: b, compact: true)))),
                  ]),
                ),
              ),
            ]),
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
    return Container(
      color: wood,
      child: sgScroll(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in store.board!.cards)
              GestureDetector(
                onTap: () => onOpen(c),
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(color: const Color(0xFFF6F1E6), borderRadius: BorderRadius.circular(2), border: Border(top: BorderSide(color: Color(c.color), width: 6))),
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.title, style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2C2416))),
                    if (c.type == SgType.job) Text('${c.company} · ${c.positionTitle}', style: appFont(fontSize: 10, color: const Color(0xFF5A4A38))),
                  ]),
                ),
              ),
          ]),
        ),
      ),
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
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: card == null ? const Color(0x22000000) : const Color(0xFF3F4A9A), borderRadius: BorderRadius.circular(4)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            if (!world) Text(extra[name] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 8, color: const Color(0xCCFFFFFF))),
          ]),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(world ? '$hit / ${names.length} countries mapped' : '$hit / 50 states mapped', style: appFont(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      Expanded(child: GridView.count(crossAxisCount: 3, padding: const EdgeInsets.all(6), mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 2.1, children: tiles)),
    ]);
  }
}

class SgFiles extends StatelessWidget {
  const SgFiles({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final files = [for (final c in store.board!.cards) ...c.files];
    return sgScroll(
      child: Column(children: [
        for (final f in files)
          ListTile(
            dense: true,
            leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.white),
            title: Text(f.name, style: appFont(fontSize: 13, color: Colors.white)),
            subtitle: Text(store.byId(f.cardId)?.title ?? '', style: appFont(fontSize: 11, color: Colors.white70)),
            onTap: () {
              final c = store.byId(f.cardId);
              if (c != null) onOpen(c);
            },
          ),
        if (files.isEmpty) Text('No files yet', style: appFont(color: Colors.white70)),
      ]),
    );
  }
}

class SgCork extends StatelessWidget {
  const SgCork({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;
  @override
  Widget build(BuildContext context) {
    final cards = store.board!.cards;
    return Container(
      color: const Color(0xFFC4A574),
      child: sgScroll(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < cards.length; i++)
              GestureDetector(
                onTap: () => onOpen(cards[i]),
                child: Transform.rotate(angle: i.isEven ? -0.04 : 0.05, child: SizedBox(width: 120, child: SgFace(card: cards[i], board: store.board!, compact: true))),
              ),
          ]),
        ),
      ),
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
    if (b.canvases.isEmpty) return const SizedBox.shrink();
    final canvas = b.canvases[b.canvasIndex.clamp(0, b.canvases.length - 1)];
    final cards = b.cards.where((c) => c.canvasId.isEmpty || c.canvasId == canvas.id).take(8).toList();
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200 && b.canvasIndex < b.canvases.length - 1) {
          store.touch(() => b.canvasIndex++);
        } else if (v > 200 && b.canvasIndex > 0) {
          store.touch(() => b.canvasIndex--);
        }
      },
      child: Container(
        color: Color(canvas.color).withValues(alpha: 0.35),
        child: Stack(children: [
          for (var i = 0; i < cards.length; i++)
            Positioned(
              left: cards[i].dx,
              top: cards[i].dy + (i == 0 ? 0 : 0),
              child: GestureDetector(
                onTap: () => onOpen(cards[i]),
                onPanUpdate: (d) => store.touch(() {
                  cards[i].canvasId = canvas.id;
                  cards[i].dx = (cards[i].dx + d.delta.dx).clamp(0, 180);
                  cards[i].dy = (cards[i].dy + d.delta.dy).clamp(0, 280);
                }),
                child: SizedBox(width: 120, child: SgFace(card: cards[i], board: b, compact: true)),
              ),
            ),
        ]),
      ),
    );
  }
}

class SgSurfaceView extends StatelessWidget {
  const SgSurfaceView({super.key, required this.store, required this.onOpen, this.multi = false, this.selected = const {}, this.onSelect, this.forceFlip = false, this.kanbanPage = 0});
  final SgStore store;
  final void Function(SgCard) onOpen;
  final bool multi;
  final Set<String> selected;
  final void Function(SgCard)? onSelect;
  final bool forceFlip;
  final double kanbanPage;

  @override
  Widget build(BuildContext context) {
    if (forceFlip) {
      final c = store.board!.cards.where((c) => c.hasHidden).firstOrNull ?? store.board!.cards.first;
      return Padding(padding: const EdgeInsets.all(12), child: SgFlip(card: c, board: store.board!, forceBack: true));
    }
    final s = store.board!.surface;
    return switch (s) {
      SgSurface.kanban => SgKanban(store: store, onOpen: onOpen, multi: multi, selected: selected, onSelect: onSelect, initialPage: kanbanPage),
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
      SgSurface.whiteboard => Container(color: const Color(0xFFF7F7F4), child: SgKanban(store: store, onOpen: onOpen)),
      SgSurface.canvas => SgCanvasBoard(store: store, onOpen: onOpen),
    };
  }
}
