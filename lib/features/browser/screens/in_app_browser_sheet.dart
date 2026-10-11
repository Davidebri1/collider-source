import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/figma/figma_stage.dart';
import '../../../core/kit/collider_kit.dart';
import '../../../core/vision/vision_kit.dart';
import '../../nav/contextual_side_nav.dart';
import '../../nav/side_nav_rail.dart';
import '../models/browser_tab.dart';
import '../browser_urls.dart';
import '../web_frame.dart';

/// REQ-07 Durable In-App Browser (Apple VisionOS Apps Basic Design System
/// 1:71 "Safari"): the address bar floats as a capsule ornament above the
/// page window. One browser instance; tabs overview replaces the page.
class InAppBrowserSheet extends StatefulWidget {
  final String initialTabId;
  final List<BrowserTab> tabs;
  final Function(BrowserTab updatedTab)? onTabUpdated;
  final Function(BrowserTab newTab)? onNewUserTab;

  const InAppBrowserSheet({
    super.key,
    required this.initialTabId,
    required this.tabs,
    this.onTabUpdated,
    this.onNewUserTab,
  });

  @override
  State<InAppBrowserSheet> createState() => _InAppBrowserSheetState();
}

class _InAppBrowserSheetState extends State<InAppBrowserSheet> {
  late String _activeTabId;
  bool _overview = false;
  final TextEditingController _addr = TextEditingController();
  final FocusNode _addrFocus = FocusNode();
  final Map<String, List<String>> _back = {};
  int _reload = 0;
  String? _shownUrl;

  // Rail controls (user directive, 2026-10-10): item 1 opens the address bar;
  // Find on Page is its own button. Find advances per request on the native
  // build; the web preview frames cross-origin pages, so find says so quietly
  // instead of pretending.
  final ValueNotifier<String?> _findRequests = ValueNotifier<String?>(null);
  final ValueNotifier<int> _clearRequests = ValueNotifier<int>(0);
  final TextEditingController _findCtrl = TextEditingController();
  bool _findOpen = false;
  BrowserEngine _engine = defaultBrowserEngine();
  bool _engineMenuOpen = false;

  BrowserTab get _tab => widget.tabs.firstWhere((t) => t.id == _activeTabId, orElse: () => widget.tabs.first);

  @override
  void initState() {
    super.initState();
    _activeTabId = widget.initialTabId;
  }

  @override
  void dispose() {
    _addr.dispose();
    _addrFocus.dispose();
    _findCtrl.dispose();
    _findRequests.dispose();
    _clearRequests.dispose();
    super.dispose();
  }

  void _switchTab(String id) => setState(() {
        _activeTabId = id;
        _overview = false;
      });

  void _newTab() {
    final t = BrowserTab(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Tab',
      url: browserStartUrl(_engine),
      isModelAssigned: false,
      isUserControlling: true,
    );
    widget.onNewUserTab?.call(t);
    _switchTab(t.id);
  }

  String _host(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

  // ── the browser's own side rail (user directive, 2026-10-10) ────────────
  // The sheet is its own route, so the shell's rail does not reach it; the
  // browser carries the same contract: item 1 is search, Find on Page is its
  // own button.
  void _onRailSelect(String key) {
    switch (key) {
      case 'search':
        setState(() => _overview = false);
        _addrFocus.requestFocus();
      case 'find':
        setState(() => _findOpen = !_findOpen);
        if (_findOpen && kIsWeb) _say('Find on page needs the app build.');
      case 'tabs':
        setState(() => _overview = !_overview);
      case 'engine':
        setState(() => _engineMenuOpen = !_engineMenuOpen);
      case 'clear':
        if (kIsWeb) {
          _say('Cache clearing needs the app build.');
        } else {
          _clearRequests.value++;
          _say('Cache cleared.');
        }
    }
  }

  void _findNext() {
    final q = _findCtrl.text.trim();
    if (q.isEmpty) return;
    if (kIsWeb) {
      _say('Find on page needs the app build.');
      return;
    }
    // The marker forces a fresh notification for repeated queries.
    _findRequests.value = '$q\u200b${DateTime.now().microsecondsSinceEpoch}';
  }

  String? _notice;
  void _say(String s) {
    setState(() => _notice = s);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _notice == s) setState(() => _notice = null);
    });
  }

  /// Address bar: a web address opens directly; anything else is searched.
  void _go(String input) {
    final q = input.trim();
    if (q.isEmpty) return;
    final isUrl = !q.contains(' ') && (q.contains('.') || q.startsWith('http'));
    final url = isUrl ? (q.startsWith('http') ? q : 'https://$q') : browserSearchUrl(q, _engine);
    final tab = _tab;
    (_back[tab.id] ??= []).add(tab.url);
    widget.onTabUpdated?.call(tab.copyWith(url: url, title: isUrl ? _host(url) : q));
    setState(() => _overview = false);
  }

  // ── Figma TRee 1:71 "Safari VisionOS" (frame 3840 x 2160) ───────────────
  // Group at (1280, 593), 1280 wide, column gap 40:
  //   toolbar 1280 x 80, radius 44, px 10, gap 48, glass rgba(128,128,128,.3)
  //   blur 75, 1 px white .3 border; groups of three 60 px circles (white .3,
  //   gap 20); address field h 64, px 16, black .3, radius 32: aA 25 | lock 20
  //   + domain SF Medium 24 | reload 25.
  //   page 1280 x 853 at y 713, radius 40, 1 px white .3 border.
  // Added (not in 1:71): the visionOS window bar under the page (dot closes),
  // because the frame has no close control and the browser must close.
  static const _frame = Size(3840, 2160);
  static const double _crop = 1280;
  static const Offset _center = Offset(1920, 1109.5);
  final Map<String, List<String>> _fwd = {};
  double _zoom = 1;

  void _goForward() {
    final stack = _fwd[_tab.id];
    if (stack == null || stack.isEmpty) return;
    final next = stack.removeLast();
    (_back[_tab.id] ??= []).add(_tab.url);
    widget.onTabUpdated?.call(_tab.copyWith(url: next, title: _host(next)));
    setState(() {});
  }

  void _duplicate() {
    final t = BrowserTab(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: _tab.title,
      url: _tab.url,
      isModelAssigned: false,
      isUserControlling: true,
    );
    widget.onNewUserTab?.call(t);
    _switchTab(t.id);
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _tab.url));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }
  bool _copied = false;

  Widget _circle(IconData icon, String tip, VoidCallback? onTap, {bool on = false, double turns = 0}) => Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: on ? const Color(0x80FFFFFF) : const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(32)),
            alignment: Alignment.center,
            child: RotatedBox(quarterTurns: (turns * 4).round(), child: Icon(icon, size: 28, color: onTap == null ? Colors.white38 : Colors.white)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    if (_shownUrl != tab.url) {
      _shownUrl = tab.url;
      _addr.text = _host(tab.url).split('/').first;
    }
    final canBack = (_back[tab.id] ?? const []).isNotEmpty;
    final canFwd = (_fwd[tab.id] ?? const []).isNotEmpty;
    final k = MediaQuery.sizeOf(context).width / _crop;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(children: [
            // The browser's side rail — the same contract as every surface:
            // item 1 is search, Find on Page is its own button (user
            // directive, 2026-10-10). The browser is its own route, so the
            // rail lives here, at the screen's left edge, vertically centred.
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: VOrnamentRail(
                  size: Kit.controlCircle,
                  items: [
                    for (final e in sideRailEntries(ActiveWorkSurface.browser)) VRailItem(e.icon, e.label),
                  ],
                  active: sideRailEntries(ActiveWorkSurface.browser).indexWhere(
                    (e) => e.key == (_overview ? 'tabs' : (_engineMenuOpen ? 'engine' : null)),
                  ),
                  onSelect: (i) => _onRailSelect(sideRailEntries(ActiveWorkSurface.browser)[i].key),
                ),
              ),
            ),
            // Engine picker: the rail's Search Engine control.
            if (_engineMenuOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _engineMenuOpen = false),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 68),
                      child: GlassMenu(
                        rows: [
                          for (final e in BrowserEngine.values)
                            GlassMenuRow(
                              icon: switch (e) {
                                BrowserEngine.google => Icons.language_rounded,
                                BrowserEngine.duckduckgo => Icons.travel_explore_rounded,
                                BrowserEngine.wikipedia => Icons.menu_book_rounded,
                              },
                              label: switch (e) {
                                BrowserEngine.google => 'Google',
                                BrowserEngine.duckduckgo => 'DuckDuckGo',
                                BrowserEngine.wikipedia => 'Wikipedia',
                              },
                              on: e == _engine,
                              onTap: () {
                                setState(() {
                                  _engine = e;
                                  _engineMenuOpen = false;
                                });
                                final tab = _tab;
                                (_back[tab.id] ??= []).add(tab.url);
                                widget.onTabUpdated?.call(tab.copyWith(url: browserStartUrl(_engine), title: 'Search'));
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            FigmaStage(frame: _frame, cropWidth: _crop, center: _center, children: [
            // Toolbar ornament.
            Positioned(
              left: 1280,
              top: 593,
              width: 1280,
              height: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: (75 / 2 * k).clamp(0.0, 40.0), sigmaY: (75 / 2 * k).clamp(0.0, 40.0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x4D808080),
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: const Color(0x4DFFFFFF), width: 1),
                    ),
                    child: Row(children: [
                      _circle(Icons.view_sidebar_outlined, 'Open Windows & Tabs', () => setState(() => _overview = !_overview), on: _overview),
                      const SizedBox(width: 20),
                      _circle(Icons.chevron_left_rounded, 'Back', canBack ? () {
                        final stack = _back[tab.id]!;
                        (_fwd[tab.id] ??= []).add(tab.url);
                        final prev = stack.removeLast();
                        widget.onTabUpdated?.call(tab.copyWith(url: prev, title: _host(prev)));
                        setState(() {});
                      } : null),
                      const SizedBox(width: 20),
                      _circle(Icons.chevron_right_rounded, 'Forward', canFwd ? _goForward : null),
                      const SizedBox(width: 48),
                      Expanded(
                        child: Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0x4D000000),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [BoxShadow(color: Color(0x80FFFFFF), offset: Offset(0, 1), blurRadius: 1)],
                          ),
                          child: Row(children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _zoom = _zoom >= 2 ? 1 : _zoom + 0.5),
                              child: SizedBox(
                                width: 32,
                                height: 64,
                                child: Center(child: Text('Aa', style: GoogleFonts.inter(fontSize: 25, color: Colors.white, decoration: TextDecoration.none))),
                              ),
                            ),
                            Expanded(
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.lock_rounded, size: 20, color: Color(0x99FFFFFF)),
                                const SizedBox(width: 8),
                                Flexible(
                                  // Width of the domain text + caret room (IntrinsicWidth
                                  // clipped the last letter).
                                  child: SizedBox(
                                    width: (TextPainter(
                                          text: TextSpan(text: _addr.text, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500)),
                                          textDirection: TextDirection.ltr,
                                        )..layout())
                                            .width +
                                        12,
                                    child: TextField(
                                      controller: _addr,
                                      focusNode: _addrFocus,
                                      textAlign: TextAlign.center,
                                      cursorColor: Colors.white,
                                      style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
                                      textInputAction: TextInputAction.go,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                      onSubmitted: (v) {
                                        _fwd[tab.id]?.clear();
                                        _go(v);
                                      },
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _reload++),
                              child: const SizedBox(width: 32, height: 64, child: Icon(Icons.refresh_rounded, size: 28, color: Colors.white)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 48),
                      _circle(_copied ? Icons.check_rounded : Icons.ios_share_rounded, _copied ? 'Link copied' : 'Copy link', _share),
                      const SizedBox(width: 20),
                      _circle(Icons.add_rounded, 'New Tab', _newTab),
                      const SizedBox(width: 20),
                      _circle(Icons.filter_none_rounded, 'Duplicate Tab', _duplicate, turns: 0.25),
                    ]),
                  ),
                ),
              ),
            ),
            // Page.
            Positioned(
              left: 1280,
              top: 713,
              width: 1280,
              height: 853,
              child: Container(
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0x4DFFFFFF), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: ColoredBox(
                    color: const Color(0x4D808080),
                    child: AnimatedSwitcher(duration: VMotion.base, child: _overview ? _tabsOverview() : _page(tab)),
                  ),
                ),
              ),
            ),
            // Window bar (added; dot closes, bar swipes down to close).
            Positioned(
              left: 1768,
              top: 1602,
              width: 304,
              height: 24,
              child: Row(children: [
                Semantics(
                  button: true,
                  label: 'Close',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99FFFFFF))),
                  ),
                ),
                const SizedBox(width: 40),
                GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) > 200) Navigator.of(context).pop();
                  },
                  child: Container(width: 240, height: 20, decoration: BoxDecoration(color: const Color(0x99FFFFFF), borderRadius: BorderRadius.circular(10))),
                ),
              ]),
            ),
            ]),
            // Find-on-page bar (rail ▸ Find on Page): floats over the page
            // window while open. Enter or the arrow repeats window.find, which
            // advances the selection natively.
            if (_findOpen)
              Positioned(
                left: 0,
                right: 0,
                top: 96,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 320,
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0x66808080),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                        ),
                        child: Row(children: [
                          const Icon(Icons.find_in_page_rounded, size: 20, color: Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _findCtrl,
                              autofocus: true,
                              cursorColor: Colors.white,
                              style: GoogleFonts.inter(fontSize: 15, color: Colors.white, decoration: TextDecoration.none),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _findNext(),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Find on page',
                                hintStyle: TextStyle(color: Color(0x59FFFFFF), fontSize: 15),
                              ),
                            ),
                          ),
                          _smallCircle(Icons.arrow_downward_rounded, 'Next match', _findNext),
                          const SizedBox(width: 8),
                          _smallCircle(Icons.close_rounded, 'Close find bar', () => setState(() => _findOpen = false)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            // The quiet line (D59 idiom): what a control did, or why it cannot.
            if (_notice != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 36,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0x66808080), borderRadius: BorderRadius.circular(18)),
                        child: Text(
                          _notice!,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white, decoration: TextDecoration.none),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _smallCircle(IconData icon, String tip, VoidCallback onTap) => Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      );

  Widget _page(BrowserTab tab) {
    return KeyedSubtree(
      key: ValueKey('page-${tab.url}-$_reload-$_zoom'),
      child: WebFrame(
        key: ValueKey('${tab.url}#$_reload#$_zoom'),
        url: _reload == 0 ? tab.url : '${tab.url}${tab.url.contains('?') ? '&' : '?'}_r=$_reload',
        zoom: _zoom,
        findRequests: _findRequests,
        clearRequests: _clearRequests,
      ),
    );
  }

  Widget _tabsOverview() {
    return LayoutBuilder(
      key: const ValueKey('tabs'),
      builder: (context, c) {
        const cols = 4;
        return Padding(
          padding: const EdgeInsets.all(40),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.9),
            itemCount: widget.tabs.length,
            itemBuilder: (_, i) {
              final t = widget.tabs[i];
              return VTile(
                selected: t.id == _activeTabId,
                onTap: () => _switchTab(t.id),
                aspect: 4 / 3,
                title: t.title,
                subtitle: t.isModelAssigned ? (t.modelName ?? 'Model') : _host(t.url),
                media: Container(
                  color: VColors.fillCell,
                  child: Icon(t.isModelAssigned ? Icons.terminal_rounded : Icons.person_outline_rounded, size: 26, color: VColors.textSecondary),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
