import 'dart:math' as math;
import 'core/theme/app_font.dart';
import 'features/smartgen/kanban_store.dart';
import 'core/files/file_store.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/vision/vision_kit.dart';
import 'core/api/collider_api.dart';
import 'core/audio/music_player.dart';
import 'features/music/floating_music.dart';
import 'models/model_def.dart';
import 'models/theme_def.dart';
import 'models/ticker_item.dart';
import 'features/ticker/widgets/model_pill.dart';
import 'features/ticker/widgets/consensus_row.dart';
import 'features/ticker/widgets/message_zoom_overlay.dart';
import 'features/ticker/widgets/local_history_pane.dart';
import 'features/prompt/floating_prompt.dart';
import 'features/nav/permanent_nav_bar.dart';
import 'features/nav/side_nav_rail.dart';
import 'features/nav/contextual_side_nav.dart';
import 'features/apps/apps_popup_pane.dart';
import 'features/wallpaper/widgets/windowless_theme_scroller.dart';
import 'features/drawers/history_drawer.dart';
import 'features/drawers/music_collection_drawer.dart';
import 'features/drawers/settings_drawer.dart';
import 'features/drawers/model_ladder_drawer.dart';
import 'features/consensus/consensus_webview.dart';
import 'features/smartgen/screens/smartgen_screen.dart';
import 'features/market/screens/market_screen.dart';
import 'features/files/screens/files_screen.dart';
import 'features/mediagen/figma_media_stage.dart';
import 'core/ambient/ambient.dart';
import 'features/browser/browser_urls.dart';
import 'features/browser/models/browser_tab.dart';
import 'features/browser/screens/in_app_browser_sheet.dart';
import 'features/theme/premium_theme_market_view.dart';
import 'features/theme/theme_living_media.dart';
import 'core/media/theme_catalog.dart';
import 'core/vision/keyboard_dof.dart';
import 'core/vision/materialize.dart';
import 'core/nav/back_guard.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'core/media/theme_media_bundle.dart';
import 'core/api/media_gen.dart';
import 'models/media_specs.dart';
import 'features/mediagen/gen_settings.dart';
import 'features/mediagen/gen_options_sheet.dart';
import 'features/mediagen/media_ticker.dart';
import 'features/account/account_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // v9: Instrument Sans is bundled in pubspec. Without this the google_fonts
  // package would still try to pull it (and Inter, and Cormorant) off the
  // Google CDN on every cold start, which is what produced mixed faces and
  // soft glyphs whenever that request was slow or blocked.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Theme catalog: bundled fallback + cached copy now, live themes.json in background.
  await ThemeCatalog.instance.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ColliderApp());
}

/// Mouse-draggable everywhere, and no scrollbars.
///
/// Flutter's default MaterialScrollBehavior.dragDevices is
/// {touch, stylus, invertedStylus, trackpad} — mouse is not in it, so on web
/// nothing could be dragged with the mouse unless it opted in individually.
/// That left the ticker rows, the theme strip and the market carousels
/// dead to a mouse.
///
/// The no-scrollbar rule needs BOTH overrides. buildOverscrollIndicator kills
/// the overscroll glow, but the default buildScrollbar still inserts a real
/// Scrollbar on web and desktop, so a track appeared during every drag.
class _MouseDraggableScrollBehavior extends MaterialScrollBehavior {
  const _MouseDraggableScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Lays the ticker window's two parts out and reports the height it actually
/// used: the pinned consensus row at its natural height, then the card list
/// and the category strip.
///
/// Only the list gives height back. The pinned row has to keep every line of
/// its one full line (R16), and the category strip is a fixed 32, so when the
/// three together do not fit inside the 40% ceiling the list is the part that
/// shrinks — and it shrinks to a scrollable list behind an edge fade rather
/// than cutting anything off. When they do fit, the window is exactly as tall
/// as its content, which is what stops a ticker holding one model from
/// standing there as an empty slab.
class _TickerWindowLayout extends MultiChildLayoutDelegate {
  _TickerWindowLayout({required this.listSlots});

  /// How tall the list would like to be: one row slot per visible row (R09)
  /// plus the category strip and its gap.
  final double listSlots;

  static const String pinned = 'ticker-pinned';
  static const String list = 'ticker-list';
  static const double _gap = 6;

  @override
  void performLayout(Size size) {
    final width = size.width;
    var used = 0.0;

    if (hasChild(pinned)) {
      // v9.1: consensus pinned on top, never more than 40 % of the ticker.
      used = layoutChild(pinned, BoxConstraints(maxWidth: width, maxHeight: size.height.isFinite ? size.height * 0.40 : double.infinity)).height;
      positionChild(pinned, Offset.zero);
      if (hasChild(list)) used += _gap;
    }

    if (hasChild(list)) {
      final available = (size.height - used).clamp(0.0, double.infinity);
      final wanted = listSlots.clamp(0.0, available);
      layoutChild(list, BoxConstraints.tightFor(width: width, height: wanted));
      positionChild(list, Offset(0, used));
      used += wanted;
    }

    size = Size(width, used);
  }

  @override
  bool shouldRelayout(covariant _TickerWindowLayout oldDelegate) => oldDelegate.listSlots != listSlots;
}

class ColliderApp extends StatelessWidget {
  const ColliderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collider',
      debugShowCheckedModeBanner: false,
      // Mouse drag must work everywhere, not just on the one PageView that
      // opted in. Flutter's default MaterialScrollBehavior.dragDevices is
      // {touch, stylus, invertedStylus, trackpad} — it omits mouse, so on web
      // every scroller and every custom drag surface ignored the mouse. The
      // default has no scrollbars, which also satisfies the no-scrollbar rule.
      scrollBehavior: const _MouseDraggableScrollBehavior(),
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080B),
        textTheme: GoogleFonts.instrumentSansTextTheme(ThemeData.dark().textTheme),
      ),
      // Remote theme posters resolve through the same bundle as local assets.
      builder: (context, child) => DefaultAssetBundle(
        bundle: ThemeMediaAssetBundle.instance,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const ColliderHomeScreen(),
    );
  }
}

class ColliderHomeScreen extends StatefulWidget {
  const ColliderHomeScreen({super.key});

  @override
  State<ColliderHomeScreen> createState() => _ColliderHomeScreenState();
}

class _ColliderHomeScreenState extends State<ColliderHomeScreen> {
  // Wallpaper state: Uninterrupted, star of the product
  WallpaperTheme _currentTheme = WallpaperCatalog.defaultTheme;
  WallpaperTheme _savedThemeBeforePreview = WallpaperCatalog.defaultTheme;

  // Selected models, per category, as the source keeps them (state.tsx
  // selectedModelIds: Record<Category, string[]>), max 9 each.
  final Map<ModelCategory, List<String>> _selByCat = {
    for (final c in ModelCategory.values) c: _defaultSelected(c),
  };
  List<String> get _selectedModelIds => _selByCat[_activeCategory]!;

  /// state.tsx defaultSelected: the first three usable on the starting tier
  /// (or the whole category when none is), reachable ones first.
  static List<String> _defaultSelected(ModelCategory c) {
    final all = ModelRoster.forCategory(c);
    final usable = all.where((m) => ModelRoster.canUse(ModelTier.free, m)).toList();
    final pool = usable.isNotEmpty ? usable : all;
    final ids = pool.map((m) => m.id).toList();
    final ordered = [
      ...ids.where((id) => MediaGen.instance.hasCredentials(id)),
      ...ids.where((id) => !MediaGen.instance.hasCredentials(id)),
    ];
    return ordered.take(3).toList();
  }

  // Media generation (D35 revoked): per-category settings, references and
  // the latest run's results (map rows 13 and 17).
  final Map<ModelCategory, GenSettings> _genSettings = {
    for (final c in [ModelCategory.image, ModelCategory.video, ModelCategory.audio]) c: GenSettings.defaultsFor(c),
  };
  final Map<ModelCategory, List<String>> _genRefs = {};
  final Map<ModelCategory, List<MediaGeneration>> _mediaGens = {};
  bool _genOptionsOpen = false;
  /// Put back into the composer when a send cannot run (D59).
  final ValueNotifier<String?> _restoreText = ValueNotifier<String?>(null);
  /// Bumped by the options sheet's Generate: the composer sends its text.
  final ValueNotifier<int> _generateTick = ValueNotifier<int>(0);

  void _notice(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1600),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(60, 0, 60, 168), // above the composer and the bar
      backgroundColor: VColors.glassDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VRadius.full)),
      content: Text(text, textAlign: TextAlign.center, style: VType.callout()),
    ));
  }

  /// A send that cannot run on this link: one quiet line, the prompt goes
  /// back into the composer, nothing else changes (D59).
  bool get _mediaShowing => _activeCategory.isMedia && (_mediaGens[_activeCategory]?.isNotEmpty ?? false);

  void _cannotRun(String prompt) {
    _restoreText.value = prompt;
    _notice("Can't run on this link");
  }

  // Active Model Category
  ModelCategory _activeCategory = ModelCategory.general;

  // Active temporary pane / drawer: 'themes', 'settings', 'consensus', 'apps', 'history', 'market', 'smartgen', 'files', 'model_ladder'
  String? _activeDrawer;

  // Local Model History modal state
  ModelDef? _localHistoryModel;

  // Zoomed message overlay state
  TickerMessage? _zoomedMessage;
  ModelDef? _zoomedModelDef;

  // Expanded accordion model IDs
  final Set<String> _expandedModelIds = {};

  // Swipe/tap-summoned global broadcast composer
  bool _isComposerSummoned = false;

  // Mobile slide-out contextual side nav state
  bool _isMobileSideNavOpen = false;

  // Current floating user prompt (floats un-framed on wallpaper)
  String _currentPrompt = '';

  // Consensus state. The score is a count rendered as n/total, or empty while
  // a shared send is unfinished (R17: an incomplete send shows an empty score,
  // no partial wording, never a percent).
  String _consensusRatio = '';
  String _consensusSummary = '';
  bool _isConsensusGenerating = false;

  // Live session state (Collider server)
  AskMode _mode = AskMode.chat;
  bool _incognito = false;
  bool _autosave = true;
  bool _busy = false;
  DateTime? _promptTime;
  final Map<String, JobState> _jobsById = {};
  String? _currentJobId;

  // Ticker items
  late List<TickerItem> _tickerItems;

  // Global History Sessions
  late List<ConversationHistorySession> _globalHistorySessions;

  // Local Model History Sessions map
  late Map<String, List<ConversationHistorySession>> _localHistorySessions;

  // Browser Tabs (only 1 active at a time)
  late List<BrowserTab> _browserTabs;

  // Contextual work surface state
  String _smartGenView = 'cards';
  String _smartGenBoardType = 'kanban';
  String _marketCategory = 'prompts';
  String _themeSection = 'gallery';
  String _filesCategory = 'all';
  String _chatSection = 'global';

  /// The rail ornament shows on the resting canvas and durable work surfaces only.
  bool get _railVisible {
    if (_localHistoryModel != null || _zoomedMessage != null || _browserOpen || _genOptionsOpen) return false;
    // Summoning the composer no longer hides the rail: "New Chat" was making
    // the navigation disappear. Focus comes from depth Ã¢â‚¬â€ the world blurs
    // behind the composer Ã¢â‚¬â€ not from deleting the frame.
    // An open answer takes the phone's full width (row 15); closing it brings the rail back.
    if (_activeDrawer == null && MediaQuery.of(context).size.width < 768 && _openPill(_tickerItems) != null) return false;
    // Home (chat) and themes only: the Smart Gen, Market and Files rails
    // selected nothing (no surface read their keys), so they are gone (D31).
    const surfaces = {null, 'themes'};
    return surfaces.contains(_activeDrawer);
  }

  ActiveWorkSurface get _currentActiveSurface {
    if (_activeDrawer == 'smartgen') return ActiveWorkSurface.smartgen;
    if (_activeDrawer == 'market') return ActiveWorkSurface.market;
    if (_activeDrawer == 'themes' || _activeDrawer == 'premium' || _activeDrawer == 'music') return ActiveWorkSurface.themes;
    if (_activeDrawer == 'files') return ActiveWorkSurface.files;
    return ActiveWorkSurface.chat;
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    final cat = ThemeCatalog.instance;
    setState(() {
      // v9.1 (from v8.6): no built-in default wallpaper; a theme that is gone
      // falls to the catalog's own default (an R2 theme).
      _currentTheme = cat.bySlug(_currentTheme.id) ?? cat.defaultTheme;
      _savedThemeBeforePreview = cat.bySlug(_savedThemeBeforePreview.id) ?? cat.defaultTheme;
    });
  }

  @override
  void dispose() {
    ThemeCatalog.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    installBackGuard(_escape);
    if (Uri.base.queryParameters['seed'] == '1') _seedSamples();
    ThemeCatalog.instance.addListener(_onCatalogChanged);
    KeyboardDof.install();
    if (Uri.base.queryParameters['drawer'] == 'premium') {
      _activeDrawer = 'premium';
      // Seed Plane 0 to a live premium loop before CoverFlow preview callback
      _currentTheme = WallpaperCatalog.premiumThemes.isNotEmpty
          ? WallpaperCatalog.premiumThemes.first
          : WallpaperCatalog.defaultTheme;
      _savedThemeBeforePreview = _currentTheme;
    } else if (Uri.base.queryParameters['drawer'] != null) {
      _activeDrawer = Uri.base.queryParameters['drawer'];
    }
    if (Uri.base.queryParameters['composer'] == '1') _isComposerSummoned = true;
    if (Uri.base.queryParameters['settings'] == '1') _settingsOpen = true;
    final cq = Uri.base.queryParameters['cat'];
    if (cq != null) _activeCategory = ModelCategory.values.firstWhere((c) => c.name == cq, orElse: () => ModelCategory.general);
    if (Uri.base.queryParameters['genopts'] == '1' && _activeCategory.isMedia) _genOptionsOpen = true;
    if (Uri.base.queryParameters['rail'] == '1') _isMobileSideNavOpen = true;
    _initializeTickerItems();
    _initializeHistorySessions();
    _initializeBrowserTabs();
    _boot().whenComplete(() {
      if (!_booted.isCompleted) _booted.complete();
      if (mounted) setState(() => _apiChecked = true);
    });
    final qp = Uri.base.queryParameters;
    if (qp['zoom'] == '1' && _tickerItems.isNotEmpty) {
      _zoomedMessage = _tickerItems.first.conversation.last;
      _zoomedModelDef = _tickerItems.first.modelDef;
    }
    if (qp['local'] == '1' && _tickerItems.isNotEmpty) {
      _localHistoryModel = _tickerItems.first.modelDef;
    }
    if (qp['expand'] == '1') {
      if (_tickerItems.isNotEmpty) _expandedModelIds.add(_tickerItems.first.modelDef.id);
    }
    if (qp['browser'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openBrowserForTab('user_default'));
    }
  }

  void _initializeTickerItems() {
    _tickerItems = [];
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }

  final Completer<void> _booted = Completer<void>();
  /// The server probe has answered (or failed): [ColliderApi.online] is known.
  bool _apiChecked = false;

  Future<void> _boot() async {
    final ok = await ColliderApi.instance.loadRoster();
    if (!mounted) return;
    if (!ok) {
      // R34: home is Google whether or not the server answered, so there is no
      // offline start page to swap in.
      return;
    }
    // Default selection: one model per provider, so every card carries a distinct colour.
    final seen = <String>{};
    final live = <String>[
      for (final m in ModelRoster.allModels.where((m) => !m.isMedia))
        if (seen.add(m.provider)) m.id,
    ];
    setState(() {
      _selByCat[ModelCategory.general] = live.take(6).toList();
    });
    await _reloadHistory(restoreLatest: true);
    // Deep links used by the launcher and the screenshot tour: ?ask=...&mode=research
    final qp = Uri.base.queryParameters;
    if (qp['mode'] != null) {
      _mode = AskMode.values.firstWhere((m) => m.wire == qp['mode'], orElse: () => AskMode.chat);
    }
    if (qp['ask'] != null && qp['ask']!.trim().isNotEmpty) _onSendPrompt(qp['ask']!);
    // ?app=smartgen|market|themes|premium|music|files|consensus — open a
    // surface directly. Used by the screenshot pass and as phone shortcuts.
    const openable = {'smartgen', 'market', 'themes', 'premium', 'music', 'files', 'consensus', 'apps'};
    final app = qp['app'];
    if (app != null && openable.contains(app)) {
      setState(() => _activeDrawer = app);
    }
    if (_tickerItems.isNotEmpty) {
      setState(() {
        if (qp['expand'] == '1') _expandedModelIds.add(_tickerItems.first.modelDef.id);
        if (qp['local'] == '1') _localHistoryModel = _tickerItems.first.modelDef;
        if (qp['zoom'] == '1') {
          _zoomedMessage = _tickerItems.first.conversation.last;
          _zoomedModelDef = _tickerItems.first.modelDef;
        }
      });
    }
  }

  Future<void> _reloadHistory({bool restoreLatest = false}) async {
    final hist = await ColliderApi.instance.history();
    if (!mounted) return;
    setState(() {
      for (final j in hist) {
        _jobsById[j.id] = j;
      }
      _globalHistorySessions = [..._seedHist, for (final j in hist) _sessionFromJob(j)];
      final local = <String, List<ConversationHistorySession>>{};
      for (final j in hist) {
        j.results.forEach((mid, r) {
          if (r.status != 'done') return;
          (local[mid] ??= []).add(ConversationHistorySession(
            id: '${j.id}_$mid',
            title: j.prompt,
            targetModelId: mid,
            relativeTime: _ago(j.created),
            timestamp: j.created,
            summary: r.essence,
            messages: [
              TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
              TickerMessage(id: '${j.id}_$mid', sender: 'model', text: r.text, timestamp: j.created),
            ],
          ));
        });
      }
      _localHistorySessions = local;
      if (restoreLatest && hist.isNotEmpty && _tickerItems.isEmpty) _applyJob(hist.first, restored: true);
    });
  }

  ConversationHistorySession _sessionFromJob(JobState j) {
    final firstEssence = j.results.values.map((r) => r.essence).firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return ConversationHistorySession(
      id: j.id,
      title: j.prompt,
      relativeTime: _ago(j.created),
      timestamp: j.created,
      summary: j.consensus.summary.isNotEmpty ? j.consensus.summary : firstEssence,
      modelIds: j.results.keys.toList(),
      messages: [
        TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
        if (j.consensus.summary.isNotEmpty) TickerMessage(id: '${j.id}_c', sender: 'model', text: j.consensus.summary, timestamp: j.created),
      ],
    );
  }

  /// Maps a server job onto the ticker: one colour-coded card per model, consensus pinned on top.
  void _applyJob(JobState j, {bool restored = false}) {
    _jobsById[j.id] = j;
    _currentJobId = j.id;
    _currentPrompt = j.prompt;
    _promptTime = j.created;
    final items = <TickerItem>[];
    j.results.forEach((mid, r) {
      final def = ModelRoster.byId(mid);
      if (def == null) return;
      // A model that failed simply has no card (row 15): no error text.
      if (r.status == 'error') return;
      final prev = _tickerItems.where((t) => t.modelDef.id == mid).toList();
      final waiting = r.status == 'pending';
      items.add(TickerItem(
        modelDef: def,
        relativeTime: restored ? _ago(j.created) : 'just now',
        summary: r.essence.isNotEmpty ? r.essence : r.text.split('\n').first,
        isStreaming: waiting,
        conversation: prev.isNotEmpty && prev.first.isIsolated
            ? prev.first.conversation
            : [
                TickerMessage(id: '${j.id}_u', sender: 'user', text: j.prompt, timestamp: j.created),
                if (r.text.isNotEmpty) TickerMessage(id: '${j.id}_$mid', sender: 'model', text: r.text, timestamp: j.created),
              ],
      ));
    });
    _tickerItems = items;
    if (j.sources.isNotEmpty) {
      _browserTabs = [
        _browserTabs.first,
        for (var i = 0; i < j.sources.length; i++)
          BrowserTab(
            id: 'src_$i',
            title: '${j.sources[i]['title'] ?? ''}',
            url: '${j.sources[i]['url'] ?? ''}',
            isModelAssigned: true,
            modelName: 'Source ${i + 1}',
          ),
      ];
    }
    if (restored) {
      _selByCat[ModelCategory.general] = j.results.keys.where((k) => ModelRoster.byId(k) != null).toList();
    }
    final c = j.consensus;
    _isConsensusGenerating = !j.done;
    _consensusRatio = c.score;
    _consensusSummary = c.summary;
  }

  /// Test-only (?seed=1): sample Files, Smart Gen cards and History so the
  /// multi-select screens can be screenshotted. Never runs otherwise.
  List<ConversationHistorySession> _seedHist = const [];
  Future<void> _seedSamples() async {
    final fs = FileStore.instance;
    await fs.init();
    if (fs.files.isEmpty) {
      for (final n in ['Trip notes.txt', 'Budget 2026.csv', 'Pitch outline.md', 'Contract.pdf', 'Moodboard.json', 'Reading list.txt']) {
        await fs.addBytes(n, Uint8List.fromList(utf8.encode('Sample: $n')), 'files');
      }
    }
    final ks = KanbanStore.instance;
    await ks.init();
    if (ks.allCards.isEmpty) {
      for (final (t, n) in [('Draft launch post', 'Two lines, one image'), ('Book venue', 'Call Friday'), ('Pick font', 'Instrument Sans vs Satoshi'), ('Shoot b-roll', 'Golden hour'), ('Fix invoice', 'Send by Monday')]) {
        await ks.edit(ks.add(0), title: t, notes: n);
      }
    }
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _seedHist = [
        for (final (i, t) in ['Weekend trip plan', 'Compare phone plans', 'Rewrite my bio', 'Explain R2 pricing', 'Name ideas for the app', 'Fix my CSS grid'].indexed)
          ConversationHistorySession(id: 'seed$i', title: t, relativeTime: '${i + 1}h ago', timestamp: now.subtract(Duration(hours: i + 1)), summary: 'Sample conversation about ${t.toLowerCase()}.', messages: const []),
      ];
      _globalHistorySessions = [..._seedHist, ..._globalHistorySessions];
    });
  }

  void _initializeHistorySessions() {
    _globalHistorySessions = [];
    _localHistorySessions = {};
  }

  void _initializeBrowserTabs() {
    // One user tab; research sources are added as tabs when a question uses the web.
    _browserTabs = [
      BrowserTab(id: 'user_default', title: 'Bing', url: browserStartUrl(), isUserControlling: true),
    ];
  }

  /// v9.1 escape audit: one rule for back, Esc and edge-swipe. Closes the
  /// top-most view only.
  bool get _anythingOpen => _browserOpen || _settingsOpen || _zoomedMessage != null || _localHistoryModel != null || _activeDrawer != null || _isMobileSideNavOpen || _genOptionsOpen;
  void _escape() {
    if (!mounted) return;
    setState(() {
      if (_browserOpen) {
        _browserOpen = false;
      } else if (_settingsOpen && _activeDrawer == 'account') {
        _activeDrawer = null;
      } else if (_settingsOpen) {
        _settingsOpen = false;
      } else if (_genOptionsOpen) {
        _genOptionsOpen = false;
      } else if (_zoomedMessage != null || _localHistoryModel != null) {
        _zoomedMessage = null;
        _zoomedModelDef = null;
        _localHistoryModel = null;
      } else if (_activeDrawer != null || _isMobileSideNavOpen) {
        _closeAllPanes();
      } else if (_isComposerSummoned) {
        _isComposerSummoned = false;
      }
    });
  }

  void _closeAllPanes() {
    _activeDrawer = null;
    _localHistoryModel = null;
    _zoomedMessage = null;
    _zoomedModelDef = null;
    _isMobileSideNavOpen = false;
  }

  void _requestSwitchSurface(String? targetDrawer) {
    // No "Unsaved Changes" prompt (removed 2026-09-27): switching surfaces just proceeds.
    // Drafts and inputs are kept in memory as before.
    _proceedSwitchSurface(targetDrawer);
  }

  void _proceedSwitchSurface(String? targetDrawer) {
    setState(() {
      _closeAllPanes();
      _activeDrawer = targetDrawer;
      _isComposerSummoned = (targetDrawer == null);
      if (targetDrawer == 'themes') {
        _savedThemeBeforePreview = _currentTheme;
      }
    });
  }

  void _openDrawer(String drawer) {
    _requestSwitchSurface(drawer);
  }

  void _openHomeComposer() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = true;
    });
  }

  void _toggleComposer() {
    setState(() {
      _closeAllPanes();
      _expandedModelIds.clear();
      _isComposerSummoned = !_isComposerSummoned;
    });
  }

  // One answer open at a time (row 15): tapping a card opens it in the
  // middle; tapping it again, or the pane's close button, closes it.
  void _onTogglePill(String id) {
    setState(() {
      if (_expandedModelIds.contains(id)) {
        _expandedModelIds.clear();
      } else {
        _expandedModelIds
          ..clear()
          ..add(id);
      }
    });
  }

  TickerItem? _openPill(List<TickerItem> pills) {
    for (final p in pills) {
      if (_expandedModelIds.contains(p.modelDef.id)) return p;
    }
    return null;
  }

  ModelPill _pill(TickerItem item, {required double elevation, bool pane = false}) => ModelPill(
        key: ValueKey('${pane ? 'pane' : 'card'}-${item.modelDef.id}'),
        item: item,
        pane: pane,
        elevation: elevation,
        isExpanded: _expandedModelIds.contains(item.modelDef.id),
        onToggleExpand: () => _onTogglePill(item.modelDef.id),
        onSendInlineReply: (reply) => _onSendInlineReply(item.modelDef.id, reply),
        onOpenBrowser: () => _openBrowserForTab(_browserTabs.length > 1 ? _browserTabs[1].id : 'user_default'),
        onTapMessage: (msg) => setState(() {
          _zoomedMessage = msg;
          _zoomedModelDef = item.modelDef;
        }),
        onOpenLocalHistory: () => setState(() => _localHistoryModel = item.modelDef),
      );

  // Main ticker (v8.3.1): every model of a category is listed; deselected
  // models are greyed out. Swiping left/right pages to the next category.
  // R08 caps the window at 40% of the screen, so the list shows three rows
  // and scrolls behind an edge fade with a chevron — never a scrollbar.
  static const List<ModelCategory> _tickerOrder = [
    ModelCategory.general, ModelCategory.coding, ModelCategory.image, ModelCategory.video, ModelCategory.audio,
  ];

  // ===== Window geometry. One geometry, every window, every state =============
  // The reported bug was a layout that snapped between different full-width
  // arrangements as you navigated, because the width was recomputed from the
  // rail, the composer and the expanded card. These four numbers are the whole
  // contract now; nothing below recomputes them.

  /// R08: "Width matches the dock." The dock is [PermanentNavBar]: three 44 pt
  /// circles, two VSpace.sm gaps, VOrnament padding of (VSpace.xs - 2).
  static const double _dockWidth = 44 * 3 + VSpace.sm * 2 + (VSpace.xs - 2) * 2;

  /// Air on every side. R36: windows float, they are not sheets.
  static const double _windowInset = 16;

  /// Between the ticker and the window above it, and above the dock.
  static const double _windowGap = 10;

  /// R08: "At most 40% of screen height." A hard ceiling, not a preference.
  double get _tickerHeight => MediaQuery.sizeOf(context).height * 0.40;

  /// R09: "row count 1, 2 or 3." A slot is sized for a model name plus a
  /// wrapped one-line summary; longer answers scroll behind the edge fade.
  static const int _maxTickerRows = 3;
  static const double _rowSlot = 92;

  /// The category strip that closes the window, with its gap.
  static const double _chipStripHeight = 0;

  /// The composer needs more room than a ticker row, so it gets the full
  /// floatable width and keeps it in every state: summoning it must not
  /// resize it (that was the composer growing huge over the expanded card).
  double get _composerWidth => MediaQuery.sizeOf(context).width - _windowInset * 2;

  /// The opened answer is a tray anchored over the ticker: wider than the dock
  /// so a thread reads, and nowhere near the screen width (bug 5).
  double get _trayWidth =>
      (_dockWidth + 104).clamp(200.0, MediaQuery.sizeOf(context).width - _windowInset * 2).toDouble();

  /// The tray takes what the ticker leaves, so the wallpaper still reads at
  /// the top of the screen when it is open (R36).
  double get _trayHeight => (MediaQuery.sizeOf(context).height * 0.30).clamp(160.0, 340.0);

  /// Real elevation: a tight contact shadow grounds the plane, a wide ambient
  /// one lifts it off the wallpaper, and a faint white bounce says light is
  /// reaching the lower edge. VGlass.resting alone is a 12% wash with a 12%
  /// shadow, which over a bright wallpaper is the unlayered slab that was
  /// reported as bug 3.
  static const List<BoxShadow> _windowShadow = [
    BoxShadow(color: Color(0x73000000), blurRadius: 8, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x7A000000), blurRadius: 38, offset: Offset(0, 20)),
    BoxShadow(color: Color(0x3D000000), blurRadius: 72, spreadRadius: -14, offset: Offset(0, 32)),
    BoxShadow(color: Color(0x1AFFFFFF), blurRadius: 20, spreadRadius: -8),
  ];

  /// One frosted plane: a single [VGlass] with an opaque-leaning fill so the
  /// wallpaper is seen through exactly one transparent layer instead of a
  /// stack of them ("don't translucent on translucent"), plus the shadow pair
  /// above and the specular rim that VGlass paints.
  Widget _windowSurface({
    required Widget child,
    double radius = VRadius.card,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    bool bare = false,
  }) =>
      bare ? Padding(padding: padding, child: child) : DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: _windowShadow),
        child: VGlass(
          radius: radius,
          material: VMaterial.modal,
          shadow: false, // the real shadow is the DecoratedBox above
          padding: padding,
          child: child,
        ),
      );
  late final PageController _catPager = PageController(initialPage: _tickerOrder.indexOf(_activeCategory).clamp(0, 4));
  /// Keeps the named category strip aligned with the paged ticker above it.
  late final ScrollController _catLabelCtl = ScrollController();
  final Map<ModelCategory, ScrollController> _tickerScroll = {for (final c in ModelCategory.values) c: ScrollController()};

  void _toggleSelect(ModelCategory c, String id) {
    setState(() {
      final sel = _selByCat[c]!;
      if (sel.contains(id)) {
        if (sel.length > 1) sel.remove(id);
      } else if (sel.length < 9) {
        sel.add(id);
      }
    });
  }

  List<TickerItem> _tickerRows(ModelCategory c) {
    // v9: this built one card per model in the category whether or not that
    // model had ever answered, so a cold app opened on four or five blank
    // tinted cards with nothing written in them — which is exactly the "no
    // information that's supposed to be there". A row now exists only when
    // there is something to read: an answer, or one on the way.
    final out = <TickerItem>[];
    for (final m in ModelRoster.forCategory(c)) {
      for (final t in _tickerItems.where((t) => t.modelDef.id == m.id)) {
        if (t.conversation.isNotEmpty || t.isStreaming) out.add(t);
      }
    }
    return out;
  }

  Widget _tickerRow(ModelCategory c, TickerItem item, double elevation) {
    final selected = _selByCat[c]!.contains(item.modelDef.id);
    final hasAnswer = item.conversation.isNotEmpty || item.isStreaming;
    final pill = _pill(item, elevation: elevation);
    final card = hasAnswer
        ? pill
        : ModelPill(
            key: ValueKey('card-${item.modelDef.id}'),
            item: item,
            elevation: elevation,
            isExpanded: false,
            onToggleExpand: () => _toggleSelect(c, item.modelDef.id),
            onSendInlineReply: (_) {},
          );
    return GestureDetector(
      key: ValueKey('row-${c.name}-${item.modelDef.id}'),
      onLongPress: () => _toggleSelect(c, item.modelDef.id),
      child: AnimatedOpacity(
        duration: VMotion.base,
        opacity: selected ? 1.0 : 0.42,
        child: selected
            ? AmbientGlow(color: item.modelDef.providerColor, radius: 18, phase: (item.modelDef.id.hashCode % 100) / 100, child: card)
            : ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
                child: card,
              ),
      ),
    );
  }

  /// One page, one arrangement: the ticker window always shows the same thing,
  /// a column of cards at the window's own width. The old version returned two
  /// different layouts from this method depending on whether an answer was
  /// open (a narrow column beside a full-width expanded pane, or a column
  /// aligned left inside a wider window). That is the snap the owner reported
  /// as bug 4, and the expanded answer now lives in its own tray above the
  /// ticker, so this method has one job.
  Widget _tickerPage(ModelCategory c) {
    final rows = _tickerRows(c);
    final sc = _tickerScroll[c]!;
    // v9: nothing has been asked in this category yet. Say so once, quietly,
    // instead of leaving the column as bare glass.
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text(
          'Nothing here yet',
          style: TextStyle(
            fontFamily: 'GoogleSansFlex',
            fontSize: 11,
            height: 1.3,
            fontWeight: FontWeight.w500,
            color: Color(0x8AFFFFFF),
          ),
        ),
      );
    }
    // No Scrollbar: a hard grey track on a glass surface reads as a debug
    // affordance and flattens the illusion. The EdgeFade plus the chevron
    // carry the affordance instead.
    return EdgeFade(
      fadeHeight: 20,
      child: Stack(
        children: [
          ListView.separated(
            controller: sc,
            padding: const EdgeInsets.only(bottom: 4),
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _tickerRow(c, rows[i], rows.length <= 1 ? 1.0 : 1.0 - i / (rows.length - 1)),
          ),
          if (rows.length > 3 && sc.hasClients && sc.position.maxScrollExtent > 0)
            Positioned(
              right: 2,
              bottom: 2,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: sc,
                  builder: (_, __) {
                    final p = sc.hasClients && sc.position.maxScrollExtent > 0
                        ? (sc.offset / sc.position.maxScrollExtent).clamp(0.0, 1.0)
                        : 0.0;
                    final more = 1 - p;
                    return Opacity(
                      opacity: (0.18 + 0.62 * more).clamp(0.0, 0.85),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const String _kConsensusId = '__consensus';
  String _consensusFull = '';
  bool _settingsOpen = false;
  static const ModelDef _consensusDef = ModelDef(id: _kConsensusId, label: 'Consensus', provider: 'Collider', desc: 'Agreement across the answering models.', tier: ModelTier.free, categories: [ModelCategory.general], weight: 0, providerColor: Color(0xFFEDEDED));

  TickerItem _consensusItem() => TickerItem(
        modelDef: _consensusDef,
        relativeTime: _promptTime == null ? '' : _clock(_promptTime!),
        summary: _consensusSummary,
        isStreaming: _isConsensusGenerating,
        conversation: [
          if (_currentPrompt.isNotEmpty) TickerMessage(id: 'cu', sender: 'user', text: _currentPrompt, timestamp: _promptTime ?? DateTime.now()),
          if (!_isConsensusGenerating) TickerMessage(id: 'cm', sender: 'model', text: '$_consensusRatio\n\n${_consensusFull.isNotEmpty ? _consensusFull : _consensusSummary}', timestamp: DateTime.now()),
        ],
      );

  /// Every line the recorder emitted carrying `label:`, in order.
  ///
  /// The recorder's GROUP, CHAIN and CONSENSUS_CHAIN fields are tables: one
  /// line per group, one per response. A regex that stops at the next all-caps
  /// label reads only the first row, because the rows themselves are labelled —
  /// so the rest vanish with no error. This collects them all.
  static List<String> _fieldLines(String text, String label) => [
        for (final l in text.split('\n'))
          if (l.trimLeft().startsWith('$label:')) l.trim(),
      ];

  /// Direct mode consensus: a real call to the keyless judge, over the real answers.
  ///
  /// Output contract is the Consensus Agent spec's Recap, and only that:
  /// Consensus Ratio (a count, never a percent), Consensus Summary (verbatim
  /// from the winning group), the Sentiment Group table, and the Logical Chain
  /// Length Table. There is no NEED, no SERVE and no DETAIL: those were
  /// advisory additions, and the spec is explicit that this records reality
  /// rather than advising.
  ///
  /// This judge reads numbered responses, never model names — it is not told
  /// which model said what, so its table is keyed by response number. The
  /// server-side judge (collider-server.mjs) is told the model names and keys
  /// its table by them. Same spec, two judges, two framings; they never hand
  /// each other's output to a parser.
  final Set<String> _errTexts = {};
  bool _isErr(String t) => t.startsWith('Error: ') || _errTexts.contains(t);

  Future<void> _directConsensus(String prompt) async {
    final answers = [
      for (final t in _tickerItems)
        if (t.conversation.isNotEmpty && t.conversation.last.sender == 'model' && !_isErr(t.conversation.last.text))
          (t.modelDef.label, t.conversation.last.text),
    ];
    final total = _tickerItems.length;
    if (answers.isEmpty) {
      setState(() {
        _isConsensusGenerating = false;
        // R17: an empty score, not "0/N" and not a "waiting" line.
        _consensusRatio = '';
        _consensusSummary = 'Nothing to compare yet.';
        _consensusFull = total == 0
            ? 'No models were selected, so there is nothing to compare.'
            : 'None of the $total selected models returned an answer to compare.';
      });
      return;
    }
    try {
      // The agent reads only the responses. It is never told which model
      // produced which response, because source identity is not an input it
      // uses — need and intent are derived from the prompt, and the responses
      // are read against that.
      final judge = await MediaGen.instance.consensus([
        {
          'role': 'system',
          'content': 'You are the Collider consensus recorder. Several models each independently '
              'answered one message. You record what is there. You do not advise, rank, or evaluate '
              'correctness.\n\n'
              'Work in this order.\n'
              '1. From the user message, derive the need and the intent.\n'
              '2. For each response, simplify it to its base minimal distinction or sentiment: the '
              'actionable portion that serves the derived need.\n'
              '3. Group the responses by that sentiment. Resolve democratically: the sentiment with '
              'the most members is the consensus.\n'
              '4. Count the logical chain depth of each response. A logical chain is a sequential '
              'clarification or simplification that extends logic and serves the need. An explicit '
              'chain reads until the next clause is not logically dependent on the previous. '
              'Implicit chains count too: a definition, statement, or narrative element that '
              'directly supports a logical conclusion, evidentiary after the point or preemptive '
              'before it. A technical definition standing alone never extends beyond 1 however many '
              'appear; it must attach to a larger logical point to extend. An apparent split is '
              'clarification and counts as the same chain. There is one prompt, one chain; anything '
              'outside that is ad libbing and does not count. Do not count words or characters, and '
              'do not use keyword or regex counting. Count meaning.\n'
              '5. Report the maximum chain length for each response.\n\n'
              'Answer with exactly these lines and nothing else. Do not add commentary.\n'
              'RATIO: <count of responses in the winning group>/<total responses>\n'
              'SUMMARY: <the winning sentiment copied verbatim from a member response>\n'
              'Then one GROUP line per sentiment group, in order of size, largest first:\n'
              'GROUP: <sentiment> = <response number>, <response number>\n'
              'Then one CHAIN line per response:\n'
              'CHAIN: <response number> = <chain count> chains, max <max length>\n'
              'Then one final line:\n'
              'CONSENSUS_CHAIN: <chain count> chains, max <the largest max length among its members>'
        },
        {
          'role': 'user',
          'content': 'MESSAGE\n$prompt\n\nRESPONSES (${answers.length})\n${[for (var i = 0; i < answers.length; i++) '--- ${i + 1} ---\n${answers[i].$2}'].join('\n\n')}'
        },
      ]);
      final ratioMatch = RegExp(r'RATIO:\s*(\d+)\s*/\s*(\d+)').firstMatch(judge);
      final line = RegExp(r'^SUMMARY:\s*(.+)$', multiLine: true).firstMatch(judge)?.group(1)?.trim() ?? judge.split('\n').first;
      // Every line carrying the label, not just the first one. A single-row
      // regex silently drops the rest of the table, which is how 3 of 4 chain
      // rows disappeared once already.
      final groups = _fieldLines(judge, 'GROUP');
      final chains = _fieldLines(judge, 'CHAIN');
      final consensusChain = _fieldLines(judge, 'CONSENSUS_CHAIN');
      if (!mounted) return;
      setState(() {
        _isConsensusGenerating = false;
        // R17: the score is a count. An unparseable ratio shows an empty score.
        final n = int.tryParse(ratioMatch?.group(1) ?? '');
        final d = int.tryParse(ratioMatch?.group(2) ?? '');
        _consensusRatio = (n != null && d != null && n > 0 && d > 0) ? '$n/$d' : '';
        // Verbatim from the winning group. Per-response one-liners are not
        // written back onto individual tickers: the agent never sees which
        // model said what, so attributing a summary to a named model would be
        // a fabrication.
        _consensusSummary = line;
        // The Consensus Agent recap, all five fields, nothing else.
        _consensusFull = [
          if (groups.isNotEmpty) 'GROUPS\n${groups.join('\n')}',
          if (chains.isNotEmpty) 'CHAINS\n${chains.join('\n')}',
          if (consensusChain.isNotEmpty) 'CONSENSUS_CHAIN\n${consensusChain.join('\n')}',
        ].join('\n\n');
      });
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyErrorMessage(e).replaceFirst('This model', 'The consensus recorder');
      setState(() {
        _isConsensusGenerating = false;
        // A failure is not a score.
        _consensusRatio = '';
        _consensusSummary = msg;
        _consensusFull = msg;
      });
    }
  }

  bool get _mediaStageOn => _activeCategory.isMedia && (_mediaGens[_activeCategory]?.isNotEmpty ?? false);

  Widget _buildMediaStage() => MediaStageContent(
        key: ValueKey('media-${_activeCategory.name}'),
        items: _mediaGens[_activeCategory]!,
        onRemix: (p) => _restoreText.value = p,
        onNotice: _notice,
        onOptions: () => setState(() => _genOptionsOpen = true),
      );

  Widget _buildTicker() {
    final idx = _tickerOrder.indexOf(_activeCategory);
    if (_catPager.hasClients && _catPager.page != null && (_catPager.page!.round() != idx) && !_catPager.position.isScrollingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_catPager.hasClients) _catPager.animateToPage(idx, duration: VMotion.base, curve: Curves.easeOutCubic);
      });
    }
    // The window owns the height (R08: 40% ceiling, one fixed height in every
    // state). This used to size itself from _rowH, or from a fraction of the
    // screen that grew to 62% when a card was open and the composer was up.
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _catPager,
            itemCount: _tickerOrder.length,
            onPageChanged: (i) => setState(() {
              _activeCategory = _tickerOrder[i];
              _expandedModelIds.clear();
            }),
            itemBuilder: (_, i) => _tickerPage(_tickerOrder[i]),
          ),
        ),
        // v9.1.3: no chip strip; categories come from the composer's + menu
        // (and a sideways swipe on the bubbles).
      ],
    );
  }

  /// Plain-word name for a category tab comes from [ModelCategoryX.label],
  /// so the tab strip and the roster can never drift apart.

  /// The ticker window (R08). Dock width, centred, air on every side, and a
  /// height that never passes 40% of the screen, whatever is open.
  ///
  /// The 40% is a ceiling rather than a target: the window is as tall as the
  /// pinned row, the visible rows and the category strip need, so a ticker
  /// holding one model is a small window instead of a slab (which is what the
  /// old fixed 62%-of-the-screen block was). One width, one ceiling, every
  /// state, so opening a card or the composer cannot resize the room.
  Widget _buildTickerWindow() {
    // v9.1.3: no consensus bubble until it has words.
    final showConsensus = !_activeCategory.isMedia && _tickerItems.isNotEmpty && _consensusSummary.trim().isNotEmpty;
    // R09: the window shows one, two or three rows. A slot is sized for a model
    // name plus a wrapped one-line summary; anything longer scrolls behind the
    // edge fade and the chevron.
    final rowCount = _tickerRows(_activeCategory).length;
    // v9.1.2: nothing asked yet -> nothing drawn, just the wallpaper.
    if (rowCount == 0 && !showConsensus) return const SizedBox.shrink();
    final visible = rowCount.clamp(1, _maxTickerRows);
    final window = SizedBox(
      // v9.1.2: chat bubbles span the screen like the reference.
      width: math.min(MediaQuery.sizeOf(context).width - 100, 520),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: _tickerHeight),
        child: _windowSurface(
          bare: true,
          padding: const EdgeInsets.fromLTRB(VSpace.xs - 2, VSpace.xs - 2, VSpace.xs - 2, VSpace.xs - 2),
          child: CustomMultiChildLayout(
            // Only the card list is elastic. The pinned row keeps its natural
            // height (R16: the line is not cut off) and the category strip is
            // fixed, so the window is exactly as tall as it needs to be and
            // gives the height back to the 40% ceiling when it overflows.
            delegate: _TickerWindowLayout(listSlots: visible * _rowSlot + _chipStripHeight),
            children: [
              LayoutId(
                id: _TickerWindowLayout.pinned,
                child: showConsensus
                    ? ConsensusRow(
                        score: _consensusRatio,
                        summary: _consensusSummary,
                        isGenerating: _isConsensusGenerating,
                        onTap: () => _onTogglePill(_kConsensusId),
                      )
                    : const SizedBox.shrink(),
              ),
              LayoutId(id: _TickerWindowLayout.list, child: _buildTicker()),
            ],
          ),
        ),
      ),
    );
    // Bug 10: summoning the composer has to push the rest of the room back.
    // The wallpaper falls out of focus in the depth-of-field plane above; what
    // was missing was the resting ticker going quiet with it instead of
    // sitting sharp and still taking taps behind the writing surface.
    return AnimatedOpacity(
      duration: VMotion.base,
      curve: Curves.easeOutCubic,
      opacity: _isComposerSummoned ? 0.34 : 1,
      child: IgnorePointer(ignoring: _isComposerSummoned, child: window),
    );
  }

  /// The one window that sits above the ticker.
  ///
  /// R12: a menu and a work surface never show together, so the opened answer
  /// (or the consensus detail) takes this slot, and summoning the composer
  /// takes it back — see [_buildComposer]'s summon path, which closes the tray.
  Widget? _buildTray() {
    if (_expandedModelIds.contains(_kConsensusId)) {
      return _buildTrayWindow(_consensusItem());
    }
    final open = _openPill(_tickerItems);
    return open == null ? null : _buildTrayWindow(open);
  }

  /// Bug 5: the opened answer is a tray anchored over the ticker, not a
  /// permanent full-width block. It grows upward from the ticker's top edge,
  /// the ticker keeps its own geometry underneath it, and the tray closes from
  /// its own close control (R37).
  Widget _buildTrayWindow(TickerItem open) => SizedBox(
        width: _trayWidth,
        height: _trayHeight,
        child: _windowSurface(
          padding: const EdgeInsets.fromLTRB(VSpace.xs - 2, VSpace.xs - 2, VSpace.xs - 2, 2),
          child: _pill(open, elevation: 1, pane: true),
        ),
      );

  /// The composer, in a slot of its own with a width that never changes.
  ///
  /// Bugs 7 and 8: it used to be the last child of the ticker's own column, so
  /// it sat on top of the category chips when the column ran past the window's
  /// max height, and its width came from the ticker's — which is why it grew
  /// huge whenever an answer was expanded. It keeps one width now, in front of
  /// a frosted plane, and never inside the ticker's layout.
  Widget _buildComposer() => SizedBox(
        width: _composerWidth,
        child: _windowSurface(
          bare: true,
          padding: const EdgeInsets.symmetric(vertical: VSpace.xs - 2),
          child: FloatingPrompt(
            summoned: _isComposerSummoned,
            busy: _busy,
            onSubmitPrompt: (text, files) => _onSendPrompt(text, files),
            onSummon: () => setState(() {
              _closeAllPanes();
              _expandedModelIds.clear();
              _isComposerSummoned = true;
            }),
            onTuck: () => setState(() => _isComposerSummoned = false),
            mode: _mode,
            onMode: (m) => setState(() => _mode = m),
            private: _incognito,
            onPrivate: (v) => setState(() => _incognito = v),
            offline: _apiChecked && !ColliderApi.instance.online,
            category: _activeCategory,
            onCategory: (c) => setState(() => _activeCategory = c),
            onOpenOptions: () => setState(() => _genOptionsOpen = true),
            restoreText: _restoreText,
            generateTick: _generateTick,
          ),
        ),
      );

  Future<void> _onSendInlineReply(String modelId, String text) async {
    final idx = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
    if (idx == -1 || text.trim().isEmpty) return;
    final now = DateTime.now();
    final before = _tickerItems[idx];
    setState(() {
      final cur = _tickerItems[idx];
      _tickerItems[idx] = cur.copyWith(
        isIsolated: true,
        isStreaming: true,
        conversation: [...cur.conversation, TickerMessage(id: 'u$now', sender: 'user', text: text, timestamp: now)],
      );
    });
    final conv = _tickerItems[idx].conversation;
    if (!ColliderApi.instance.online) {
      final msgs = [for (final m in conv) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text}];
      try {
        _answer(modelId, await MediaGen.instance.chat(modelId, msgs), false);
      } catch (e) {
        _answer(modelId, e is MediaGenError ? e.reason : friendlyErrorMessage(e), true);
      }
      return;
    }
    try {
      final r = await ColliderApi.instance.reply(
        model: modelId,
        mode: _mode,
        messages: [for (final m in conv) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text}],
      );
      if (!mounted) return;
      setState(() {
        final i = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
        if (i == -1) return;
        final cur = _tickerItems[i];
        _tickerItems[i] = cur.copyWith(
          isStreaming: false,
          relativeTime: 'just now',
          summary: r.essence,
          conversation: [...cur.conversation, TickerMessage(id: 'm${DateTime.now()}', sender: 'model', text: r.text, timestamp: DateTime.now())],
        );
      });
    } catch (_) {
      // No backend (e.g. static hosting, /api 404) or no answer: quietly put
      // the card back as it was (v8.3, D41). No error text, no spinner.
      if (!mounted) return;
      setState(() {
        final i = _tickerItems.indexWhere((it) => it.modelDef.id == modelId);
        if (i != -1) _tickerItems[i] = before;
      });
    }
  }

  /// Media send (source sendChat media routes): one generation per selected
  /// model with the category's settings. Runs that cannot happen fail
  /// quietly (D59); the board keeps the previous results.
  Future<void> _onSendMedia(String prompt) async {
    final cat = _activeCategory;
    final models = [for (final id in _selByCat[cat]!) if (ModelRoster.byId(id) != null) ModelRoster.byId(id)!];
    if (models.isEmpty) return;
    final settings = _genSettings[cat]!..fitTo(cat, models);
    final flags = settings.flags(cat);
    final runnable = models.where((m) => MediaGen.instance.hasCredentials(m.id)).toList();
    if (runnable.isEmpty) {
      _cannotRun(prompt);
      return;
    }
    final kind = switch (cat) { ModelCategory.video => 'video', ModelCategory.audio => 'audio', _ => 'image' };
    final now = DateTime.now();
    final prev = _mediaGens[cat];
    setState(() {
      _busy = true;
      _isComposerSummoned = false;
      _mediaGens[cat] = [
        for (final m in runnable) MediaGeneration(model: m, kind: kind, prompt: prompt, basis: costOf(m, flags, prompt).basis, at: now, pending: true),
      ];
    });
    final refs = _genRefs[cat] ?? const [];
    await Future.wait([
      for (final m in runnable)
        MediaGen.instance.generate(m.id, prompt, flags, imageDataUris: refs).then((r) {
          if (!mounted) return;
          setState(() {
            final l = _mediaGens[cat]!;
            final i = l.indexWhere((g) => g.model.id == m.id && g.pending);
            if (i != -1) l[i] = l[i].done(r.url);
          });
        }).catchError((_) {
          if (!mounted) return;
          setState(() => _mediaGens[cat]!.removeWhere((g) => g.model.id == m.id && g.pending));
        }),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_mediaGens[cat]!.isEmpty) {
        if (prev == null) {
          _mediaGens.remove(cat);
        } else {
          _mediaGens[cat] = prev;
        }
      }
    });
    if (!_mediaGens.containsKey(cat) || identical(_mediaGens[cat], prev)) _cannotRun(prompt);
  }

  /// No Collider server, but this build has a provider key: the source's own
  /// direct OpenRouter path (chat.ts callOpenRouter).
  void _answer(String id, String text, bool error) {
    if (!mounted) return;
    if (error) _errTexts.add(text);
    setState(() {
      final i = _tickerItems.indexWhere((t) => t.modelDef.id == id);
      if (i == -1) return;
      final cur = _tickerItems[i];
      final now = DateTime.now();
      _tickerItems[i] = cur.copyWith(isStreaming: false, relativeTime: _clock(now), summary: text.split('\n').first,
          conversation: [...cur.conversation, TickerMessage(id: 'm$id${now.microsecondsSinceEpoch}', sender: 'model', text: text, timestamp: now)]);
    });
  }

  static String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _onSendDirect(String prompt, List<String> models) async {
    final now = DateTime.now();
    List<TickerMessage> hist(String id) => [
          for (final t in _tickerItems)
            if (t.modelDef.id == id) ...t.conversation,
        ];
    final before = {for (final id in models) id: hist(id)};
    setState(() {
      _busy = true;
      _isComposerSummoned = false;
      _closeAllPanes();
      _expandedModelIds.clear();
      _currentPrompt = prompt;
      _promptTime = now;
      _isConsensusGenerating = true;
      _consensusRatio = '';
      _consensusSummary = '';
      _consensusFull = '';
      _tickerItems = [
        for (final id in models)
          TickerItem(modelDef: ModelRoster.byId(id)!, relativeTime: '', summary: '', isStreaming: true, conversation: [...before[id]!, TickerMessage(id: 'u$id${now.microsecondsSinceEpoch}', sender: 'user', text: prompt, timestamp: now)]),
      ];
    });
    await Future.wait([
      for (final id in models)
        MediaGen.instance.chat(id, [
          // No shared system prompt. Each model answers with its own house
          // behaviour; a single persona here flattened them into one voice.
          for (final m in before[id]!) if (!_isErr(m.text)) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text},
          {'role': 'user', 'content': prompt},
        ]).then((text) => _answer(id, text, false), onError: (e) => _answer(id, e is MediaGenError ? e.reason : friendlyErrorMessage(e), true)),
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    await _directConsensus(prompt);
  }

  Future<void> _onSendPrompt(String prompt, [List<String> files = const []]) async {
    if (_activeCategory.isMedia) return _onSendMedia(prompt);
    final models = _selectedModelIds.where((id) {
      final d = ModelRoster.byId(id);
      return d != null && !d.isMedia;
    }).toList();
    if (models.isEmpty) return;
    if (!ColliderApi.instance.online) {
      // v8.3.1: every selected model is asked directly; one that cannot
      // answer shows its real error in its bubble.
      return _onSendDirect(prompt, models);
    }
    final now = DateTime.now();
    // Restored as-is if there is no backend to answer (D41).
    final prevItems = _tickerItems;
    final prevPrompt = _currentPrompt;
    final prevTime = _promptTime;
    final prevRatio = _consensusRatio;
    final prevSummary = _consensusSummary;
    setState(() {
      _busy = true;
      _isComposerSummoned = false;
      _closeAllPanes();
      _expandedModelIds.clear();
      _currentPrompt = prompt;
      _promptTime = now;
      _isConsensusGenerating = true;
      _consensusRatio = '';
      _consensusSummary = '';
      _tickerItems = [
        for (final id in models)
          TickerItem(
            modelDef: ModelRoster.byId(id)!,
            relativeTime: '',
            summary: '',
            isStreaming: true,
            conversation: [TickerMessage(id: 'u$id', sender: 'user', text: prompt, timestamp: now)],
          ),
      ];
    });
    try {
      final id = await ColliderApi.instance.ask(prompt: prompt, models: models, mode: _mode, autosave: _autosave, incognito: _incognito);
      await for (final j in ColliderApi.instance.watch(id)) {
        if (!mounted) return;
        setState(() => _applyJob(j));
      }
      await _reloadHistory();
    } catch (_) {
      // No backend (static hosting: /api answers 404) or the server dropped:
      // fail quietly (v8.3, D41). The screen goes back to how it was, with
      // no error text and no spinner left running.
      if (!mounted) return;
      setState(() {
        _isConsensusGenerating = false;
        _tickerItems = prevItems;
        _currentPrompt = prevPrompt;
        _promptTime = prevTime;
        _consensusRatio = prevRatio;
        _consensusSummary = prevSummary;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Load conversation and immediately send user there in expanded view
  void _loadAndExpandSession(ConversationHistorySession session) {
    final jobId = session.id.split('_').first;
    if (_jobsById.containsKey(jobId)) {
      setState(() {
        _closeAllPanes();
        _tickerItems = [];
        _applyJob(_jobsById[jobId]!, restored: true);
        _expandedModelIds.clear();
        if (session.targetModelId != null) _expandedModelIds.add(session.targetModelId!);
      });
      return;
    }
    setState(() {
      _activeDrawer = null;
      _localHistoryModel = null;
      _zoomedMessage = null;
      _isMobileSideNavOpen = false;

      final targetId = session.targetModelId ?? (session.modelIds.isNotEmpty ? session.modelIds.first : _selectedModelIds.first);
      
      // Ensure target model is in selected list so it appears in the active rows
      if (!_selectedModelIds.contains(targetId)) {
        _selectedModelIds.insert(0, targetId);
      }

      // Ensure active category matches target model's category
      final targetDef = ModelRoster.byId(targetId);
      if (targetDef != null && !targetDef.categories.contains(_activeCategory) && targetDef.categories.isNotEmpty) {
        _activeCategory = targetDef.categories.first;
      }

      final idx = _tickerItems.indexWhere((it) => it.modelDef.id == targetId);
      if (idx != -1) {
        _tickerItems[idx] = _tickerItems[idx].copyWith(
          conversation: session.messages,
          summary: session.summary,
          relativeTime: session.relativeTime,
        );
      }

      _expandedModelIds.clear();
      _expandedModelIds.add(targetId);
    });
  }

  bool _browserOpen = false;
  String _browserActiveTabId = 'user_default';

  /// R34: one browser instance. Asking again while it is already open only
  /// retargets the window that is on screen.
  Future<void> _openBrowserForTab(String tabId) async {
    await _booted.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    if (!mounted) return;
    setState(() {
      _activeDrawer = null;
      _browserOpen = true;
      _browserActiveTabId = tabId;
    });
  }

  void _closeBrowser() {
    if (!_browserOpen) return;
    setState(() {
      _browserOpen = false;
      _activeDrawer = null;
    });
  }

  Widget _buildSideNav({required bool isMobile}) {
    // REQ-21 visual language: a slim detached rail of circular glass buttons sits at
    // the screen edge; the contextual panel content opens beside it when summoned.
    final surface = _currentActiveSurface;
    final String? railKey = switch (surface) {
      ActiveWorkSurface.chat => _isMobileSideNavOpen ? _chatSection : null,
      ActiveWorkSurface.smartgen => _smartGenView,
      ActiveWorkSurface.market => _isMobileSideNavOpen ? 'search' : _marketCategory,
      ActiveWorkSurface.themes => _activeDrawer == 'premium' ? 'premium' : (_activeDrawer == 'music' ? 'music' : 'gallery'),
      ActiveWorkSurface.browser => null,
      ActiveWorkSurface.files => _filesCategory,
    };

    void togglePanel(void Function() apply, bool same) {
      setState(() {
        apply();
        _isMobileSideNavOpen = same ? !_isMobileSideNavOpen : true;
      });
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SideNavRail(
          surface: surface,
          activeKey: railKey,
          compact: isMobile,
          onSelect: (key) {
            switch (surface) {
              case ActiveWorkSurface.chat:
                if (key == 'new') {
                  setState(() => _isMobileSideNavOpen = false);
                  _openHomeComposer();
                } else {
                  togglePanel(() => _chatSection = key, key == _chatSection);
                }
              case ActiveWorkSurface.smartgen:
                setState(() {
                  _isMobileSideNavOpen = false;
                  if (key != 'new') _smartGenView = key;
                });
              case ActiveWorkSurface.market:
                if (key == 'search') {
                  togglePanel(() {}, true);
                } else {
                  setState(() {
                    _isMobileSideNavOpen = false;
                    _marketCategory = key;
                  });
                }
              case ActiveWorkSurface.themes:
                setState(() {
                  _isMobileSideNavOpen = false;
                  _themeSection = key;
                  _activeDrawer = key == 'gallery' ? 'themes' : key;
                });
              case ActiveWorkSurface.browser:
                break;
              case ActiveWorkSurface.files:
                setState(() {
                  _isMobileSideNavOpen = false;
                  _filesCategory = key;
                });
            }
          },
        ),
        if (_isMobileSideNavOpen && surface == ActiveWorkSurface.chat) ...[
          const SizedBox(width: 10),
          ContextualSideNav(
            activeSurface: _currentActiveSurface,
            activeCategory: _activeCategory,
            selectedModelIds: _selectedModelIds,
            localHistory: _localHistorySessions,
            globalHistory: _globalHistorySessions,
            consensusRatio: _consensusRatio,
            consensusSummary: _consensusSummary,
            expandedModelId: _expandedModelIds.isNotEmpty ? _expandedModelIds.first : null,
            chatSection: _chatSection,
            onClose: () => setState(() => _isMobileSideNavOpen = false),
      onSelectCategory: (cat) => setState(() => _activeCategory = cat),
      onToggleModel: (modelId) {
        setState(() {
          if (_selectedModelIds.contains(modelId)) {
            if (_selectedModelIds.length > 1) {
              _selectedModelIds.remove(modelId);
            }
          } else {
            if (_selectedModelIds.length < 9) {
              _selectedModelIds.add(modelId);
            }
          }
        });
      },
      onSelectSession: (sess) => _loadAndExpandSession(sess),
      onOpenConsensus: () => _requestSwitchSurface('consensus'),
      onNewConversation: _openHomeComposer,
      activeSmartGenView: _smartGenView,
      activeSmartGenBoardType: _smartGenBoardType,
      onSelectSmartGenView: (v) => setState(() => _smartGenView = v),
      onSelectSmartGenBoardType: (b) => setState(() => _smartGenBoardType = b),
      activeMarketCategory: _marketCategory,
      onSelectMarketCategory: (c) => setState(() => _marketCategory = c),
      activeThemeSection: _themeSection,
      onSelectThemeSection: (s) {
        setState(() {
          _themeSection = s;
          if (s == 'gallery') {
            _activeDrawer = 'themes';
          } else if (s == 'premium') {
            _activeDrawer = 'premium';
          } else if (s == 'music') {
            _activeDrawer = 'music';
          }
        });
      },
      browserTabs: _browserTabs,
      activeBrowserTabId: 'user_default',
      onCloseBrowserTab: (id) => setState(() => _browserTabs.removeWhere((t) => t.id == id)),
      onClearBrowserCache: () {},
      activeFilesCategory: _filesCategory,
      onSelectFilesCategory: (c) => setState(() => _filesCategory = c),
      onRequestSwitchSurface: (surface) {
        final target = switch (surface) {
          ActiveWorkSurface.chat => null,
          ActiveWorkSurface.smartgen => 'smartgen',
          ActiveWorkSurface.market => 'market',
          ActiveWorkSurface.themes => 'themes',
          ActiveWorkSurface.browser => null,
          ActiveWorkSurface.files => 'files',
        };
        _requestSwitchSurface(target);
      },
      onPaneInteraction: () {},
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Max 9 active model rows filtered by active category with fallback
    var categoryPills = _tickerItems
        .where((it) => it.modelDef.categories.contains(_activeCategory) && _selectedModelIds.contains(it.modelDef.id))
        .take(9)
        .toList();

    if (categoryPills.isEmpty) {
      categoryPills = _tickerItems
          .where((it) => it.modelDef.categories.contains(_activeCategory))
          .take(9)
          .toList();
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: Focus(autofocus: true, child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ================= PLANE 0: BACKGROUND WALLPAPER =================
          // Not built under the Premium Theme Market: the market paints its own
          // opaque #000 -> #111 root and its own ambient loop over the whole
          // viewport, so Plane 0 was invisible there while still decoding a
          // full-bleed still on every swipe during idle playback.
          if (_activeDrawer != 'premium') ...[
          Positioned.fill(
            child: ThemeLivingBackdrop(
              key: ValueKey('live-${_currentTheme.id}-${_currentTheme.videoPath ?? _currentTheme.assetPath}-${_activeDrawer == 'premium' ? 'ambient' : 'live'}'),
              theme: _currentTheme,
              // Asset-swap: live loop + Builder BackgroundVideo filter when Premium Market
              // (supersedes prior H6 sharp-tint / preferVideo:false)
              // The premium market renders its own ambient loop of the focused theme;
              // Plane 0 stays on the poster there so only one stream is open.
              // The Theme Gallery paints its own room and preview (row 6).
              preferVideo: _activeDrawer != 'premium' && _activeDrawer != 'themes',
              builderAmbient: _activeDrawer == 'premium',
            ),
          ),
          ],

          // Base ambient dim. Overlays and work surfaces bring their own VScrim
          // (kit overlay 0.35 + medium blur) so the wallpaper stays visible;
          // the theme gallery keeps a light tint.
          if (_activeDrawer == 'themes')
            Positioned.fill(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: const SizedBox.expand())),

          // Depth of field for the summoned composer: the world falls out of
          // focus behind the writing surface. Previously summoning only
          // reflowed the layout, so the composer read as a flat overlay stuck
          // on top of the room rather than a nearer plane in it.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isComposerSummoned,
              child: AnimatedOpacity(
                duration: VMotion.base,
                curve: Curves.easeOutCubic,
                opacity: _isComposerSummoned ? 1 : 0,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.black.withValues(alpha: 0.34),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          // v8.7: depth of field while typing: the room behind goes soft.
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<bool>(
                valueListenable: KeyboardDof.active,
                builder: (_, on, __) => TweenAnimationBuilder<double>(
                  tween: Tween(end: on ? 14 : 0),
                  duration: const Duration(milliseconds: 260),
                  builder: (_, b, __) => b < 0.3 ? const SizedBox.shrink() : BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: b, sigmaY: b), child: const SizedBox.expand()),
                ),
              ),
            ),
          ),

          // ================= PLANE 1: THE TICKER WINDOW, THE TRAY, THE COMPOSER =================
          // Hidden during Premium Theme Market (Body) so ticker chrome doesn't bleed through.
          //
          // One arrangement, in every state, bottom-up:
          //
          //   dock (drawn further down) · air · composer
          //   air · ticker window (dock width, at most 40% of the height)
          //   air · tray (only while an answer is open)
          //
          // Nothing here is measured from the rail, the composer or the open card
          // any more, so navigating cannot snap the layout into a different
          // full-width arrangement. Nothing touches an edge.
          if (!_settingsOpen && !_browserOpen && !(isMobile && _isMobileSideNavOpen) && !const {'premium', 'themes', 'apps', 'smartgen', 'market', 'files', 'consensus', 'history', 'music', 'account'}.contains(_activeDrawer))
          Positioned.fill(
            bottom: 12,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  // v9.1.2: bubbles at the top like the reference photo,
                  // composer at the bottom, open wallpaper between.
                  mainAxisSize: _mediaShowing ? MainAxisSize.min : MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!_mediaShowing) const SizedBox(height: 12),
                    // Map row 13: a generation gets the room to show its media
                    // and its panel, so the media board keeps this plane to
                    // itself and only the composer floats in the floatable width.
                    if (_mediaShowing)
                      _buildComposer()
                    else ...[
                      // Bug 5: the opened answer is a tray anchored over the
                      // ticker, not a permanent block in the middle of it.
                      if (_buildTray() case final tray?) ...[
                        tray,
                        const SizedBox(height: _windowGap),
                      ],
                      // Bug 10: this one dims when the composer is summoned.
                      ValueListenableBuilder<bool>(
                        valueListenable: KeyboardDof.active,
                        builder: (_, on, child) => ImageFiltered(enabled: on, imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: child!),
                        child: _buildTickerWindow(),
                      ),
                      const Spacer(),
                      // Bug 7: the composer has its own slot now, so it cannot
                      // land on the category chips.
                      _buildComposer(),
                    ],
                    const SizedBox(height: _windowGap),
                  ],
                ),
              ),
            ),
          ),




          // v8.3.1: row 13 media gen window ported from v8.4 (Figma 2013:71).
          if (!_browserOpen && !(isMobile && _isMobileSideNavOpen) && !const {'premium', 'themes', 'apps', 'smartgen', 'market', 'files', 'consensus', 'music'}.contains(_activeDrawer) && _mediaStageOn)
            Positioned.fill(bottom: 210, child: _buildMediaStage()),

          // ================= PLANE 2: APPS POPUP PANE =================
          // Middle neutral area, no visible canvas, blurred background, clickaway + close icon
          if (_activeDrawer == 'apps')
            Positioned.fill(
              child: AppsPopupPane(
                onClose: () => setState(() => _activeDrawer = null),
                onOpenSmartGen: () => _requestSwitchSurface('smartgen'),
                onOpenDiscoverMarket: () => _requestSwitchSurface('market'),
                onOpenThemeGallery: () => _requestSwitchSurface('themes'),
                onOpenPremiumMarketplace: () => _requestSwitchSurface('premium'),
                onOpenFiles: () => _requestSwitchSurface('files'),
                onOpenMusicPlayer: () => _requestSwitchSurface('music'),
                onOpenBrowser: () => _openBrowserForTab('user_default'),
                onOpenSettings: () => setState(() { _activeDrawer = null; _settingsOpen = true; }),
              ),
            ),

          // ================= PLANE 3: LOCAL MODEL HISTORY PANE =================
          // Centered popup pane, searches body & title, relative timestamps
          if (_localHistoryModel != null)
            Positioned.fill(
              child: LocalHistoryPane(
                modelDef: _localHistoryModel!,
                // Real history only (D30): no invented fallback session.
                sessions: _localHistorySessions[_localHistoryModel!.id] ?? const [],
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _localHistoryModel = null),
              ),
            ),

          // ================= PLANE 4: MESSAGE ZOOM OVERLAY =================
          // Dimmed/blurred backdrop, no visible window, faded edges, bottom actions
          if (_zoomedMessage != null && _zoomedModelDef != null)
            Positioned.fill(
              child: MessageZoomOverlay(
                message: _zoomedMessage!,
                modelName: _zoomedModelDef!.label,
                providerColor: _zoomedModelDef!.providerColor,
                onClose: () => setState(() => _zoomedMessage = null),
                onBranchIsolated: () {
                  _onSendInlineReply(_zoomedModelDef!.id, "Branched branch from zoomed message.");
                },
              ),
            ),

          // ================= PLANE 5: DRAWERS & DURABLE WORK SURFACES =================
          if (_activeDrawer == 'history')
            Positioned.fill(
              child: HistoryDrawer(
                sessions: _globalHistorySessions,
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          if (_activeDrawer == 'model_ladder')
            Positioned.fill(
              child: ModelLadderDrawer(
                activeCategory: _activeCategory,
                selectedModelIds: _selectedModelIds,
                onSelectCategory: (cat) {
                  setState(() {
                    _activeCategory = cat;
                  });
                },
                onToggleModel: (modelId) {
                  setState(() {
                    if (_selectedModelIds.contains(modelId)) {
                      if (_selectedModelIds.length > 1) {
                        _selectedModelIds.remove(modelId);
                      }
                    } else {
                      if (_selectedModelIds.length < 9) {
                        _selectedModelIds.add(modelId);
                      }
                    }
                  });
                },
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          if (_activeDrawer == 'themes')
            Positioned.fill(
              child: WindowlessThemeScroller(
                currentTheme: _currentTheme,
                // v8.3.1: browsing never changes the app background (only Set does).
                onLivePreview: (_) {},
                onConfirmTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onCancel: () => setState(() {
                  _currentTheme = _savedThemeBeforePreview;
                  _activeDrawer = null;
                }),
                onUpgradeTier: () => setState(() => _activeDrawer = 'premium'),
              ),
            ),

          if (_activeDrawer == 'premium')
            Positioned.fill(
              // Swipe down returns to the free Theme Gallery.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 300) setState(() => _activeDrawer = 'themes');
                },
                child: PremiumThemeMarketView(
                currentTheme: _currentTheme,
                onApplyTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onPreviewTheme: (theme) {
                  // Only the focused theme streams video; warm neighbour posters.
                  ThemeMediaPrefetch.precacheNeighbors(context, WallpaperCatalog.premiumThemes, theme);
                  setState(() {
                    _currentTheme = theme;
                  });
                },
                onClose: () => setState(() => _activeDrawer = null),
              ),
              ),
            ),

          // No songs in the catalog: no Music drawer (v8.3, D46).
          if (_activeDrawer == 'music' && MusicPlayer.library.isNotEmpty)
            Positioned.fill(
              child: MusicCollectionDrawer(
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),


          if (_activeDrawer == 'account' && !_settingsOpen)
            Positioned.fill(
              child: AccountSheet(tier: ModelTier.free, onClose: () => setState(() => _activeDrawer = null)),
            ),

          // Durable work surfaces sit over one shared scrim (kit overlay + medium blur).
          if (_activeDrawer == 'smartgen' || _activeDrawer == 'market' || _activeDrawer == 'files')
            const Positioned.fill(child: VScrim()),

          if (_activeDrawer == 'smartgen')
            Positioned(
              left: isMobile ? 0 : 360,
              right: 0,
              top: 0,
              bottom: 78,
              child: SmartGenScreen(
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          if (_activeDrawer == 'market')
            Positioned(
              left: isMobile ? 0 : 360,
              right: 0,
              top: 0,
              bottom: 78,
              child: MarketScreen(
                onClose: () => _requestSwitchSurface(null),
                onUsePrompt: (p) => _onSendPrompt(p),
                onNotice: _notice,
              ),
            ),

          // v8.2 round 3 (D31): the Tiers screen (invented prices, dead
          // upgrade buttons) and the Skills screen (toggles wired to nothing)
          // were reachable only by deep link; both are deleted.

          if (_activeDrawer == 'files')
            Positioned(
              left: isMobile ? 0 : 360,
              right: 0,
              top: 0,
              bottom: 78,
              child: FilesScreen(
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          if (_activeDrawer == 'consensus')
            Positioned.fill(
              // The app shell bar stays on every screen (requirement 7).
              bottom: isMobile ? 78 : 0,
              child: ConsensusWebView(
                job: _currentJobId == null ? null : _jobsById[_currentJobId],
                onClose: () => setState(() => _activeDrawer = null),
              ),
            ),

          // Map row 17: generation options for the active media category.
          if (_genOptionsOpen && _activeCategory.isMedia && _activeDrawer == null)
            Positioned.fill(
              bottom: 74,
              child: GenOptionsSheet(
                category: _activeCategory,
                models: [for (final id in _selectedModelIds) if (ModelRoster.byId(id) != null) ModelRoster.byId(id)!],
                settings: _genSettings[_activeCategory]!,
                references: _genRefs[_activeCategory] ?? const [],
                onReferences: (r) => setState(() => _genRefs[_activeCategory] = r),
                previewUrl: _mediaGens[_activeCategory]?.where((g) => g.url != null).firstOrNull?.url,
                posterFallback: _currentTheme.stillPath ?? _currentTheme.assetPath,
                onChanged: () => setState(() {}),
                onGenerate: () => setState(() {
                  _genOptionsOpen = false;
                  _isComposerSummoned = true;
                  _generateTick.value++;
                }),
                onClose: () => setState(() => _genOptionsOpen = false),
              ),
            ),

          // ================= PLANE 3: CONTEXTUAL SIDE NAV =================
          if (isMobile) ...[
            // Mobile backdrop when side nav is open
            if (_isMobileSideNavOpen && _railVisible)
              Positioned.fill(
                child: VScrim(onTap: () => setState(() => _isMobileSideNavOpen = false)),
              ),

            // REQ-21: the rail ornament is present on the resting canvas and every
            // durable work surface; focused overlays own the stage while open.
            if (_railVisible)
              Positioned(
                left: 10,
                bottom: 230, // v9.1.3: above the nav column
                child: _buildSideNav(isMobile: true),
              ),
          ] else ...[
            if (_railVisible)
            Positioned(
              left: 12,
              bottom: 84,
              child: _buildSideNav(isMobile: false),
            ),
          ],

          // ================= MUSIC WIDGET: the one instance =================
          // v8.3 (DEVIATIONS.md D38): shown only while switched on in Settings;
          // own layer + own drag state; pinned wherever the user puts it
          // inside the safe area above the bar; position persisted.
          Positioned.fill(
              // Keyed: the conditional layers before it come and go, and the
              // widget's expanded / drag state must survive that.
              key: const ValueKey('floating-music'),
              child: FloatingMusic(
                overMarket: _activeDrawer == 'premium',
                // Full-screen focused surfaces own the screen (D26).
                hidden: const {'music', 'consensus'}.contains(_activeDrawer) ||
                    _zoomedMessage != null ||
                    _localHistoryModel != null,
                onOpenCollection: () => _openDrawer('music'),
              ),
            ),

          // ================= PLANE 3: BROWSER WINDOW =================
          // A window in the room, not a route above it. It sits under the dock
          // (PLANE 4), so dock taps reach the dock and close the browser (R12),
          // and it lays no scrim over the wallpaper, which stays visible around
          // all four sides of it (R36). The transparent barrier keeps taps on
          // the resting surface from reaching through behind it.
          if (_browserOpen) ...[
            const Positioned.fill(child: ModalBarrier(color: Colors.transparent)),
            Positioned.fill(
              child: Center(
                child: InAppBrowserSheet(
                  initialTabId: _browserActiveTabId,
                  tabs: _browserTabs,
                  onClose: _closeBrowser,
                  onTabUpdated: (updated) {
                    setState(() {
                      final idx = _browserTabs.indexWhere((t) => t.id == updated.id);
                      if (idx != -1) _browserTabs[idx] = updated;
                    });
                  },
                  onNewUserTab: (newTab) {
                    setState(() {
                      _browserTabs.add(newTab);
                    });
                  },
                ),
              ),
            ),
          ],

          // ================= PLANE 4: PERMANENT BOTTOM DOCK =================
          // Shown on every screen, the Premium Theme Market included (the market
          // reserves its height; see PremiumThemeMarketView.bottomBarReserve).
          // Hidden on phone widths while consensus is open: the scene has its own back control.
          // v8.3.1: Settings opens over the current screen (no reset), blurred behind.
          // v9.1: Settings materializes in and dissolves out (spring).
          Positioned.fill(
            child: MaterializeSwitch(
              show: _settingsOpen,
              builder: (_) =>               // v8.7: a submenu opened from Settings sits on its own plane in
              // front; Settings steps back (smaller, softer) behind it.
AnimatedScale(
                scale: _activeDrawer == 'account' ? 0.94 : 1,
                duration: VMotion.base,
                child: ImageFiltered(
                  enabled: _activeDrawer == 'account',
                  imageFilter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: SettingsDrawer(
                onClose: () => setState(() => _settingsOpen = false),
                incognito: _incognito,
                autosave: _autosave,
                onIncognito: (v) => setState(() => _incognito = v),
                onAutosave: (v) => setState(() => _autosave = v),
                onAccount: () => setState(() => _activeDrawer = 'account'),
              ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: MaterializeSwitch(show: _settingsOpen && _activeDrawer == 'account', builder: (_) => AccountSheet(tier: ModelTier.free, onClose: () => setState(() => _activeDrawer = null)))),

          // v9.1.3: no bottom bar. Settings / Home / Apps live in a small
          // receding column at the left edge, above the composer.
          Positioned(
            left: 10,
            bottom: 84,
            child: SafeArea(
              top: false,
              child: Align(
                child: SpecularSweep(radius: 40, child: PermanentNavBar(
                  isComposerSummoned: _isComposerSummoned,
                  onToggleComposer: () {
                    // R12: any nav tap closes every other open pane.
                    _closeBrowser();
                    _toggleComposer();
                  },
                  onHome: () {
                    _closeBrowser();
                    if (_activeDrawer != null) {
                      _requestSwitchSurface(null);
                    } else {
                      _openHomeComposer();
                    }
                  },
                  onApps: () {
                    _closeBrowser();
                    _openDrawer('apps');
                  },
                  onSettings: () {
                    _closeBrowser();
                    setState(() => _settingsOpen = !_settingsOpen);
                  },
                  activeDrawer: _activeDrawer,
                )),
              ),
            ),
          ),

          // v9.1 escape: swipe in from the left edge closes the top view.
          if (_anythingOpen)
            Positioned(
              left: 0, top: 0, bottom: 0, width: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) { if ((d.primaryVelocity ?? 0) > 250) _escape(); },
              ),
            ),
        ],
      ),
    )));
  }
}

