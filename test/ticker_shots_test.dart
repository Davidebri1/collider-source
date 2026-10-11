// Screenshot harness for the conversation ticker (wechat 0:639).
// Run with: flutter test test/ticker_shots_test.dart --update-goldens
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:collider_flutter/features/ticker/widgets/figma_ticker.dart';
import 'package:collider_flutter/models/model_def.dart';
import 'package:collider_flutter/models/ticker_item.dart';

Future<void> _save(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/verify/$name.png'),
  );
}

List<ModelDef> _models() => [
      ModelRoster.byId('pro/glm-5-2')!,
      ModelRoster.byId('pro/gpt-5-6-luna')!,
      ModelRoster.byId('pro/qwen-3-6-plus')!,
      ModelRoster.byId('pro/grok-latest')!,
      ModelRoster.byId('pro/mistral-large')!,
      ModelRoster.byId('pro/sonar-reasoning-pro')!,
    ];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    const fontDir =
        r'C:\Users\D\Documents\collider-muse-apps-bound-20260930\collider-muse-apps-bound-20260930\assets\fonts';
    const weights = {400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold'};
    for (final e in weights.entries) {
      final data =
          File('$fontDir\\instrument-sans-${e.key}.ttf').readAsBytesSync();
      for (final family in ['InstrumentSans', 'InstrumentSans-${e.value}']) {
        final loader = FontLoader(family)
          ..addFont(Future.value(ByteData.view(data.buffer)));
        await loader.load();
      }
    }
    final icons = File(
            r'C:\Users\D\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf')
        .readAsBytesSync();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.buffer)));
    await iconLoader.load();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ticker rows window — collapsed', (tester) async {
    final models = _models();
    final items = [
      for (final m in models)
        TickerItem(
          modelDef: m,
          relativeTime: 'just now',
          summary:
              'Collider routes one prompt to every selected model and diffs the answers into a single consensus row.',
          conversation: [
            TickerMessage(
              id: 'u',
              sender: 'user',
              text: 'What is Collider?',
              timestamp: DateTime(2026, 10, 11, 9, 30),
            ),
            TickerMessage(
              id: 'm',
              sender: 'model',
              text:
                  'Collider routes one prompt to every selected model and diffs the answers into a single consensus row.',
              timestamp: DateTime(2026, 10, 11, 9, 30),
            ),
          ],
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF101014),
          body: SizedBox(
            width: 390,
            height: 844,
            child: TickerColumnWindow(
              items: items,
              openId: null,
              onOpen: (_) {},
              consensusTitle: '✦ 5/6 Consensus',
              consensusLine: 'One prompt, every model, one row of answers.',
              onConsensus: () {},
              joined: false,
              activeIds: models.map((m) => m.id).toSet(),
              onToggle: (_) {},
              categoryLabel: 'general',
              onCategorySwipe: (_) {},
            ),
          ),
        ),
      ),
    );
    await _save(tester, 'ticker-rows');
  });

  testWidgets('ticker rows window — one row dimmed by toggle', (tester) async {
    final models = _models();
    final items = [
      for (final m in models)
        TickerItem(
          modelDef: m,
          relativeTime: 'just now',
          summary: 'A complete one-line takeaway that never truncates.',
          conversation: const [],
        ),
    ];
    final active = models.map((m) => m.id).toSet()..remove(models.first.id);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF101014),
          body: SizedBox(
            width: 390,
            height: 844,
            child: TickerColumnWindow(
              items: items,
              openId: models[1].id,
              onOpen: (_) {},
              consensusTitle: '✦ 5/6 Consensus',
              consensusLine: 'One prompt, every model, one row of answers.',
              onConsensus: () {},
              joined: false,
              activeIds: active,
              onToggle: (_) {},
              categoryLabel: 'general',
              onCategorySwipe: (_) {},
            ),
          ),
        ),
      ),
    );
    await _save(tester, 'ticker-rows-dimmed');
  });
}
