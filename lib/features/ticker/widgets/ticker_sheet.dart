import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/kit/collider_kit.dart';
import '../../../core/kit/focus_carousel.dart';
import '../../../models/ticker_item.dart';

/// The ticker.
///
/// Built from the wechat vision os Window export rather than from numbers typed
/// at the call site. The export is 334 x 464: five glass rows, 300 x 88 at a
/// radius of 20, on a 94 pitch, filling the panel exactly - 5 x 88 + 4 x 6 = 464.
/// No slack, no filler, no "Answers" heading. That ratio set is the whole
/// component:
///
///   * row height is 88/464 of panel height
///   * row width is 300/334 of panel width
///   * the name is 20/88 of row height, the summary 16/88 at 40% white
///
/// Holding those ratios is what makes it read as the reference at any size, so
/// every number below is a fraction of the panel, never a literal.
///
/// Proportion across the two windows comes from the Figma frame: the summaries
/// window is 476 wide beside a 791 thread window - 37.6 / 62.4, not 50/50.
///
/// Spec, not interpretation:
///   * max 40% viewport height
///   * up to 9 models (R03) - the reel carries them, not a crushed rhythm
///   * consensus row pinned above the reel, and nowhere else
///   * tapping a row opens that model's thread in the right portion
class TickerSheet extends StatelessWidget {
  const TickerSheet({
    super.key,
    required this.items,
    required this.openId,
    required this.onOpen,
    required this.onReply,
    required this.onTapMessage,
    required this.consensusTitle,
    required this.consensusLine,
    required this.onConsensus,
    this.onClose,
  });

  final List<TickerItem> items;
  final String? openId;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onReply;
  final ValueChanged<TickerMessage> onTapMessage;
  final String consensusTitle;
  final String consensusLine;
  final VoidCallback onConsensus;
  final VoidCallback? onClose;

  /// Air around the group. visionOS floats; it does not bleed.
  static const double gutter = 12;

  /// Surface contract: the ticker is a bottom window, never taller than this.
  /// Dock width is the other half of the same clause and it binds first.
  static const double maxHeightFraction = 0.40;

  /// Height of the dock's own footprint. The window sits on top of it.
  static const double dockInset = 74;

  /// The composer is a bar on its window, not a screen-spanning field.
  static const double composerHeight = 52;
  static const double composerGap = 10;

  /// The rim is a real border, so it eats into the content box. Every inner
  /// measurement is taken off the outer box minus this, which is the 2px that
  /// a row sized to the outer width overflows by.
  static const double strokeWidth = 1.0;

  // ── proportions, all read off the export ──────────────────────────────────
  static const double _panelAspect = 334 / 464; // collapsed window
  static const double _rowWidth = 300 / 334;
  static const double _rowAspect = 88 / 300; // the row's own shape
  static const double _radiusOfRow = 20 / 300;
  static const double _avatar = 56 / 88;
  static const double _nameOfRow = 20 / 88;
  static const double _summaryOfRow = 16 / 88;
  static const double _gapOfRow = 6 / 88;
  static const double _padOfRow = 16 / 88;

  /// Row metrics at a given summaries width. The row scales with the window, so
  /// a narrower window gets a proportionally smaller row rather than the same
  /// row squeezed.
  static double heightFor(double viewportHeight) =>
      (viewportHeight * maxHeightFraction).clamp(200.0, viewportHeight);

  /// Every box the resting workspace needs, in one place.
  ///
  /// The surface contract is "bottom window, max 40% height, **dock width**".
  /// Dock width is the binding term and it is small: at 430pt the dock is 168pt,
  /// and at the reference aspect that is a 168 x 233 window - a quarter of the
  /// screen. The 40% ceiling is never reached. Building to the ceiling instead is
  /// what produced the earlier 250-390pt slab, 1.5x to 2.3x the dock, which read
  /// as a sheet of paper rather than a window.
  ///
  /// One layout, three consumers: the summaries window, the thread window that
  /// opens beside it, and the composer that belongs to whichever is showing.
  /// Deriving them together is the point - when each surface picked its own box,
  /// the composer grew to the full screen width and overlap stopped being an
  /// accident.
  static TickerLayout layoutFor(
    Size viewport, {
    required bool expanded,
    bool tickerVisible = true,
    double dockTop = dockInset,
  }) {
    // Nothing is showing: there is no window for the composer to ride, so it
    // sits on the dock. It used to be placed above the *hypothetical* ticker
    // window, which on the media surface left it floating ~300pt above the
    // dock with nothing under it.
    if (!tickerVisible) {
      final w = math.min(Kit.dockWidth, viewport.width);
      return TickerLayout(
        summaries: Rect.zero,
        thread: Rect.zero,
        composer: Rect.fromLTWH(
          (viewport.width - w) / 2,
          viewport.height - dockTop - gutter - composerHeight,
          w,
          composerHeight,
        ),
      );
    }

    final w = math.min(Kit.dockWidth, viewport.width);
    final capH = (viewport.height * maxHeightFraction).clamp(0.0, viewport.height);
    // Height follows from the width at the reference aspect, then is capped, so
    // a narrow window never grows into a tall one.
    final h = math.min(capH, w / _panelAspect);

    final threadW = expanded ? math.max(0.0, viewport.width - gutter * 2 - w - 1.0) : 0.0;
    final groupW = w + (expanded ? threadW + 1.0 : 0.0);
    final groupLeft = (viewport.width - groupW) / 2;
    final top = viewport.height - (dockTop + gutter) - h;

    final summaries = Rect.fromLTWH(groupLeft, top, w, h);
    final thread = expanded ? Rect.fromLTWH(groupLeft + w + 1.0, top, threadW, h) : Rect.zero;

    // The composer belongs to the window it types into and rides directly on it:
    // collapsed that is the summaries window, expanded it is the thread. It is
    // never wider than that window, and never wider than the screen.
    final owner = thread.width > 0 ? thread : summaries;
    final composer = Rect.fromLTWH(
      owner.left,
      owner.top - composerGap - composerHeight,
      owner.width,
      composerHeight,
    );

    return TickerLayout(summaries: summaries, thread: thread, composer: composer);
  }

  /// Every dimension a row needs, derived once so nothing can drift.
  static TickerMetrics metricsFor({required double summariesW}) {
    // The row is sized off the summaries column, never off the window: a row has
    // to fit the column it sits in or it overflows, and its own shape (300x88) is
    // what carries the reference - not an absolute height.
    final rowW = summariesW * _rowWidth;
    final rowH = rowW * _rowAspect;
    return TickerMetrics(
      summariesW: summariesW,
      rowH: rowH,
      rowW: rowW,
      pitch: rowH + rowH * _gapOfRow,
      gap: rowH * _gapOfRow,
      inset: (summariesW - rowW) / 2,
      radius: rowW * _radiusOfRow,
      avatar: rowH * _avatar,
      pad: rowH * _padOfRow,
      name: rowH * _nameOfRow,
      summary: rowH * _summaryOfRow,
    );
  }

  static const double rowGap = 3;
  static const double rowHeight = 32;
  static const double consensusHeight = 44;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final open = items.where((i) => i.modelDef.id == openId).firstOrNull;
    final layout = layoutFor(size, expanded: open != null);
    final expanded = open != null && layout.thread.width > 0;
    // The panel spans whichever windows are open, so the glass is one object
    // with a divider rather than two panes that can drift apart.
    final panelW = expanded ? layout.summaries.width + 1.0 + layout.thread.width : layout.summaries.width;
    final panelH = layout.summaries.height;
    final m = metricsFor(summariesW: layout.summariesInnerW);

    return SizedBox(
      width: panelW,
      height: panelH,
      child: FGlass(
        radius: BorderRadius.circular(m.radius * 1.25),
        fill: const Color(0x4D808080),
        // A window that does not sit on something is a decal. The shadow is
        // what separates the glass from the wallpaper underneath it; the rim
        // catches the light on the top edge only.
        shadow: Kit.shadow(3),
        stroke: Kit.rimHairline,
        strokeWidth: TickerSheet.strokeWidth,
        padding: EdgeInsets.zero,
        child: Row(children: [
          SizedBox(width: m.summariesW, child: _summaries(open, m)),
          if (expanded) ...[
            Container(width: 1, color: Colors.white.withValues(alpha: 0.10)),
            Expanded(
              child: ConversationPane(
                key: ValueKey('thread-${open.modelDef.id}'),
                item: open,
                m: m,
                onReply: onReply,
                onTapMessage: onTapMessage,
                onClose: onClose,
              ),
            ),
          ],
        ]),
      ),
    );
  }

  /// Left: pinned consensus row, then the reel of model rows.
  Widget _summaries(TickerItem? open, TickerMetrics m) {
    final selected = open == null ? -1 : items.indexWhere((i) => i.modelDef.id == open.modelDef.id);
    return Column(children: [
      _ConsensusRow(title: consensusTitle, line: consensusLine, onTap: onConsensus, m: m),
      Expanded(
        child: FocusCarousel(
          itemCount: items.length,
          itemExtent: m.pitch,
          selectedIndex: selected < 0 ? null : selected,
          onSelect: (i) => onOpen(items[i].modelDef.id),
          padding: EdgeInsets.fromLTRB(m.inset, 2, m.inset, m.inset * 0.4),
          itemBuilder: (_, i, isSelected) => Padding(
            padding: EdgeInsets.only(bottom: m.gap),
            child: ResponseRow(
              item: items[i],
              m: m,
              selected: isSelected,
              onTap: () => onOpen(items[i].modelDef.id),
            ),
          ),
        ),
      ),
    ]);
  }
}

class TickerMetrics {
  const TickerMetrics({
    required this.summariesW,
    required this.rowH,
    required this.rowW,
    required this.pitch,
    required this.gap,
    required this.inset,
    required this.radius,
    required this.avatar,
    required this.pad,
    required this.name,
    required this.summary,
  });
  final double summariesW;
  final double rowH;
  final double rowW;
  final double pitch;
  final double gap;
  final double inset;
  final double radius;
  final double avatar;
  final double pad;
  final double name;
  final double summary;
}

/// The resting workspace's geometry, resolved once.
///
/// The host positions the ticker and the composer from this; neither measures
/// anything itself. That is the whole fix for the composer ending up a
/// screen-wide pill - it had been free to choose its own width.
class TickerLayout {
  const TickerLayout({required this.summaries, required this.thread, required this.composer});
  final Rect summaries;
  final Rect thread;
  final Rect composer;

  /// Width available inside the rim, which is what rows are measured against.
  double get summariesInnerW => math.max(0.0, summaries.width - TickerSheet.strokeWidth * 2);

  /// The span the glass occupies: one window, or the two-up.
  Rect get glass => thread.width > 0
      ? Rect.fromLTWH(
          summaries.left,
          summaries.top,
          summaries.width + 1.0 + thread.width,
          summaries.height,
        )
      : summaries;
}

/// Consensus — pinned here and nowhere else.
class _ConsensusRow extends StatelessWidget {
  const _ConsensusRow({required this.title, required this.line, required this.onTap, required this.m});
  final String title;
  final String line;
  final VoidCallback onTap;
  final TickerMetrics m;

  @override
  Widget build(BuildContext context) {
    // The consensus strip is Collider's addition, so it takes the row rhythm at
    // a reduced weight rather than a height invented on its own.
    final h = m.rowH * 0.62;
    return Semantics(
      button: true,
      label: line.isEmpty ? title : '$title. $line',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: h,
          margin: EdgeInsets.fromLTRB(m.inset, m.gap, m.inset, m.gap),
          padding: EdgeInsets.symmetric(horizontal: m.pad),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(m.radius),
          ),
          child: Row(children: [
            Icon(Icons.balance_rounded, size: m.name * 1.15, color: Colors.white70),
            SizedBox(width: m.pad * 0.55),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: m.summary,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: m.summary * 0.85,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One model: name, response summary, time. No provider line, no initials, no
/// model colour — the name is the identity.
class ResponseRow extends StatelessWidget {
  const ResponseRow({super.key, required this.item, required this.m, required this.selected, required this.onTap});
  final TickerItem item;
  final TickerMetrics m;
  final bool selected;
  final VoidCallback onTap;

  String get _summary {
    if (item.summary.isNotEmpty) return item.summary;
    final last = item.conversation.isEmpty ? null : item.conversation.last;
    return (last?.text ?? '').replaceAll('\n', ' ').trim();
  }

  String get _time {
    final last = item.conversation.isEmpty ? null : item.conversation.last;
    if (item.isStreaming) return '';
    if (last == null) return item.relativeTime;
    final t = last.timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final time = _time;
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.modelDef.label}. $summary',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: m.rowH,
          padding: EdgeInsets.symmetric(horizontal: m.pad),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(m.radius),
          ),
          child: Row(children: [
            _Disc(size: m.avatar, dim: !selected),
            SizedBox(width: m.gap * 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        item.modelDef.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: m.name,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      SizedBox(width: m.pad * 0.4),
                      Text(
                        time,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: m.summary * 0.82,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ]),
                  if (summary.isNotEmpty)
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: m.summary,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The reference row leads with a 56 disc. Collider has no avatar artwork, so
/// the disc is a quiet placeholder that holds the rhythm - it is never a model
/// colour and never carries the name.
class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.dim});
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: dim ? 0.06 : 0.12),
        ),
      );
}

/// The right portion: one model's full thread.
class ConversationPane extends StatefulWidget {
  const ConversationPane({
    super.key,
    required this.item,
    required this.m,
    required this.onReply,
    required this.onTapMessage,
    this.onClose,
  });
  final TickerItem item;
  final TickerMetrics m;
  final ValueChanged<String> onReply;
  final ValueChanged<TickerMessage> onTapMessage;
  final VoidCallback? onClose;

  @override
  State<ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends State<ConversationPane> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    _ctl.clear();
    widget.onReply(t);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final m = widget.m;
    return Column(children: [
      Container(
        height: m.rowH * 0.72,
        padding: EdgeInsets.fromLTRB(m.pad, 0, m.gap * 2, 0),
        child: Row(children: [
          Expanded(
            child: Text(
              item.modelDef.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: m.name,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (widget.onClose != null)
            _Circle(icon: Icons.close_rounded, label: 'Close', size: m.avatar * 0.7, onTap: widget.onClose!),
        ]),
      ),
      Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
      Expanded(
        child: item.conversation.isEmpty
            ? Center(
                child: Text(
                  item.isStreaming ? 'Writing…' : 'No response yet.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: m.summary,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(m.pad),
                physics: const BouncingScrollPhysics(),
                itemCount: item.conversation.length,
                itemBuilder: (_, i) {
                  final msg = item.conversation[i];
                  return msg.sender == 'user'
                      ? _Outgoing(msg: msg, m: m)
                      : GestureDetector(onTap: () => widget.onTapMessage(msg), child: _Incoming(msg: msg, m: m));
                },
              ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(m.pad, 0, m.pad, m.pad * 0.6),
        child: Row(children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: m.avatar * 0.8),
              padding: EdgeInsets.symmetric(horizontal: m.pad * 0.8, vertical: m.pad * 0.55),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(m.radius * 1.6),
              ),
              child: TextField(
                controller: _ctl,
                onSubmitted: (_) => _send(),
                cursorColor: Colors.white,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: m.summary,
                  height: 1.3,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Reply',
                  hintStyle: TextStyle(color: const Color(0x59FFFFFF), fontSize: m.summary),
                ),
              ),
            ),
          ),
          SizedBox(width: m.gap * 2),
          _Circle(
            icon: Icons.arrow_upward_rounded,
            label: 'Send',
            size: m.avatar * 0.8,
            onTap: _send,
          ),
        ]),
      ),
    ]);
  }
}

class _Incoming extends StatelessWidget {
  const _Incoming({required this.msg, required this.m});
  final TickerMessage msg;
  final TickerMetrics m;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: m.gap * 1.4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: m.pad * 0.8, vertical: m.pad * 0.6),
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(m.radius * 0.25),
              topRight: Radius.circular(m.radius),
              bottomLeft: Radius.circular(m.radius),
              bottomRight: Radius.circular(m.radius),
            ),
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: m.summary,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
      );
}

class _Outgoing extends StatelessWidget {
  const _Outgoing({required this.msg, required this.m});
  final TickerMessage msg;
  final TickerMetrics m;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: m.gap * 1.4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: m.pad * 0.8, vertical: m.pad * 0.6),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(m.radius),
              topRight: Radius.circular(m.radius * 0.25),
              bottomLeft: Radius.circular(m.radius),
              bottomRight: Radius.circular(m.radius),
            ),
          ),
          child: Text(
            msg.text,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: m.summary,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
      );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.icon, required this.label, required this.size, required this.onTap});
  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
            child: Icon(icon, size: size * 0.52, color: Colors.white),
          ),
        ),
      );
}
