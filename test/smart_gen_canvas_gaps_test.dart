
import 'package:collider_flutter/features/smartgen/sg_free_drag.dart';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:collider_flutter/features/smartgen/sg_pane.dart';
import 'package:collider_flutter/features/smartgen/sg_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '/tmp/collider_sg_canvas_gaps',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_mockPathProvider);
  setUp(_mockPathProvider);

  test('drag position persistence round-trips card and board dx/dy via JSON', () {
    final s = SgStore()..ensureStarter();
    final host = s.board!;
    s.addCanvas('Desk', 'Glass');
    final canvasId = host.canvases.first.id;
    final card = s.addCard(SgType.task)!;
    s.touch(() {
      card.dx = 91;
      card.dy = 203;
      card.canvasId = canvasId;
    });
    final other = s.createBoard('Lookbook', goHome: false);
    s.openBoard(host.id);
    s.placeBoardOnCanvas(other.id, canvasId, dx: 55, dy: 120);
    s.touch(() {
      other.surface = SgSurface.album;
      other.dx = 55;
      other.dy = 120;
    });

    final doc = {
      'boards': [for (final b in s.boards) b.toJson()],
      'active': host.id,
    };
    final boards = [
      for (final raw in doc['boards'] as List)
        SgBoard.fromJson((raw as Map).cast<String, Object?>()),
    ];
    final hostBack = boards.firstWhere((b) => b.id == host.id);
    final cardBack = hostBack.cards.firstWhere((c) => c.id == card.id);
    expect(cardBack.dx, 91);
    expect(cardBack.dy, 203);
    final tile = boards.firstWhere((b) => b.id == other.id);
    expect(tile.hostCanvasId, canvasId);
    expect(tile.dx, 55);
    expect(tile.dy, 120);
  });

  test('throw physics lands away from release point when velocity is non-zero', () {
    const start = Offset(40, 80);
    const velocity = Offset(1400, -900);
    final end = SgFreeLayouts.simulateThrow(start: start, velocity: velocity);
    expect((end - start).distance, greaterThan(40));
    expect(end.dx, isNot(start.dx));
    // With snap, settles into the snap slot.
    const snap = Offset(24, 24);
    final snapped = SgFreeLayouts.simulateThrow(start: start, velocity: velocity, snapTarget: snap);
    expect(snapped, snap);
  });

  test('hard throw toward each edge settles fully in bounds (cards and board tiles)', () {
    const viewport = Size(360, 640);
    const pad = SgFreeLayouts.canvasEdgePad;
    // Card-sized and board-tile-sized items both stay inset from the frame.
    for (final item in const [Size(128, 96), Size(132, 110)]) {
      final bounds = SgFreeLayouts.originBoundsFor(viewport, item);
      expect(bounds.left, pad);
      expect(bounds.top, pad);
      expect(bounds.right, viewport.width - item.width - pad);
      expect(bounds.bottom, viewport.height - item.height - pad);

      final start = Offset((bounds.left + bounds.right) / 2, (bounds.top + bounds.bottom) / 2);
      const hard = 4200.0;
      final throws = <String, Offset>{
        'right': const Offset(hard, 0),
        'left': const Offset(-hard, 0),
        'bottom': const Offset(0, hard),
        'top': const Offset(0, -hard),
        'corner': const Offset(hard, hard),
      };
      for (final entry in throws.entries) {
        final end = SgFreeLayouts.simulateThrow(
          start: start,
          velocity: entry.value,
          originBounds: bounds,
        );
        expect(end.dx, inInclusiveRange(bounds.left, bounds.right),
            reason: '${entry.key} dx for $item');
        expect(end.dy, inInclusiveRange(bounds.top, bounds.bottom),
            reason: '${entry.key} dy for $item');
        // Inset from every frame edge (same pad as canvasGrid).
        expect(end.dx, greaterThanOrEqualTo(pad - 0.01),
            reason: '${entry.key} left inset for $item');
        expect(end.dy, greaterThanOrEqualTo(pad - 0.01),
            reason: '${entry.key} top inset for $item');
        expect(end.dx + item.width, lessThanOrEqualTo(viewport.width - pad + 0.01),
            reason: '${entry.key} right inset for $item');
        expect(end.dy + item.height, lessThanOrEqualTo(viewport.height - pad + 0.01),
            reason: '${entry.key} bottom inset for $item');
      }

      // Snap on: nearest in-bounds slot, even when the coast would exit.
      final slots = SgFreeLayouts.canvasGrid(viewport, 6, tileW: item.width, tileH: item.height);
      final fit = SgFreeLayouts.inBoundsSlots(slots, viewport);
      expect(fit, isNotEmpty);
      for (final s in fit) {
        expect(s.left, greaterThanOrEqualTo(pad - 0.01));
        expect(s.top, greaterThanOrEqualTo(pad - 0.01));
        expect(s.left + s.width, lessThanOrEqualTo(viewport.width - pad + 0.01));
        expect(s.top + s.height, lessThanOrEqualTo(viewport.height - pad + 0.01));
      }
      final coast = SgFreeLayouts.simulateThrow(
        start: start,
        velocity: const Offset(hard, 0),
        originBounds: bounds,
      );
      final nearest = fit[SgFreeLayouts.nearestSlot(coast, fit)].origin;
      final snapped = SgFreeLayouts.simulateThrow(
        start: start,
        velocity: const Offset(hard, 0),
        snapTarget: nearest,
        originBounds: bounds,
      );
      expect(snapped, nearest);
      expect(snapped.dx, greaterThanOrEqualTo(pad - 0.01));
      expect(snapped.dy, greaterThanOrEqualTo(pad - 0.01));
      expect(snapped.dx + item.width, lessThanOrEqualTo(viewport.width - pad + 0.01));
      expect(snapped.dy + item.height, lessThanOrEqualTo(viewport.height - pad + 0.01));
    }
  });

  testWidgets('board tiles render kind faces on the canvas', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final s = SgStore()..ensureStarter();
    final host = s.board!;
    s.addCanvas('Desk', 'Glass');
    final canvasId = host.canvases.first.id;
    final notebook = s.createBoard('Shot list', goHome: false);
    final album = s.createBoard('Lookbook', goHome: false);
    final vision = s.createBoard('Mood', goHome: false);
    s.openBoard(host.id);
    s.touch(() {
      notebook.surface = SgSurface.notebook;
      album.surface = SgSurface.album;
      vision.surface = SgSurface.vision;
      notebook.hostCanvasId = canvasId;
      album.hostCanvasId = canvasId;
      vision.hostCanvasId = canvasId;
      notebook.dx = 20;
      notebook.dy = 60;
      album.dx = 180;
      album.dy = 60;
      vision.dx = 20;
      vision.dy = 200;
      host.surface = SgSurface.canvas;
      host.snapAlign = false;
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 440,
          height: 900,
          child: SgCanvasBoard(store: s, onOpen: (_) {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Shot list'), findsWidgets);
    expect(find.text('Lookbook'), findsWidgets);
    expect(find.text('Mood'), findsWidgets);
    expect(find.text('Notebook'), findsWidgets);
    expect(find.text('Gallery'), findsWidgets);
    expect(find.text('Vision board'), findsWidgets);
  });

  test('canvas backgroundThemeId persists through JSON', () {
    final s = SgStore()..ensureStarter();
    s.addCanvas('Desk', 'Glass');
    final id = s.board!.canvases.first.id;
    s.setCanvasBackground(id, 'starbridge');
    expect(s.board!.canvases.first.backgroundThemeId, 'starbridge');
    final back = SgCanvas.fromJson(s.board!.canvases.first.toJson());
    expect(back.backgroundThemeId, 'starbridge');
  });

  testWidgets('Genie minimise and restore over the canvas', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = SgStore.instance;
    store.debugReset();
    store.ensureStarter();
    store.addCanvas('Desk', 'Glass');
    store.touch(() {
      store.board!.surface = SgSurface.canvas;
      store.board!.snapAlign = false;
    });
    store.atHome = false;
    store.loaded = true;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(440, 956)),
        child: Scaffold(
          body: SgPane(onClose: () {}, section: 'canvas'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Keep board open even if boot flipped home.
    store.atHome = false;
    store.touch(() => store.board!.surface = SgSurface.canvas);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final menu = find.byTooltip('Board menu');
    expect(menu, findsWidgets);
    await tester.tap(menu.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Genie'), findsWidgets);
    await tester.tap(find.text('Genie').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('sg-genie-panel')), findsOneWidget);

    await tester.tap(find.byTooltip('Minimize Genie').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('sg-genie-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('sg-genie-panel')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sg-genie-fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('sg-genie-panel')), findsOneWidget);
  });
}

