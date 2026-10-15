import 'dart:io';

import 'package:collider_flutter/core/vision/cpane.dart';
import 'package:collider_flutter/features/prompt/floating_prompt.dart';
import 'package:collider_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pane guard: no screen paints its own glass, blur, shadow or width', () {
    final r = Process.runSync('dart', ['run', 'tool/pane_guard.dart']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });

  testWidgets('Smart Gen hides the home composer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ColliderHomeScreen(initialDrawer: 'smartgen')));
    // First frame still uses the fallback reserve. The post-frame measure
    // lifts the pane; the next frame is the one that must clear the bar.
    await tester.pump();
    await tester.pump();

    expect(find.byKey(CPane.bodyKey), findsOneWidget);
    expect(find.byType(FloatingPrompt), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
