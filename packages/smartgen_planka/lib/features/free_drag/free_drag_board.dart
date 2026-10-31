import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/models/planka_card.dart';
import 'package:planka_app/models/planka_list.dart';

String _fmtDue(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m != null) return '${m.group(3)}.${m.group(2)}.${m.group(1)}';
  return s;
}

class _NoBarScroll extends ScrollBehavior {
  const _NoBarScroll();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Free-drag canvas over board cards when Align (snapAlign) is off.
class FreeDragBoard extends StatefulWidget {
  const FreeDragBoard({
    super.key,
    required this.lists,
    required this.onOpenCard,
    this.cardBuilder,
  });

  final List<PlankaList> lists;
  final void Function(PlankaCard card) onOpenCard;
  final Widget Function(BuildContext context, PlankaCard card)? cardBuilder;

  @override
  State<FreeDragBoard> createState() => _FreeDragBoardState();
}

class _FreeDragBoardState extends State<FreeDragBoard> {
  String? _dragging;
  bool _seeded = false;
  Size _plane = const Size(440, 800);

  List<PlankaCard> get _cards {
    final out = <PlankaCard>[];
    for (final l in widget.lists) {
      out.addAll(l.cards);
    }
    return out;
  }

  void _ensureSeed(Size plane) {
    if (_seeded) return;
    final store = PlankaStore.instance;
    final cards = _cards;
    if (cards.isEmpty) return;
    _seeded = true;
    final need = cards.any((c) => !store.cardFreePos.containsKey(c.id));
    if (!need) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gap = 12.0;
      final tileW = 160.0;
      final tileH = 96.0;
      for (var i = 0; i < cards.length; i++) {
        final c = cards[i];
        if (store.cardFreePos.containsKey(c.id)) continue;
        final col = i % 2;
        final row = i ~/ 2;
        final jx = ((i % 5) - 2) * 10.0;
        final jy = ((i % 3) - 1) * 14.0;
        store.setCardFreePos(
          c.id,
          (12 + col * (tileW + gap) + jx + (i.isEven ? 8 : -6)).clamp(0, 900),
          (12 + row * (tileH + gap) + jy).clamp(0, 1400),
        );
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final cards = _cards;
    return LayoutBuilder(builder: (context, box) {
      _plane = Size(box.maxWidth, math.max(box.maxHeight, 640));
      _ensureSeed(_plane);
      var contentW = _plane.width;
      var contentH = _plane.height;
      for (final c in cards) {
        final pos = store.cardFreePos[c.id] ?? const {'dx': 12.0, 'dy': 12.0};
        contentW = math.max(contentW, (pos['dx'] ?? 0) + 180);
        contentH = math.max(contentH, (pos['dy'] ?? 0) + 140);
      }
      final plane = Size(contentW, contentH);
      return ScrollConfiguration(
        behavior: const _NoBarScroll(),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: plane.width,
              height: plane.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < cards.length; i++)
                    _tile(store, cards[i], plane),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _tile(PlankaStore store, PlankaCard card, Size plane) {
    final pos = store.cardFreePos[card.id] ?? const {'dx': 12.0, 'dy': 12.0};
    final dx = pos['dx'] ?? 12.0;
    final dy = pos['dy'] ?? 12.0;
    final cover = store.cardCoverColors[card.id];
    return AnimatedPositioned(
      key: ValueKey(card.id),
      duration: _dragging == card.id ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      left: dx,
      top: dy,
      width: 168,
      child: GestureDetector(
        onTap: () => widget.onOpenCard(card),
        onPanStart: (_) => setState(() => _dragging = card.id),
        onPanUpdate: (d) {
          store.setCardFreePos(
            card.id,
            (dx + d.delta.dx).clamp(0, math.max(0, plane.width - 40)),
            (dy + d.delta.dy).clamp(0, math.max(0, plane.height - 40)),
          );
          setState(() {});
        },
        onPanEnd: (_) {
          if (store.snapAlign) {
            // snap to loose 2-col grid
            final col = (dx / 180).round().clamp(0, 4);
            final row = (dy / 110).round().clamp(0, 20);
            store.setCardFreePos(card.id, 12 + col * 180.0, 12 + row * 110.0);
          }
          setState(() => _dragging = null);
        },
        onPanCancel: () => setState(() => _dragging = null),
        child: Transform.scale(
          scale: _dragging == card.id ? 1.04 : 1,
          child: widget.cardBuilder?.call(context, card) ??
              Material(
                elevation: _dragging == card.id ? 6 : 2,
                borderRadius: BorderRadius.circular(8),
                color: cover != null ? Color(cover) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (card.labels.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final l in card.labels.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(l.name, style: const TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                          ],
                        ),
                      Text(card.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (card.dueDate != null && card.dueDate!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_fmtDue(card.dueDate), style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
