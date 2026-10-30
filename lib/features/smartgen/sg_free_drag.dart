import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_font.dart';
import 'sg_model.dart';

class _NoBarScroll extends ScrollBehavior {
  const _NoBarScroll();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// One tidy-slot for snap-to-align on a free plane.
class SgSlot {
  const SgSlot({required this.left, required this.top, required this.width, required this.height});
  final double left;
  final double top;
  final double width;
  final double height;
  Offset get origin => Offset(left, top);
}

/// Layout helpers shared by every spatial Smart Gen surface.
class SgFreeLayouts {
  static List<SgSlot> masonry(Size plane, int count, {double gap = 8, double pad = 10, bool stagger = true}) {
    if (count == 0) return const [];
    final colW = (plane.width - pad * 2 - gap) / 2;
    var yL = pad;
    var yR = pad + (stagger ? gap * 1.5 : 0);
    final out = <SgSlot>[];
    for (var i = 0; i < count; i++) {
      final tall = i.isEven;
      final h = tall ? colW * 1.35 : colW * 0.92;
      if (i.isEven) {
        out.add(SgSlot(left: pad, top: yL, width: colW, height: h));
        yL += h + gap;
      } else {
        out.add(SgSlot(left: pad + colW + gap, top: yR, width: colW, height: h));
        yR += h + gap;
      }
    }
    return out;
  }

  static List<SgSlot> grid2(Size plane, int count, {double gap = 8, double pad = 10, double aspect = 0.92}) {
    if (count == 0) return const [];
    final colW = (plane.width - pad * 2 - gap) / 2;
    final h = colW / aspect;
    final out = <SgSlot>[];
    for (var i = 0; i < count; i++) {
      final col = i % 2;
      final row = i ~/ 2;
      out.add(SgSlot(left: pad + col * (colW + gap), top: pad + row * (h + gap), width: colW, height: h));
    }
    return out;
  }

  static List<SgSlot> papers(Size plane, int count, {double tileW = 152, double tileH = 110, double gapX = 16, double gapY = 20, double pad = 12}) {
    if (count == 0) return const [];
    final cols = math.max(1, ((plane.width - pad * 2 + gapX) / (tileW + gapX)).floor());
    final out = <SgSlot>[];
    for (var i = 0; i < count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      out.add(SgSlot(left: pad + col * (tileW + gapX), top: pad + row * (tileH + gapY), width: tileW, height: tileH));
    }
    return out;
  }

  static List<SgSlot> storyRow(Size plane, int count, {double frac = 0.72, double gap = 10, double pad = 10}) {
    if (count == 0) return const [];
    final w = math.max(150.0, plane.width * frac);
    final h = math.max(220.0, plane.height - pad * 2 - 12);
    final out = <SgSlot>[];
    for (var i = 0; i < count; i++) {
      out.add(SgSlot(left: pad + i * (w + gap), top: pad, width: w, height: h));
    }
    return out;
  }

  static List<SgSlot> canvasGrid(Size plane, int count, {double tileW = 128, double tileH = 96, double gap = 16, double pad = 24}) {
    return papers(plane, count, tileW: tileW, tileH: tileH, gapX: gap, gapY: gap, pad: pad);
  }

  static void seedScattered(List<SgCard> cards, List<SgSlot> base, {double jitter = 52}) {
    for (var i = 0; i < cards.length; i++) {
      final s = base[i % base.length];
      final jx = ((i % 5) - 2) * (jitter * 0.55);
      final jy = ((i % 3) - 1) * (jitter * 0.7) + i * 10;
      cards[i].dx = (s.left + jx + (i.isEven ? 18 : -14)).clamp(0, 900);
      cards[i].dy = (s.top + jy).clamp(0, 1400);
    }
  }

  static void applySlots(List<SgCard> cards, List<SgSlot> slots) {
    for (var i = 0; i < cards.length; i++) {
      final s = slots[i % slots.length];
      cards[i].dx = s.left;
      cards[i].dy = s.top;
    }
  }

  /// True when cards still sit on the default stack (or share one point).
  static bool looksUnplaced(List<SgCard> cards) {
    if (cards.isEmpty) return false;
    if (cards.length == 1) return cards.first.dx == 12 && cards.first.dy == 12;
    final a = cards.first;
    return cards.every((c) => (c.dx - a.dx).abs() < 2 && (c.dy - a.dy).abs() < 2);
  }

  static int nearestSlot(Offset p, List<SgSlot> slots) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < slots.length; i++) {
      final d = (slots[i].origin - p).distance;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }
}

/// Shared free-drag plane + snap/align toggle (R23 / David free-drag law).
/// Default: open-ended drop anywhere. Snap toggle aligns into [slotsFor] order
/// and subsequent drops snap to those slots while snap is on.
class SgFreePlane extends StatefulWidget {
  const SgFreePlane({
    super.key,
    required this.store,
    required this.cards,
    required this.slotsFor,
    required this.tileBuilder,
    this.background,
    this.title,
    this.titleIcon,
    this.titleIconColor = Colors.white70,
    this.onOpen,
  });

  final SgStore store;
  final List<SgCard> cards;
  final List<SgSlot> Function(Size plane, List<SgCard> cards) slotsFor;
  final Widget Function(BuildContext context, SgCard card, int index, Size tile) tileBuilder;
  final Widget? background;
  final String? title;
  final IconData? titleIcon;
  final Color titleIconColor;
  final void Function(SgCard)? onOpen;

  @override
  State<SgFreePlane> createState() => _SgFreePlaneState();
}

class _SgFreePlaneState extends State<SgFreePlane> {
  bool _seeded = false;
  String? _dragging;
  Size _plane = const Size(440, 700);

  SgBoard? get _board => widget.store.board;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
  }

  @override
  void didUpdateWidget(covariant SgFreePlane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStore);
      widget.store.addListener(_onStore);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _ensureSeed(Size plane) {
    if (_seeded || widget.cards.isEmpty || _board == null) return;
    _seeded = true;
    final slots = widget.slotsFor(plane, widget.cards);
    final snap = _board!.snapAlign;
    final unplaced = SgFreeLayouts.looksUnplaced(widget.cards);
    if (!snap && !unplaced) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.store.touch(() {
        if (snap) {
          SgFreeLayouts.applySlots(widget.cards, slots);
        } else if (unplaced) {
          SgFreeLayouts.seedScattered(widget.cards, slots);
        }
      });
    });
  }

  List<Widget> _tiles(Size plane, List<SgSlot> slots) {
    final out = <Widget>[];
    for (var i = 0; i < widget.cards.length; i++) {
      final card = widget.cards[i];
      final slot = slots.isEmpty ? const SgSlot(left: 0, top: 0, width: 140, height: 120) : slots[i % slots.length];
      final tile = Size(slot.width, slot.height);
      out.add(AnimatedPositioned(
        key: ValueKey(card.id),
        duration: _dragging == card.id ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        left: card.dx,
        top: card.dy,
        width: tile.width,
        height: tile.height,
        child: GestureDetector(
          onTap: widget.onOpen == null ? null : () => widget.onOpen!(card),
          onPanStart: (_) => setState(() => _dragging = card.id),
          onPanUpdate: (d) {
            widget.store.touch(() {
              card.dx = (card.dx + d.delta.dx).clamp(0, math.max(0, plane.width - 32));
              card.dy = (card.dy + d.delta.dy).clamp(0, math.max(0, plane.height - 32));
            });
          },
          onPanEnd: (_) {
            if (_board?.snapAlign == true && slots.isNotEmpty) {
              final preferred = i < slots.length ? i : 0;
              final nearest = SgFreeLayouts.nearestSlot(Offset(card.dx, card.dy), slots);
              final pick = (Offset(card.dx, card.dy) - slots[preferred].origin).distance < 72 ? preferred : nearest;
              widget.store.touch(() {
                card.dx = slots[pick].left;
                card.dy = slots[pick].top;
              });
            }
            setState(() => _dragging = null);
          },
          onPanCancel: () => setState(() => _dragging = null),
          child: Transform.scale(
            scale: _dragging == card.id ? 1.04 : 1,
            child: widget.tileBuilder(context, card, i, tile),
          ),
        ),
      ));
    }
    return out;
  }

  void _toggleSnap() {
    final b = _board;
    if (b == null) return;
    final next = !b.snapAlign;
    final slots = widget.slotsFor(_plane, widget.cards);
    widget.store.touch(() {
      b.snapAlign = next;
      if (next) SgFreeLayouts.applySlots(widget.cards, slots);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = _board?.snapAlign == true;
    return ColoredBox(
      color: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
          child: Row(children: [
            if (widget.titleIcon != null) ...[
              Icon(widget.titleIcon, size: 16, color: widget.titleIconColor),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                widget.title ?? '',
                style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
            ),
            Semantics(
              button: true,
              label: snap ? 'Free place' : 'Align to grid',
              child: IconButton(
                tooltip: snap ? 'Free place' : 'Align to grid',
                iconSize: 20,
                color: snap ? const Color(0xFFFFD56A) : Colors.white70,
                onPressed: _toggleSnap,
                icon: Icon(snap ? Icons.grid_off_rounded : Icons.grid_view_rounded),
              ),
            ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _plane = Size(box.maxWidth, math.max(box.maxHeight, 640));
            _ensureSeed(_plane);
            final slots = widget.slotsFor(_plane, widget.cards);
            var contentH = _plane.height;
            var contentW = _plane.width;
            for (var i = 0; i < widget.cards.length; i++) {
              final s = slots.isEmpty ? const SgSlot(left: 0, top: 0, width: 140, height: 120) : slots[i % slots.length];
              contentH = math.max(contentH, widget.cards[i].dy + s.height + 24);
              contentW = math.max(contentW, widget.cards[i].dx + s.width + 24);
            }
            final plane = Size(contentW, contentH);
            final stack = Stack(clipBehavior: Clip.none, children: [
              if (widget.background != null) Positioned.fill(child: widget.background!),
              ..._tiles(plane, slots),
            ]);
            return ScrollConfiguration(
              behavior: const _NoBarScroll(),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: plane.width, height: plane.height, child: stack),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}
