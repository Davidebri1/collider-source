import 'package:collider_flutter/features/smartgen/screens/smartgen_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSmartGen', () {
    test('reads the need, the serve and the cards', () {
      final r = parseSmartGen('''
NEED: The board has intake but no verification step.
SERVE: Each proposed card closes a gap the board does not name yet.
CARDS:
- Re-check imports against the source folder | catches a rename mid-run
- Add a resolution gate | rejects anything under 1440 on the short side
''');
      expect(r.need, 'The board has intake but no verification step.');
      expect(r.serve, 'Each proposed card closes a gap the board does not name yet.');
      expect(r.cards, [
        ('Re-check imports against the source folder', 'catches a rename mid-run'),
        ('Add a resolution gate', 'rejects anything under 1440 on the short side'),
      ]);
    });

    test('a card with no note is still a card', () {
      final r = parseSmartGen('NEED: n\nSERVE: s\nCARDS:\n- Just a title\n');
      expect(r.cards, [('Just a title', '')]);
    });

    test('notes keep any further pipes', () {
      final r = parseSmartGen('CARDS:\n- Title | a | b\n');
      expect(r.cards, [('Title', 'a | b')]);
    });

    test('caps at six cards', () {
      final many = ['CARDS:', for (var i = 0; i < 12; i++) '- Card $i | n'].join('\n');
      expect(parseSmartGen(many).cards.length, 6);
    });

    test('prose and stray dashes are not cards', () {
      final r = parseSmartGen('NEED: n\nSome preamble - not a card\nCARDS:\n- Real card\n');
      expect(r.cards.map((c) => c.$1), ['Real card']);
    });

    test('a reply with no CARDS block yields nothing rather than throwing', () {
      final r = parseSmartGen("I can't help with that.");
      expect(r.cards, isEmpty);
      expect(r.need, isEmpty);
      expect(r.serve, isEmpty);
    });
  });
}