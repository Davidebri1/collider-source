import 'dart:math' as math;

import 'package:collider_flutter/features/smartgen/screens/smartgen_screen.dart';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:collider_flutter/features/smartgen/sg_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '/tmp/collider_sg_test',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_mockPathProvider);
  setUp(_mockPathProvider);

  test('parseSmartGen still reads the agent shape', () {
    final r = parseSmartGen('NEED: n\nSERVE: s\nCARDS:\n- Title | note\n');
    expect(r.cards, [('Title', 'note')]);
  });

  test('new board is empty with To Do / Doing / Done', () {
    final s = SgStore()..createBoard('Board');
    final b = s.board!;
    expect(b.name, 'Board');
    expect(b.cards, isEmpty);
    expect(b.lists.map((l) => l.title), ['To Do', 'Doing', 'Done']);
    expect(b.statuses, ['To Do', 'Doing', 'Done']);
  });

  test('store opens with no boards and no invented seed', () {
    final s = SgStore();
    s.loaded = true;
    expect(s.boards, isEmpty);
    expect(s.board, isNull);
    expect(s.atHome, isTrue);
  });

  test('a new card lands at the top of the first list', () {
    final s = SgStore()..ensureStarter();
    final made = s.addCard(SgType.note);
    expect(made, isNotNull);
    expect(s.board!.cardsIn(s.board!.orderedLists.first.id).first.id, made!.id);
  });

  test('dragging into a list inherits that list name when the behavior is on', () {
    final s = SgStore()..ensureStarter();
    final made = s.addCard(SgType.task)!;
    final done = s.board!.orderedLists.last;
    s.moveCard(made.id, done.id);
    expect(s.byId(made.id)!.listId, done.id);
    expect(s.byId(made.id)!.status, 'Done');
  });

  test('hourly trigger advances status and mark-done lands on the final column', () {
    final s = SgStore()..ensureStarter();
    final c = s.addCard(SgType.task)!;
    s.touch(() => c.triggers = 'done-final,hourly');
    expect(s.applyHourly(), greaterThan(0));
    expect(s.byId(c.id)!.status, 'Doing');
    s.markDone(s.byId(c.id)!);
    expect(s.byId(c.id)!.status, 'Done');
  });

  test('the eleventh canvas is refused and the 1000th card is refused', () {
    final s = SgStore()..ensureStarter();
    for (var i = 0; i < 10; i++) {
      expect(s.addCanvas('C$i', 'Glass'), i < 10);
    }
    // first 10 succeed; 11th fails — board starts with 0 canvases
    expect(s.board!.canvases.length, 10);
    expect(s.addCanvas('too many', 'Glass'), isFalse);
    expect(s.notice, contains('10'));
    while (s.cardCount < SgStore.maxCards) {
      final c = s.addCard(SgType.task);
      expect(c, isNotNull);
    }
    expect(s.addCard(SgType.task), isNull);
    expect(s.notice, contains('999'));
  });

  test('bulk delete removes exactly the selected cards', () {
    final s = SgStore()..ensureStarter();
    for (var i = 0; i < 5; i++) {
      s.addCard(SgType.task);
    }
    final ids = s.board!.cards.take(3).map((c) => c.id).toList();
    final before = s.board!.cards.length;
    s.removeCards(ids);
    expect(s.board!.cards.length, before - 3);
    expect(s.board!.cards.where((c) => ids.contains(c.id)), isEmpty);
  });

  test('field types and the done hook match the clone', () {
    expect(kFieldTypes, ['text', 'textarea', 'richtext', 'number', 'date', 'datetime', 'checkbox', 'select', 'multi', 'person', 'url', 'file']);
    expect(SgBoardKind.values.map((k) => k.name), ['notebook', 'portfolio', 'corkboard', 'clipboard', 'ledger', 'desk', 'binder', 'slate']);
    expect(SgHoldKind.values.map((k) => k.name), ['tray', 'shelf', 'table', 'wall', 'spread', 'rack']);
    final status = <String, String>{};
    runHooks(
      kDefaultHooks,
      SgHookEvent(trigger: SgHookTrigger.fieldChange, cardId: 'c1', fieldKey: 'done', value: true),
      SgHookMutations(
        setField: (id, key, value) => status['$id.$key'] = value,
        moveToList: (_, __) {},
        addLabel: (_, __) {},
        createCard: (_, __) {},
      ),
    );
    expect(status['c1.status'], 'done');
  });

  testWidgets('card fronts are upright and a column fits the pane', (tester) async {
    final store = SgStore()..ensureStarter();
    for (final title in ['Alpha', 'Beta', 'Gamma', 'Delta']) {
      final c = store.addCard(SgType.task)!;
      store.touch(() => c.title = title);
    }
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 286,
          height: 520,
          child: SgKanban(store: store, onOpen: (_) {}),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (final title in ['Alpha', 'Beta', 'Gamma', 'Delta']) {
      final finder = find.text(title);
      expect(finder, findsOneWidget, reason: title);
      final text = tester.renderObject<RenderParagraph>(finder);
      expect(text.getTransformTo(null).storage[0], greaterThan(0), reason: '$title is mirrored');
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0), reason: title);
      expect(rect.right, lessThanOrEqualTo(287), reason: '$title is clipped by the pane');
    }
    final todo = tester.getRect(find.text('To Do'));
    final doing = tester.getRect(find.text('Doing'));
    final slot = doing.left - todo.left;
    final peek = (286 - slot) / slot;
    expect(peek, inInclusiveRange(0.15, 0.20), reason: 'the next list should peek');
    expect(doing.left, lessThan(286), reason: 'Doing is off screen');
    expect(todo.right, lessThan(286));

    final position = tester.state<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.horizontal)).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    final add = tester.getRect(find.text('+ Add list'));
    expect(add.left, greaterThanOrEqualTo(0));
    expect(add.right, lessThanOrEqualTo(287));
  });

  testWidgets('a fractional page rests between two lists', (tester) async {
    final store = SgStore()..ensureStarter();
    store.addCard(SgType.task);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 286,
          height: 520,
          child: SgKanban(store: store, onOpen: (_) {}, initialPage: 0.5),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final todo = tester.getRect(find.text('To Do'));
    final doing = tester.getRect(find.text('Doing'));
    expect(todo.left, lessThan(0), reason: 'To Do should be sliding off');
    expect(todo.right, greaterThan(40), reason: 'To Do should still be on screen');
    expect(todo.right, lessThan(286));
    expect(doing.left, greaterThan(todo.right));
    expect(doing.left, lessThan(200));
    expect(doing.right, greaterThan(286), reason: 'Doing should run off the right edge');
  });

  testWidgets('every chip on the card sheet clears 4.5:1 and the actions are fully visible', (tester) async {
    tester.view.physicalSize = const Size(390, 6400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SgStore.instance.debugReset();
    SgStore.instance.ensureStarter();
    final c = SgStore.instance.addCard(SgType.task)!;
    SgStore.instance.touch(() => c.title = 'Sheet card');
    addTearDown(SgStore.instance.debugReset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: SmartGenScreen(onClose: _noop)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Open board from home if needed
    if (find.text('Create board').evaluate().isNotEmpty) {
      await tester.tap(find.text('Create board'));
      await tester.pump();
    }
    if (find.text('Board').evaluate().isNotEmpty && find.text('Sheet card').evaluate().isEmpty) {
      // may already be on board
    }
    await tester.tap(find.text('Sheet card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = find.byKey(const ValueKey('sg-card-sheet'));
    expect(sheet, findsOneWidget);
    final paper = tester.widget<ColoredBox>(sheet).color;

    final sheetRect = tester.getRect(sheet);
    for (final label in ['Cover', 'Move', 'Labels', 'Members', 'Checklist', 'Attachment', 'Done']) {
      final finder = find.descendant(of: sheet, matching: find.text(label));
      expect(finder, findsWidgets, reason: label);
      final rect = tester.getRect(finder.first);
      expect(rect.bottom, lessThanOrEqualTo(sheetRect.bottom + 1), reason: label);
      expect(rect.top, greaterThanOrEqualTo(sheetRect.top - 1), reason: label);
      final text = tester.widget<Text>(finder.first);
      final style = text.style!;
      final fg = style.color ?? const Color(0xFF1C1B19);
      expect(_contrast(fg, paper), greaterThanOrEqualTo(4.5), reason: label);
    }
  });

  testWidgets('boards home is empty until the user creates a board', (tester) async {
    SgStore.instance.debugReset();
    SgStore.instance.loaded = true;
    SgStore.instance.atHome = true;
    addTearDown(SgStore.instance.debugReset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: SmartGenScreen(onClose: _noop)),
    ));
    await tester.pump();
    expect(find.text('No boards yet'), findsOneWidget);
    expect(find.text('Create board'), findsOneWidget);
    expect(find.text('Launch'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Sprint');
    await tester.tap(find.text('Create board'));
    await tester.pump();
    expect(find.text('Sprint'), findsWidgets);
    expect(find.text('To Do'), findsOneWidget);
    // BoardView lazily builds columns; Doing/Done exist on the store.
    expect(SgStore.instance.board!.lists.map((l) => l.title).toList(), ['To Do', 'Doing', 'Done']);
  });
}

void _noop() {}

double _contrast(Color a, Color b) {
  double lum(Color c) {
    double f(double v) {
      v /= 255;
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }
    final r = f(c.r * 255), g = f(c.g * 255), bl = f(c.b * 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * bl;
  }
  final l1 = lum(a), l2 = lum(b);
  final light = math.max(l1, l2), dark = math.min(l1, l2);
  return (light + 0.05) / (dark + 0.05);
}
