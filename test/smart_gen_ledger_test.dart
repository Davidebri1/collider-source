import 'package:collider_flutter/features/smartgen/screens/smartgen_screen.dart';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
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

  test('genie mass-edits and refactors without calling a provider', () {
    final s = SgStore()..ensureStarter();
    final reply = s.askGenie('set all priority to high');
    expect(reply, contains('priority'));
    expect(s.board!.cards.every((c) => c.priority == 3), isTrue);
    final ref = s.askGenie('refactor task as note');
    expect(ref, contains('Note'));
    expect(s.board!.cards.where((c) => c.type == SgType.task), isEmpty);
    expect(callAiApi('hello', cards: 1, columns: 1), contains('not called'));
  });
}