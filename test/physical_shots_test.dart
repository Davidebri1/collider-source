import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:collider_flutter/features/smartgen/sg_physical.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desk shows canvas objects holding a card', (tester) async {
    tester.view.physicalSize = const Size(880, 1912);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SgStore.instance;
    store.debugReset();
    store.ensureStarter();
    store.addCanvas('Notebook', 'Notebook');
    store.addCanvas('Gallery', 'Gallery');
    store.addCanvas('Folder', 'Folder');
    final card = store.addCard(SgType.note)!;
    store.touch(() => card.title = 'Field note');
    store.atHome = false;
    store.loaded = true;
    addTearDown(store.debugReset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Scaffold(
        body: SizedBox(
          width: 440,
          height: 700,
          child: SgPhysicalStage(store: store, onOpen: (_) {}),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Notebook'), findsWidgets);
    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('Folder'), findsWidgets);
    expect(find.text('Field note'), findsWidgets);
    expect(find.text('No notebook pages yet'), findsNothing);
    expect(find.text('Canvas 1'), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}
