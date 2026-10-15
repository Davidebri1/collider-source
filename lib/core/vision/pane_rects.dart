import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// David (Oct 15): no side nav may ever overlap a pane.
///
/// Every pane reports its on-screen rect here ([PaneRect]); the shell places
/// the side nav with [placeSideNav], which only returns a slot that does not
/// intersect any reported rect (test/side_nav_clear_test.dart).
class PaneRects {
  PaneRects._();
  static final ValueNotifier<Map<Object, Rect>> rects = ValueNotifier(const {});

  static void _set(Object id, Rect? r) {
    final m = Map<Object, Rect>.of(rects.value);
    if (r == null) {
      if (m.remove(id) == null) return;
    } else {
      final old = m[id];
      if (old != null && (old.left - r.left).abs() < .5 && (old.top - r.top).abs() < .5 && (old.right - r.right).abs() < .5 && (old.bottom - r.bottom).abs() < .5) return;
      m[id] = r;
    }
    rects.value = Map.unmodifiable(m);
  }
}

/// Wrap a pane's visible box. It reports its global rect every time it
/// paints (so a pane that moves or animates in keeps its rect current) and
/// removes it when it leaves the tree.
class PaneRect extends SingleChildRenderObjectWidget {
  const PaneRect({super.key, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaneRect();
}

class _RenderPaneRect extends RenderProxyBox {
  final Object _id = Object();
  Rect? _last;
  bool _queued = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!hasSize) return;
    final r = Rect.fromPoints(localToGlobal(Offset.zero), localToGlobal(size.bottomRight(Offset.zero)));
    if (r == _last) return;
    _last = r;
    if (_queued) return;
    _queued = true;
    // Never notify listeners during paint.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (attached && _last != null) PaneRects._set(_id, _last);
    });
  }

  @override
  void detach() {
    final id = _id;
    _last = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => PaneRects._set(id, null));
    super.detach();
  }
}

/// Where the side nav goes and in which form.
class SideNavSlot {
  final Rect rect;
  final bool labels;
  /// Nothing else clears the pane: one round button (the current section)
  /// in the bottom-left corner; tapping it opens the full nav as a menu.
  final bool collapsed;
  const SideNavSlot(this.rect, this.labels, {this.collapsed = false});
}

/// The collapsed nav: one 42 pt entry plus padding.
const double sideNavCollapsedHeight = sideNavEntryIcon + 12;

/// Side nav sizes (SideNavRail): 58 wide; an entry is 58 tall with its
/// label, 42 without, 1 between entries, 12 of padding.
const double sideNavEntryLabelled = 58;
const double sideNavEntryIcon = 42;
double sideNavHeight(int entries, {required bool labels}) =>
    entries * (labels ? sideNavEntryLabelled : sideNavEntryIcon) + math.max(0, entries - 1) + 12;
const double sideNavWidth = 58;

/// The side nav sits at the left edge. Its home is [restBottom] above the
/// screen bottom (above the composer). When a pane is open it moves to the
/// bottom-left corner beside the dock, below the panes, as in the v8.3
/// Gallery: labelled if that fits, icons only if not; if neither fits
/// below, above the panes; else collapsed to one button in the corner.
/// Returns null (hidden) only if even that would touch a pane.
SideNavSlot? placeSideNav({
  required Size screen,
  required int entries,
  required Iterable<Rect> panes,
  double left = 10,
  double restBottom = 230,
  double cornerBottom = 8,
  double topLimit = 60,
  double gap = 4,
}) {
  final col = Rect.fromLTWH(left, 0, sideNavWidth, screen.height);
  final hit = [for (final p in panes) if (p.overlaps(col)) p];
  bool clear(Rect r) => r.top >= topLimit && r.bottom <= screen.height && !hit.any((p) => p.inflate(gap).overlaps(r));
  Rect at(double bottom, bool labels) {
    final h = sideNavHeight(entries, labels: labels);
    return Rect.fromLTWH(left, screen.height - bottom - h, sideNavWidth, h);
  }

  final rest = at(restBottom, true);
  if (clear(rest)) return SideNavSlot(rest, true);
  for (final labels in [true, false]) {
    final r = at(cornerBottom, labels);
    if (clear(r)) return SideNavSlot(r, labels);
  }
  if (hit.isNotEmpty) {
    final top = hit.map((p) => p.top).reduce(math.min);
    for (final labels in [true, false]) {
      final h = sideNavHeight(entries, labels: labels);
      final r = Rect.fromLTWH(left, top - gap - h, sideNavWidth, h);
      if (clear(r)) return SideNavSlot(r, labels);
    }
  }
  final one = Rect.fromLTWH(left, screen.height - cornerBottom - sideNavCollapsedHeight, sideNavWidth, sideNavCollapsedHeight);
  if (clear(one)) return SideNavSlot(one, false, collapsed: true);
  return null;
}
