import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/theme/edge_fade.dart';
import '../../../models/ticker_item.dart';

/// Map row 15 — Model Response Ticker, a straight copy of wechat CHAT 2013:75
/// at its own size (scene coordinates, 2610 x 1468). Collapsed answers are the
/// left column window (0:646: 476 x 720 at 639,361); the opened answer is the
/// middle window (9:338: 791 x 720 at 1114,362) with its close button and the
/// text box (54:296). Sample contacts are replaced by the real models; the
/// 64 px avatar is a flat disc in the model's own colour (no glow, no badge).
class Row15 {
  static const frame = Size(2610, 1468);
  // Crop: tab bar (540) .. middle window right edge (1905): the window
  // group's own width, no extra margin (v8.4 follow-up), so the scale is the
  // largest the frame allows.
  static const cropWidth = 1365.0;
  static const center = Offset(1222.5, 734);
  static const rail = Rect.fromLTWH(540, 624, 76, 220);
  static const leftWin = Rect.fromLTWH(639, 361, 476, 720);
  static const midWin = Rect.fromLTWH(1114, 362, 791, 720);
  static const textBox = Rect.fromLTWH(1136, 952, 726, 149);
}

String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String initials(String label) {
  final parts = label.split(RegExp(r'[\s\-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final a = parts.first.characters.first.toUpperCase();
  final b = parts.length > 1 ? parts[1].characters.first.toUpperCase() : '';
  return '$a$b';
}

/// Left column window (collapsed answers) — Master Spec §4.2 edition: a
/// bounded, app-coordinate window (width = the dock's, height ≤ 40% of the
/// screen, ~5 rows visible, the rest on internal scroll). Non-interactive
/// surface, zero row chrome. Press a row to toggle its model on/off with a
/// graduated decay; the row's chevron opens the conversation. Horizontal
/// swipe changes the model category. Page indicator dots sit under the list.
class TickerColumnWindow extends StatefulWidget {
  const TickerColumnWindow({
    super.key,
    required this.items,
    required this.openId,
    required this.onOpen,
    required this.consensusTitle,
    required this.consensusLine,
    required this.onConsensus,
    required this.joined,
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
  final bool joined; // middle window open: right corners square (0:646)
  final Set<String> activeIds;
  final ValueChanged<String> onToggle;
  final String categoryLabel;
  final ValueChanged<int> onCategorySwipe; // +1 next category, -1 previous

  static const double rowExtent = 66;
  static const int visibleRows = 5;

  @override
  State<TickerColumnWindow> createState() => _TickerColumnWindowState();
}

class _TickerColumnWindowState extends State<TickerColumnWindow> {
  final ScrollController _scroll = ScrollController();
  double _offset = 0;

  int get _pages => (widget.items.length / TickerColumnWindow.visibleRows).ceil().clamp(1, 99);
  int get _page => (_offset / (TickerColumnWindow.visibleRows * TickerColumnWindow.rowExtent)).round().clamp(0, _pages - 1);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.joined
        ? const BorderRadius.only(topLeft: Radius.circular(28), bottomLeft: Radius.circular(28))
        : BorderRadius.circular(28);
    final rows = widget.items;
    final listExtent = (rows.length < TickerColumnWindow.visibleRows
            ? rows.length
            : TickerColumnWindow.visibleRows) *
        TickerColumnWindow.rowExtent;
    return GestureDetector(
      // Category swipe: right = next, left = previous.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -350) widget.onCategorySwipe(1);
        if (v > 350) widget.onCategorySwipe(-1);
      },
      child: _WindowShell(
        radius: r,
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Consensus (pinned row) + the current category name.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onConsensus,
                  child: SizedBox(
                    height: 46,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(widget.consensusTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(widget.consensusLine,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, height: 1.15, fontWeight: FontWeight.w600, color: Color(0x99FFFFFF))),
                        ]),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: Container(
                          key: ValueKey(widget.categoryLabel),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(widget.categoryLabel.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0xB3FFFFFF))),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                // Rows: ~5 visible, the rest on internal momentum scroll,
                // dissolving into the glass at both ends.
                SizedBox(
                  height: listExtent,
                  child: EdgeFade(
                    fadeTopFraction: 0.10,
                    fadeBottomFraction: 0.10,
                    child: ListView.builder(
                      controller: _scroll
                        ..addListener(() {
                          final p = (_scroll.offset / (TickerColumnWindow.visibleRows * TickerColumnWindow.rowExtent)).round();
                          if (p != _page) setState(() => _offset = _scroll.offset);
                        }),
                      physics: const BouncingScrollPhysics(),
                      itemExtent: TickerColumnWindow.rowExtent,
                      itemCount: rows.length,
                      itemBuilder: (c, i) => _TickerRow(
                        item: rows[i],
                        selected: rows[i].modelDef.id == widget.openId,
                        active: widget.activeIds.contains(rows[i].modelDef.id),
                        onToggle: () => widget.onToggle(rows[i].modelDef.id),
                        onOpen: () => widget.onOpen(rows[i].modelDef.id),
                      ),
                    ),
                  ),
                ),
                // Page indicator dots (one per page of five).
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
                // visionOS window grabber.
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(color: const Color(0x3DFFFFFF), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

/// The ticker window's optical shell: one-pass glass — blur, resting fill,
/// hairline rim (Plane 2). Both the rows and the opened conversation render
/// inside this same shell.
class _WindowShell extends StatelessWidget {
  final BorderRadius radius;
  final Widget child;
  const _WindowShell({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: const Color(0x14FFFFFF),
            border: Border.all(color: const Color(0x26FFFFFF), width: 0.5),
          ),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
          child: child,
        ),
      ),
    );
  }
}

/// One model row: name, time, one-line takeaway, tinted across
/// the whole card in the model's own colour (Master Spec §3.3 —
/// the "left border only" restriction was struck). Press toggles
/// the model on/off with a graduated decay. No discs, no badges
/// (D20). The chevron opens the conversation (D17/D18).
class _TickerRow extends StatelessWidget {
  final TickerItem item;
  final bool selected;
  final bool active;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _TickerRow({required this.item, required this.selected, required this.active, required this.onToggle, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final last = item.conversation.isNotEmpty ? item.conversation.last : null;
    final time = item.isStreaming ? '…' : (last != null ? _clock(last.timestamp) : item.relativeTime);
    final msg = item.summary.isNotEmpty ? item.summary : (last?.text ?? '');
    final tint = item.modelDef.providerColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: active ? 280 : 340),
        curve: active ? Curves.easeOutCubic : Curves.easeInCubic,
        opacity: active ? 1.0 : 0.38,
        child: AnimatedScale(
          duration: Duration(milliseconds: active ? 280 : 340),
          curve: active ? Curves.easeOutBack : Curves.easeInCubic,
          scale: active ? 1.0 : 0.96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  tint.withOpacity(selected ? 0.28 : 0.16),
                  const Color(0x0AFFFFFF),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    height: 18,
                    child: Row(children: [
                      Expanded(child: Text(item.modelDef.label,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, height: 1.15, fontWeight: FontWeight.w700, color: Colors.white))),
                      const SizedBox(width: 8),
                      Opacity(opacity: 0.55, child: Text(time, style: const TextStyle(fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w600, color: Colors.white))),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 16,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(msg.replaceAll('\n', ' '),
                          style: const TextStyle(fontSize: 12, height: 1.15, fontWeight: FontWeight.w600, color: Color(0x99FFFFFF))),
                    ),
                  ),
                ]),
              ),
                // Open affordance: the conversation expands from here.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0x99FFFFFF)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The opened conversation in app coordinates — D17: on a phone it takes the
/// rows' place inside the same bounded window (never full-width); D18: it is
/// closeable from the header. Reply sends an isolated branch to this model.
class TickerAnswerCompact extends StatefulWidget {
  final TickerItem item;
  final VoidCallback onClose;
  final ValueChanged<String> onReply;
  final void Function(TickerMessage) onTapMessage;

  const TickerAnswerCompact({super.key, required this.item, required this.onClose, required this.onReply, required this.onTapMessage});

  @override
  State<TickerAnswerCompact> createState() => _TickerAnswerCompactState();
}

class _TickerAnswerCompactState extends State<TickerAnswerCompact> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _send() {
    final t = _reply.text.trim();
    if (t.isEmpty) return;
    _reply.clear();
    widget.onReply(t);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item.modelDef;
    return _WindowShell(
      radius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: the model's name + close (D18).
          SizedBox(
            height: 30,
            child: Row(children: [
              Expanded(
                child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 18, color: Color(0xB3FFFFFF))),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: EdgeFade(
            fadeTopFraction: 0.08,
            fadeBottomFraction: 0.08,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                for (final msg in widget.item.conversation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: msg.sender == 'user'
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0x4DFFFFFF),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(3), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                              ),
                              child: Text(msg.text, style: const TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                          )
                        : GestureDetector(
                            onTap: () => widget.onTapMessage(msg),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 320),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0x26FFFFFF),
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(12), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                                ),
                                child: Text(msg.text, style: const TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ),
                  ),
                if (widget.item.isStreaming)
                  const Padding(padding: EdgeInsets.only(left: 8), child: Text('…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0x99FFFFFF)))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Isolated branch composer (Master Spec §3.3).
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0x26000000),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _reply,
                cursorColor: Colors.white,
                style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: 'Reply', hintStyle: TextStyle(fontSize: 12.5, color: Color(0x66FFFFFF))),
                onSubmitted: (_) => _send(),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _send,
              child: const Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
            ),
          ]),
        ),
        ],
      ),
    );
  }
}

/// Middle window (the opened answer) — 9:338, 791 x 720, plus text box 54:296.
class TickerAnswerWindow extends StatefulWidget {
  const TickerAnswerWindow({super.key, required this.item, required this.onClose, required this.onReply, required this.onTapMessage});
  final TickerItem item;
  final VoidCallback onClose;
  final ValueChanged<String> onReply;
  final ValueChanged<TickerMessage> onTapMessage;
  @override
  State<TickerAnswerWindow> createState() => _TickerAnswerWindowState();
}

class _TickerAnswerWindowState extends State<TickerAnswerWindow> {
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
    final m = item.modelDef;
    return SizedBox(
      width: 791,
      height: 739,
      child: Stack(clipBehavior: Clip.none, children: [
        FGlass(
          width: 791,
          height: 720,
          radius: const BorderRadius.only(topRight: Radius.circular(46), bottomRight: Radius.circular(46)),
          stroke: const Color(0x66FFFFFF),
          child: Stack(children: [
            // User Status Container 9:339 at (33,38).
            Positioned(
              left: 33,
              top: 38,
              right: 100,
              height: 24,
              child: Row(children: [
                Flexible(child: FText(m.label, size: 24, height: 24, weight: FontWeight.w700)),
                const SizedBox(width: 11),
                FText(item.isStreaming ? 'Answering' : item.relativeTime, size: 15, height: 20, weight: FontWeight.w700, opacity: 0.4),
              ]),
            ),
            // Close Button Container 10:438 at (711,26), 48 x 48.
            Positioned(
              left: 711,
              top: 26,
              width: 48,
              height: 48,
              child: Semantics(
                button: true,
                label: 'Close',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
                    child: const Icon(Icons.close_rounded, size: 24, color: Colors.white),
                  ),
                ),
              ),
            ),
            // Messages from y 110 (9:414) to the text box (y 590).
            // Edge-faded into the glass at both ends (wechat reference).
            Positioned(
              left: 0,
              right: 0,
              top: 110,
              height: 470,
              child: EdgeFade(
                fadeHeight: 24,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 21),
                  children: [
                    for (final msg in item.conversation)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 21),
                        child: msg.sender == 'user'
                            ? _Outgoing(msg: msg)
                            : GestureDetector(onTap: () => widget.onTapMessage(msg), child: _Incoming(msg: msg)),
                      ),
                    if (item.isStreaming)
                      const Padding(padding: EdgeInsets.only(left: 114), child: FText('…', size: 18, height: 24, weight: FontWeight.w700, opacity: 0.6)),
                  ],
                ),
              ),
            ),
          ]),
        ),
        // Text Box Container 54:296: (22, 590) relative, 726 x 149, rgba(0,0,0,.3), r 36.
        Positioned(
          left: 22,
          top: 590,
          width: 726,
          height: 149,
          child: FGlass(
            radius: BorderRadius.circular(36),
            fill: const Color(0x4D000000),
            child: Stack(children: [
              Positioned(
                left: 25,
                top: 22,
                right: 25,
                height: 50,
                child: TextField(
                  controller: _ctl,
                  onSubmitted: (_) => _send(),
                  cursorColor: Colors.white,
                  style: const TextStyle(fontSize: 20, height: 1.2, color: Colors.white, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                ),
              ),
              // Send 54:301 at (597,81); attachment 54:298 at (654,81).
              Positioned(left: 597, top: 81, width: 48, height: 48, child: _CircleButton(icon: Icons.arrow_upward_rounded, label: 'Send', onTap: _send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.label, required this.onTap});
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
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
        ),
      );
}

class _Incoming extends StatelessWidget {
  const _Incoming({required this.msg});
  final TickerMessage msg;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 32, right: 32),
        child: FGlass(
          radius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FText(msg.text, size: 18, height: 24, weight: FontWeight.w700, maxLines: null, ellipsis: false),
            const SizedBox(height: 4),
            FText(_clock(msg.timestamp), size: 16, height: 16, weight: FontWeight.w700, opacity: 0.4),
          ]),
        ),
      );
}

class _Outgoing extends StatelessWidget {
  const _Outgoing({required this.msg});
  final TickerMessage msg;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: 120),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0x4DFFFFFF),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(4), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              FText(msg.text, size: 18, height: 24, weight: FontWeight.w700, maxLines: null, ellipsis: false, align: TextAlign.right),
              const SizedBox(height: 4),
              FText(_clock(msg.timestamp), size: 16, height: 16, weight: FontWeight.w700, opacity: 0.4),
            ]),
          ),
        ),
        const SizedBox(width: 13),
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x4D808080)),
          child: const Icon(Icons.person_rounded, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 32),
      ]);
}
