import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collider_flutter/core/figma/figma_stage.dart';
import 'package:collider_flutter/core/vision/pane_rects.dart';
void main() {
  testWidgets("a pane inside FigmaStage reports its on-screen rect", (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Stack(children: [Positioned.fill(child: FigmaStage(frame: const Size(1336.4, 835.2), cropWidth: 1294.1, center: const Offset(715.9, 420.6), children: const [
      Positioned(left: 95.4, top: 0, width: 1241, height: 841.2, child: IgnorePointer(child: PaneRect(child: SizedBox.expand()))),
    ]))])));
    await t.pump();
    await t.pump();
    final r = PaneRects.rects.value.values.single;
    expect((r.left - 8).abs() < 1 && (r.right - 382).abs() < 1, isTrue, reason: '$r');
    expect(((r.top + r.bottom) / 2 - 422).abs() < 2, isTrue, reason: '$r');
  });
}

