import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:collider_flutter/core/vision/pane_rects.dart';

/// David (Oct 15): no side nav may overlap a pane. placeSideNav must return a
/// slot that clears every pane rect, for the real panes at 390x844 and for
/// any centred pane the CPane margins allow.
void main() {
  const screen = Size(390, 844);
  void clears(String name, int entries, List<Rect> panes) {
    final slot = placeSideNav(screen: screen, entries: entries, panes: panes);
    expect(slot, isNotNull, reason: '$name: no slot');
    for (final p in panes) {
      expect(p.overlaps(slot!.rect), isFalse, reason: '$name: nav ${slot.rect} over pane $p');
    }
    expect(slot!.rect.left, greaterThanOrEqualTo(0));
    expect(slot.rect.bottom, lessThanOrEqualTo(screen.height));
  }

  test('home: no pane, nav at rest with labels', () {
    final s = placeSideNav(screen: screen, entries: 4, panes: const []);
    expect(s!.labels, isTrue);
  });
  test('Gallery (card 358x465 + strip, centred)', () => clears('gallery', 3, [Rect.fromCenter(center: const Offset(195, 422), width: 358, height: 533)]));
  test('Files (v8.4 window centred, 8 pt sides)', () => clears('files', 6, [Rect.fromCenter(center: const Offset(195, 422), width: 374, height: 253)]));
  test('Premium (cover to price, full width)', () => clears('premium', 3, [const Rect.fromLTWH(0, 198, 390, 448)]));
  test('Discover / any CPane at its tallest (564)', () => clears('cpane', 3, [Rect.fromCenter(center: const Offset(195, 422), width: 358, height: 564)]));
  test('random centred panes up to the CPane maximum', () {
    final r = math.Random(7);
    for (var i = 0; i < 400; i++) {
      final h = 120 + r.nextDouble() * 444;
      final w = 200 + r.nextDouble() * 174;
      clears('random $i', 1 + r.nextInt(3), [Rect.fromCenter(center: const Offset(195, 422), width: w, height: h)]);
    }
  });
}
