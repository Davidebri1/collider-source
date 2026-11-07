
import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/features/views/views_screen.dart';
import 'package:planka_app/features/statistics/workspace_statistics_screen.dart';

/// Board menu — stock planka indigo chrome; only offline-capable actions.
class BoardMenuScreen extends StatefulWidget {
  const BoardMenuScreen({super.key});

  @override
  State<BoardMenuScreen> createState() => _BoardMenuScreenState();
}

class _BoardMenuScreenState extends State<BoardMenuScreen> {
  String? get _boardId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) return args;
    final boards = PlankaStore.instance.boards;
    return boards.isEmpty ? null : boards.first['id'] as String;
  }

  String get _boardName {
    final id = _boardId;
    if (id == null) return 'Board';
    for (final b in PlankaStore.instance.boards) {
      if (b['id'] == id) return '${b['name'] ?? 'Board'}';
    }
    return 'Board';
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Board menu'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About this board'),
            onTap: () async {
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(_boardName),
                  content: const Text('Kanban board in Smart Gen.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Change background'),
            onTap: () async {
              const swatches = <Color>[
                Color(0xFF0079BF),
                Color(0xFF519839),
                Color(0xFFB04632),
                Color(0xFF89609E),
                Color(0xFFCD5A91),
                Color(0xFF4BBF6B),
                Color(0xFF00AECC),
                Color(0xFF0E1016),
              ];
              final picked = await showModalBottomSheet<Color>(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final c in swatches)
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx, c),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              final id = _boardId;
              if (picked != null && id != null) {
                store.setBoardColor(id, picked.toARGB32());
                if (mounted) setState(() {});
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Labels'),
            onTap: () => Navigator.pushNamed(context, '/labels', arguments: _boardId),
          ),
          ListTile(
            leading: const Icon(Icons.view_column_outlined),
            title: const Text('Views'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Workspace Statistics'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WorkspaceStatisticsScreen(boardId: _boardId)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archived items'),
            onTap: () => Navigator.pushNamed(context, '/archive', arguments: _boardId),
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Undo'),
            enabled: store.canUndo,
            onTap: store.canUndo
                ? () {
                    store.undo();
                    Navigator.pop(context);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Genie'),
            onTap: () => Navigator.pushNamed(context, '/genie'),
          ),
        ],
      ),
    );
  }
}
