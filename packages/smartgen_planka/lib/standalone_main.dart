import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:planka_app/features/board_menu/board_menu_screen.dart';
import 'package:planka_app/features/custom_fields/custom_fields_screen.dart';
import 'package:planka_app/features/search/search_screen.dart';
import 'package:planka_app/features/views/views_screen.dart';
import 'package:planka_app/local/planka_store.dart';
import 'package:planka_app/main.dart' as pl;
import 'package:planka_app/models/planka_board.dart';
import 'package:planka_app/models/planka_card.dart';
import 'package:planka_app/models/card_models/planka_label.dart';
import 'package:planka_app/models/planka_project.dart';
import 'package:planka_app/providers/auth_provider.dart';
import 'package:planka_app/screens/board_screen.dart';
import 'package:planka_app/screens/list_screen.dart';
import 'package:planka_app/screens/project_screen.dart';
import 'package:planka_app/screens/ui/fullscreen_card.dart';
import 'package:provider/provider.dart';

/// Standalone Flutter-web entry for capture (same method as stock planka_app).
/// Query: `?sgcap=1&screen=home|board|card|menu|customfields|table|calendar|timeline|search|filter|cover|labels`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  final store = PlankaStore.instance;
  store.onSave = (_) async {};
  store.onLoad = () async => null;
  await store.ensureLoaded();

  final qp = Uri.base.queryParameters;
  final capture = qp['sgcap'] == '1' || qp.containsKey('screen');
  Map<String, String> ids = {};
  if (capture) {
    ids = store.seedCapturePreview();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('de', 'DE'),
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        Locale('tr', 'TR'),
        Locale('it', 'IT'),
        Locale('ru', 'RU'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      saveLocale: false,
      startLocale: const Locale('en', 'US'),
      child: CaptureApp(screen: qp['screen'] ?? 'home', ids: ids),
    ),
  );
}

class CaptureApp extends StatelessWidget {
  const CaptureApp({super.key, required this.screen, required this.ids});
  final String screen;
  final Map<String, String> ids;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ...pl.plankaProviders(),
        ChangeNotifierProvider.value(value: PlankaStore.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: pl.plankaTheme(context),
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: _CaptureHome(screen: screen, ids: ids),
        routes: pl.plankaRoutes(),
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: const _NoBar(),
            child: child ?? const ColoredBox(color: Color(0xFF0079BF)),
          );
        },
      ),
    );
  }
}

class _NoBar extends ScrollBehavior {
  const _NoBar();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _CaptureHome extends StatefulWidget {
  const _CaptureHome({required this.screen, required this.ids});
  final String screen;
  final Map<String, String> ids;
  @override
  State<_CaptureHome> createState() => _CaptureHomeState();
}

class _CaptureHomeState extends State<_CaptureHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
    });
  }

  PlankaProject _project() {
    final store = PlankaStore.instance;
    final pid = widget.ids['projectId'] ?? (store.projects.isNotEmpty ? store.projects.first['id'] as String : '');
    final detail = store.projectDetailPayload(pid);
    return PlankaProject.fromJson(
      Map<String, dynamic>.from(detail['item'] as Map),
      Map<String, dynamic>.from(detail['included'] as Map),
    );
  }

  PlankaBoard _board() {
    final store = PlankaStore.instance;
    final bid = widget.ids['boardId'] ?? (store.boards.isNotEmpty ? store.boards.first['id'] as String : '');
    final detail = store.boardDetailPayload(bid);
    return PlankaBoard.fromJson(
      Map<String, dynamic>.from(detail['item'] as Map),
      Map<String, dynamic>.from(detail['included'] as Map),
    );
  }

  PlankaCard _card() {
    final store = PlankaStore.instance;
    final cid = widget.ids['cardId'] ?? (store.cards.isNotEmpty ? store.cards.first['id'] as String : '');
    final raw = store.cards.firstWhere((c) => c['id'] == cid, orElse: () => store.cards.first);
    final assignedIds = store.cardLabels
        .where((cl) => cl['cardId'] == cid)
        .map((cl) => cl['labelId'] as String)
        .toSet();
    final labels = store.labels
        .where((l) => assignedIds.contains(l['id']))
        .map((l) => PlankaLabel.fromJson(Map<String, dynamic>.from(l)))
        .toList();
    return PlankaCard(
      id: raw['id'] as String,
      boardId: raw['boardId'] as String,
      name: raw['name'] as String,
      listId: raw['listId'] as String,
      position: (raw['position'] as num?) ?? 0,
      description: raw['description'] as String?,
      dueDate: raw['dueDate'] as String?,
      isSubscribed: raw['isSubscribed'] == true,
      coverAttachmentId: raw['coverAttachmentId'] as String?,
      creatorUserId: raw['creatorUserId'] as String? ?? store.localUserId,
      labels: labels,
      tasks: const [],
      cardMemberships: const [],
      cardAttachment: const [],
      cardUsers: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.screen;
    switch (s) {
      case 'home':
      case 'projects':
        return const ProjectScreen();
      case 'boards':
        return BoardScreen(project: _project());
      case 'board':
      case 'lists':
        PlankaStore.instance.snapAlign = true;
        return ListScreen(currentProject: _project(), currentBoard: _board());
      case 'freedrag':
        PlankaStore.instance.snapAlign = false;
        PlankaStore.instance.cardFreePos.clear();
        return ListScreen(currentProject: _project(), currentBoard: _board());
      case 'card':
      case 'card_detail':
        return FCardScreen(currentBoard: _board(), card: _card());
      case 'menu':
      case 'board_menu':
        return const BoardMenuScreen();
      case 'customfields':
      case 'custom_fields':
        return const CustomFieldsScreen();
      case 'customfields_add':
        return const CustomFieldsScreen(openAddOnLoad: true);
      case 'table':
        return const ViewsScreen(initialIndex: 1);
      case 'calendar':
        return const ViewsScreen(initialIndex: 2);
      case 'timeline':
        return const ViewsScreen(initialIndex: 3);
      case 'search':
        return const SearchScreen();
      case 'filter':
        return _FilterCapture(board: _board(), project: _project());
      case 'cover':
        return _CoverCapture(board: _board(), project: _project());
      case 'labels':
        return _LabelsCapture(board: _board());
      default:
        return const ProjectScreen();
    }
  }
}

/// Filter sheet over the board (Trello Filter wording).
class _FilterCapture extends StatefulWidget {
  const _FilterCapture({required this.board, required this.project});
  final PlankaBoard board;
  final PlankaProject project;
  @override
  State<_FilterCapture> createState() => _FilterCaptureState();
}

class _FilterCaptureState extends State<_FilterCapture> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = PlankaStore.instance;
      store.filterQuery = 'Design';
      
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) {
          final ctrl = TextEditingController(text: store.filterQuery ?? '');
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.filter_list),
                    hintText: 'Filter cards',
                  ),
                  onChanged: (q) {
                    store.filterQuery = q;
                    
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListScreen(currentProject: widget.project, currentBoard: widget.board);
  }
}

/// Cover tint picker (full-card cover colour) for capture.
class _CoverCapture extends StatefulWidget {
  const _CoverCapture({required this.board, required this.project});
  final PlankaBoard board;
  final PlankaProject project;
  @override
  State<_CoverCapture> createState() => _CoverCaptureState();
}

class _CoverCaptureState extends State<_CoverCapture> {
  static const _swatches = <int>[
    0xFFEA8385,
    0xFFE6AE76,
    0xFF72B3C6,
    0xFFEA9EB0,
    0xFFBDC788,
    0xFF5FBEB8,
    0xFFF4BD63,
    0xFF0079BF,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) {
          final store = PlankaStore.instance;
          final cid = store.cards.isNotEmpty ? store.cards.first['id'] as String : '';
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cover', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _swatches)
                      GestureDetector(
                        onTap: () {
                          store.setCardCoverColor(cid, c);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(c),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListScreen(currentProject: widget.project, currentBoard: widget.board);
  }
}

/// Labels picker sheet for capture.
class _LabelsCapture extends StatefulWidget {
  const _LabelsCapture({required this.board});
  final PlankaBoard board;
  @override
  State<_LabelsCapture> createState() => _LabelsCaptureState();
}

class _LabelsCaptureState extends State<_LabelsCapture> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) {
          final store = PlankaStore.instance;
          final labs = store.labels.where((l) => l['boardId'] == widget.board.id).toList();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Labels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final l in labs)
                  ListTile(
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _colorFor('${l['color']}'),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text('${l['name']}'),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    });
  }

  Color _colorFor(String name) {
    const map = {
      'berry-red': Color(0xFFEA8385),
      'pumpkin-orange': Color(0xFFE6AE76),
      'lagoon-blue': Color(0xFF72B3C6),
      'orange-peel': Color(0xFFF4BD63),
      'lagune-blue': Color(0xFF5FBEB8),
      'bright-moss': Color(0xFFBDC788),
    };
    return map[name] ?? const Color(0xFF9FA0A2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.board.name)),
      body: const ColoredBox(color: Color(0xFF0079BF), child: SizedBox.expand()),
    );
  }
}
