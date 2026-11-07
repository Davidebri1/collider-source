import 'package:flutter/material.dart';

import '../../core/theme/app_font.dart';
import 'sg_assets.dart';
import 'sg_model.dart';

/// Top-down photographic board. Canvas types sit on it as objects and hold cards.
class SgPhysicalStage extends StatefulWidget {
  const SgPhysicalStage({super.key, required this.store, required this.onOpen});
  final SgStore store;
  final void Function(SgCard) onOpen;

  @override
  State<SgPhysicalStage> createState() => _SgPhysicalStageState();
}

class _SgPhysicalStageState extends State<SgPhysicalStage> {
  final Map<String, TextEditingController> _titles = {};
  final GlobalKey _stageKey = GlobalKey();
  String? _dragCard;
  bool _acceptedElsewhere = false;
  double _ox = 0, _oy = 0;

  @override
  void dispose() {
    for (final c in _titles.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _title(SgCard c) => _titles.putIfAbsent(c.id, () => TextEditingController(text: c.title));

  Rect _frame(SgCanvas c, int index, Size size) {
    final x = c.x >= 0 ? c.x : 0.04 + (index % 2) * 0.48;
    final y = c.y >= 0 ? c.y : (0.05 + (index ~/ 2) * 0.36).clamp(0.04, 0.62);
    final w = c.w >= 0 ? c.w : 0.44;
    final h = c.h >= 0 ? c.h : 0.32;
    return Rect.fromLTWH(x * size.width, y * size.height, w * size.width, h * size.height);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final b = store.board!;
    final others = [for (final ob in store.boards) if (ob.id != b.id) ob];
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return Stack(key: _stageKey, fit: StackFit.expand, children: [
        Positioned.fill(child: _BoardPhoto(kind: b.kind)),
        for (var i = 0; i < b.canvases.length; i++) _canvas(b, b.canvases[i], i, size),
        for (final c in b.cards)
          if (c.canvasId.isEmpty && c.id != _dragCard)
            Positioned(left: 8, bottom: 8, child: _cardFace(c)),
        if (others.isNotEmpty)
          Positioned(
            left: 8,
            right: 8,
            top: 6,
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final ob in others.take(4)) _boardChip(ob)],
            ),
          ),
      ]);
    });
  }

  Widget _boardChip(SgBoard ob) {
    return DragTarget<String>(
      onAcceptWithDetails: (d) {
        _acceptedElsewhere = true;
        widget.store.transferCard(d.data, boardId: ob.id);
        setState(() => _dragCard = null);
      },
      builder: (context, candidate, rejected) {
        return Container(
          width: 108,
          margin: const EdgeInsets.only(right: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: candidate.isEmpty ? const Color(0x66FFFFFF) : const Color(0xFFFFD56A), width: 1.5),
            image: DecorationImage(image: AssetImage(sgBoardPhoto(ob.kind)), fit: BoxFit.cover),
          ),
          child: Text(ob.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        );
      },
    );
  }

  Widget _canvas(SgBoard b, SgCanvas canvas, int index, Size size) {
    final frame = _frame(canvas, index, size);
    final cards = [for (final c in b.cards) if (c.canvasId == canvas.id && c.id != _dragCard) c];
    return Positioned(
      left: frame.left,
      top: frame.top,
      width: frame.width,
      height: frame.height,
      child: DragTarget<String>(
        onAcceptWithDetails: (d) {
          _acceptedElsewhere = true;
          final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
          final local = box?.globalToLocal(d.offset) ?? Offset(frame.left + 8, frame.top + 24);
          widget.store.transferCard(
            d.data,
            boardId: b.id,
            canvasId: canvas.id,
            fx: ((local.dx - frame.left) / frame.width).clamp(0.04, 0.62),
            fy: ((local.dy - frame.top) / frame.height).clamp(0.18, 0.62),
          );
          setState(() => _dragCard = null);
        },
        builder: (context, candidate, rejected) {
          return SizedBox(
            width: frame.width,
            height: frame.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: candidate.isEmpty ? const Color(0xAA1A120C) : const Color(0xFFFFD56A), width: candidate.isEmpty ? 1 : 2),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Stack(fit: StackFit.expand, children: [
                  _CanvasSurface(kind: canvas.kind),
                  if (canvas.kind == 'Notebook') const CustomPaint(painter: _RulePainter()),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      GestureDetector(
                        onPanStart: (_) {
                          _ox = canvas.x < 0 ? frame.left / size.width : canvas.x;
                          _oy = canvas.y < 0 ? frame.top / size.height : canvas.y;
                        },
                        onPanUpdate: (d) {
                          setState(() {
                            canvas.x = (_ox + d.delta.dx / size.width).clamp(0.0, 0.72);
                            canvas.y = (_oy + d.delta.dy / size.height).clamp(0.0, 0.72);
                            _ox = canvas.x;
                            _oy = canvas.y;
                            canvas.w = canvas.w < 0 ? frame.width / size.width : canvas.w;
                            canvas.h = canvas.h < 0 ? frame.height / size.height : canvas.h;
                          });
                        },
                        onPanEnd: (_) => widget.store.placeCanvasFrame(canvas.id, canvas.x, canvas.y, canvas.w < 0 ? 0.44 : canvas.w, canvas.h < 0 ? 0.32 : canvas.h),
                        child: SizedBox(
                          height: 20,
                          child: Row(children: [
                            Expanded(child: Text(canvas.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19)))),
                            Tooltip(
                              message: 'Close',
                              child: GestureDetector(
                                onTap: () => widget.store.removeCanvas(canvas.id),
                                child: const Icon(Icons.close, size: 14, color: Color(0xFF1C1B19)),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      Expanded(child: _working(b, canvas, cards)),
                    ]),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onPanUpdate: (d) {
                        final w = ((canvas.w < 0 ? frame.width / size.width : canvas.w) * size.width + d.delta.dx) / size.width;
                        final h = ((canvas.h < 0 ? frame.height / size.height : canvas.h) * size.height + d.delta.dy) / size.height;
                        setState(() {
                          canvas.w = w.clamp(0.24, 0.96);
                          canvas.h = h.clamp(0.18, 0.9);
                          if (canvas.x < 0) canvas.x = frame.left / size.width;
                          if (canvas.y < 0) canvas.y = frame.top / size.height;
                        });
                      },
                      onPanEnd: (_) => widget.store.placeCanvasFrame(canvas.id, canvas.x, canvas.y, canvas.w, canvas.h),
                      child: const SizedBox(width: 16, height: 16),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _working(SgBoard b, SgCanvas canvas, List<SgCard> cards) {
    return switch (canvas.kind) {
      'Kanban Board widget' || 'Swimlane vertical' || 'Swimlane horizontal' => _lanes(b, cards, vertical: canvas.kind != 'Swimlane horizontal'),
      'Calendar Widget' => _month(),
      'Chart' => _chart(b),
      _ => _cards(cards),
    };
  }

  Widget _cards(List<SgCard> cards) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final c in cards) _cardFace(c)],
    );
  }

  Widget _lanes(SgBoard b, List<SgCard> cards, {required bool vertical}) {
    final lists = b.orderedLists;
    final lanes = [
      for (final list in lists)
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0x22000000)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(list.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19))),
              for (final c in cards.where((c) => c.listId == list.id).take(3))
                Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 9, color: const Color(0xFF1C1B19))),
            ]),
          ),
        ),
    ];
    if (vertical) return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: lanes);
    return Column(children: lanes);
  }

  Widget _month() {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    return Wrap(children: [
      for (var d = 1; d <= days; d++)
        SizedBox(width: 16, height: 14, child: Text('$d', style: appFont(fontSize: 8, color: const Color(0xFF1C1B19)))),
    ]);
  }

  Widget _chart(SgBoard b) {
    final counts = <SgType, int>{};
    for (final c in b.cards) {
      counts[c.type] = (counts[c.type] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.expand();
    final maxN = counts.values.fold<int>(1, (m, n) => n > m ? n : m);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (final e in counts.entries.take(6))
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            SizedBox(height: 36 * e.value / maxN, child: const ColoredBox(color: Color(0xFF3D7A6A))),
            Text(e.key.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 7, color: const Color(0xFF1C1B19))),
          ]),
        ),
    ]);
  }

  Widget _cardFace(SgCard c) {
    final ctrl = _title(c);
    return LongPressDraggable<String>(
      data: c.id,
      feedback: Material(color: Colors.transparent, child: _face(c, ctrl, editing: false)),
      childWhenDragging: const SizedBox(width: 108, height: 36),
      onDragStarted: () => setState(() => _dragCard = c.id),
      onDragEnd: (d) {
        if (_acceptedElsewhere) {
          _acceptedElsewhere = false;
          setState(() => _dragCard = null);
          return;
        }
        final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
        final board = widget.store.board;
        if (box != null && board != null) {
          final local = box.globalToLocal(d.offset);
          SgCanvas? hit;
          var hitIndex = 0;
          for (var i = board.canvases.length - 1; i >= 0; i--) {
            if (_frame(board.canvases[i], i, box.size).contains(local)) {
              hit = board.canvases[i];
              hitIndex = i;
              break;
            }
          }
          if (hit != null) {
            final frame = _frame(hit, hitIndex, box.size);
            widget.store.transferCard(
              c.id,
              boardId: board.id,
              canvasId: hit.id,
              fx: ((local.dx - frame.left) / frame.width).clamp(0.02, 0.62),
              fy: ((local.dy - frame.top) / frame.height).clamp(0.16, 0.7),
            );
          }
        }
        setState(() => _dragCard = null);
      },
      child: GestureDetector(onDoubleTap: () => widget.onOpen(c), child: _face(c, ctrl, editing: true)),
    );
  }

  Widget _face(SgCard c, TextEditingController ctrl, {required bool editing}) {
    return Container(
      width: 108,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        image: const DecorationImage(image: AssetImage('assets/smartgen/paper.jpg'), fit: BoxFit.cover),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1))],
        border: const Border(left: BorderSide(color: Color(0xFF3D7A6A), width: 3)),
      ),
      child: editing
          ? TextField(
              controller: ctrl,
              style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19)),
              decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
              onSubmitted: (v) => widget.store.touch(() => c.title = v.trim().isEmpty ? c.title : v.trim()),
            )
          : Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19))),
    );
  }
}

class _BoardPhoto extends StatelessWidget {
  const _BoardPhoto({required this.kind});
  final SgBoardKind kind;

  @override
  Widget build(BuildContext context) {
    final photo = AssetImage(sgBoardPhoto(kind));
    if (kind == SgBoardKind.roundTable) {
      return Stack(fit: StackFit.expand, children: [
        const Image(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover),
        Center(child: AspectRatio(aspectRatio: 1, child: ClipOval(child: Image(image: photo, fit: BoxFit.cover)))),
      ]);
    }
    if (kind == SgBoardKind.nightStand) {
      return Stack(fit: StackFit.expand, children: [
        const Image(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover),
        Center(child: FractionallySizedBox(widthFactor: 0.62, heightFactor: 0.42, child: Image(image: photo, fit: BoxFit.cover))),
      ]);
    }
    return Image(image: photo, fit: BoxFit.cover, filterQuality: FilterQuality.high);
  }
}

class _CanvasSurface extends StatelessWidget {
  const _CanvasSurface({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final photo = AssetImage(sgCanvasPhoto(kind));
    if (kind == 'Glass') {
      return const Image(image: AssetImage('assets/smartgen/desk.jpg'), fit: BoxFit.cover, opacity: AlwaysStoppedAnimation(0.55));
    }
    if (kind == 'Mirror') {
      return Stack(fit: StackFit.expand, children: [
        Image(image: photo, fit: BoxFit.cover),
        const DecoratedBox(decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Color(0xFF3A2A1C), width: 6)))),
      ]);
    }
    return Image(image: photo, fit: BoxFit.cover, filterQuality: FilterQuality.medium);
  }
}

class _RulePainter extends CustomPainter {
  const _RulePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x334A6FA5)
      ..strokeWidth = 1;
    for (var y = 28.0; y < size.height; y += 14) {
      canvas.drawLine(Offset(8, y), Offset(size.width - 6, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Library thumbnail: the type's photographic working surface.
class SgPhotoThumb extends StatelessWidget {
  const SgPhotoThumb({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(sgCanvasPhoto(kind), fit: BoxFit.cover),
    );
  }
}
