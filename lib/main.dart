import 'package:dio/dio.dart';
import 'dart:math' as math;
import 'core/theme/app_font.dart';
import 'features/smartgen/sg_model.dart';
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
import 'features/ticker/widgets/glm_column_window.dart';
import 'features/ticker/widgets/model_pill.dart';
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
import 'features/theme/theme_pack_store.dart';
import 'features/theme/theme_living_media.dart';
import 'core/media/theme_catalog.dart';
import 'core/vision/keyboard_dof.dart';
import 'core/vision/materialize.dart';
import 'core/vision/cpane.dart';
import 'core/media/first_frame.dart';
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
      // AUTHORITY S-C13: SF Pro on Apple (fontFamily null), Inter elsewhere.
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true, fontFamily: kAppFont, fontFamilyFallback: const ['Inter']).copyWith(
        scaffoldBackgroundColor: const Color(0xFF07080B),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: kAppFont ?? 'Inter', fontFamilyFallback: const ['Inter']),
        primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(fontFamily: kAppFont ?? 'Inter', fontFamilyFallback: const ['Inter']),
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
  /// Opens this drawer on the first frame. Screenshot links use `?app=`.
  /// Tests pass it here because the test binding has no query string.
  const ColliderHomeScreen({super.key, this.initialDrawer});
  final String? initialDrawer;

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
  String _smartGenView = 'tasks';
  String _smartGenBoardType = 'kanban';
  String _marketCategory = 'stills';
  String _themeSection = 'gallery';
  String _filesCategory = 'all';
  /// v9.1.7 (#24): Music collection on the side nav: all, themes, ambient.
  String _musicCollection = 'all';
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
    // Smart Gen's pane is centred and the rail would cover its left edge, so
    // the rail yields while that pane is open. Cards, canvases, boards and
    // Genie stay inside the pane.
    const surfaces = {null, 'themes', 'market', 'files', 'music'};
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
      // QA builds only: ?qa_theme=<theme id> sets that wallpaper on Home, the
      // same state change as "Set as wallpaper" (qa/set_wallpaper_check.py).
      final qt = ThemePackStore.qaUnlockAll ? Uri.base.queryParameters['qa_theme'] : null;
      final q = qt == null ? null : cat.bySlug(qt);
      if (q != null) {
        _currentTheme = q;
        _savedThemeBeforePreview = q;
      }
    });
    // v9.1.6d (#3): start the current wallpaper's poster as soon as the
    // catalogue lands, so the Gallery frame is never empty while it decodes.
    final v = _currentTheme.videoUrl;
    if (_currentTheme.isLive && v != null) unawaited(FirstFrames.get(v));
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      _escape();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    ThemeCatalog.instance.removeListener(_onCatalogChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    installBackGuard(_escape);
    // v9.1.4: Escape works whatever holds focus (or when nothing does).
    HardwareKeyboard.instance.addHandler(_onKey);
    if (Uri.base.queryParameters['seed'] == '1') _seedSamples();
    ThemeCatalog.instance.addListener(_onCatalogChanged);
    KeyboardDof.install();
    if (Uri.base.queryParameters['drawer'] == 'premium') {
      _activeDrawer = 'premium';
      // v9.1.4 (playtest #2): keep the home wallpaper; the store only previews.
      _savedThemeBeforePreview = _currentTheme;
      _prevDrawer = 'premium';
    } else if (Uri.base.queryParameters['drawer'] != null) {
      _activeDrawer = Uri.base.queryParameters['drawer'];
    }
    if (Uri.base.queryParameters['composer'] == '1') _isComposerSummoned = true;
    if (Uri.base.queryParameters['settings'] == '1') _settingsOpen = true;
    if (Uri.base.queryParameters['browser'] == '1') _browserOpen = true;
    final rs = int.tryParse(Uri.base.queryParameters['restore'] ?? '');
    if (rs != null) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() => _activeDrawer = 'history');
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted && rs < _globalHistorySessions.length) _loadAndExpandSession(_globalHistorySessions[rs]);
        });
      });
    }
    final cq = Uri.base.queryParameters['cat'];
    if (cq != null) _activeCategory = ModelCategory.values.firstWhere((c) => c.name == cq, orElse: () => ModelCategory.general);
    if (Uri.base.queryParameters['genopts'] == '1' && _activeCategory.isMedia) _genOptionsOpen = true;
    if (Uri.base.queryParameters['rail'] == '1') _isMobileSideNavOpen = true;
    _activeDrawer ??= widget.initialDrawer;
    _initializeTickerItems();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _qaSeedAnswers(); });
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

  void _qaSeedAnswers() {
    final qp = Uri.base.queryParameters;
    // QA builds only: ?qa_files=1 puts one short R2 video in Files so the
    // Player can be opened and checked.
    if (ThemePackStore.qaUnlockAll && qp['qa_files'] == '1') {
      () async {
        final fs = FileStore.instance;
        await fs.init();
        if (fs.files.any((f) => f.name == 'QA clip.mp4')) return;
        final r = await Dio().get<List<int>>('${ThemeCatalog.mediaBaseUrl}FARM%20SKY.mp4', options: Options(responseType: ResponseType.bytes));
        if (r.data != null) await fs.addBytes('QA clip.mp4', Uint8List.fromList(r.data!), 'files');
      }();
    }
    // QA builds only: ?qa_answers=1 fills the General ticker with sample
    // answers so tap-to-expand, the inline composer and the long-press menu
    // can be checked without spending model calls.
    if (ThemePackStore.qaUnlockAll && qp['qa_answers'] == '1') {
      final now = DateTime.now();
      const lines = [
        'Pack light: three outfits, one jacket, rain shell for Saturday.',
        'Book the 9:40 train; it saves an hour over driving.',
        'Saturday looks wet after 2 PM, so do the hike in the morning.',
        'The cabin has a kitchen, so plan two dinners in.',
        'Budget about \$420 for two nights including fuel.',
        'Bring a power bank: the trail has no signal past the lake.',
        'Reserve the lake kayaks the day before; they sell out.',
        'Leave by 4 PM Sunday to beat traffic back.',
      ];
      setState(() {
        _currentPrompt = 'Plan my weekend trip to the lake';
        _promptTime = now;
        var i = 0;
        _tickerItems = [
          for (final m in ModelRoster.forCategory(ModelCategory.general))
            TickerItem(
              modelDef: m,
              relativeTime: _clock(now),
              summary: lines[i % lines.length],
              conversation: [
                TickerMessage(id: 'qa-u-${m.id}', sender: 'user', text: _currentPrompt, timestamp: now),
                TickerMessage(id: 'qa-m-${m.id}', sender: 'model', text: '${lines[i++ % lines.length]}\n\nSample answer for QA.', timestamp: now),
              ],
            ),
        ];
      });
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
      final keepIsolated = prev.isNotEmpty && prev.first.isIsolated;
      items.add(TickerItem(
        modelDef: def,
        relativeTime: restored ? _ago(j.created) : 'just now',
        summary: r.essence.isNotEmpty ? r.essence : r.text.split('\n').first,
        isStreaming: waiting,
        isIsolated: keepIsolated,
        conversation: keepIsolated
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
    final ks = SgStore.instance;
    await ks.init();
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
        _activeDrawer = null;
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
      } else if (_expandedModelIds.isNotEmpty && _activeDrawer == null) {
        _expandedModelIds.clear(); // v9.1.4 (playtest #6): Esc closes the opened answer
      } else if (_activeDrawer != null || _isMobileSideNavOpen) {
        _closeAllPanes();
      } else if (_isComposerSummoned) {
        _isComposerSummoned = false;
      }
    });
  }

  // v9.1.6e ROOT CAUSE of the grey slab: `_catPager.page` (and the ticker
  // scroll controllers' `.position`) call List.single on their positions.
  // While a pane swap briefly attached two scroll views, that threw
  // 'Bad state: Too many elements' inside build, and release Flutter paints
  // a failed build as a flat grey ErrorWidget: the slab. Every such access is
  // now guarded by positions.length == 1; the 1px scroll nudge is removed.

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
      _settingsOpen = false; // peers replace each other
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

  // ===== v9.1.4 layer manager =====
  // Three kinds of layer: the persistent conversation (ticker, answers, the
  // open answer, the draft) is never cleared by navigation; peers (Settings,
  // Apps, every Apps/side-nav destination) replace each other through a
  // cross-fade (MaterializeSwitch / Materialize); children (Account from
  // Settings, viewers from Files, the zoomed answer) open in front of their
  // parent, smaller, and leave the parent in place. See briefs/qa/layer-audit.md.
  void _openPeer(String id) {
    setState(() {
      final wasOpen = id == 'settings' ? _settingsOpen : _activeDrawer == id;
      _browserOpen = false;
      _zoomedMessage = null;
      _zoomedModelDef = null;
      _localHistoryModel = null;
      _isMobileSideNavOpen = false;
      _settingsOpen = false;
      _activeDrawer = null;
      if (wasOpen) return; // tapping the open peer's button closes it
      if (id == 'settings') {
        _settingsOpen = true;
      } else {
        _activeDrawer = id;
      }
    });
  }

  void _openHomeComposer() {
    setState(() {
      _closeAllPanes();
      _isComposerSummoned = true;
    });
  }

  void _toggleComposer() {
    setState(() {
      _closeAllPanes();
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
        // v9.1.4 (playtest #6): the answer shows once, in the pane.
        isExpanded: pane && _expandedModelIds.contains(item.modelDef.id),
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
  static const int _maxTickerRows = 4; // four shown, the rest scroll (v8.6)
  /// v9.1.7 (#6/#7): under a tall pane the ticker docks in the band above the
  /// composer with two rows showing; the rest still scroll.
  static const int _dockedTickerRows = 2;
  /// Panes tall enough to cover the ticker. Each one ends above the dock band.
  bool _premiumCovered = false;
  // While Premium materializes, Plane 0 keeps the wallpaper David had: the
  // market previews its first theme at once, and swapping Plane 0 to it
  // flashed the dark loading fallback.
  WallpaperTheme get _plane0Theme => _activeDrawer == 'premium' ? _savedThemeBeforePreview : _currentTheme;
  Timer? _premiumCoverTimer;
  bool _premiumCovers() {
    if (_premiumCovered) return true;
    _premiumCoverTimer ??= Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _premiumCoverTimer = null;
      if (_activeDrawer == 'premium') setState(() => _premiumCovered = true);
    });
    return false;
  }
  // v9.1.7 (CPane): the ticker docks under EVERY pane, built once here.
  bool get _tallPaneOpen => _browserOpen || _settingsOpen || _activeDrawer != null;
  final GlobalKey _composerKey = GlobalKey();
  /// Distance from the screen bottom to just above the composer. Measured
  /// after layout. The ticker may sit behind a pane; the composer may not.
  double _dockBand = 0;
  // v9.1.7 (CPane): the one bottom reserve every pane inherits. It is at
  // least the composer, so a focused pane ends above the bar.
  /// The home composer sends a message. It has no job on another surface, so
  /// those screens do not show it and do not reserve its band.
  bool get _composerVisible => !_tallPaneOpen;
  double get _paneReserve => _composerVisible ? math.max(_dockBand, 110.0) : 78.0;
  void _measureDockBand() {
    final box = _composerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize || box.size.height < 1) return;
    final h = MediaQuery.sizeOf(context).height;
    // 12px of wallpaper between the pane's bottom edge and the composer.
    final band = (h - box.localToGlobal(Offset.zero).dy + 12).clamp(0.0, h * 0.5);
    if ((band - _dockBand).abs() > 1) setState(() => _dockBand = band);
  }
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
  // v9.1.7 (#122): the opened conversation takes the open wallpaper above
  // the ticker (it was 30 %, about one message under the header and tools);
  // the tray is Flexible in the column, so it never runs under the top edge.
  double get _trayHeight => (MediaQuery.sizeOf(context).height * 0.58).clamp(160.0, 600.0);

  /// Real elevation: a tight contact shadow grounds the plane, a wide ambient
  /// one lifts it off the wallpaper, and a faint white bounce says light is
  /// reaching the lower edge. VGlass.resting alone is a 12% wash with a 12%
  /// shadow, which over a bright wallpaper is the unlayered slab that was
  /// reported as bug 3.
  static final List<BoxShadow> _windowShadow = VElev.e12;

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
  // One attached scroll view per controller: reading .position with two
  // attached throws in build (the grey-slab root cause, 9.1.6e).
  bool _one(ScrollController c) => c.positions.length == 1;

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

  // Restored v8.6 (9f839b7): the rail is one row per model in the category,
  // answered or not, so every model can be seen and toggled.
  List<TickerItem> _tickerRows(ModelCategory c) {
    final rows = [
      for (final m in ModelRoster.forCategory(c))
        _tickerItems.firstWhere(
          (t) => t.modelDef.id == m.id,
          orElse: () => TickerItem(modelDef: m, relativeTime: '', summary: '', conversation: const []),
        ),
    ];
    // R41: isolated models are a second block, after the shared query, so one
    // hairline separates them. Roster order is kept inside each block.
    final shared = [for (final t in rows) if (!t.isIsolated) t];
    final isolated = [for (final t in rows) if (t.isIsolated) t];
    return [...shared, ...isolated];
  }

  /// Long-press on a ticker row: its context menu (tap outside closes it).
  void _rowMenu(ModelCategory c, TickerItem item) {
    HapticFeedback.mediumImpact();
    final id = item.modelDef.id;
    final on = _selByCat[c]!.contains(id);
    final hasAnswer = item.conversation.isNotEmpty;
    final last = item.conversation.lastWhere((m) => m.sender == 'model', orElse: () => TickerMessage(id: '', sender: 'model', text: '', timestamp: DateTime.now()));
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: const Color(0x47000000),
      transitionDuration: VMotion.base,
      pageBuilder: (ctx, _, __) {
        void close() => Navigator.of(ctx).pop();
        return Material(type: MaterialType.transparency, child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(item.modelDef.label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                const SizedBox(height: 12),
                GlassMenu(scale: 1.0, width: 240, rows: [
                  if (hasAnswer)
                    GlassMenuRow(icon: Icons.chat_bubble_outline_rounded, label: 'Open conversation', on: true, toggle: false, onTap: () {
                      close();
                      _onTogglePill(id);
                    }),
                  GlassMenuRow(icon: on ? Icons.toggle_on_rounded : Icons.toggle_off_outlined, label: on ? 'Turn off' : 'Turn on', on: on, onTap: () {
                    close();
                    _toggleSelect(c, id);
                  }),
                  if (last.text.isNotEmpty)
                    GlassMenuRow(icon: Icons.copy_rounded, label: 'Copy reply', on: true, toggle: false, onTap: () {
                      Clipboard.setData(ClipboardData(text: last.text));
                      close();
                    }),
                  if (hasAnswer)
                    GlassMenuRow(icon: Icons.delete_outline_rounded, label: 'Clear conversation', on: true, toggle: false, onTap: () {
                      close();
                      setState(() => _tickerItems.removeWhere((t) => t.modelDef.id == id));
                    }),
                ]),
              ]),
            ),
          ),
        ));
      },
    );
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
      onLongPress: () => _rowMenu(c, item),
      child: AnimatedOpacity(
        duration: VMotion.base,
        opacity: 1.0, // full-strength text; off-rows read by no glow, not by fading
        child: selected
            ? AmbientGlow(color: item.modelDef.providerColor, radius: 18, phase: (item.modelDef.id.hashCode % 100) / 100, child: card)
            // v9.1.6 (root cause of the grey slab): a ColorFiltered over a row
            // with its own BackdropFilter, inside the EdgeFade mask, flattens the
            // whole ticker into a grey block on web. Off rows just fade.
            : card,
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
          style: appFont(fontSize: 11, height: 1.3, fontWeight: FontWeight.w500, color: const Color(0x8AFFFFFF)),
        ),
      );
    }
    // No Scrollbar: a hard grey track on a glass surface reads as a debug
    // affordance and flattens the illusion. The EdgeFade plus the chevron
    // carry the affordance instead.
    // v9.1.6 (grey slab): no ShaderMask over rows that carry BackdropFilters;
    // on web the mask's layer flattens them to grey. Rows clip at the edge.
    return ClipRect(
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false, overscroll: false),
            child: ListView.separated(
            controller: sc,
            padding: const EdgeInsets.only(bottom: 4),
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final row = _tickerRow(c, rows[i], rows.length <= 1 ? 1.0 : 1.0 - i / (rows.length - 1));
              // Hairline where the shared block ends and the isolated block
              // starts (feat/ticker-isolation-and-budget). No label.
              final split = i > 0 && rows[i].isIsolated && !rows[i - 1].isIsolated;
              if (!split) return row;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.white.withValues(alpha: 0),
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 4),
                  row,
                ],
              );
            },
          ),
          ),
          if (rows.length > 3 && _one(sc) && sc.position.maxScrollExtent > 0)
            Positioned(
              right: 2,
              bottom: 2,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: sc,
                  builder: (_, __) {
                    final p = _one(sc) && sc.position.maxScrollExtent > 0
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
    // R41: a direct reply takes that model out of the shared query. The score
    // and the line count only the models still on it.
    final shared = [for (final t in _tickerItems) if (!t.isIsolated) t];
    final answers = [
      for (final t in shared)
        if (t.conversation.isNotEmpty && t.conversation.last.sender == 'model' && !_isErr(t.conversation.last.text))
          (t.modelDef.label, t.conversation.last.text),
    ];
    final total = shared.length;
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
    if (_one(_catPager) && _catPager.page != null && (_catPager.page!.round() != idx) && !_catPager.position.isScrollingNotifier.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_one(_catPager)) _catPager.animateToPage(idx, duration: VMotion.base, curve: Curves.easeOutCubic);
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

  /// GLM ticker (R08). A centred column, at most 40% of the screen, on its own
  /// layer under every pane. Nothing above it reserves a band for it.
  Widget _buildTickerWindow() {
    final rows = _tickerRows(_activeCategory);
    if (rows.isEmpty && _consensusSummary.trim().isEmpty) return const SizedBox.shrink();
    final order = _tickerOrder;
    final window = SizedBox(
      width: math.min(260, MediaQuery.sizeOf(context).width - 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: _tickerHeight),
        child: GlmTickerColumn(
          items: rows,
          openId: _expandedModelIds.isEmpty ? null : _expandedModelIds.first,
          onOpen: _onTogglePill,
          consensusTitle: _consensusRatio.trim().isEmpty ? 'Consensus' : _consensusRatio,
          consensusLine: _isConsensusGenerating ? 'Comparing answers' : (_consensusSummary.trim().isEmpty ? 'Where the models agree' : _consensusSummary),
          onConsensus: () => setState(() => _activeDrawer = 'consensus'),
          activeIds: _selectedModelIds.toSet(),
          onToggle: (id) => _toggleSelect(_activeCategory, id),
          categoryLabel: _activeCategory.label,
          onCategorySwipe: (dir) {
            final i = order.indexOf(_activeCategory);
            setState(() {
              _activeCategory = order[(i + dir + order.length) % order.length];
              _expandedModelIds.clear();
            });
          },
        ),
      ),
    );
    return IgnorePointer(ignoring: _isComposerSummoned, child: window);
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
        key: _composerKey,
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
    if (!error && !_qaAnswers) _summarise(id, text);
  }

  /// The ticker line is a real one-line summary from the Consensus Agent
  /// (MiniMax first), not the reply's first line. The first line stands in
  /// only until the summary lands, or if the agent cannot be reached.
  Future<void> _summarise(String id, String text) async {
    try {
      final s = await MediaGen.instance.consensus([
        {'role': 'system', 'content': 'Summarise the reply in ONE plain sentence of at most 14 words. No preamble, no quotes, no markdown.'},
        {'role': 'user', 'content': text.length > 6000 ? text.substring(0, 6000) : text},
      ]);
      final line = s.replaceAll(RegExp(r'[*#`>]'), '').trim().split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
      if (!mounted || line.isEmpty) return;
      setState(() {
        final i = _tickerItems.indexWhere((t) => t.modelDef.id == id);
        if (i == -1) return;
        final last = _tickerItems[i].conversation.isEmpty ? null : _tickerItems[i].conversation.last;
        if (last == null || last.text != text) return; // a newer reply already arrived
        _tickerItems[i] = _tickerItems[i].copyWith(summary: line);
      });
    } catch (_) {}
  }

  static String _clock(DateTime t) => '${(t.hour % 12 == 0 ? 12 : t.hour % 12)}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';

  /// QA builds only (COLLIDER_QA_UNLOCK + ?qa_answers=1): a test-only answer
  /// source, so threads and History can be checked without model calls.
  /// Compiled out of the live build.
  static bool get _qaAnswers => ThemePackStore.qaUnlockAll && Uri.base.queryParameters['qa_answers'] == '1';
  int _qaTurn = 0;
  Future<String> _qaReply(String id, String prompt) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return 'QA reply ${++_qaTurn} from ${ModelRoster.byId(id)?.label ?? id}: "$prompt"';
  }

  Future<void> _onSendDirect(String prompt, List<String> models) async {
    final now = DateTime.now();
    List<TickerMessage> hist(String id) => [
          for (final t in _tickerItems)
            if (t.modelDef.id == id) ...t.conversation,
        ];
    final before = {for (final id in models) id: hist(id)};
    setState(() {
      _busy = true;
      // v9.1.3: sending keeps the composer (and the keyboard) up.
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
        // Models not asked this turn keep their conversation (never wiped).
        for (final t in _tickerItems)
          if (!models.contains(t.modelDef.id)) t,
      ];
    });
    await Future.wait([
      for (final id in models)
        if (_qaAnswers) _qaReply(id, prompt).then((text) => _answer(id, text, false)) else
        MediaGen.instance.chat(id, [
          // No shared system prompt. Each model answers with its own house
          // behaviour; a single persona here flattened them into one voice.
          for (final m in before[id]!) if (!_isErr(m.text)) {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text},
          {'role': 'user', 'content': prompt},
        ]).then((text) => _answer(id, text, false), onError: (e) => _answer(id, e is MediaGenError ? e.reason : friendlyErrorMessage(e), true)),
    ]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // The full conversation is saved to History (unless Incognito / off).
      if (_autosave && !_incognito) {
        final done = DateTime.now();
        final sid = 'local_${now.microsecondsSinceEpoch}';
        _globalHistorySessions = [
          ConversationHistorySession(id: sid, title: prompt, relativeTime: 'just now', timestamp: done, summary: prompt, modelIds: models,
              messages: [for (final t in _tickerItems) if (models.contains(t.modelDef.id)) ...t.conversation]),
          ..._globalHistorySessions,
        ];
        for (final t in _tickerItems) {
          if (!models.contains(t.modelDef.id)) continue;
          _localHistorySessions[t.modelDef.id] = [
            ConversationHistorySession(id: '${sid}_${t.modelDef.id}', title: prompt, targetModelId: t.modelDef.id, relativeTime: 'just now', timestamp: done, summary: t.summary, modelIds: [t.modelDef.id], messages: t.conversation),
            ...?_localHistorySessions[t.modelDef.id],
          ];
        }
      }
    });
    if (!_qaAnswers) await _directConsensus(prompt);
    if (_qaAnswers && mounted) setState(() => _isConsensusGenerating = false);
  }

  Future<void> _onSendPrompt(String prompt, [List<String> files = const []]) async {
    // v9.1.7 (#127): the composer closes after every send (direct, media,
    // QA and backend paths alike), not only on a tap on the wallpaper.
    if (_isComposerSummoned && mounted) setState(() => _isComposerSummoned = false);
    FocusManager.instance.primaryFocus?.unfocus();
    if (_activeCategory.isMedia) return _onSendMedia(prompt);
    final models = _selectedModelIds.where((id) {
      final d = ModelRoster.byId(id);
      return d != null && !d.isMedia;
    }).toList();
    if (models.isEmpty) return;
    if (!ColliderApi.instance.online || _qaAnswers) {
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
      } else if (targetDef != null) {
        // v9.1.6: the restored conversation needs a row to open into; an
        // empty ticker used to leave an "open" id with nothing to show.
        _tickerItems = [
          ..._tickerItems,
          TickerItem(modelDef: targetDef, relativeTime: session.relativeTime, summary: session.summary, conversation: session.messages),
        ];
      }

      _expandedModelIds.clear();
      _expandedModelIds.add(targetId);
    });
  }

  bool _browserOpen = false;
  final _browserKey = GlobalKey();
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
      ActiveWorkSurface.market => _marketCategory,
      ActiveWorkSurface.themes => _activeDrawer == 'premium' ? 'premium' : (_activeDrawer == 'music' ? (_musicCollection == 'all' ? 'music' : 'music_$_musicCollection') : 'gallery'),
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
          musicOpen: _activeDrawer == 'music',
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
                {
                  setState(() {
                    _isMobileSideNavOpen = false;
                    _marketCategory = key;
                  });
                }
              case ActiveWorkSurface.themes:
                setState(() {
                  _isMobileSideNavOpen = false;
                  if (key.startsWith('music')) {
                    _musicCollection = key == 'music' ? 'all' : key.substring(6);
                    _activeDrawer = 'music';
                  } else {
                    _themeSection = key;
                    _activeDrawer = key == 'gallery' ? 'themes' : key;
                  }
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

  // v9.1.4 (playtest #1): browsing the store or gallery never changes the
  // wallpaper. Entering saves it; leaving without Set puts it back (Set
  // updates the saved theme, so restoring is then a no-op).
  String? _prevDrawer;
  static const _previewDrawers = {'premium', 'themes'};
  void _guardPreview() {
    final was = _previewDrawers.contains(_prevDrawer);
    final now = _previewDrawers.contains(_activeDrawer);
    if (!was && now) _savedThemeBeforePreview = _currentTheme;
    if (was && !now && _currentTheme.id != _savedThemeBeforePreview.id) _currentTheme = _savedThemeBeforePreview;
    _prevDrawer = _activeDrawer;
  }

  bool get _otherSurfaceFocused => _settingsOpen || _browserOpen || (_activeDrawer != null) || _zoomedMessage != null || _localHistoryModel != null;
  /// One blur for the ticker whenever something else has focus.
  static const double _tickerBlur = 3;
  /// The blur stays on the ticker rows only. Wrapping the whole column
  /// (including the spacer above the rows) builds a full-screen layer, and
  /// on web a pane's backdrop filter samples that layer. The spacer is
  /// empty, so the sample is black and the glass paints as a solid slab
  /// instead of the wallpaper.
  Widget _tickerGate(Widget child) {
    return IgnorePointer(ignoring: _otherSurfaceFocused, child: child);
  }

  @override
  String _lastSurfaceSig = '';
  Offset? _swipeStart;
  DateTime _swipeT = DateTime.now();

  Widget build(BuildContext context) {
    if (_activeDrawer != 'premium') { _premiumCovered = false; _premiumCoverTimer?.cancel(); _premiumCoverTimer = null; }
    final surfaceSig = '$_activeDrawer|${_expandedModelIds.join(',')}|$_settingsOpen|$_browserOpen|$_zoomedMessage|$_localHistoryModel';
    if (surfaceSig != _lastSurfaceSig) { _lastSurfaceSig = surfaceSig; }
    _guardPreview();
    // The composer is wider than a phone pane. Measure it after layout and
    // keep the pane's bottom edge above it, or the + and send buttons sit on
    // the pane's corners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureDockBand();
    });
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
      bindings: const {},
      child: Focus(autofocus: true, child: Scaffold(
      // v9.1.4: swipe down dismisses the top sheet (mobile convention);
      // scrolling lists inside still win their own drags.
      // v9.1.6d (#37, proved with real pointer drags): a GestureDetector here
      // lost the gesture arena to every inner drag/tap recogniser, so swipe
      // down closed nothing. A raw Listener sees every pointer regardless of
      // the arena: a clear downward swipe closes the top surface, everywhere.
      body: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) { _swipeStart = e.position; _swipeT = DateTime.now(); },
      onPointerUp: (e) {
        final st = _swipeStart; _swipeStart = null;
        if (st == null || !_anythingOpen) return;
        final d = e.position - st;
        if (d.dy > 120 && d.dx.abs() < d.dy * 0.6) _escape();
        else if (st.dx < 28 && d.dx > 70 && d.dy.abs() < d.dx * 0.7) _escape(); // edge swipe back
        // Tap outside the browser window: decided on the raw pointer, because
        // the page platform view swallows the gesture arena.
        if (_browserOpen && d.distance < 8) {
          final box = InAppBrowserSheet.paneKey.currentContext?.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize && !(box.localToGlobal(Offset.zero) & box.size).contains(e.position)) _closeBrowser();
        } // distance + direction only: slow test rigs and slow swipes both count
      },
      child: CShell(bottomReserve: _paneReserve, child: Stack(
        fit: StackFit.expand,
        children: [
          // ================= PLANE 0: BACKGROUND WALLPAPER =================
          // Not built under the Premium Theme Market: the market paints its own
          // opaque #000 -> #111 root and its own ambient loop over the whole
          // viewport, so Plane 0 was invisible there while still decoding a
          // full-bleed still on every swipe during idle playback.
          // v9.1.7 (#36): the wallpaper stays until Premium has fully
          // materialized over it; dropping it the moment Premium opened was a
          // hard cut to black before the market faded in.
          if (!(_activeDrawer == 'premium' && _premiumCovers())) ...[
          Positioned.fill(
            child: ThemeLivingBackdrop(
              key: ValueKey('live-${_plane0Theme.id}-${_plane0Theme.videoPath ?? _plane0Theme.assetPath}-live'),
              theme: _plane0Theme,
              // Asset-swap: live loop + Builder BackgroundVideo filter when Premium Market
              // (supersedes prior H6 sharp-tint / preferVideo:false)
              // The premium market renders its own ambient loop of the focused theme;
              // Plane 0 stays on the poster there so only one stream is open.
              // The Theme Gallery paints its own room and preview (row 6).
              preferVideo: _activeDrawer != 'premium' && _activeDrawer != 'themes',
              builderAmbient: false, // never built under a settled Premium
            ),
          ),
          ],
          // v9.1.7 (#18): Discover is black edge to edge, the dock band included;
          // the docked ticker reads over black like it does under Premium.
          // v9.1.7 (#126): no full-screen black behind Discover any more; the
          // black is the centred pane itself.

          // Base ambient dim. Overlays and work surfaces bring their own VScrim
          // (kit overlay 0.35 + medium blur) so the wallpaper stays visible;
          // the theme gallery keeps a light tint.
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'themes', builder: (_) => GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(_closeAllPanes), child: const SizedBox.expand()))), // David: Gallery never dims or blurs the wallpaper
          // v9.1.3 depth rule: a work surface over the main view blurs (takes
          // away the background's capability) and dims (cinematic focus) what
          // is behind it. Nothing sits flat over the main view.
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            // A Materialize Opacity here is invisible, but on web it is the layer
            // the pane's backdrop filter samples, so the glass paints as a flat
            // black slab instead of the wallpaper. The catch is a bare target.
            if (_browserOpen || const {'files', 'smartgen', 'history', 'music', 'apps', 'consensus', 'market'}.contains(_activeDrawer))
              Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() { _browserOpen = false; _closeAllPanes(); }), child: const SizedBox.expand())),

          // Depth of field for the summoned composer: the world falls out of
          // focus behind the writing surface. The filter is not mounted while
          // the composer is at rest. A backdrop filter inside a transparent
          // opacity still paints on web, and every pane above it then samples
          // that empty layer instead of the wallpaper.
          if (_isComposerSummoned)
            Positioned.fill(
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
          // v9.1.4 (playtest #6): a tap outside the opened answer closes it.
          // v9.1.7 (#16): a tap on the wallpaper also tucks a summoned composer,
          // so after sending, the rows (quiet while writing) can be opened.
          if ((_expandedModelIds.isNotEmpty || _isComposerSummoned) && _activeDrawer == null && !_settingsOpen && !_browserOpen)
            // v9.1.6c ROOT CAUSE of the grey slab: a blurring scrim painted beneath
            // the ticker turns the rows into a flat grey block on web (bisected
            // with ?dbg: removing only this scrim cleared it). Tap-outside layers
            // under the ticker only catch taps and dim; they never blur.
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() { _expandedModelIds.clear(); _isComposerSummoned = false; FocusManager.instance.primaryFocus?.unfocus(); }), child: const SizedBox.expand())),
          // The ticker is the core experience: ALWAYS present. When another
          // surface has focus it stays, blurred and non-interactive.
          // v9.1.6g REAL root cause of the grey slab (reproduced every time
          // with ?restore=0&noguard=1, traced with element ancestor chains):
          // the conditional tap-outside Positioned just above is inserted or
          // removed when a session opens or closes. This Stack is unkeyed, so
          // Flutter matched that new Positioned to the ticker's old element and
          // rebuilt the whole ticker as a fresh element below it. The new
          // ListView/PageView attached to the shared ScrollControllers before
          // the old (deactivated) ones detached: two positions, List.single
          // threw in build, release painted the grey ErrorWidget. The key
          // keeps the ticker's element, so it is never rebuilt or duplicated.
          Positioned.fill(
            key: const ValueKey('ticker-layer'),
            bottom: 12 + 56 + 4, // docked on the bottom bar: one layer
            child: _tickerGate(SafeArea(
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
                    if (_mediaShowing && _composerVisible)
                      _buildComposer()
                    else if (!_mediaShowing) ...[
                      // Bug 5: the opened answer is a tray anchored over the
                      // ticker, not a permanent block in the middle of it.
                      // v9.1.6: the approved layout (app-11): the rail sits
                      // centred in the lower half, directly over the composer,
                      // with open wallpaper above it.
                      const Spacer(),
                      if (_buildTray() case final tray?) ...[
                        Flexible(flex: 40, child: tray),
                        const SizedBox(height: _windowGap),
                      ],
                      // Bug 10: this one dims when the composer is summoned.
                      ValueListenableBuilder<bool>(
                        key: const ValueKey('ticker-window'),
                        valueListenable: KeyboardDof.active,
                        // v9.1.6 (root cause of the grey slab): an ImageFiltered over rows that
                        // carry their own BackdropFilter renders as a flat grey block on web,
                        // and the field-focus signal can stay on after History's search
                        // closes. The wallpaper DOF plane already blurs; the rail just quiets.
                        // v9.1.7: the same blur the ticker gets under every pane (_tickerGate,
                        // sigma 3), so typing and panes push the rail back the same way.
                        builder: (_, on, child) => ImageFiltered(
                          enabled: _otherSurfaceFocused || (on && _isComposerSummoned),
                          imageFilter: ui.ImageFilter.blur(sigmaX: _tickerBlur, sigmaY: _tickerBlur),
                          child: AnimatedOpacity(duration: VMotion.base, opacity: on && _isComposerSummoned ? 0.6 : 1, child: child!),
                        ),
                        child: _buildTickerWindow(),
                      ),
                      const SizedBox(height: _windowGap),
                      // Bug 7: the composer has its own slot now, so it cannot
                      // land on the category chips.
                      if (_composerVisible) _buildComposer(),
                    ],
                    const SizedBox(height: _windowGap),
                  ],
                ),
              ),
            )),
          ),




          // v8.3.1: row 13 media gen window ported from v8.4 (Figma 2013:71).
          if (!_browserOpen && !(isMobile && _isMobileSideNavOpen) && !const {'premium', 'themes', 'apps', 'smartgen', 'market', 'files', 'consensus', 'music'}.contains(_activeDrawer) && _mediaStageOn)
            Positioned.fill(bottom: 210, child: _buildMediaStage()),

          // ================= PLANE 2: APPS POPUP PANE =================
          // Middle neutral area, no visible canvas, blurred background, clickaway + close icon
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'apps', builder: (_) => AppsPopupPane(
                onClose: () => setState(() => _activeDrawer = null),
                onOpenSmartGen: () => _requestSwitchSurface('smartgen'),
                onOpenDiscoverMarket: () => _requestSwitchSurface('market'),
                onOpenThemeGallery: () => _requestSwitchSurface('themes'),
                onOpenPremiumMarketplace: () => _requestSwitchSurface('premium'),
                onOpenFiles: () => _requestSwitchSurface('files'),
                onOpenMusicPlayer: () => _requestSwitchSurface('music'),
                onOpenBrowser: () => _openBrowserForTab('user_default'),
                onOpenSettings: () => setState(() { _activeDrawer = null; _settingsOpen = true; }),
              ))),

          // ================= PLANE 3: LOCAL MODEL HISTORY PANE =================
          // Centered popup pane, searches body & title, relative timestamps
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _localHistoryModel != null, builder: (_) => LocalHistoryPane(
                modelDef: _localHistoryModel!,
                // Real history only (D30): no invented fallback session.
                sessions: _localHistorySessions[_localHistoryModel!.id] ?? const [],
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _localHistoryModel = null),
              ))),

          // ================= PLANE 4: MESSAGE ZOOM OVERLAY =================
          // Dimmed/blurred backdrop, no visible window, faded edges, bottom actions
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _zoomedMessage != null && _zoomedModelDef != null, builder: (_) => MessageZoomOverlay(
                message: _zoomedMessage!,
                modelName: _zoomedModelDef!.label,
                providerColor: _zoomedModelDef!.providerColor,
                onClose: () => setState(() => _zoomedMessage = null),
                onBranchIsolated: () {
                  _onSendInlineReply(_zoomedModelDef!.id, "Branched branch from zoomed message.");
                },
              ))),

          // ================= PLANE 5: DRAWERS & DURABLE WORK SURFACES =================
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'history', builder: (_) => HistoryDrawer(
                sessions: _globalHistorySessions,
                onSelectSession: (sess) => _loadAndExpandSession(sess),
                onClose: () => setState(() => _activeDrawer = null),
              ))),

          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'model_ladder', builder: (_) => ModelLadderDrawer(
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
              ))),

          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'themes', builder: (_) => WindowlessThemeScroller(
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
              ))),

          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'premium', builder: (_) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                child: PremiumThemeMarketView(
                // v9.1.4 (playtest #2): rebuild once the catalog arrives, so a
                // direct link shows real covers.
                key: ValueKey('market-${WallpaperCatalog.premiumThemes.length}'),
                currentTheme: _currentTheme,
                onApplyTheme: (theme) => setState(() {
                  _currentTheme = theme;
                  _savedThemeBeforePreview = theme;
                  _activeDrawer = null;
                }),
                onPreviewTheme: (theme) {
                  // Only the focused theme streams video; warm neighbour posters.
                  ThemeMediaPrefetch.precacheNeighbors(context, WallpaperCatalog.premiumThemes, theme);
                  // v9.1.4: a preview that lands while the store dissolves out
                  // must not overwrite the restored wallpaper.
                  if (_activeDrawer != 'premium') return;
                  setState(() {
                    _currentTheme = theme;
                  });
                },
                onClose: () => setState(() => _activeDrawer = null),
                onFree: () => setState(() => _activeDrawer = 'themes'),
              ),
              ))),

          // No songs in the catalog: no Music drawer (v8.3, D46).
          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'music' && MusicPlayer.library.isNotEmpty, builder: (_) => MusicCollectionDrawer(
                collection: _musicCollection,
                onClose: () => setState(() => _activeDrawer = null),
              ))),


          // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
            Positioned.fill(child: MaterializeSwitch(show: _activeDrawer == 'account' && !_settingsOpen, builder: (_) => AccountSheet(tier: ModelTier.free, onClose: () => setState(() => _activeDrawer = null)))),

          // Durable work surfaces sit over one shared scrim (kit overlay + medium blur).
          // v9.1.6: no second scrim here: the shared depth scrim above already
          // blurs and dims; a second pass blurred the ticker out of sight.

          if (_activeDrawer == 'smartgen')
            Positioned.fill(
              child: SmartGenScreen(
                section: _smartGenView,
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          if (_activeDrawer == 'market')
            Positioned.fill(
              // CPane: centred, reserves the docked ticker and composer itself.
              child: MarketScreen(
                feed: _marketCategory,
                onClose: () => _requestSwitchSurface(null),
                onUsePrompt: (p) => _onSendPrompt(p),
                onNotice: _notice,
              ),
            ),

          // v8.2 round 3 (D31): the Tiers screen (invented prices, dead
          // upgrade buttons) and the Skills screen (toggles wired to nothing)
          // were reachable only by deep link; both are deleted.

          if (_activeDrawer == 'files')
            Positioned.fill(
              child: FilesScreen(
                type: _filesCategory,
                onClose: () => _requestSwitchSurface(null),
              ),
            ),

          if (_activeDrawer == 'consensus')
            Positioned.fill(
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
            // v9.1.4 (playtest #14): dissolves out instead of a hard cut.
              Positioned.fill(child: MaterializeSwitch(show: _isMobileSideNavOpen && _railVisible, builder: (_) => VScrim(onTap: () => setState(() => _isMobileSideNavOpen = false)))),

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
            // Tap outside the window closes it (David: swipe and tap outside are the escapes).
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeBrowser)),
            Positioned.fill(
              child: Center(
                child: InAppBrowserSheet(
                  key: _browserKey,
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
              builder: (_) => SettingsDrawer(
                onClose: () => setState(() => _settingsOpen = false),
                incognito: _incognito,
                autosave: _autosave,
                onIncognito: (v) => setState(() => _incognito = v),
                onAutosave: (v) => setState(() => _autosave = v),
                onAccount: () => setState(() => _activeDrawer = 'account'),
              ),
            ),
          ),
          Positioned.fill(child: MaterializeSwitch(show: _settingsOpen && _activeDrawer == 'account', builder: (_) => AccountSheet(tier: ModelTier.free, onClose: () => setState(() => _activeDrawer = null)))),

          // Home bottom bar restored (Settings / Apps); only the redundant
          // chat button was removed. The composer docks directly above it.
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
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
                    if (_settingsOpen) setState(() => _settingsOpen = false);
                    if (_activeDrawer != null) {
                      _requestSwitchSurface(null);
                    } else {
                      _openHomeComposer();
                    }
                  },
                  onApps: () => _openPeer('apps'),
                  onSettings: () => _openPeer('settings'),
                  activeDrawer: _activeDrawer,
                )),
              ),
            ),
          ),

          // One rule everywhere: a swipe in from the left edge (back) or a
          // swipe down from the top of a panel closes the top-most view. A raw
          // Listener, so no rail or list can win the gesture first.
          // Playtest (Upload / video tile did nothing): a childless translucent
          // Listener here was the top Stack child whenever anything was open,
          // and a Stack stops hit-testing at the first child that is hit, so
          // it swallowed every tap meant for the pane under it. Removed; the
          // root Listener handles swipe-down and edge-swipe back.
        ],
      )),
      ),
    )));
  }

}

