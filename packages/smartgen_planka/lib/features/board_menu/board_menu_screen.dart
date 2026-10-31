import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

/// Trello iOS "Board menu" (lowercase m in title).
class BoardMenuScreen extends StatelessWidget {
  const BoardMenuScreen({super.key});

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
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const SizedBox.shrink(),
            onTap: () => Navigator.pushNamed(context, '/genie'),
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const SizedBox.shrink(),
            enabled: store.canUndo,
            onTap: store.canUndo
                ? () {
                    store.undo();
                    Navigator.pop(context);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.redo),
            title: const SizedBox.shrink(),
            enabled: store.canRedo,
            onTap: store.canRedo
                ? () {
                    store.redo();
                    Navigator.pop(context);
                  }
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Members'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Invite to workspace'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About this board'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Change visibility'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Change background'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Labels'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions_outlined),
            title: const Text('Stickers'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Custom Fields'),
            onTap: () => Navigator.pushNamed(context, '/customfields'),
          ),
          ListTile(
            leading: const Icon(Icons.extension_outlined),
            title: const Text('Power-Ups'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Automation'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Table'),
            subtitle: const Text('Calendar and Timeline'),
            onTap: () => Navigator.pushNamed(context, '/views'),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search'),
            onTap: () => Navigator.pushNamed(context, '/search'),
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('Archived items'),
            onTap: () => Navigator.pushNamed(context, '/archive'),
          ),
          ListTile(
            leading: const Icon(Icons.filter_list),
            title: const Text('Filter cards'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copy board'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email-to-board settings'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Print, export, and share'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Activity'),
            onTap: () {},
          ),
          SwitchListTile(
            secondary: Icon(store.snapAlign ? Icons.dashboard_outlined : Icons.open_with),
            title: Text(store.snapAlign ? 'Align to grid' : 'Free place'),
            value: store.snapAlign,
            onChanged: (v) {
              store.snapAlign = v;
              store.persist();
              (context as Element).markNeedsBuild();
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave board'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Close board'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
