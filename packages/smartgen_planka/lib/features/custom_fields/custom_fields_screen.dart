import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

/// PLANKA custom field types (exact names/casing from PLANKA Pro).
const _fieldTypes = <({String key, String label, IconData icon})>[
  (key: 'text', label: 'Text', icon: Icons.short_text),
  (key: 'number', label: 'Number', icon: Icons.pin_outlined),
  (key: 'date', label: 'Date', icon: Icons.event),
  (key: 'currency', label: 'Currency', icon: Icons.attach_money),
  (key: 'checkbox', label: 'Yes/No', icon: Icons.check_box_outlined),
  (key: 'url', label: 'URL', icon: Icons.link),
  (key: 'dropdown', label: 'Dropdown', icon: Icons.arrow_drop_down_circle_outlined),
];

String _labelForType(String type) {
  for (final t in _fieldTypes) {
    if (t.key == type) return t.label;
  }
  if (type.isEmpty) return type;
  return '${type[0].toUpperCase()}${type.substring(1)}';
}

IconData _iconFor(String type) {
  for (final t in _fieldTypes) {
    if (t.key == type) return t.icon;
  }
  return Icons.short_text;
}

class CustomFieldsScreen extends StatefulWidget {
  const CustomFieldsScreen({super.key, this.openAddOnLoad = false});
  final bool openAddOnLoad;
  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen> {
  String? _boardId;

  @override
  void initState() {
    super.initState();
    final boards = PlankaStore.instance.boards;
    _boardId = boards.isNotEmpty ? boards.first['id'] as String : null;
    if (widget.openAddOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final groups = PlankaStore.instance.customFieldGroups
            .where((g) => g['boardId'] == _boardId)
            .toList();
        if (groups.isNotEmpty) _openAddFieldSheet(groups.first['id'] as String);
      });
    }
  }

  Future<void> _openAddFieldSheet(String groupId) async {
    final store = PlankaStore.instance;
    final nameCtrl = TextEditingController();
    String selected = 'text';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Custom Fields', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in _fieldTypes)
                        ChoiceChip(
                          showCheckmark: false,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon, size: 16),
                              const SizedBox(width: 6),
                              Text(t.label),
                            ],
                          ),
                          selected: selected == t.key,
                          onSelected: (_) => setSheet(() => selected = t.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty || _boardId == null) return;
                      store.createCustomField(
                        boardId: _boardId!,
                        customFieldGroupId: groupId,
                        name: name,
                        type: selected,
                        options: selected == 'dropdown' ? const ['Open', 'Blocked', 'Done'] : null,
                      );
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                    child: const Icon(Icons.check),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final groups = store.customFieldGroups.where((g) => g['boardId'] == _boardId).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Fields'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _boardId == null
                ? null
                : () async {
                    store.createCustomFieldGroup(boardId: _boardId!, name: 'Group');
                    setState(() {});
                  },
          ),
        ],
      ),
      body: _boardId == null
          ? const Center(child: Icon(Icons.inbox_outlined))
          : ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                for (final g in groups) ...[
                  ListTile(
                    title: Text('${g['name']}', textAlign: TextAlign.center),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        store.deleteCustomFieldGroup(g['id'] as String);
                        setState(() {});
                      },
                    ),
                  ),
                  ...store.customFields
                      .where((f) => f['customFieldGroupId'] == g['id'])
                      .map((f) => ListTile(
                            dense: true,
                            leading: Icon(_iconFor('${f['type']}')),
                            title: Text('${f['name']}'),
                            subtitle: Text(_labelForType('${f['type']}')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                store.deleteCustomField(f['id'] as String);
                                setState(() {});
                              },
                            ),
                          )),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: IconButton(
                        tooltip: 'Custom Fields',
                        onPressed: () => _openAddFieldSheet(g['id'] as String),
                        icon: const Icon(Icons.add),
                      ),
                    ),
                  ),
                  const Divider(),
                ],
              ],
            ),
    );
  }
}
