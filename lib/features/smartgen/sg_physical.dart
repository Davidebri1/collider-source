import 'package:flutter/material.dart';

import '../../core/theme/app_font.dart';
import 'sg_assets.dart';
import 'sg_model.dart';
import 'sg_object_face.dart';

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
  Offset? _cardLocal;
  int? _activePointer;
  String _gesture = '';
  Offset _lastGlobal = Offset.zero;

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
        Positioned.fill(child: sgBoardFace(b)),
        for (var i = 0; i < b.canvases.length; i++) _canvas(b, b.canvases[i], i, size),
        for (final c in b.cards)
          if (c.canvasId.isEmpty)
            Positioned(left: 8, bottom: 8, child: _cardFace(c)),
        if (_dragCard != null && _cardLocal != null && b.cards.any((c) => c.id == _dragCard))
          Positioned(
            left: _cardLocal!.dx,
            top: _cardLocal!.dy,
            child: IgnorePointer(child: Opacity(opacity: 0.92, child: _cardFace(b.cards.firstWhere((c) => c.id == _dragCard)))),
          ),
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
    final cards = [for (final c in b.cards) if (c.canvasId == canvas.id) c];
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
                  sgObjectFace(canvas.kind),
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(
                        height: 22,
                        child: Row(children: [
                          Expanded(
                            child: Semantics(
                              container: true,
                              button: true,
                              label: 'Move ${canvas.kind}',
                              child: ExcludeSemantics(
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerDown: (e) => _beginFrame(e, canvas, size, frame, 'move'),
                                  onPointerMove: (e) => _updateFrame(e, canvas, size),
                                  onPointerUp: (e) => _endFrame(e, canvas),
                                  onPointerCancel: (e) => _endFrame(e, canvas),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Text(canvas.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19))),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Remove ${canvas.kind}',
                            child: GestureDetector(
                              onTap: () => widget.store.removeCanvas(canvas.id),
                              child: const SizedBox(width: 22, height: 22, child: Icon(Icons.close, size: 14, color: Color(0xFF1C1B19))),
                            ),
                          ),
                        ]),
                      ),
                      Expanded(
                        child: Padding(
                          padding: sgObjectInsets(canvas.kind),
                          child: _working(b, canvas, cards),
                        ),
                      ),
                    ]),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                      child: Semantics(
                      container: true,
                      button: true,
                      label: 'Resize ${canvas.kind}',
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _beginFrame(e, canvas, size, frame, 'resize'),
                        onPointerMove: (e) => _updateFrame(e, canvas, size),
                        onPointerUp: (e) => _endFrame(e, canvas),
                        onPointerCancel: (e) => _endFrame(e, canvas),
                        child: const SizedBox(width: 36, height: 36, child: CustomPaint(painter: _ResizeGripPainter())),
                      ),
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

  void _beginFrame(PointerDownEvent e, SgCanvas canvas, Size size, Rect frame, String mode) {
    _activePointer = e.pointer;
    _gesture = mode;
    _lastGlobal = e.position;
    if (canvas.x < 0) canvas.x = frame.left / size.width;
    if (canvas.y < 0) canvas.y = frame.top / size.height;
    if (canvas.w < 0) canvas.w = frame.width / size.width;
    if (canvas.h < 0) canvas.h = frame.height / size.height;
  }

  void _updateFrame(PointerMoveEvent e, SgCanvas canvas, Size size) {
    if (e.pointer != _activePointer || size.width <= 0 || size.height <= 0) return;
    final dx = (e.position.dx - _lastGlobal.dx) / size.width;
    final dy = (e.position.dy - _lastGlobal.dy) / size.height;
    _lastGlobal = e.position;
    setState(() {
      if (_gesture == 'move') {
        canvas.x = (canvas.x + dx).clamp(0.0, 0.72);
        canvas.y = (canvas.y + dy).clamp(0.0, 0.72);
      } else if (_gesture == 'resize') {
        canvas.w = (canvas.w + dx).clamp(0.24, 0.96);
        canvas.h = (canvas.h + dy).clamp(0.18, 0.9);
      }
    });
  }

  void _endFrame(PointerEvent e, SgCanvas canvas) {
    if (e.pointer != _activePointer) return;
    _activePointer = null;
    widget.store.placeCanvasFrame(canvas.id, canvas.x, canvas.y, canvas.w, canvas.h);
  }

  Widget _working(SgBoard b, SgCanvas canvas, List<SgCard> cards) {
    return switch (canvas.kind) {
      'Kanban Board widget' || 'Swimlane vertical' || 'Swimlane horizontal' => _lanes(b, cards, vertical: canvas.kind != 'Swimlane horizontal'),
      // The face already draws the chart, month, or portrait. The card sits
      // at the bottom so that drawing stays visible.
      'Calendar Widget' || 'Chart' || 'Name Photo Description' => Align(alignment: Alignment.bottomLeft, child: _cards(cards)),
      _ => _cards(cards),
    };
  }

  Widget _cards(List<SgCard> cards) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in cards) _cardFace(c)]);
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

  void _dropCard(SgCard c, Offset global) {
    if (_acceptedElsewhere) {
      _acceptedElsewhere = false;
      setState(() => _dragCard = null);
      return;
    }
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    final board = widget.store.board;
    if (box != null && board != null) {
      final local = box.globalToLocal(global);
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
    setState(() {
      _dragCard = null;
      _cardLocal = null;
    });
  }

  void _cardDown(SgCard c, PointerDownEvent e) {
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _dragCard = c.id;
      _cardLocal = box?.globalToLocal(e.position) ?? Offset.zero;
    });
  }

  void _cardMove(PointerMoveEvent e) {
    if (_dragCard == null) return;
    final box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() => _cardLocal = box?.globalToLocal(e.position));
  }

  Widget _cardFace(SgCard c) {
    final ctrl = _title(c);
    return GestureDetector(
      excludeFromSemantics: true,
      onDoubleTap: () => widget.onOpen(c),
      child: _face(c, ctrl, editing: true),
    );
  }

  Widget _face(SgCard c, TextEditingController ctrl, {required bool editing}) {
    return Opacity(
      opacity: _dragCard == c.id ? 0.35 : 1,
      child: Container(
      width: 124,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        image: const DecorationImage(image: AssetImage('assets/smartgen/paper.jpg'), fit: BoxFit.cover),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1))],
        border: const Border(left: BorderSide(color: Color(0xFF3D7A6A), width: 3)),
      ),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Row(children: [
        Semantics(
          container: true,
          button: true,
          label: 'Drag ${c.title}',
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _cardDown(c, e),
            onPointerMove: _cardMove,
            onPointerUp: (e) => _dropCard(c, e.position),
            onPointerCancel: (e) => _dropCard(c, e.position),
            child: const SizedBox(width: 28, height: 22, child: ColoredBox(color: Color(0xFF3D7A6A))),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: editing
              ? TextField(
                  controller: ctrl,
                  style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19)),
                  decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
                  onSubmitted: (v) => widget.store.touch(() => c.title = v.trim().isEmpty ? c.title : v.trim()),
                  onTapOutside: (_) => widget.store.touch(() => c.title = ctrl.text.trim().isEmpty ? c.title : ctrl.text.trim()),
                )
              : Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1C1B19))),
        ),
      ]),
      ),
    ),
    );
  }
}

class _ResizeGripPainter extends CustomPainter {
  const _ResizeGripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1B19)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width - 8, size.height - 4), Offset(size.width - 4, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 4, size.height - 8), Offset(size.width - 4, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 14, size.height - 4), Offset(size.width - 4, size.height - 14), paint);
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
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/smartgen/desk.jpg', fit: BoxFit.cover),
        Padding(padding: const EdgeInsets.all(4), child: sgObjectFace(kind)),
      ]),
    );
  }
}
