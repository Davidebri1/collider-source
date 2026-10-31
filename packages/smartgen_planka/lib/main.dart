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
      '/customfields': (ctx) => const CustomFieldsScreen(),
      '/views': (ctx) => const ViewsScreen(),
      '/search': (ctx) => const SearchScreen(),
      '/genie': (ctx) => const GenieScreen(),
      '/archive': (ctx) => const ArchiveScreen(),
    };

ThemeData plankaTheme(BuildContext context) {
  final base = Theme.of(context).textTheme.apply(
        fontFamily: 'GoogleSansFlex',
        fontSizeFactor: 0.8,
        fontSizeDelta: 2.0,
      );
  return ThemeData(
    primarySwatch: Colors.indigo,
    fontFamily: 'GoogleSansFlex',
    textTheme: base,
    // David: headers centre; left align is for data fields only.
    appBarTheme: const AppBarTheme(centerTitle: true),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(0),
      thumbVisibility: WidgetStateProperty.all(false),
    ),
  );
}
