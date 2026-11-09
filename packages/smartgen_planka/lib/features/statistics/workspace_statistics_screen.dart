import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

/// Ported from the ARGON 8474 AppFlowy Smart Gen backup
/// (screens/smartgen_screen.dart, _buildStatisticsFloatingPanel, R81):
/// totals plus the breakdown by column, read from this board's real cards.
/// The backup's Priority / Urgent / By Type counts are left out: Smart Gen
/// cards here have no priority, urgency or type field to count.
class WorkspaceStatisticsScreen extends StatelessWidget {
  const WorkspaceStatisticsScreen({super.key, required this.boardId});
  final String? boardId;

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Close Statistics Panel',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Workspace Statistics'),
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final lists = store.lists
              .where((l) => l['boardId'] == boardId && !store.archivedListIds.contains(l['id']))
              .toList()
            ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
          final listIds = {for (final l in lists) l['id']};
          final cards = store.cards
              .where((c) => listIds.contains(c['listId']) && !store.archivedCardIds.contains(c['id']))
              .toList();
          final deadlineCount = cards.where((c) => '${c['dueDate'] ?? ''}'.isNotEmpty).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statMetric('Total', '${cards.length}'),
                  _statMetric('Deadlines', '$deadlineCount'),
                ],
              ),
              const Divider(height: 28),
              const Text('By Column', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final l in lists)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${l['name']}: ${cards.where((c) => c['listId'] == l['id']).length}', style: const TextStyle(fontSize: 14)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statMetric(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
