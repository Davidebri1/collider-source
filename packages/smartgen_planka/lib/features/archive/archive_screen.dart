import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final archivedCards = store.cards.where((c) => store.archivedCardIds.contains(c['id'])).toList();
    final archivedLists = store.lists.where((l) => store.archivedListIds.contains(l['id'])).toList();
    return Scaffold(
      
      appBar: AppBar(title: const Icon(Icons.archive_outlined)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          for (final l in archivedLists)
            ListTile(
              leading: const Icon(Icons.view_agenda_outlined),
              title: Text('${l['name']}'),
              trailing: IconButton(
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: () {
                  store.archivedListIds.remove(l['id']);
                  store.persist();
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
          for (final c in archivedCards)
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text('${c['name']}'),
              trailing: IconButton(
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: () {
                  store.archivedCardIds.remove(c['id']);
                  store.persist();
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
        ],
      ),
    );
  }
}
