import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'hooks.dart';
import 'local/planka_store.dart';
import 'main.dart' as pl;
import 'providers/auth_provider.dart';
import 'models/planka_board.dart';
import 'models/planka_project.dart';
import 'screens/list_screen.dart';
import 'screens/project_screen.dart';

export 'hooks.dart';
export 'local/planka_store.dart' show PlankaStore, PlankaPersistSave, PlankaPersistLoad;

bool _ready = false;

Future<void> ensurePlankaReady({
  PlankaGenieChat? genie,
  PlankaPersistSave? save,
  PlankaPersistLoad? load,
  AttachmentBytesPut? attachmentPut,
  AttachmentBytesGet? attachmentGet,
}) async {
  if (_ready) return;
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  if (genie != null) plankaGenieChat = genie;
  if (attachmentPut != null) plankaAttachmentPut = attachmentPut;
  if (attachmentGet != null) plankaAttachmentGet = attachmentGet;
  final store = PlankaStore.instance;
  store.onSave = save;
  store.onLoad = load;
  await store.ensureLoaded();
  _ready = true;
}

Future<void> persistPlanka() => PlankaStore.instance.persist();

/// Seed capture-only preview when the host URL asks for it (?sgcap=1).
void seedPlankaCaptureIfRequested() {
  final qp = Uri.base.queryParameters;
  if (qp['sgcap'] == '1' || qp['sgcap'] == 'true') {
    PlankaStore.instance.seedCapturePreview();
  }
}

/// Nested host embed — no MaterialApp (avoids fighting Collider's browser history).
class PlankaNavigator extends StatelessWidget {
  const PlankaNavigator({super.key, this.onClose, this.onOpenLiveSurfaces});
  final VoidCallback? onClose;
  /// Open notebook / album / vision / … via the live SgPane screens.
  final VoidCallback? onOpenLiveSurfaces;

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('de', 'DE'),
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        Locale('tr', 'TR'),
        Locale('it', 'IT'),
        Locale('ru', 'RU'),
      ],
      path: 'packages/planka_app/assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      saveLocale: false,
      startLocale: const Locale('en', 'US'),
      errorWidget: (_) => const ColoredBox(color: Color(0xFF0079BF), child: SizedBox.expand()),
      child: Builder(
        builder: (ctx) {
          return MultiProvider(
            providers: pl.plankaProviders(),
            child: Theme(
              data: pl.plankaTheme(ctx),
              child: Localizations(
                locale: ctx.locale,
                delegates: ctx.localizationDelegates,
                child: ScrollConfiguration(
                  behavior: const _NoScrollbarBehavior(),
                  child: Material(
                    color: const Color(0xFF0079BF),
                    child: Navigator(
                      onGenerateRoute: (settings) {
                        final name = settings.name ?? '/';
                        WidgetBuilder builder;
                        if (name == '/' || name == '/projects') {
                          builder = (_) => _PlankaHome(
                                onClose: onClose,
                                onOpenLiveSurfaces: onOpenLiveSurfaces,
                              );
                        } else {
                          final routes = pl.plankaRoutes();
                          builder = routes[name] ?? (_) => _PlankaHome(onClose: onClose);
                        }
                        return MaterialPageRoute<void>(
                          settings: settings,
                          builder: builder,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _PlankaHome extends StatefulWidget {
  const _PlankaHome({this.onClose, this.onOpenLiveSurfaces});
  final VoidCallback? onClose;
  final VoidCallback? onOpenLiveSurfaces;
  @override
  State<_PlankaHome> createState() => _PlankaHomeState();
}

class _PlankaHomeState extends State<_PlankaHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = PlankaStore.instance;
    final capture = Uri.base.queryParameters['sgcap'] == '1' ||
        Uri.base.queryParameters['sgcap'] == 'true';
    // Capture host: open first board lists so Collider pane shows the board.
    if (capture && store.boards.isNotEmpty && store.lists.isNotEmpty) {
      final b = store.boards.first;
      final detail = store.boardDetailPayload(b['id'] as String);
      final board = PlankaBoard.fromJson(
        Map<String, dynamic>.from(detail['item'] as Map),
        Map<String, dynamic>.from(detail['included'] as Map),
      );
      PlankaProject? project;
      if (store.projects.isNotEmpty) {
        final pid = store.projects.first['id'] as String;
        final pd = store.projectDetailPayload(pid);
        project = PlankaProject.fromJson(
          Map<String, dynamic>.from(pd['item'] as Map),
          Map<String, dynamic>.from(pd['included'] as Map),
        );
      }
      return ListScreen(
        currentProject: project,
        currentBoard: board,
        onHostClose: widget.onClose,
      );
    }
    return ProjectScreen(
      onHostClose: widget.onClose,
      onOpenLiveSurfaces: widget.onOpenLiveSurfaces,
    );
  }
}
