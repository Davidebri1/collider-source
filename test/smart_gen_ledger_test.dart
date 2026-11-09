import 'dart:math' as math;

import 'package:collider_flutter/features/smartgen/screens/smartgen_screen.dart';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:collider_flutter/features/smartgen/sg_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseSmartGen still reads the agent shape', () {
    final r = parseSmartGen('NEED: n\nSERVE: s\nCARDS:\n- Title | note\n');
    expect(r.cards, [('Title', 'note')]);
  });

  test('starter board is one card set across the ledger surfaces', () {
    final s = SgStore()..ensureStarter();
    final b = s.board!;
    expect(b.cards.length, greaterThan(4));
    expect(b.lists.map((l) => l.title), ['To Do', 'Doing', 'Done']);
    expect(b.cards.any((c) => c.matchesPlace('California')), isTrue);
    expect(b.cards.any((c) => c.matchesPlace('Japan')), isTrue);
    expect(b.cards.any((c) => c.files.isNotEmpty), isTrue);
    expect(b.cards.any((c) => c.type == SgType.job), isTrue);
    expect(b.cards.any((c) => c.pages.length >= 3), isTrue);
    expect(s.search('venue'), isNotEmpty);
  });

  test('a new card lands at the top of the first list', () {
    final s = SgStore()..ensureStarter();
    final made = s.addCard(SgType.note);
    expect(made, isNotNull);
    expect(s.board!.cardsIn(s.board!.orderedLists.first.id).first.id, made!.id);
  });

  test('dragging into a list inherits that list name when the behavior is on', () {
    final s = SgStore()..ensureStarter();
    final card = s.byId('c1')!;
    s.moveCard(card.id, 'l3');
    expect(s.byId('c1')!.listId, 'l3');
    expect(s.byId('c1')!.status, 'Done');
  });

  test('hourly trigger advances status and mark-done lands on the final column', () {
    final s = SgStore()..ensureStarter();
    expect(s.applyHourly(), greaterThan(0));
    expect(s.byId('c1')!.status, 'Doing');
    s.markDone(s.byId('c1')!);
    expect(s.byId('c1')!.status, 'Done');
  });

  test('the eleventh canvas is refused and the 1000th card is refused', () {
    final s = SgStore()..ensureStarter();
    for (var i = 0; i < 9; i++) {
      expect(s.addCanvas('C$i', 'Glass'), isTrue);
    }
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
    for (final title in ['Draft launch post', 'California', 'Japan', 'Trip notes']) {
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
    addTearDown(SgStore.instance.debugReset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: SmartGenScreen(onClose: _noop)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Draft launch post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = find.byKey(const ValueKey('sg-card-sheet'));
    expect(sheet, findsOneWidget);
    final paper = tester.widget<ColoredBox>(sheet).color;

    final sheetRect = tester.getRect(sheet);
    for (final label in ['Cover', 'Move', 'Labels', 'Members', 'Checklist', 'Attachment', 'Done']) {
      final finder = find.descendant(of: sheet, matching: find.text(label));
      expect(finder, findsWidgets, reason: label);
      final count = finder.evaluate().length;
      for (var i = 0; i < count; i++) {
        final rect = tester.getRect(finder.at(i));
        expect(sheetRect.inflate(1).contains(rect.topLeft) && sheetRect.inflate(1).contains(rect.bottomRight), isTrue, reason: '$label is clipped on the card sheet');
      }
    }

    final chips = find.descendant(of: sheet, matching: find.byWidgetPredicate((w) => w is ActionChip || w is ChoiceChip || w is FilterChip));
    expect(chips, findsWidgets);
    final element = chips.evaluate().toList();
    expect(element, isNotEmpty);
    for (final chip in element) {
      final fill = _chipFill(chip);
      expect(fill, isNotNull, reason: 'chip has no fill');
      final background = _over(fill!, paper);
      final paragraphs = <RenderParagraph>[];
      _paragraphs(chip, paragraphs);
      expect(paragraphs, isNotEmpty, reason: 'chip has no label');
      for (final para in paragraphs) {
        final ink = para.text.style?.color;
        expect(ink, isNotNull, reason: para.text.toPlainText());
        final ratio = _contrast(_over(ink!, background), background);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: '${para.text.toPlainText()} contrast ${ratio.toStringAsFixed(2)} ink $ink on $background');
      }
    }
    expect(find.descendant(of: sheet, matching: find.text('Doing')), findsWidgets);
    expect(find.descendant(of: sheet, matching: find.text('Done')), findsWidgets);
    expect(find.descendant(of: sheet, matching: find.text('Custom fields')), findsOneWidget);
    expect(find.text('Custom Fields'), findsNothing);
    expect(find.text('Board Menu'), findsNothing);

    await tester.tap(find.descendant(of: sheet, matching: find.text('Cover')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Card cover'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.byKey(const ValueKey('sg-cover-sheet')), findsOneWidget);
  });

  testWidgets('the selected view tab and board-kind chip are the strong fill', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SgStore.instance.debugReset();
    SgStore.instance.ensureStarter();
    addTearDown(SgStore.instance.debugReset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: SmartGenScreen(onClose: _noop)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    _expectStrongChip(tester, 'Kanban', 'Calendar');

    // The overdue note covers the header for a moment. Wait it out, then open the menu.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.tap(find.byTooltip('Board menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Board menu'), findsOneWidget);
    expect(find.text('Board Menu'), findsNothing);
    _expectStrongChip(tester, 'notebook', 'portfolio');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  test('genie mass-edits and refactors without calling a provider', () {
    final s = SgStore()..ensureStarter();
    final reply = s.askGenie('set all priority to high');
    expect(reply, contains('priority'));
    expect(s.board!.cards.every((c) => c.priority == 3), isTrue);
    final kept = s.board!.cards.firstWhere((c) => c.type == SgType.task);
    kept.color = 0xFF61BD4F;
    final ref = s.askGenie('refactor task as note');
    expect(ref, contains('Note'));
    expect(s.board!.cards.where((c) => c.type == SgType.task), isEmpty);
    expect(s.board!.cards.firstWhere((c) => c.id == kept.id).color, 0xFF61BD4F);
    expect(s.board!.cards.where((c) => c.type == SgType.note && c.id != kept.id).every((c) => c.color == SgType.note.argb), isTrue);
    expect(callAiApi('hello', cards: 1, columns: 1), contains('not called'));
  });
}

void _noop() {}

void _expectStrongChip(WidgetTester tester, String selected, String idle) {
  final selectedFill = _chipFill(find.widgetWithText(ChoiceChip, selected).evaluate().first);
  final idleFill = _chipFill(find.widgetWithText(ChoiceChip, idle).evaluate().first);
  expect(selectedFill, isNotNull, reason: '$selected has no fill');
  expect(selectedFill!.a, greaterThan(0.85), reason: '$selected should be the solid chip');
  expect(_luminance(selectedFill), greaterThan(0.7), reason: '$selected fill is faint');
  expect(idleFill == null || idleFill.a < 0.45, isTrue, reason: '$idle is a solid chip (${idleFill?.a})');
  final selectedInk = tester.renderObject<RenderParagraph>(find.text(selected)).text.style?.color;
  final idleInk = tester.renderObject<RenderParagraph>(find.text(idle)).text.style?.color;
  expect(_luminance(selectedInk!), lessThan(0.25), reason: '$selected label is light on the solid chip');
  expect(_luminance(idleInk!), greaterThan(0.7), reason: '$idle label is dark on the outline chip');
}

double _channel(double s) => s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) => 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double _contrast(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

Color _over(Color fg, Color bg) {
  final a = fg.a;
  if (a >= 0.99) return fg.withValues(alpha: 1);
  return Color.from(
    alpha: 1,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

Color? _chipFill(Element chip) {
  Color? found;
  void walk(Element e) {
    final w = e.widget;
    if (w is Ink && w.decoration is ShapeDecoration) {
      final color = (w.decoration! as ShapeDecoration).color;
      if (color != null && color.a > 0.05) found ??= color;
    }
    if (w is Material && w.color != null && w.color!.a > 0.05) {
      found ??= w.color;
    }
    e.visitChildren(walk);
  }
  chip.visitChildren(walk);
  return found;
}

void _paragraphs(Element e, List<RenderParagraph> out) {
  final ro = e.renderObject;
  if (ro is RenderParagraph) out.add(ro);
  e.visitChildren((c) => _paragraphs(c, out));
}