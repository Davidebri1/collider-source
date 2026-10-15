// v9.1.7 batch 4 (David, Oct 15): every pane is centred vertically on the
// full screen. Fails if a CPane's centre is more than 2 px off the centre of
// a 390x844 phone, for both fits, with and without the docked ticker band.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collider_flutter/core/vision/cpane.dart';

void main() {
  for (final fit in CPaneFit.values) {
    for (final reserve in [110.0, 260.0]) {
      testWidgets('CPane $fit is centred at 390x844 (dock $reserve)', (t) async {
        t.view.physicalSize = const Size(1170, 2532);
        t.view.devicePixelRatio = 3;
        t.view.padding = const FakeViewPadding(top: 141, bottom: 102);
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData.fromView(t.view),
            child: CShell(
              bottomReserve: reserve,
              child: Stack(fit: StackFit.expand, children: [
                Positioned.fill(child: CPane(key: key, fit: fit, child: const SizedBox(height: 300))),
              ]),
            ),
          ),
        ));
        final glass = find.descendant(of: find.byKey(key), matching: find.byType(ClipRRect)).first;
        final r = t.getRect(glass);
        expect((r.center.dy - 422).abs(), lessThanOrEqualTo(2), reason: 'pane centre ${r.center.dy}, screen centre 422');
        expect((r.center.dx - 195).abs(), lessThanOrEqualTo(2), reason: 'pane centre x ${r.center.dx}');
        expect(r.bottom, lessThanOrEqualTo(844 - CPaneTokens.chromeReserve), reason: 'pane runs over the composer');
      });
    }
  }
}
