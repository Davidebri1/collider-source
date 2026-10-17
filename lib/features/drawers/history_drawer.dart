import 'package:flutter/material.dart';
import '../../../models/ticker_item.dart';
import '../../../core/vision/cpane.dart';
import '../../../core/vision/vision_kit.dart';
import '../../../core/vision/selection.dart';

/// REQ-13 Global History Drawer — notes-list window (Vision OS Design System
/// 417:8104 "All iCloud"): large title, recessed search capsule, rows with
/// title, one-line summary and relative time; edges fade into the glass.
class HistoryDrawer extends StatefulWidget {
  final List<ConversationHistorySession> sessions;
  final Function(ConversationHistorySession session) onSelectSession;
  final VoidCallback onClose;

  const HistoryDrawer({
    super.key,
    required this.sessions,
    required this.onSelectSession,
    required this.onClose,
  });

  @override
  State<HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<HistoryDrawer> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  final Selection<String> _sel = Selection<String>();

  @override
  void initState() {
    super.initState();
    HistoryEdits.instance.load();
    HistoryEdits.instance.addListener(_r);
    _sel.addListener(_r);
  }

  void _r() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _searchCtrl.dispose();
    HistoryEdits.instance.removeListener(_r);
    _sel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final ed = HistoryEdits.instance;
    final sessions = widget.sessions
        .where((s) => !ed.hidden.contains(s.id))
        .map((s) => ed.titles[s.id] == null ? s : ConversationHistorySession(id: s.id, title: ed.titles[s.id]!, targetModelId: s.targetModelId, relativeTime: s.relativeTime, timestamp: s.timestamp, summary: s.summary, modelIds: s.modelIds, messages: s.messages))
        .where((s) => q.isEmpty || s.title.toLowerCase().contains(q) || s.summary.toLowerCase().contains(q))
        .toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: widget.onClose),
        // v9.1.7: on CPane (centred, one glass, layer elevation, shell reserve).
        CPaneWindow(
              title: 'History',
              actions: [VCircleButton(icon: Icons.close_rounded, tooltip: 'Close', onTap: widget.onClose)],
              child: HistorySessionList(
                sessions: sessions,
                searchController: _searchCtrl,
                onQuery: (v) => setState(() => _query = v.trim()),
                onSelect: (x) => _sel.active ? _sel.toggle(x.id) : widget.onSelectSession(x),
                selected: _sel.ids,
                onLongPress: (x) => _sel.toggle(x.id),
              ),
            ),
        if (_sel.active)
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: Center(
              child: SelectionBar(
                count: _sel.count,
                onSelectAll: () => _sel.all(sessions.map((x) => x.id)),
                onDone: _sel.clear,
                actions: [
                  SelectionAction(Icons.edit_rounded, 'Rename', () async {
                    final t = await askName(context, title: 'Rename ${_sel.count} chats');
                    if (t != null && t.trim().isNotEmpty) await ed.rename(_sel.ids, t.trim());
                    _sel.clear();
                  }),
                  SelectionAction(Icons.delete_outline_rounded, 'Delete', () async {
                    await ed.hide(_sel.ids);
                    _sel.clear();
                  }, destructive: true),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared notes-style session list (global + local history).
class HistorySessionList extends StatelessWidget {
  final List<ConversationHistorySession> sessions;
  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final ValueChanged<ConversationHistorySession> onSelect;
  final String searchHint;
  /// v9.1 multi-select (optional).
  final Set<String> selected;
  final ValueChanged<ConversationHistorySession>? onLongPress;

  const HistorySessionList({
    this.selected = const {},
    this.onLongPress,
    super.key,
    required this.sessions,
    required this.searchController,
    required this.onQuery,
    required this.onSelect,
    this.searchHint = 'Search',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSearchField(controller: searchController, hint: searchHint, onChanged: onQuery),
        const SizedBox(height: VSpace.sm),
        Flexible(
          // Nothing saved: nothing shown (v8.3, D45).
          child: sessions.isEmpty
              ? const SizedBox(height: VSpace.xl)
              : EdgeFade(
                  fadeHeight: 14,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: VSpace.xxs),
                    itemBuilder: (_, i) {
                      final s = sessions[i];
                      final on = selected.contains(s.id);
                      return GestureDetector(
                        onLongPress: onLongPress == null ? null : () => onLongPress!(s),
                        child: VPress(
                        onTap: () => onSelect(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: VSpace.sm, vertical: 10),
                          decoration: BoxDecoration(
                            color: on ? const Color(0x660A84FF) : VColors.fillCell,
                            borderRadius: BorderRadius.circular(VRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(s.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: VType.callout(weight: FontWeight.w600).copyWith(fontSize: VType.md)),
                                  ),
                                  const SizedBox(width: VSpace.xs),
                                  Text(s.relativeTime, style: VType.caption()),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(s.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.footnote()),
                            ],
                          ),
                        ),
                      ));
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
