import 'package:flutter/material.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/edge_fade.dart';
import '../../../models/ticker_item.dart';

/// GLM ticker column (backup/glm-spatial-consistency). A bounded window:
/// press a row to toggle that model with a graduated decay, the chevron opens
/// the conversation, a sideways swipe changes category, and page dots mark the
/// scroll. Isolated models (R41) stay fully lit under a hairline, with a left
/// edge, instead of decaying with a toggled-off row.
class GlmTickerColumn extends StatefulWidget {
  const GlmTickerColumn({
    super.key,
    required this.items,
    required this.openId,
    required this.onOpen,
    required this.consensusTitle,
    required this.consensusLine,
    required this.onConsensus,
    required this.activeIds,
    required this.onToggle,
    required this.categoryLabel,
    required this.onCategorySwipe,
  });

  final List<TickerItem> items;
  final String? openId;
  final ValueChanged<String> onOpen;
  final String consensusTitle;
  final String consensusLine;
  final VoidCallback onConsensus;
  final Set<String> activeIds;
  final ValueChanged<String> onToggle;
  final String categoryLabel;
  final ValueChanged<int> onCategorySwipe;

  static const double rowExtent = 66;
  static const int visibleRows = 5;

  @override
  State<GlmTickerColumn> createState() => _GlmTickerColumnState();
}

class _GlmTickerColumnState extends State<GlmTickerColumn> {
  final ScrollController _scroll = ScrollController();
  int _page = 0;

  int get _pages => (widget.items.length / GlmTickerColumn.visibleRows).ceil().clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final page = (_scroll.offset / (GlmTickerColumn.visibleRows * GlmTickerColumn.rowExtent)).round().clamp(0, _pages - 1);
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.items;
    final shown = rows.length < GlmTickerColumn.visibleRows ? rows.length : GlmTickerColumn.visibleRows;
    return LayoutBuilder(builder: (context, constraints) {
    const chrome = 46.0 + 6 + 18 + 28;
    final cap = constraints.maxHeight.isFinite ? constraints.maxHeight - chrome : shown * GlmTickerColumn.rowExtent;
    final listExtent = (shown * GlmTickerColumn.rowExtent).clamp(0.0, cap < GlmTickerColumn.rowExtent ? GlmTickerColumn.rowExtent : cap);
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -350) widget.onCategorySwipe(1);
        if (v > 350) widget.onCategorySwipe(-1);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: const Color(0x14FFFFFF),
              border: Border.all(color: const Color(0x26FFFFFF), width: 0.5),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onConsensus,
                  child: SizedBox(
                    height: 46,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(widget.consensusTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 15, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(widget.consensusLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 11, height: 1.15, fontWeight: FontWeight.w600, color: const Color(0x99FFFFFF))),
                        ]),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: Container(
                          key: ValueKey(widget.categoryLabel),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(999)),
                          child: Text(widget.categoryLabel.toUpperCase(), style: appFont(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: const Color(0xB3FFFFFF))),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: listExtent,
                  child: EdgeFade(
                    fadeHeight: 12,
                    child: ListView.builder(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      itemExtent: GlmTickerColumn.rowExtent,
                      itemCount: rows.length,
                      itemBuilder: (c, i) {
                        final item = rows[i];
                        final split = i > 0 && item.isIsolated && !rows[i - 1].isIsolated;
                        return _TickerRow(
                          item: item,
                          selected: item.modelDef.id == widget.openId,
                          active: widget.activeIds.contains(item.modelDef.id),
                          split: split,
                          onToggle: () => widget.onToggle(item.modelDef.id),
                          onOpen: () => widget.onOpen(item.modelDef.id),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 18,
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var p = 0; p < _pages; p++) ...[
                        if (p > 0) const SizedBox(width: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          width: p == _page ? 14 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(255, 255, 255, p == _page ? 0.85 : 0.30),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
    });
  }
}

class _TickerRow extends StatelessWidget {
  const _TickerRow({
    required this.item,
    required this.selected,
    required this.active,
    required this.split,
    required this.onToggle,
    required this.onOpen,
  });

  final TickerItem item;
  final bool selected;
  final bool active;
  final bool split;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final last = item.conversation.isNotEmpty ? item.conversation.last : null;
    final time = item.isStreaming ? '…' : (last != null ? _clock(last.timestamp) : item.relativeTime);
    final msg = item.summary.isNotEmpty ? item.summary : (last?.text ?? '');
    final tint = item.modelDef.providerColor;
    // Toggled-off rows decay. An isolated model stays fully lit (R41).
    final dim = !active && !item.isIsolated;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (split)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0x00FFFFFF), Color(0x29FFFFFF), Color(0x00FFFFFF)]),
            ),
          ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: AnimatedOpacity(
              duration: Duration(milliseconds: dim ? 340 : 280),
              curve: dim ? Curves.easeInCubic : Curves.easeOutCubic,
              opacity: dim ? 0.38 : 1,
              child: AnimatedScale(
                duration: Duration(milliseconds: dim ? 340 : 280),
                curve: dim ? Curves.easeInCubic : Curves.easeOutBack,
                scale: dim ? 0.96 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(tint.withValues(alpha: selected ? 0.28 : 0.16), const Color(0x0AFFFFFF)),
                      borderRadius: BorderRadius.circular(16),
                      border: item.isIsolated
                          ? Border(left: BorderSide(color: tint.withValues(alpha: 0.85), width: 2.5))
                          : null,
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                            SizedBox(
                              height: 18,
                              child: Row(children: [
                                Expanded(child: Text(item.modelDef.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 14, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white))),
                                const SizedBox(width: 8),
                                Opacity(opacity: 0.55, child: Text(time, style: appFont(fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w600, color: Colors.white))),
                              ]),
                            ),
                            const SizedBox(height: 3),
                            Text(msg.replaceAll('\n', ' '), maxLines: 1, overflow: TextOverflow.ellipsis, style: appFont(fontSize: 12, height: 1.15, fontWeight: FontWeight.w600, color: const Color(0x99FFFFFF))),
                          ]),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpen,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.chevron_right_rounded, size: 18, color: Color(0x99FFFFFF)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
