import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/ticker_item.dart';
import '../../../core/files/file_store.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/media/theme_catalog.dart';
import '../../theme/theme_living_media.dart';

/// REQ-03 Multi-Model Response card (Vision OS Design System 417:6826 comment
/// card; WeChat visionOS 0:639 elevation). Avatar → model mark, bold name →
/// model name, timestamp → response time, message → the model's thesis,
/// reaction row → the per-model tools. Cards gain elevation as they rise.
/// v8.3 (map row 15, WeChat 0-639, D51): a [ModelPill] is either a collapsed
/// card in the left column (full model name, two lines of the answer) or,
/// with [pane], the opened answer in the middle with its own close button.
class ModelPill extends StatefulWidget {
  final TickerItem item;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final Function(String replyText)? onSendInlineReply;
  final VoidCallback? onOpenBrowser;
  final Function(TickerMessage message)? onTapMessage;
  final VoidCallback? onOpenLocalHistory;

  /// 0 = resting (bottom of the stack) … 1 = highest card.
  final double elevation;

  /// The opened answer (the tray over the ticker) rather than a collapsed card.
  final bool pane;

  const ModelPill({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onToggleExpand,
    this.onSendInlineReply,
    this.onOpenBrowser,
    this.onTapMessage,
    this.onOpenLocalHistory,
    this.elevation = 0,
    this.pane = false,
  });

  @override
  State<ModelPill> createState() => _ModelPillState();
}

class _ModelPillState extends State<ModelPill> {
  // Real theme posters (streamed + cached) stand in for generated media thumbs.
  static const List<String> _mediaSlugs = ['lantern-alley', 'copper-kiln', 'glasshouse-fog', 'tide-glass'];
  String _mediaPosterFor(int i) {
    final slug = _mediaSlugs[i % _mediaSlugs.length];
    return ThemeCatalog.instance.bySlug(slug)?.posterUrl ?? '${ThemeCatalog.mediaBaseUrl}themes/$slug/poster.webp';
  }

  final TextEditingController _inlineCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  String _searchFilter = '';
  final List<String> _attachedFiles = [];

  @override
  void dispose() {
    _inlineCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      backgroundColor: VColors.glassDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.full)),
      content: Text(text, style: VType.callout()),
    ));
  }

  void _submitInline() {
    final text = _inlineCtrl.text.trim();
    if (text.isEmpty && _attachedFiles.isEmpty) return;
    widget.onSendInlineReply?.call(text);
    _inlineCtrl.clear();
    setState(() => _attachedFiles.clear());
  }

  Future<void> _pickLocalFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
      if (res != null && res.files.isNotEmpty) {
        setState(() => _attachedFiles.addAll(res.files.map((f) => f.name)));
        final note = await FileStore.instance.addPicked(res.files, 'model'); // listed in Files (D22)
        if (!mounted) return;
        if (note != null) {
          await showVAlert(context, icon: Icons.error_outline_rounded, title: note, actions: const [VAlertChoice('OK')]);
        } else {
          _toast('Attached ${res.files.length} file(s)');
        }
      }
    } catch (_) {}
  }

  void _copyLastMessage() {
    if (widget.item.conversation.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.item.conversation.last.text));
    _toast('Copied ${widget.item.modelDef.label}');
  }

  @override
  Widget build(BuildContext context) => widget.pane ? _buildPane(context) : _buildCard(context);

  /// The opened answer: summary on top, the tools, the whole conversation
  /// (fills the tray) and the reply field for this model.
  Widget _buildPane(BuildContext context) {
    final item = widget.item;
    final c = item.modelDef.providerColor;
    // The tray that hosts this already supplies the frost and the specular rim,
    // so this surface is a defined plane on top of it: an opaque-leaning fill
    // that lets the model tint through without adding a second transparent
    // layer. It used to run its own 18 px BackdropFilter over another glass
    // window, which is exactly the translucent-on-translucent stacking the
    // house rule forbids, and it still carries real elevation.
    final surface = Color.alphaBlend(c.withValues(alpha: 0.16), const Color(0xFF171722));
    // v9.1.4 (playtest #6): the opened answer is frosted glass, no rim.
    return ClipRRect(
      borderRadius: BorderRadius.circular(VRadius.lg - 4),
      child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: VFrost.blur, sigmaY: VFrost.blur),
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.withValues(alpha: 0.06), VFrost.tint),
        borderRadius: BorderRadius.circular(VRadius.lg - 4),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.46), blurRadius: 34, spreadRadius: -6, offset: const Offset(0, 18)),
          BoxShadow(color: c.withValues(alpha: 0.22), blurRadius: 22, spreadRadius: -10),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(VSpace.sm, 10, VSpace.xs, 8),
        child: _paneBody(context, c),
      ),
    ),
    ),
    );
  }

  Widget _paneBody(BuildContext context, Color c) {
    final item = widget.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
// E2E: in the opened answer the summary sits where the model name used to
              // sit and the name drops to fine print underneath.
              //
              // v9: the fine print keeps the time and drops the name. Both
              // changes agree on the important part — the answer leads — but
              // the model name was never asked for, and printing it under the
              // answer still puts it on screen.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.summary.isNotEmpty)
                      Text(item.summary, style: VType.callout(weight: FontWeight.w600).copyWith(height: 1.32)),
                    if (item.relativeTime.isNotEmpty) ...[
                      if (item.summary.isNotEmpty) const SizedBox(height: 3),
                      Text(item.relativeTime, style: VType.caption(color: VColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              VCloseButton(onTap: widget.onToggleExpand),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            runSpacing: 6,
            children: [
              _Tool(
                icon: _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
                tooltip: 'Search conversation',
                selected: _isSearching,
                onTap: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchFilter = '';
                }),
              ),
              _Tool(icon: Icons.attach_file_rounded, tooltip: 'Local model files', onTap: _pickLocalFiles),
              if (widget.onOpenLocalHistory != null) _Tool(icon: Icons.history_rounded, tooltip: 'Local history', onTap: widget.onOpenLocalHistory),
              _Tool(icon: Icons.copy_rounded, tooltip: 'Copy answer', onTap: _copyLastMessage),
              if (widget.onOpenBrowser != null) _Tool(icon: Icons.language_rounded, tooltip: 'Model browser', onTap: widget.onOpenBrowser),
            ],
          ),
          ..._expanded(item, fill: true),
      ],
    );
  }

  /// A collapsed card in the left column.
  Widget _buildCard(BuildContext context) {
    final item = widget.item;
    final c = item.modelDef.providerColor;
    final e = widget.isExpanded ? 1.0 : widget.elevation.clamp(0.0, 1.0);
    // Colour-coded card: each model owns a tint; higher cards sit higher (brighter, deeper shadow).
    // A card is a defined plane, not a third transparent wash: the wallpaper is
    // already behind one frosted window, so the tint is blended onto an opaque
    // base. Translucent gradients stacked on translucent glass are what made the
    // ticker read as one unlayered slab.
    final tint = Color.lerp(c.withValues(alpha: 0.10), c.withValues(alpha: 0.24), e)!;
    final top = Color.alphaBlend(tint, const Color(0xFF15151E));
    final bottom = Color.lerp(top, Colors.black, 0.20)!;
    final waiting = item.isStreaming;

    return AnimatedContainer(
      duration: VMotion.base,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        // v9.1.2: a soft translucent chat bubble straight on the wallpaper,
        // no outline.
        color: Color.alphaBlend(c.withValues(alpha: 0.06 + 0.08 * e), const Color(0xD018181E)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6))],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VPress(
            onTap: widget.onToggleExpand,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // v9.1 (David): a narrow model-name column; the one-line
                // summary gets the width. Opening the card shows it in full.
                // v9.1 ambient: a living pulse only while the model is answering.
                if (waiting) ...[_PulseDot(color: c), const SizedBox(width: 6)],
                SizedBox(
                  width: 74,
                  child: Text(item.modelDef.label, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w600).copyWith(height: 1.15)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: waiting
                      ? _SkeletonLines(key: const ValueKey('wait'), color: c)
                      : Text(item.summary.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: VType.footnote(color: VColors.textPrimary, weight: FontWeight.w400).copyWith(height: 1.3)),
                ),
                if (!waiting && item.relativeTime.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(item.relativeTime, style: VType.caption(color: VColors.textTertiary, weight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          if (widget.isExpanded) const SizedBox(height: 6),
          if (widget.isExpanded) VPress(
            onTap: widget.onToggleExpand,
            child: AnimatedSwitcher(
              duration: VMotion.base,
              layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
              child: waiting
                  ? _SkeletonLines(key: const ValueKey('wait'), color: c)
                  : Text(
                      // Never truncated. The owner's rule: the summary is
                      // always present in full for each model response, and a
                      // card that grows scrolls inside the ticker window behind
                      // its edge fade. v9 raises it from textSecondary to
                      // textPrimary — it is the content of the card, and at
                      // tertiary weight it read as disabled.
                      item.summary,
                      key: ValueKey(item.summary),
                      style: VType.footnote(color: VColors.textPrimary, weight: FontWeight.w400).copyWith(height: 1.35),
                    ),
            ),
          ),
          if (item.mediaUrls != null && item.mediaUrls!.isNotEmpty) ...[
            const SizedBox(height: VSpace.xs),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.mediaUrls!.length,
                separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.sm),
                  child: ThemeImage(_mediaPosterFor(i), width: 58, height: 58, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The conversation fills the pane, or stays under 240 px elsewhere.
  Widget _fillOr(bool fill, {required Widget child}) =>
      fill ? Expanded(child: child) : ConstrainedBox(constraints: const BoxConstraints(maxHeight: 240), child: child);

  List<Widget> _expanded(TickerItem item, {bool fill = false}) {
    return [
      if (_isSearching) ...[
        const SizedBox(height: VSpace.xs),
        VSearchField(
          controller: _searchCtrl,
          hint: 'Search',
          height: 32,
          onChanged: (v) => setState(() => _searchFilter = v.toLowerCase()),
        ),
      ],
      if (_attachedFiles.isNotEmpty) ...[
        const SizedBox(height: VSpace.xs),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in _attachedFiles)
              VChip(label: f, selected: true, onTap: () => setState(() => _attachedFiles.remove(f))),
          ],
        ),
      ],
      const SizedBox(height: VSpace.xs),
      _fillOr(
        fill,
        child: EdgeFade(
          fadeHeight: 12,
          child: ListView.builder(
            shrinkWrap: !fill,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
            itemCount: item.conversation.length,
            itemBuilder: (_, i) {
              final msg = item.conversation[i];
              if (_searchFilter.isNotEmpty && !msg.text.toLowerCase().contains(_searchFilter)) {
                return const SizedBox.shrink();
              }
              final isUser = msg.sender == 'user';
              final t = msg.timestamp;
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: VPress(
                  onTap: () => widget.onTapMessage?.call(msg),
                  child: _TailedBubble(
                    isUser: isUser,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // v9: a model message is stamped with its time only.
                          // "You" still marks the user's own turns; model names
                          // never appear on the thread.
                          '${isUser ? 'You' : ''}  ${(t.hour % 12 == 0 ? 12 : t.hour % 12)}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}'.trim(),
                          style: VType.caption(color: VColors.textSecondary, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        isUser
                            ? Text(msg.text, style: VType.callout(weight: FontWeight.w400).copyWith(height: 1.4))
                            // Full answer, never cut: the owner banned truncating
                            // what a model said. The user's own message may be
                            // shortened in future, but only behind something
                            // that expands it.
                            : MdText(msg.text),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // v9.1.4 (playtest #6): no second input; the one composer is at the bottom.
      // v9.1.6: ported back verbatim from v9-final (collider-source).
      const SizedBox(height: VSpace.xs),
      // Isolated inline composer capsule (sends to this model only)
      Container(
        height: 40,
        padding: const EdgeInsets.only(left: VSpace.sm, right: 4),
        decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inlineCtrl,
                cursorColor: VColors.textPrimary,
                style: VType.callout(weight: FontWeight.w400),
                decoration: InputDecoration(
                  hintStyle: VType.callout(color: VColors.textTertiary, weight: FontWeight.w400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _submitInline(),
              ),
            ),
            VCircleButton(icon: Icons.arrow_upward_rounded, size: 32, selected: true, tooltip: 'Send', onTap: _submitInline),
          ],
        ),
      ),
    ];
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;
  const _Tool({required this.icon, required this.tooltip, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: VCircleButton(icon: icon, size: 28, tooltip: tooltip, selected: selected, onTap: onTap),
    );
  }
}

/// Speech bubble with a directional tail (no nested blur: plain fill on glass).
class _TailedBubble extends StatelessWidget {
  final bool isUser;
  final Widget child;
  const _TailedBubble({required this.isUser, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      constraints: const BoxConstraints(maxWidth: 260),
      child: ClipPath(
        clipper: _TailedBubbleClipper(isUser: isUser),
        child: Container(
          padding: EdgeInsets.fromLTRB(isUser ? 12 : 14, 8, isUser ? 14 : 12, 16),
          color: isUser ? VColors.overlayLight : VColors.fillCell,
          child: child,
        ),
      ),
    );
  }
}

class _TailedBubbleClipper extends CustomClipper<Path> {
  final bool isUser;
  const _TailedBubbleClipper({required this.isUser});

  @override
  Path getClip(Size size) {
    const radius = VRadius.md;
    const tail = 8.0;
    final bottom = size.height - tail;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, bottom), const Radius.circular(radius)));
    if (isUser) {
      path.moveTo(size.width - 18, bottom);
      path.lineTo(size.width - 2, size.height);
      path.lineTo(size.width - 24, bottom - 1);
    } else {
      path.moveTo(18, bottom);
      path.lineTo(2, size.height);
      path.lineTo(24, bottom - 1);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _TailedBubbleClipper oldClipper) => oldClipper.isUser != isUser;
}


/// Shimmering loading lines shown until the answer arrives.
class _SkeletonLines extends StatefulWidget {
  final Color color;
  const _SkeletonLines({super.key, required this.color});
  @override
  State<_SkeletonLines> createState() => _SkeletonLinesState();
}

class _SkeletonLinesState extends State<_SkeletonLines> with SingleTickerProviderStateMixin {
  // v9.1.4 (playtest #13/#16): waiting is a quiet fade, not shimmer bars; a
  // model that hasn't answered after 25 s says so plainly.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  bool _late = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 25), () {
      if (!mounted) return;
      _c.stop();
      setState(() => _late = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 15, color: Color(0xB3FFFFFF));
    if (_late) return const Text("Couldn't reach this model", style: st);
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 0.8).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: const Text('Thinking…', style: st),
    );
  }
}


class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
        child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
      );
}
