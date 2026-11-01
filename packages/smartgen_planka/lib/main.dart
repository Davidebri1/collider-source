import 'package:flutter/material.dart';
import 'package:planka_app/providers/attachment_provider.dart';
import 'package:planka_app/providers/card_actions_provider.dart';
import 'package:planka_app/providers/card_provider.dart';
import 'package:planka_app/providers/list_provider.dart';
import 'package:planka_app/providers/project_provider.dart';
import 'package:planka_app/providers/user_provider.dart';
import 'package:planka_app/screens/ui/fullscreen_card.dart';
import 'package:planka_app/screens/list_screen.dart';
import 'package:planka_app/screens/project_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import './providers/auth_provider.dart';
import './providers/board_provider.dart';
import './screens/board_screen.dart';
import './features/board_menu/board_menu_screen.dart';
import './features/custom_fields/custom_fields_screen.dart';
import './features/views/views_screen.dart';
import './features/search/search_screen.dart';
import './features/genie/genie_screen.dart';
import './features/archive/archive_screen.dart';
import './features/labels/labels_screen.dart';

List<SingleChildWidget> plankaProviders() => [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProxyProvider<AuthProvider, ProjectProvider>(
        create: (ctx) => ProjectProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? ProjectProvider(auth),
      ),
      ChangeNotifierProxyProvider<AuthProvider, BoardProvider>(
        create: (ctx) => BoardProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? BoardProvider(auth),
      ),
      ChangeNotifierProxyProvider<AuthProvider, ListProvider>(
        create: (ctx) => ListProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? ListProvider(auth),
      ),
      ChangeNotifierProxyProvider<AuthProvider, CardProvider>(
        create: (ctx) => CardProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? CardProvider(auth),
      ),
      ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
        create: (ctx) => UserProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? UserProvider(auth),
      ),
      ChangeNotifierProxyProvider<AuthProvider, AttachmentProvider>(
        create: (ctx) => AttachmentProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? AttachmentProvider(auth),
      ),
      ChangeNotifierProxyProvider<AuthProvider, CardActionsProvider>(
        create: (ctx) => CardActionsProvider(Provider.of<AuthProvider>(ctx, listen: false)),
        update: (_, auth, previous) => previous ?? CardActionsProvider(auth),
      ),
    ];

Map<String, WidgetBuilder> plankaRoutes() => {
      '/projects': (ctx) => const ProjectScreen(),
      '/boards': (ctx) => BoardScreen(),
      '/lists': (ctx) => ListScreen(),
      '/card': (ctx) => FCardScreen(),
      '/boardmenu': (ctx) => const BoardMenuScreen(),
      '/labels': (ctx) {
        final id = ModalRoute.of(ctx)?.settings.arguments as String?;
        return LabelsScreen(boardId: id);
      },
      '/customfields': (ctx) => const CustomFieldsScreen(),
      '/views': (ctx) => const ViewsScreen(),
      '/search': (ctx) => const SearchScreen(),
      '/genie': (ctx) => const GenieScreen(),
      '/archive': (ctx) => const ArchiveScreen(),
    };

ThemeData plankaTheme(BuildContext context) {
  // Stock planka_app ThemeData. Force dark ink so Collider's dark host theme
  // cannot leak light-on-light text into card headings.
  const ink = Color(0xFF212121);
  return ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.indigo,
    scaffoldBackgroundColor: const Color(0xFFF3F0F7),
    // Avoid TextStyle.apply(fontSizeFactor) — Flutter 3.47 asserts when any
    // TextTheme style has a null fontSize (M3 defaults).
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF3F0F7),
      foregroundColor: ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w500),
    ),
  );
}
