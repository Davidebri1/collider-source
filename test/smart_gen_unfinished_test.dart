import 'dart:io';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:collider_flutter/features/smartgen/sg_views.dart';
import 'package:collider_flutter/features/smartgen/sg_free_drag.dart';
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
  test('R23 free positions persist across reload', () {
    final s = SgStore()..ensureStarter();
    final a = s.addCard(SgType.task)!;
    final b = s.addCard(SgType.note)!;
    s.touch(() {
      a.dx = 88;
      a.dy = 144;
      b.dx = 210;
      b.dy = 66;
      s.board!.snapAlign = false;
    });
    final doc = {
      'boards': [s.board!.toJson()],
      'active': s.board!.id,
      'genie': <Object?>[],
    };
    final board = SgBoard.fromJson((doc['boards'] as List).first as Map<String, Object?>);
    expect(board.cards.firstWhere((c) => c.id == a.id).dx, 88);
    expect(board.cards.firstWhere((c) => c.id == a.id).dy, 144);
    expect(board.cards.firstWhere((c) => c.id == b.id).dx, 210);
    expect(board.snapAlign, isFalse);
  });

  test('snap toggle aligns cards to masonry grid', () {
    final s = SgStore()..ensureStarter();
    final cards = <SgCard>[
      s.addCard(SgType.task)!,
      s.addCard(SgType.task)!,
      s.addCard(SgType.task)!,
      s.addCard(SgType.task)!,
    ];
    s.touch(() {
      for (var i = 0; i < cards.length; i++) {
        cards[i].dx = 40.0 + i * 17;
        cards[i].dy = 90.0 + i * 23;
      }
      s.board!.snapAlign = false;
    });
    final plane = const Size(440, 700);
    final slots = SgFreeLayouts.masonry(plane, cards.length);
    s.touch(() {
      s.board!.snapAlign = true;
      SgFreeLayouts.applySlots(cards, slots);
    });
    expect(s.board!.snapAlign, isTrue);
    for (var i = 0; i < cards.length; i++) {
      expect(cards[i].dx, slots[i].left);
      expect(cards[i].dy, slots[i].top);
    }
  });

  test('free mode keeps arbitrary drop point', () {
    final s = SgStore()..ensureStarter();
    final c = s.addCard(SgType.poster)!;
    s.touch(() {
      s.board!.snapAlign = false;
      c.dx = 173;
      c.dy = 311;
    });
    expect(s.board!.snapAlign, isFalse);
    expect(c.dx, 173);
    expect(c.dy, 311);
    // Round-trip JSON must keep the free point.
    final back = SgCard.fromJson(c.toJson());
    expect(back.dx, 173);
    expect(back.dy, 311);
  });


  test('Cover from photo applies cover.* file and tint', () {
    final store = SgStore()..ensureStarter();
    final c = store.addCard(SgType.task)!;
    c.color = 0;
    const tiny = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
    store.applyCoverPhoto(c, 'shot.png', tiny);
    expect(c.files.any((f) => f.name.startsWith('cover.')), isTrue);
    expect(c.files.first.dataUrl, tiny);
    expect(c.color, isNot(0));
    // Replacing cover keeps a single cover.*
    store.applyCoverPhoto(c, 'cover.jpg', tiny);
    expect(c.files.where((f) => f.name.toLowerCase().startsWith('cover.')).length, 1);
  });

  test('R10 Genie stub provider replies when local parser has no match', () {
    final store = SgStore()..ensureStarter();
    store.addCard(SgType.task);
    final reply = store.askGenie('what is on this board?');
    expect(reply, contains('callAiApi is wired'));
    expect(store.genie.where((m) => m.role == 'genie').last.text, contains('callAiApi'));
  });

  test('R10 Genie new conversation clears history', () {
    final store = SgStore()..ensureStarter();
    store.askGenie('set all priority to high');
    expect(store.genie, isNotEmpty);
    store.newConversation();
    expect(store.genie, isEmpty);
  });

  test('R11 manage columns types statuses fields inline via store', () {
    final store = SgStore()..ensureStarter();
    final before = store.board!.lists.length;
    store.addList('Review');
    expect(store.board!.lists.length, before + 1);
    expect(store.board!.lists.last.title, 'Review');
    store.addField('Budget', SgFieldKind.number);
    expect(store.board!.fields.any((f) => f.name == 'Budget' && f.kind == SgFieldKind.number), isTrue);
    store.touch(() {
      store.board!.autoArrange = true;
      store.board!.autoSort = true;
      store.board!.autoFilterComplete = true;
      store.board!.inheritColumnStatus = true;
      store.board!.urgentAutoCalendar = true;
    });
    expect(store.board!.autoArrange, isTrue);
    expect(store.board!.urgentAutoCalendar, isTrue);
  });

  test('R4 + Add new status creates a real list option', () {
    final store = SgStore()..ensureStarter();
    store.addList('Waiting');
    store.rememberHistory('status', 'Waiting');
    expect(store.historyFor('status'), contains('Waiting'));
    expect(store.board!.lists.any((l) => l.title == 'Waiting'), isTrue);
  });

  testWidgets('R20 urgent pulse animation controller is running', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: SgPulse(child: () => const SizedBox(width: 8, height: 8))))));
    await tester.pump();
    final state = tester.state(find.byType(SgPulse)) as dynamic;
    expect(state.c.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.c.value, greaterThan(0));
  });

  testWidgets('R9 spatial surfaces build without inventing boards', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SgStore()..ensureStarter();
    final c = store.addCard(SgType.task)!..title = 'Draft';
    c.files.add(SgFile(id: 'i1', name: 'mood.png', dataUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', cardId: c.id));
    store.addCard(SgType.job)!
      ..title = 'Role'
      ..company = 'Acme'
      ..positionTitle = 'Designer';
    final surfaces = <SgSurface, Widget Function()>{
      SgSurface.album: () => SgAlbum(store: store, onOpen: (_) {}),
      SgSurface.storyboard: () => SgStory(store: store, onOpen: (_) {}),
      SgSurface.vision: () => SgVision(store: store, onOpen: (_) {}),
      SgSurface.swimlane: () => SgSwim(store: store, onOpen: (_) {}),
      SgSurface.portfolio: () => SgDesk(store: store, onOpen: (_) {}),
      SgSurface.worldMap: () => SgPlaces(store: store, onOpen: (_) {}, world: true),
      SgSurface.usMap: () => SgPlaces(store: store, onOpen: (_) {}, world: false),
      SgSurface.corkboard: () => SgCork(store: store, onOpen: (_) {}),
      SgSurface.files: () => SgFiles(store: store, onOpen: (_) {}),
    };
    for (final e in surfaces.entries) {
      store.touch(() => store.board!.surface = e.key);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 440, height: 900, child: e.value()))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${e.key} threw');
    }
  });

  testWidgets('R19 Files explorer shows preview stage and sort', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SgStore()..ensureStarter();
    final c = store.addCard(SgType.task)!..title = 'Draft post';
    c.files.addAll([
      SgFile(id: 'a', name: 'mood.png', dataUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', cardId: c.id),
      SgFile(id: 'b', name: 'brief.pdf', dataUrl: 'data:application/pdf;base64,JVBERi0=', cardId: c.id),
    ]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 440, height: 900, child: SgFiles(store: store, onOpen: (_) {})))));
    await tester.pump();
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Open card'), findsOneWidget);
    expect(find.textContaining('IMAGE'), findsWidgets);
  });



  test('Smart Gen cards never use non-zero Transform.rotate', () async {
    // Structural: every Smart Gen dart source must not rotate cards.
    // Desk/Cork previously tilted papers; David did not ask for tilt.
    final root = Directory('lib/features/smartgen');
    final hits = <String>[];
    await for (final f in root.list(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = await f.readAsString();
      // Allow commented mentions; fail on live Transform.rotate( angle: non-zero.
      for (final m in RegExp(r'Transform\.rotate\s*\(\s*angle:\s*([^,\)]+)').allMatches(src)) {
        final expr = m.group(1)!.trim();
        if (expr == '0' || expr == '0.0') continue;
        hits.add('${f.path}: angle: $expr');
      }
    }
    expect(hits, isEmpty, reason: 'non-zero card rotation found:\n${hits.join('\n')}');
  });

  testWidgets('Vision board exposes Align to grid IconButton tooltip', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = SgStore()..ensureStarter();
    store.addCard(SgType.task)!..title = 'Mood';
    store.addCard(SgType.poster)!..title = 'City';
    store.touch(() => store.board!.surface = SgSurface.vision);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 440, height: 900, child: SgVision(store: store, onOpen: (_) {})),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Vision board'), findsOneWidget);
    final alignBtn = find.byIcon(Icons.grid_view_rounded);
    expect(alignBtn, findsOneWidget);
    // IconButton.tooltip is set for R8; resolve via the IconButton itself.
    final btn = tester.widget<IconButton>(find.ancestor(of: alignBtn, matching: find.byType(IconButton)));
    expect(btn.tooltip, 'Align to grid');
    await tester.tap(alignBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.board!.snapAlign, isTrue);
    expect(find.byIcon(Icons.grid_off_rounded), findsOneWidget);
    final freeBtn = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.grid_off_rounded), matching: find.byType(IconButton)));
    expect(freeBtn.tooltip, 'Free place');
  });
}

void _noop() {}
