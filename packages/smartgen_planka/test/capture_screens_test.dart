import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/features/board_menu/board_menu_screen.dart';
import 'package:planka_app/features/custom_fields/custom_fields_screen.dart';
import 'package:planka_app/features/search/search_screen.dart';
import 'package:planka_app/features/views/views_screen.dart';
import 'package:planka_app/features/archive/archive_screen.dart';
import 'package:planka_app/features/genie/genie_screen.dart';
import 'package:planka_app/screens/project_screen.dart';

Future<void> _save(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject(find.byType(RepaintBoundary).first) as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bd = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = Directory('/workspace/sgrev/v920/collider/artifacts/smartgen_planka_captures/ours');
  await dir.create(recursive: true);
  final f = File('${dir.path}/g_$name.png');
  await f.writeAsBytes(bd!.buffer.asUint8List());
  // OCR-ish: collect Text widgets
  final texts = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget as Text;
    if (w.data != null && w.data!.trim().isNotEmpty) texts.add(w.data!.trim());
  }
  print('wrote ${f.path} ${image.width}x${image.height} texts=${texts.take(20).toList()}');
}

Widget _app(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'GoogleSansFlex',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0079BF)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0079BF),
      appBarTheme: const AppBarTheme(centerTitle: true),
    ),
    home: RepaintBoundary(
      child: SizedBox(width: 440, height: 956, child: home),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final store = PlankaStore.instance;
    store.onSave = (_) async {};
    store.onLoad = () async => null;
    await store.ensureLoaded();
  });

  Future<void> prep(WidgetTester tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('board_menu', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const BoardMenuScreen()));
    await tester.pump();
    await _save(tester, 'board_menu');
  });

  testWidgets('custom_fields', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const CustomFieldsScreen()));
    await tester.pump();
    await _save(tester, 'custom_fields');
  });

  testWidgets('search', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const SearchScreen()));
    await tester.pump();
    await _save(tester, 'search');
  });

  testWidgets('views', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const ViewsScreen()));
    await tester.pump();
    await _save(tester, 'views');
  });

  testWidgets('archive', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const ArchiveScreen()));
    await tester.pump();
    await _save(tester, 'archive');
  });

  testWidgets('genie', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const GenieScreen()));
    await tester.pump();
    await _save(tester, 'genie');
  });

  testWidgets('projects', (tester) async {
    await prep(tester);
    await tester.pumpWidget(_app(const ProjectScreen()));
    await tester.pump();
    await _save(tester, 'projects');
  });
}
