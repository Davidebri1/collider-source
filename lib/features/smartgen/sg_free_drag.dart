import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

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

  /// Inset from the visible canvas frame used by [canvasGrid] slots and by
  /// throw / drag origin bounds so items never sit flush on the pane edge.
  static const double canvasEdgePad = 24;

  static List<SgSlot> canvasGrid(Size plane, int count, {double tileW = 128, double tileH = 96, double gap = 16, double pad = canvasEdgePad}) {
    return papers(plane, count, tileW: tileW, tileH: tileH, gapX: gap, gapY: gap, pad: pad);
  }

  static void seedScattered(List<SgCard> cards, List<SgSlot> base, {double jitter = 52, Size? viewport, Size itemSize = const Size(128, 96)}) {
    final pad = canvasEdgePad;
    final bounds = viewport != null ? originBoundsFor(viewport, itemSize) : null;
    for (var i = 0; i < cards.length; i++) {
      final s = base[i % base.length];
      final jx = ((i % 5) - 2) * (jitter * 0.55);
      final jy = ((i % 3) - 1) * (jitter * 0.7) + i * 10;
      var dx = s.left + jx + (i.isEven ? 18 : -14);
      var dy = s.top + jy;
      if (bounds != null) {
        dx = dx.clamp(bounds.left, bounds.right);
        dy = dy.clamp(bounds.top, bounds.bottom);
      } else {
        dx = dx.clamp(pad, 900);
        dy = dy.clamp(pad, 1400);
      }
      cards[i].dx = dx;
      cards[i].dy = dy;
    }
  }

  static Offset clampOrigin(Offset o, Size viewport, Size itemSize, {double pad = canvasEdgePad}) {
    final b = originBoundsFor(viewport, itemSize, pad: pad);
    return Offset(o.dx.clamp(b.left, b.right), o.dy.clamp(b.top, b.bottom));
  }

  static void applySlots(List<SgCard> cards, List<SgSlot> slots) {
    for (var i = 0; i < cards.length; i++) {
      final s = slots[i % slots.length];
      cards[i].dx = s.left;
      cards[i].dy = s.top;
    }
  }

  static void applyBoardSlots(List<SgBoard> boards, List<SgSlot> slots) {
    for (var i = 0; i < boards.length; i++) {
      final s = slots[i % slots.length];
      boards[i].dx = s.left;
      boards[i].dy = s.top;
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

  /// Allowed top-left origins so an [itemSize] tile stays fully inside [viewport]
  /// with [pad] (default [canvasEdgePad]) clear of the frame on every side.
  static Rect originBoundsFor(Size viewport, Size itemSize, {double pad = canvasEdgePad}) {
    final maxX = math.max(pad, viewport.width - itemSize.width - pad);
    final maxY = math.max(pad, viewport.height - itemSize.height - pad);
    return Rect.fromLTRB(pad, pad, maxX, maxY);
  }

  /// Slots whose tile fits fully inside [viewport] with [pad] clear of the frame.
  static List<SgSlot> inBoundsSlots(List<SgSlot> slots, Size viewport, {double pad = canvasEdgePad}) {
    return [
      for (final s in slots)
        if (s.left >= pad &&
            s.top >= pad &&
            s.left + s.width <= viewport.width - pad + 0.5 &&
            s.top + s.height <= viewport.height - pad + 0.5)
          s,
    ];
  }

  /// Glide with friction. When the coast would leave [originBounds] (or a
  /// [snapTarget] is set), settle with a SpringSimulation — soft edge bounce,
  /// same reading as iOS scroll rubber-banding. Returns the final origin.
  static Offset simulateThrow({
    required Offset start,
    required Offset velocity,
    Offset? snapTarget,
    Rect? originBounds,
    double friction = 0.135,
    double spring = 180,
    double damping = 18,
    double dt = 1 / 60,
    int maxSteps = 240,
  }) {
    final bounds = originBounds;
    var x = start.dx;
    var y = start.dy;
    final fx = FrictionSimulation(friction, x, velocity.dx);
    final fy = FrictionSimulation(friction, y, velocity.dy);
    var t = 0.0;
    var vx = velocity.dx;
    var vy = velocity.dy;
    var needSpring = snapTarget != null;
    for (var i = 0; i < maxSteps; i++) {
      t += dt;
      final nx = fx.x(t);
      final ny = fy.x(t);
      vx = fx.dx(t);
      vy = fy.dx(t);
      if (bounds != null) {
        final hitX = nx < bounds.left || nx > bounds.right;
        final hitY = ny < bounds.top || ny > bounds.bottom;
        if (hitX || hitY) {
          x = nx;
          y = ny;
          needSpring = true;
          break;
        }
      }
      x = nx;
      y = ny;
      if (fx.isDone(t) && fy.isDone(t)) break;
    }
    if (bounds != null) {
      // Coast ended outside (numerical / overshoot) — still spring home.
      if (x < bounds.left || x > bounds.right || y < bounds.top || y > bounds.bottom) {
        needSpring = true;
      }
    }
    if (!needSpring) return Offset(x, y);

    Offset target;
    if (snapTarget != null) {
      if (bounds != null) {
        target = Offset(
          snapTarget.dx.clamp(bounds.left, bounds.right),
          snapTarget.dy.clamp(bounds.top, bounds.bottom),
        );
      } else {
        target = snapTarget;
      }
    } else {
      assert(bounds != null);
      target = Offset(
        x.clamp(bounds!.left, bounds.right),
        y.clamp(bounds.top, bounds.bottom),
      );
    }

    final springDesc = SpringDescription(mass: 1, stiffness: spring, damping: damping);
    final sx = SpringSimulation(springDesc, x, target.dx, vx);
    final sy = SpringSimulation(springDesc, y, target.dy, vy);
    t = 0;
    for (var i = 0; i < maxSteps; i++) {
      t += dt;
      x = sx.x(t);
      y = sy.x(t);
      if (sx.isDone(t) && sy.isDone(t)) break;
    }
    // Snap exactly onto the settle target (spring asymptote).
    return target;
  }
}

/// Compact face for a board tile on the canvas — looks like its surface/kind.
class SgBoardTileFace extends StatelessWidget {
  const SgBoardTileFace({super.key, required this.board, this.dragging = false});
  final SgBoard board;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final surface = board.surface == SgSurface.kanban
        ? switch (board.kind) {
            SgBoardKind.kanban => SgSurface.kanban,
            SgBoardKind.calendar => SgSurface.calendar,
            SgBoardKind.whiteboard => SgSurface.whiteboard,
            _ => SgSurface.desk,
          }
        : board.surface;
    final (Color fill, IconData icon, Color ink) = switch (surface) {
      SgSurface.notebook => (const Color(0xFFE8DCC8), Icons.menu_book_rounded, const Color(0xFF3A2A18)),
      SgSurface.album => (const Color(0xFF1A1A1E), Icons.photo_library_rounded, Colors.white),
      SgSurface.vision => (const Color(0xFF2A1830), Icons.auto_awesome_mosaic_rounded, const Color(0xFFFFD56A)),
      SgSurface.corkboard => (const Color(0xFFB08A5A), Icons.push_pin_rounded, const Color(0xFF3A2410)),
      SgSurface.desk || SgSurface.portfolio => (const Color(0xFF8B5E3C), Icons.desk_rounded, Colors.white),
      SgSurface.clipboard => (const Color(0xFFD8D0C0), Icons.assignment_rounded, const Color(0xFF2A2A2A)),
      SgSurface.ledger => (const Color(0xFF2C3A2C), Icons.menu_book_outlined, const Color(0xFFE7E2D1)),
      SgSurface.binder => (const Color(0xFF3A4A6A), Icons.folder_rounded, Colors.white),
      SgSurface.slate || SgSurface.whiteboard => (const Color(0xFF2A2D35), Icons.edit_rounded, Colors.white),
      SgSurface.storyboard => (const Color(0xFF1E2430), Icons.view_carousel_rounded, Colors.white),
      SgSurface.calendar => (const Color(0xFF1E2A3A), Icons.calendar_month_rounded, Colors.white),
      SgSurface.swimlane => (const Color(0xFF1A2830), Icons.view_week_rounded, Colors.white),
      _ => (Color(board.background | 0xFF000000), Icons.dashboard_rounded, Colors.white),
    };
    return Material(
      elevation: dragging ? 8 : 3,
      borderRadius: BorderRadius.circular(10),
      color: fill,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: ink.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  surface.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appFont(fontSize: 11, fontWeight: FontWeight.w600, color: ink.withValues(alpha: 0.75)),
                ),
              ),
            ]),
            const Spacer(),
            Text(
              board.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
            ),
            if (surface == SgSurface.album || surface == SgSurface.vision) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        height: 22,
                        margin: EdgeInsets.only(right: i < 2 ? 3 : 0),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.18 + i * 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (surface == SgSurface.notebook) ...[
              const SizedBox(height: 6),
              for (var i = 0; i < 3; i++)
                Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 4),
                  color: ink.withValues(alpha: 0.2),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared free-drag plane + snap/align toggle (R23) with velocity throw.
class SgFreePlane extends StatefulWidget {
  const SgFreePlane({
    super.key,
    required this.store,
    required this.cards,
    required this.slotsFor,
    required this.tileBuilder,
    this.boards = const [],
    this.boardTileSize = const Size(132, 110),
    this.onOpenBoard,
    this.background,
    this.title,
    this.titleIcon,
    this.titleIconColor = Colors.white70,
    this.onOpen,
    this.trailing,
    this.showSnapToggle = true,
  });

  final SgStore store;
  final List<SgCard> cards;
  final List<SgBoard> boards;
  final Size boardTileSize;
  final void Function(SgBoard)? onOpenBoard;
  final List<SgSlot> Function(Size plane, List<SgCard> cards) slotsFor;
  final Widget Function(BuildContext context, SgCard card, int index, Size tile) tileBuilder;
  final Widget? background;
  final String? title;
  final IconData? titleIcon;
  final Color titleIconColor;
  final void Function(SgCard)? onOpen;
  final Widget? trailing;
  final bool showSnapToggle;

  @override
  State<SgFreePlane> createState() => _SgFreePlaneState();
}

class _SgFreePlaneState extends State<SgFreePlane> with TickerProviderStateMixin {
  bool _seeded = false;
  String? _dragging;
  Size _plane = const Size(440, 700);
  AnimationController? _throwCtrl;
  Offset _throwFrom = Offset.zero;
  Offset _throwTo = Offset.zero;
  String? _throwId;
  bool _throwIsBoard = false;

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
    _throwCtrl?.dispose();
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _ensureSeed(Size plane) {
    if (_seeded || (widget.cards.isEmpty && widget.boards.isEmpty) || _board == null) return;
    _seeded = true;
    final slots = widget.slotsFor(plane, widget.cards);
    final snap = _board!.snapAlign;
    final unplaced = widget.cards.isNotEmpty && SgFreeLayouts.looksUnplaced(widget.cards);
    if (!snap && !unplaced) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.store.touch(() {
        if (snap) {
          if (widget.cards.isNotEmpty) SgFreeLayouts.applySlots(widget.cards, slots);
          if (widget.boards.isNotEmpty) {
            final boardSlots = SgFreeLayouts.canvasGrid(plane, widget.boards.length, tileW: widget.boardTileSize.width, tileH: widget.boardTileSize.height);
            SgFreeLayouts.applyBoardSlots(widget.boards, boardSlots);
          }
        } else if (unplaced) {
          SgFreeLayouts.seedScattered(widget.cards, slots, viewport: plane);
        }
      });
    });
  }

  /// Keep every card / board tile clear of the frame by [canvasEdgePad].
  void _clampAllInViewport(Size viewport) {
    if (_board == null || (widget.cards.isEmpty && widget.boards.isEmpty)) return;
    final slots = widget.slotsFor(viewport, widget.cards);
    var dirty = false;
    for (var i = 0; i < widget.cards.length; i++) {
      final c = widget.cards[i];
      final tile = slots.isEmpty
          ? const Size(140, 120)
          : Size(slots[i % slots.length].width, slots[i % slots.length].height);
      final next = SgFreeLayouts.clampOrigin(Offset(c.dx, c.dy), viewport, tile);
      if ((next.dx - c.dx).abs() > 0.5 || (next.dy - c.dy).abs() > 0.5) {
        dirty = true;
        break;
      }
    }
    if (!dirty) {
      for (final b in widget.boards) {
        final next = SgFreeLayouts.clampOrigin(Offset(b.dx, b.dy), viewport, widget.boardTileSize);
        if ((next.dx - b.dx).abs() > 0.5 || (next.dy - b.dy).abs() > 0.5) {
          dirty = true;
          break;
        }
      }
    }
    if (!dirty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.store.touch(() {
        for (var i = 0; i < widget.cards.length; i++) {
          final c = widget.cards[i];
          final tile = slots.isEmpty
              ? const Size(140, 120)
              : Size(slots[i % slots.length].width, slots[i % slots.length].height);
          final next = SgFreeLayouts.clampOrigin(Offset(c.dx, c.dy), viewport, tile);
          c.dx = next.dx;
          c.dy = next.dy;
        }
        for (final b in widget.boards) {
          final next = SgFreeLayouts.clampOrigin(Offset(b.dx, b.dy), viewport, widget.boardTileSize);
          b.dx = next.dx;
          b.dy = next.dy;
        }
      });
    });
  }

  void _startThrow({
    required String id,
    required bool isBoard,
    required Offset from,
    required Offset velocity,
    required Size viewport,
    required Size itemSize,
    required List<SgSlot> slots,
    int preferredSlot = 0,
  }) {
    final bounds = SgFreeLayouts.originBoundsFor(viewport, itemSize);
    final fitSlots = SgFreeLayouts.inBoundsSlots(slots, viewport);
    Offset? snapTarget;
    final snap = _board?.snapAlign == true && fitSlots.isNotEmpty;
    // Predict glide; spring-settle inside viewport (and into snap slot when on).
    late final Offset end;
    if (snap) {
      final coast = SgFreeLayouts.simulateThrow(start: from, velocity: velocity, originBounds: bounds);
      final nearest = SgFreeLayouts.nearestSlot(coast, fitSlots);
      final preferred = preferredSlot < fitSlots.length ? preferredSlot : 0;
      final pick = (coast - fitSlots[preferred].origin).distance < 72 ? preferred : nearest;
      snapTarget = fitSlots[pick].origin;
      end = SgFreeLayouts.simulateThrow(
        start: from,
        velocity: velocity,
        snapTarget: snapTarget,
        originBounds: bounds,
      );
    } else {
      end = SgFreeLayouts.simulateThrow(start: from, velocity: velocity, originBounds: bounds);
    }

    _throwCtrl?.dispose();
    _throwFrom = from;
    _throwTo = end;
    _throwId = id;
    _throwIsBoard = isBoard;
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _throwCtrl = ctrl;
    ctrl.addListener(() {
      final t = Curves.easeOutCubic.transform(ctrl.value);
      final pos = Offset.lerp(_throwFrom, _throwTo, t)!;
      widget.store.touch(() {
        if (_throwIsBoard) {
          for (final b in widget.boards) {
            if (b.id == _throwId) {
              b.dx = pos.dx;
              b.dy = pos.dy;
              break;
            }
          }
        } else {
          for (final c in widget.cards) {
            if (c.id == _throwId) {
              c.dx = pos.dx;
              c.dy = pos.dy;
              break;
            }
          }
        }
      });
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.store.touch(() {
          if (_throwIsBoard) {
            for (final b in widget.boards) {
              if (b.id == _throwId) {
                b.dx = _throwTo.dx;
                b.dy = _throwTo.dy;
                break;
              }
            }
          } else {
            for (final c in widget.cards) {
              if (c.id == _throwId) {
                c.dx = _throwTo.dx;
                c.dy = _throwTo.dy;
                break;
              }
            }
          }
        });
        setState(() {
          _throwId = null;
          _dragging = null;
        });
      }
    });
    ctrl.forward(from: 0);
  }

  List<Widget> _tiles(Size plane, List<SgSlot> slots) {
    final out = <Widget>[];
    for (var i = 0; i < widget.cards.length; i++) {
      final card = widget.cards[i];
      final slot = slots.isEmpty ? const SgSlot(left: 0, top: 0, width: 140, height: 120) : slots[i % slots.length];
      final tile = Size(slot.width, slot.height);
      final animating = _throwId == card.id && !_throwIsBoard;
      out.add(AnimatedPositioned(
        key: ValueKey(card.id),
        duration: (_dragging == card.id || animating) ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        left: card.dx,
        top: card.dy,
        width: tile.width,
        height: tile.height,
        child: GestureDetector(
          onTap: widget.onOpen == null ? null : () => widget.onOpen!(card),
          onPanStart: (_) => setState(() => _dragging = card.id),
          onPanUpdate: (d) {
            final ob = SgFreeLayouts.originBoundsFor(_plane, tile);
            widget.store.touch(() {
              card.dx = (card.dx + d.delta.dx).clamp(ob.left, ob.right);
              card.dy = (card.dy + d.delta.dy).clamp(ob.top, ob.bottom);
            });
          },
          onPanEnd: (details) {
            final v = details.velocity.pixelsPerSecond;
            if (v.distance > 80) {
              // Web pointer samples under-report flick speed; keep the feel snappy.
              final boosted = Offset(v.dx * 2.4, v.dy * 2.4);
              _startThrow(
                id: card.id,
                isBoard: false,
                from: Offset(card.dx, card.dy),
                velocity: boosted,
                viewport: _plane,
                itemSize: tile,
                slots: slots,
                preferredSlot: i,
              );
            } else if (_board?.snapAlign == true && slots.isNotEmpty) {
              final preferred = i < slots.length ? i : 0;
              final nearest = SgFreeLayouts.nearestSlot(Offset(card.dx, card.dy), slots);
              final pick = (Offset(card.dx, card.dy) - slots[preferred].origin).distance < 72 ? preferred : nearest;
              widget.store.touch(() {
                card.dx = slots[pick].left;
                card.dy = slots[pick].top;
              });
              setState(() => _dragging = null);
            } else {
              setState(() => _dragging = null);
            }
          },
          onPanCancel: () => setState(() => _dragging = null),
          child: Transform.scale(
            scale: _dragging == card.id ? 1.04 : 1,
            child: widget.tileBuilder(context, card, i, tile),
          ),
        ),
      ));
    }

    final boardSlots = SgFreeLayouts.canvasGrid(plane, math.max(widget.boards.length, 1), tileW: widget.boardTileSize.width, tileH: widget.boardTileSize.height);
    for (var i = 0; i < widget.boards.length; i++) {
      final b = widget.boards[i];
      final animating = _throwId == b.id && _throwIsBoard;
      out.add(AnimatedPositioned(
        key: ValueKey('board-${b.id}'),
        duration: (_dragging == b.id || animating) ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        left: b.dx,
        top: b.dy,
        width: widget.boardTileSize.width,
        height: widget.boardTileSize.height,
        child: GestureDetector(
          onTap: widget.onOpenBoard == null ? null : () => widget.onOpenBoard!(b),
          onPanStart: (_) => setState(() => _dragging = b.id),
          onPanUpdate: (d) {
            final ob = SgFreeLayouts.originBoundsFor(_plane, widget.boardTileSize);
            widget.store.touch(() {
              b.dx = (b.dx + d.delta.dx).clamp(ob.left, ob.right);
              b.dy = (b.dy + d.delta.dy).clamp(ob.top, ob.bottom);
            });
          },
          onPanEnd: (details) {
            final v = details.velocity.pixelsPerSecond;
            if (v.distance > 80) {
              final boosted = Offset(v.dx * 2.4, v.dy * 2.4);
              _startThrow(
                id: b.id,
                isBoard: true,
                from: Offset(b.dx, b.dy),
                velocity: boosted,
                viewport: _plane,
                itemSize: widget.boardTileSize,
                slots: boardSlots,
                preferredSlot: i,
              );
            } else if (_board?.snapAlign == true && boardSlots.isNotEmpty) {
              final preferred = i < boardSlots.length ? i : 0;
              final nearest = SgFreeLayouts.nearestSlot(Offset(b.dx, b.dy), boardSlots);
              final pick = (Offset(b.dx, b.dy) - boardSlots[preferred].origin).distance < 72 ? preferred : nearest;
              widget.store.touch(() {
                b.dx = boardSlots[pick].left;
                b.dy = boardSlots[pick].top;
              });
              setState(() => _dragging = null);
            } else {
              setState(() => _dragging = null);
            }
          },
          onPanCancel: () => setState(() => _dragging = null),
          child: Transform.scale(
            scale: _dragging == b.id ? 1.04 : 1,
            child: SgBoardTileFace(board: b, dragging: _dragging == b.id),
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
      if (next) {
        SgFreeLayouts.applySlots(widget.cards, slots);
        if (widget.boards.isNotEmpty) {
          final boardSlots = SgFreeLayouts.canvasGrid(_plane, widget.boards.length, tileW: widget.boardTileSize.width, tileH: widget.boardTileSize.height);
          SgFreeLayouts.applyBoardSlots(widget.boards, boardSlots);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snap = _board?.snapAlign == true;
    return ColoredBox(
      color: Colors.transparent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 40,
          child: Stack(alignment: Alignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.titleIcon != null) ...[
                Icon(widget.titleIcon, size: 16, color: widget.titleIconColor),
                const SizedBox(width: 6),
              ],
              Text(
                widget.title ?? '',
                textAlign: TextAlign.center,
                style: appFont(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70),
              ),
            ]),
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.trailing != null) widget.trailing!,
                if (widget.showSnapToggle)
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
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _plane = Size(box.maxWidth, math.max(box.maxHeight, 1));
            _ensureSeed(_plane);
            _clampAllInViewport(_plane);
            final slots = widget.slotsFor(_plane, widget.cards);
            var contentH = _plane.height;
            var contentW = _plane.width;
            for (var i = 0; i < widget.cards.length; i++) {
              final s = slots.isEmpty ? const SgSlot(left: 0, top: 0, width: 140, height: 120) : slots[i % slots.length];
              contentH = math.max(contentH, widget.cards[i].dy + s.height + 24);
              contentW = math.max(contentW, widget.cards[i].dx + s.width + 24);
            }
            for (final b in widget.boards) {
              contentH = math.max(contentH, b.dy + widget.boardTileSize.height + 24);
              contentW = math.max(contentW, b.dx + widget.boardTileSize.width + 24);
            }
            final plane = Size(contentW, contentH);
            // Clip to the visible canvas — throw spring may briefly overshoot
            // during settle; the item must never paint past the pane edge.
            final stack = ClipRect(
              child: Stack(clipBehavior: Clip.hardEdge, children: [
                if (widget.background != null) Positioned.fill(child: widget.background!),
                ..._tiles(plane, slots),
              ]),
            );
            // Prefer a non-scrolling plane so card pans / throws are not stolen by
            // nested ScrollViews. Only scroll when content truly overflows.
            final overflow = plane.width > box.maxWidth + 1 || plane.height > box.maxHeight + 1;
            if (!overflow) {
              return SizedBox(width: box.maxWidth, height: box.maxHeight, child: stack);
            }
            return ScrollConfiguration(
              behavior: const _NoBarScroll(),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
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
