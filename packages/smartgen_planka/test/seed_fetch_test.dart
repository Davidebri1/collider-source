import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/providers/auth_provider.dart';
import 'package:planka_app/providers/list_provider.dart';
import 'package:planka_app/providers/project_provider.dart';

void main() {
  testWidgets('seed then fetch', (tester) async {
    final store = PlankaStore.instance;
    store.onSave = (_) async {};
    store.onLoad = () async => null;
    // reset loaded flag via new seed which clears
    final ids = store.seedCapturePreview();
    expect(store.lists.length, 3);
    expect(store.cards.length, 4);
    final auth = AuthProvider();
    final lp = ListProvider(auth);
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      return FutureBuilder(
        future: lp.fetchLists(boardId: ids['boardId']!, context: ctx),
        builder: (_, s) => Text('lists=${lp.lists.length} state=${s.connectionState} err=${s.hasError}'),
      );
    })));
    await tester.pumpAndSettle();
    print('lists ${lp.lists.length} names=${lp.lists.map((l)=>l.name).toList()}');
    print('cards per ${lp.lists.map((l)=>l.cards.length).toList()}');
    final pp = ProjectProvider(auth);
    await pp.fetchProjects();
    print('projects ${pp.projects.map((p)=>p.name).toList()}');
    expect(lp.lists.length, 3);
    expect(pp.projects.length, 1);
  });
}
