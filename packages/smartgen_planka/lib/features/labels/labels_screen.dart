import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

/// Board labels manager — create / rename / delete.
class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key, this.boardId});
  final String? boardId;

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  static const _palette = <(String name, Color color)>[
    ('berry-red', Color(0xFFEB5A46)),
    ('orange-peel', Color(0xFFFF9F1A)),
    ('yellow-curry', Color(0xFFF2D600)),
    ('bright-moss', Color(0xFF61BD4F)),
    ('lagoon-blue', Color(0xFF0079BF)),
    ('purple-rain', Color(0xFFC377E0)),
  ];

  String get _boardId {
    final store = PlankaStore.instance;
    return widget.boardId ??
        (store.boards.isNotEmpty ? store.boards.first['id'] as String : '');
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final labs = store.labels.where((l) => l['boardId'] == _boardId).toList()
      ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    return Scaffold(
      
      appBar: AppBar(
        
        
        title: const Text('Labels'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          for (final l in labs)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _colorOf('${l['color']}'),
                radius: 12,
              ),
              title: Text('${l['name']}', style: const TextStyle(color: Colors.black87)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.black54),
                onPressed: () {
                  store.deleteLabel(l['id'] as String);
                  setState(() {});
                },
              ),
              onTap: () async {
                final ctrl = TextEditingController(text: '${l['name']}');
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFFFFFFFF),
                    title: const Text('Rename label', style: TextStyle(color: Colors.black87)),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                    ],
                  ),
                );
                if (ok == true && ctrl.text.trim().isNotEmpty) {
                  store.updateLabel(l['id'] as String, name: ctrl.text.trim());
                  setState(() {});
                }
              },
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              final next = _palette[labs.length % _palette.length];
              store.createLabel(
                boardId: _boardId,
                name: 'Label ${labs.length + 1}',
                color: next.$1,
                position: labs.length + 1,
              );
              setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Create a new label'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5C6BC0)),
          ),
        ],
      ),
    );
  }

  Color _colorOf(String name) {
    for (final p in _palette) {
      if (p.$1 == name) return p.$2;
    }
    return const Color(0xFF888888);
  }
}
