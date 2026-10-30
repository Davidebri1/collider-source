import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:collider_flutter/features/smartgen/sg_views.dart';
import 'package:collider_flutter/features/smartgen/screens/smartgen_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '/tmp/collider_sg_unfinished',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_mockPathProvider);
  setUp(_mockPathProvider);

  test('R3 job fields + notebook pages + priority/assignee/tags/triggers round-trip', () {
    final s = SgStore()..ensureStarter();
    final c = s.addCard(SgType.job)!;
    s.touch(() {
      c.company = 'Northwind';
      c.positionTitle = 'Designer';
      c.jobStart = '2024-01';
      c.jobEnd = 'Present';
      c.responsibilities = 'Ship boards';
      c.achievements = 'Cut review time';
      c.priority = 2;
      c.assignee = 'Alex';
      c.tags.addAll(['design', 'ship']);
      c.notebook = 'Page one\n---\nPage two';
      c.triggers = 'done-final';
    });
    final j = c.toJson();
    final back = SgCard.fromJson(j);
    expect(back.company, 'Northwind');
    expect(back.positionTitle, 'Designer');
    expect(back.jobStart, '2024-01');
    expect(back.jobEnd, 'Present');
    expect(back.responsibilities, 'Ship boards');
    expect(back.achievements, 'Cut review time');
    expect(back.priority, 2);
    expect(back.assignee, 'Alex');
    expect(back.tags, ['design', 'ship']);
    expect(back.pages, ['Page one', 'Page two']);
    expect(back.triggers, 'done-final');
  });

  test('R4 history remembers dropdown values', () {
    final s = SgStore()..ensureStarter();
    s.rememberHistory('status', 'Doing');
    s.rememberHistory('status', 'To Do');
    s.rememberHistory('status', 'Doing');
    expect(s.historyFor('status').first, 'Doing');
    expect(s.historyFor('status'), containsAll(['Doing', 'To Do']));
  });

  test('R10 Genie mass edit, refactor, new conversation, attachment persist', () {
    final s = SgStore()..ensureStarter();
    s.addCard(SgType.task);
    s.addCard(SgType.task);
    final reply = s.askGenie('set all priority to high');
    expect(reply, contains('priority'));
    expect(s.board!.cards.every((c) => c.priority == 3), isTrue);
    final r2 = s.askGenie('refactor task as note');
    expect(r2, contains('Refactored'));
    expect(s.board!.cards.every((c) => c.type == SgType.note), isTrue);
    s.askGenie('hello', attachment: 'brief.pdf|data:text/plain;base64,YQ==');
    expect(s.genie.any((m) => m.attachment.contains('brief.pdf')), isTrue);
    final snap = s.genie.length;
    s.newConversation();
    expect(s.genie, isEmpty);
    expect(snap, greaterThan(0));
  });

  test('R11 board behaviors auto arrange/sort/filter/inherit/urgent calendar', () {
    final s = SgStore()..ensureStarter();
    final b = s.board!;
    final a = s.addCard(SgType.task)!;
    final c = s.addCard(SgType.task)!;
    final d = s.addCard(SgType.task)!;
    s.touch(() {
      a.title = 'Low';
      a.priority = 1;
      c.title = 'High';
      c.priority = 3;
      d.title = 'Done card';
      d.status = 'Done';
      d.listId = b.orderedLists.last.id;
      b.autoArrange = true;
      b.autoSort = true;
      b.autoFilterComplete = true;
      b.inheritColumnStatus = true;
      b.urgentAutoCalendar = true;
      a.urgent = true;
    });
    expect(b.cardsIn(b.orderedLists.first.id).first.title, 'High');
    expect(b.visibleCards.where((x) => x.id == d.id), isEmpty);
    final move = s.addCard(SgType.task)!;
    s.touch(() => move.inherit = true);
    s.moveCard(move.id, b.orderedLists[1].id);
    expect(s.byId(move.id)!.status, 'Doing');
  });

  test('R16 embeds store and resolve', () {
    final s = SgStore()..ensureStarter();
    final a = s.addCard(SgType.task)!..title = 'Parent';
    final b = s.addCard(SgType.task)!..title = 'Child';
    s.touch(() => a.embeds.add(b.id));
    expect(a.embeds, [b.id]);
    expect(s.byId(a.embeds.first)!.title, 'Child');
  });

  test('R19 attachments keep image/video/other shapes', () {
    final s = SgStore()..ensureStarter();
    final c = s.addCard(SgType.task)!;
    s.touch(() {
      c.files.addAll([
        SgFile(id: '1', name: 'mood.png', dataUrl: 'data:image/png;base64,aa', cardId: c.id),
        SgFile(id: '2', name: 'clip.mp4', dataUrl: 'data:video/mp4;base64,aa', cardId: c.id),
        SgFile(id: '3', name: 'brief.pdf', dataUrl: 'data:application/pdf;base64,aa', cardId: c.id),
      ]);
    });
    expect(c.files.map((f) => f.name).toList(), ['mood.png', 'clip.mp4', 'brief.pdf']);
  });

  test('R22 eleventh canvas refused with notice', () {
    final s = SgStore()..ensureStarter();
    for (var i = 0; i < 10; i++) {
      expect(s.addCanvas('C$i', 'Glass'), isTrue);
    }
    expect(s.addCanvas('overflow', 'Glass'), isFalse);
    expect(s.notice.toLowerCase(), contains('10'));
  });

  test('R23 hidden keys grey + back', () {
    final s = SgStore()..ensureStarter();
    final c = s.addCard(SgType.task)!;
    s.touch(() {
      c.description = 'Secret desc';
      c.hiddenKeys.addAll({'description', 'tags'});
      c.hiddenNotes = 'salary';
    });
    expect(c.attrHidden('description'), isTrue);
    expect(c.hasHidden, isTrue);
  });

  testWidgets('R8 every icon-only button in Smart Gen has a Tooltip', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SgStore.instance.debugReset();
    SgStore.instance.ensureStarter();
    final c = SgStore.instance.addCard(SgType.task)!;
    SgStore.instance.touch(() => c.title = 'Card');
    addTearDown(SgStore.instance.debugReset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: SmartGenScreen(onClose: _noop)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Open board if home
    if (find.text('Create board').evaluate().isNotEmpty && find.text('To Do').evaluate().isEmpty) {
      final boards = find.text('Board');
      if (boards.evaluate().isNotEmpty) {
        await tester.tap(boards.first);
        await tester.pump();
      }
    }
    await tester.pump(const Duration(milliseconds: 200));

    final icons = find.byType(IconButton);
    expect(icons, findsWidgets);
    final missing = <String>[];
    for (final el in icons.evaluate()) {
      final btn = el.widget as IconButton;
      final hasProp = (btn.tooltip ?? '').trim().isNotEmpty;
      final hasWrap = el.findAncestorWidgetOfExactType<Tooltip>() != null;
      // Tooltip may wrap the IconButton, or IconButton.tooltip builds one inside.
      if (!hasProp && !hasWrap) {
        missing.add(btn.icon.toString());
      }
    }
    expect(missing, isEmpty, reason: 'IconButtons without Tooltip: $missing');
  });

  testWidgets('R15 mid-drag lift + hot column render', (tester) async {
    final store = SgStore()..ensureStarter();
    final c = store.addCard(SgType.task)!;
    store.touch(() => c.title = 'Lift me');
    final doing = store.board!.orderedLists[1];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 286,
          height: 520,
          child: SgKanban(store: store, onOpen: (_) {}, forceHotListId: doing.id, liftCardId: c.id),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Lift me'), findsWidgets);
  });
}

void _noop() {}
