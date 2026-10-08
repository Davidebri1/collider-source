import 'package:flutter/material.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../models/ticker_item.dart';

/// The ticker.
///
/// Spec, not interpretation:
///   * max 40% of viewport height
///   * the summaries column occupies 50% of the width
///   * up to 9 model rows (R03 - nine models in one view)
///   * the consensus row is pinned above them, and belongs here only
///   * tapping a row opens that model's thread in the right half
///
/// Row anatomy is the reference row: name, the response summary, time.
/// No provider line, no initials, no invented section title.
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

  static const double maxHeightFraction = 0.40;
  static const double gutter = 12;
  static const double summaryFraction = 0.50;
  static const double consensusHeight = 38;
  static const double rowHeight = 32;
  static const double rowGap = 3;

  /// Height of the sheet for a given viewport. The host positions the window
  /// (it sits on the dock) and the composer sits on this height, so both sides
  /// agree on one number instead of guessing.
  static double heightFor(double viewportHeight) =>
      (viewportHeight * maxHeightFraction).clamp(200.0, viewportHeight);

  /// Row height that lets every selected model fit inside the cap.
  ///
  /// R03 wants nine models in one view and the surface contract caps the
  /// window at 40% of the viewport - on a shorter phone those only both hold
  /// if the row rhythm gives ground, so the rhythm is derived, not fixed.
  static double rowHeightFor(double viewportHeight, int rowCount) {
    if (rowCount <= 0) return rowHeight;
    const consensusBlock = 6 + consensusHeight + 4; // margin top, height, bottom
    const listPadding = 2 + 4;
    final available = heightFor(viewportHeight) - consensusBlock - listPadding;
    return ((available - rowGap * rowCount) / rowCount).clamp(22.0, rowHeight);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final open = items.where((i) => i.modelDef.id == openId).firstOrNull;
    final rowH = rowHeightFor(media.height, items.length);

    return FGlass(
      radius: BorderRadius.circular(20),
      fill: const Color(0x4D808080),
      padding: EdgeInsets.zero,
      child: open == null
          ? Row(children: [
              SizedBox(width: media.width * summaryFraction, child: _summaries(open, rowH)),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.10)),
              Expanded(child: _placeholder()),
            ])
          : Row(children: [
              SizedBox(width: media.width * summaryFraction, child: _summaries(open, rowH)),
              Container(width: 1, color: Colors.white.withValues(alpha: 0.10)),
              Expanded(
                child: ConversationPane(
                  key: ValueKey('thread-${open.modelDef.id}'),
                  item: open,
                  onReply: onReply,
                  onTapMessage: onTapMessage,
                  onClose: onClose,
                ),
              ),
            ]),
    );
  }

  /// Left half: pinned consensus row, then every model row.
  Widget _summaries(TickerItem? open, double rowH) {
    return Column(children: [
      _ConsensusRow(title: consensusTitle, line: consensusLine, onTap: onConsensus),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: rowGap),
            child: ResponseRow(
              item: items[i],
              height: rowH,
              selected: items[i].modelDef.id == openId,
              onTap: () => onOpen(items[i].modelDef.id),
            ),
          ),
        ),
      ),
    ]);
  }

  /// Right half before anything is opened: the window is empty, not blank grey.
  Widget _placeholder() {
    return Center(
      child: Text(
        '',
        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white.withValues(alpha: 0.0)),
      ),
    );
  }
}

/// Consensus - pinned here and nowhere else.
class _ConsensusRow extends StatelessWidget {
  const _ConsensusRow({required this.title, required this.line, required this.onTap});
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: line.isEmpty ? title : '$title. $line',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: TickerSheet.consensusHeight,
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.balance_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
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
                          fontSize: 9.5,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.70),
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

/// One model and its response summary.
class ResponseRow extends StatelessWidget {
  const ResponseRow({
    super.key,
    required this.item,
    required this.height,
    required this.selected,
    required this.onTap,
  });
  final TickerItem item;
  final double height;
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
    // Type gives ground with the row so the two lines never crowd the box.
    final s = (height / TickerSheet.rowHeight).clamp(0.78, 1.0);
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.modelDef.label}. $summary',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(children: [
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
                          fontSize: 12 * s,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        time,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.5 * s,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.45),
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
                        fontSize: 10.5 * s,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.75),
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

/// The right half: one model's full thread.
class ConversationPane extends StatefulWidget {
  const ConversationPane({
    super.key,
    required this.item,
    required this.onReply,
    required this.onTapMessage,
    this.onClose,
  });
  final TickerItem item;
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
    return Column(children: [
      SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(children: [
            Expanded(
              child: Text(
                item.modelDef.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (widget.onClose != null)
              _Circle(icon: Icons.close_rounded, label: 'Close', onTap: widget.onClose!),
          ]),
        ),
      ),
      Container(height: 1, color: Colors.white.withValues(alpha: 0.10)),
      Expanded(
        child: item.conversation.isEmpty
            ? Center(
                child: Text(
                  item.isStreaming ? 'Writing…' : 'No response yet.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                physics: const BouncingScrollPhysics(),
                itemCount: item.conversation.length,
                itemBuilder: (_, i) {
                  final msg = item.conversation[i];
                  return msg.sender == 'user'
                      ? _Outgoing(msg: msg)
                      : GestureDetector(onTap: () => widget.onTapMessage(msg), child: _Incoming(msg: msg));
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Row(children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _ctl,
                onSubmitted: (_) => _send(),
                cursorColor: Colors.white,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.3, color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Reply',
                  hintStyle: TextStyle(color: Color(0x59FFFFFF), fontSize: 12.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Circle(icon: Icons.arrow_upward_rounded, label: 'Send', onTap: _send),
        ]),
      ),
    ]);
  }
}

class _Incoming extends StatelessWidget {
  const _Incoming({required this.msg});
  final TickerMessage msg;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: const BoxDecoration(
            color: Color(0x1FFFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(13),
              bottomLeft: Radius.circular(13),
              bottomRight: Radius.circular(13),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
      );
}

class _Outgoing extends StatelessWidget {
  const _Outgoing({required this.msg});
  final TickerMessage msg;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: const BoxDecoration(
            color: Color(0x33FFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(13),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(13),
              bottomRight: Radius.circular(13),
            ),
          ),
          child: Text(
            msg.text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
      );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x33FFFFFF)),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
        ),
      );
}