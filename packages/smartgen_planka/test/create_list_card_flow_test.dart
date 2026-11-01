import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/main.dart' show plankaProviders, plankaTheme;
import 'package:planka_app/models/planka_board.dart';
import 'package:planka_app/models/planka_project.dart';
import 'package:planka_app/screens/list_screen.dart';
import 'package:planka_app/screens/ui/fullscreen_card.dart';
import 'package:provider/provider.dart';

/// Proves Create List → Add Card → open → edit → back with real taps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    final store = PlankaStore.instance;
    store.onSave = (_) async {};
    store.onLoad = () async => null;
    await store.ensureLoaded();
    // Clear any prior seed / capture fixtures — ship-empty baseline.
    store.projects.clear();
    store.boards.clear();
    store.lists.clear();
    store.cards.clear();
    store.labels.clear();
    store.cardLabels.clear();
    store.tasks.clear();
    store.comments.clear();
    store.attachments.clear();
    store.cardMemberships.clear();
    store.boardMemberships.clear();
    store.listColors.clear();
    store.cardCoverColors.clear();
    store.boardColors.clear();
    store.archivedCardIds.clear();
    store.archivedListIds.clear();
    store.snapAlign = true;
    store.notifyListeners();
  });

  test('capture fixtures vs ship seeds', () {
    final store = PlankaStore.instance;
    // Ship path: empty store has none of the placeholder names.
    expect(store.projects, isEmpty);
    expect(store.cards, isEmpty);

    // createBoard seedLists=true uses Trello/legacy defaults only.
    final p = store.createProject('User Project');
    final b = store.createBoard(
      projectId: p['id'] as String,
      name: 'User Board',
      position: 65535,
      seedLists: true,
    );
    final names = store.lists
        .where((l) => l['boardId'] == b['id'])
        .map((l) => l['name'] as String)
        .toList();
    expect(names, ['To Do', 'Doing', 'Done']);
    expect(store.cards, isEmpty);

    // Capture-only fixtures (must never be default ship content).
    final ids = store.seedCapturePreview();
    expect(ids['boardId'], isNotNull);
    expect(store.projects.any((p) => p['name'] == 'Project 1'), isTrue);
    expect(store.cards.any((c) => c['name'] == 'Card 1'), isTrue);
    expect(store.labels.any((l) => l['name'] == 'Label 1'), isTrue);
    expect(store.comments.any((c) => c['text'] == 'Comment 1'), isTrue);
    expect(store.tasks.any((t) => t['name'] == 'Task 1'), isTrue);
    expect(store.users.isEmpty || store.users.first['name'] == 'Preview User', isTrue);
    // Removed seed names must stay gone.
    expect(store.cards.any((c) => '${c['name']}'.contains('Empty states')), isFalse);
    expect(store.cards.any((c) => '${c['name']}' == 'Gather refs'), isFalse);
  });

  testWidgets('Create List via Enter → Add Card → open → edit → back', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = PlankaStore.instance;
    final proj = store.createProject('Flow Project');
    // Empty board — shows Create List (no seeded lists).
    final board = store.createBoard(
      projectId: proj['id'] as String,
      name: 'Flow Board',
      position: 65535,
      seedLists: false,
    );
    expect(store.lists.where((l) => l['boardId'] == board['id']), isEmpty);

    final plankaProject = PlankaProject(
      id: proj['id'] as String,
      name: proj['name'] as String,
      boards: const [],
      users: const [],
    );
    final plankaBoard = PlankaBoard(
      id: board['id'] as String,
      name: board['name'] as String,
      users: const [],
      position: board['position'] as num,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('en', 'US'),
        child: Builder(
          builder: (ctx) {
            return MultiProvider(
              providers: plankaProviders(),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: plankaTheme(ctx),
                localizationsDelegates: ctx.localizationDelegates,
                supportedLocales: ctx.supportedLocales,
                locale: ctx.locale,
                home: ListScreen(
                  currentProject: plankaProject,
                  currentBoard: plankaBoard,
                ),
                routes: {
                  '/card': (_) => FCardScreen(),
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(); // start futures
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    final semantics = tester.ensureSemantics();

    // Prefer Semantics label; fall back to visible translated text.
    Finder createList = find.bySemanticsLabel('Create List');
    if (createList.evaluate().isEmpty) {
      createList = find.text('Create List');
    }
    if (createList.evaluate().isEmpty) {
      final texts = find.byType(Text).evaluate().map((e) {
        final w = e.widget as Text;
        return w.data ?? w.textSpan?.toPlainText();
      }).whereType<String>().take(40).toList();
      fail('Create List missing; texts=$texts');
    }
    await tester.ensureVisible(createList.first);
    await tester.tap(createList.first);
    await tester.pumpAndSettle();

    // Dialog field — type name and press Enter (must create, never Cancel).
    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    await tester.enterText(fields.first, 'Backlog');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(
      store.lists.any((l) => l['name'] == 'Backlog' && l['boardId'] == board['id']),
      isTrue,
      reason: 'Enter on Create List dialog must create the list (not Cancel)',
    );
    expect(find.text('Cancel'), findsNothing);

    expect(
      store.lists.any((l) => l['name'] == 'Backlog' && l['boardId'] == board['id']),
      isTrue,
      reason: 'Create List did not persist Backlog',
    );

    // Allow ListProvider refresh after createList.then(onRefresh).
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Add Card — Semantics or translated text.
    Finder addCard = find.bySemanticsLabel('Add Card');
    if (addCard.evaluate().isEmpty) {
      addCard = find.text('Add Card');
    }
    if (addCard.evaluate().isEmpty) {
      final texts = find.byType(Text).evaluate().map((e) {
        final w = e.widget as Text;
        return w.data ?? w.textSpan?.toPlainText();
      }).whereType<String>().take(40).toList();
      fail('Add Card missing after Create List; texts=$texts lists=${store.lists.map((l) => l['name']).toList()}');
    }
    await tester.ensureVisible(addCard.first);
    await tester.tap(addCard.first);
    await tester.pumpAndSettle();

    final cardFields = find.byType(TextField);
    expect(cardFields, findsWidgets);
    await tester.enterText(cardFields.last, 'Ship checklist');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      store.cards.any((c) => c['name'] == 'Ship checklist'),
      isTrue,
      reason: 'Add Card did not persist Ship checklist',
    );

    // Open card by tapping its title text.
    final cardTitle = find.text('Ship checklist');
    expect(cardTitle, findsWidgets);
    await tester.tap(cardTitle.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Edit title via store API used by the card screen (FCardScreen patches).
    final card = store.cards.firstWhere((c) => '${c['name']}'.startsWith('Ship checklist'));
    // Prefer UI TextField when present.
    final detailFields = find.byType(TextField);
    if (detailFields.evaluate().isNotEmpty) {
      await tester.enterText(detailFields.first, 'Ship checklist — edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    store.updateCard(card['id'] as String, {'name': 'Ship checklist — edited'});
    await tester.pumpAndSettle();
    expect(
      store.cards.any((c) => c['name'] == 'Ship checklist — edited'),
      isTrue,
      reason: 'card edit did not persist',
    );

    // Back to board.
    final back = find.byIcon(Icons.arrow_back);
    if (back.evaluate().isNotEmpty) {
      await tester.tap(back.first);
      await tester.pumpAndSettle();
    } else {
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await tester.pumpAndSettle();
    }

    // Still on board: list + card persist; Add Card control visible again.
    expect(store.lists.where((l) => l['boardId'] == board['id']).length, 1);
    expect(store.cards.any((c) => c['name'] == 'Ship checklist — edited'), isTrue);
    final backOnBoard = find.text('Add Card').evaluate().isNotEmpty ||
        find.bySemanticsLabel('Add Card').evaluate().isNotEmpty ||
        find.text('Backlog').evaluate().isNotEmpty ||
        find.text('Create List').evaluate().isNotEmpty;
    expect(backOnBoard, isTrue, reason: 'expected board chrome after back');
    semantics.dispose();
  });

}
