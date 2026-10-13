import '../../../core/theme/edge_fade.dart';
import 'package:flutter/material.dart';
import '../../../core/vision/vision_kit.dart';
import '../models/browser_tab.dart';
import '../browser_urls.dart';
import '../web_frame.dart';

/// REQ-07 Durable In-App Browser (Apple VisionOS Apps Basic Design System
/// 1:71 "Safari"): the address bar floats as a capsule ornament above the
/// page window. One browser instance; tabs overview replaces the page.
///
/// R36: this is a window, not a sheet. It is laid out by the shell inside the
/// wallpaper, with air on all four sides, and it no longer opens as a dialog --
/// a dialog route put a scrim over the whole screen and a barrier over the nav
/// dock, so the wallpaper went dark and dock taps died (R12).
class InAppBrowserSheet extends StatefulWidget {
  final String initialTabId;
  final List<BrowserTab> tabs;
  final Function(BrowserTab updatedTab)? onTabUpdated;
  final Function(BrowserTab newTab)? onNewUserTab;

  /// The shell owns open/close, so the window asks rather than popping a route.
  final VoidCallback? onClose;

  const InAppBrowserSheet({
    super.key,
    required this.initialTabId,
    required this.tabs,
    this.onTabUpdated,
    this.onNewUserTab,
    this.onClose,
  });

  @override
  State<InAppBrowserSheet> createState() => _InAppBrowserSheetState();
}

/// Room above the window for the status strip, and below it for the permanent
/// nav dock (12 + 56 + 12) so the two never overlap.
const double _kTopInset = 52.0;
const double _kDockZone = 88.0;
const double _kOrnamentH = 42.0;
const double _kWindowBarH = 14.0;

class _InAppBrowserSheetState extends State<InAppBrowserSheet> {
  late String _activeTabId;
  bool _overview = false;
  final TextEditingController _addr = TextEditingController();
  final Map<String, List<String>> _back = {};
  int _reload = 0;
  String? _shownUrl;

  BrowserTab get _tab => widget.tabs.firstWhere((t) => t.id == _activeTabId, orElse: () => widget.tabs.first);

  @override
  void initState() {
    super.initState();
    _activeTabId = widget.initialTabId;
  }

  @override
  void didUpdateWidget(covariant InAppBrowserSheet old) {
    super.didUpdateWidget(old);
    // R34: one instance. Asking for another tab while open switches the tab of
    // the window already on screen instead of putting up a second browser.
    if (old.initialTabId != widget.initialTabId &&
        widget.tabs.any((t) => t.id == widget.initialTabId) &&
        widget.initialTabId != _activeTabId) {
      _activeTabId = widget.initialTabId;
    }
  }

  void _switchTab(String id) => setState(() {
        _activeTabId = id;
        _overview = false;
      });

  void _newTab() {
    final t = BrowserTab(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Tab',
      url: browserStartUrl(),
      isModelAssigned: false,
      isUserControlling: true,
    );
    widget.onNewUserTab?.call(t);
    _switchTab(t.id);
  }

  String _host(String url) => url.replaceFirst(RegExp(r'^https?://'), '');

  void _open(String url, String title) {
    final tab = _tab;
    (_back[tab.id] ??= []).add(tab.url);
    widget.onTabUpdated?.call(tab.copyWith(url: url, title: title));
    setState(() => _overview = false);
  }

  /// R34: home is Google, on open and on the home control alike.
  void _goHome() => _open(browserStartUrl(), 'Google');

  /// Address bar: a web address opens directly; anything else is searched.
  void _go(String input) {
    final q = input.trim();
    if (q.isEmpty) return;
    final isUrl = !q.contains(' ') && (q.contains('.') || q.startsWith('http'));
    final url = isUrl ? (q.startsWith('http') ? q : 'https://$q') : browserSearchUrl(q);
    _open(url, isUrl ? _host(url) : q);
  }

  void _goBack() {
    final stack = _back[_tab.id];
    if (stack == null || stack.isEmpty) return;
    final prev = stack.removeLast();
    widget.onTabUpdated?.call(_tab.copyWith(url: prev, title: _host(prev)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tab;
    if (_shownUrl != tab.url) {
      _shownUrl = tab.url;
      _addr.text = _host(tab.url);
    }
    final media = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final w = VOverlay.toolWidth(context);
    const chrome = _kOrnamentH + VSpace.sm * 2 + _kWindowBarH;
    final room = media.height - (_kTopInset + safe.top) - (_kDockZone + safe.bottom) - chrome;
    final h = room.clamp(180.0, VOverlay.toolMaxHeight(context));

    // One width for the whole window: the ornament above the page window has to
    // line up with it, and both stay inside the phone's edges.
    return SizedBox(
      width: w,
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Address bar ornament
        VOrnament(
          padding: const EdgeInsets.all(VSpace.xxs + 1),
          child: Row(
            children: [
              VCircleButton(icon: Icons.close_rounded, size: 32, tooltip: 'Close', onTap: widget.onClose),
              const SizedBox(width: VSpace.xs - 2),
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: VSpace.xs),
                  decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
                  child: Row(
                    children: [
                      VPress(
                        onTap: _goHome,
                        tooltip: 'Home',
                        child: const Icon(Icons.home_outlined, size: 14, color: VColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _addr,
                          textAlign: TextAlign.center,
                          cursorColor: VColors.textPrimary,
                          style: VType.callout(),
                          textInputAction: TextInputAction.go,
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          onSubmitted: _go,
                        ),
                      ),
                      VPress(
                        onTap: () => setState(() => _reload++),
                        tooltip: 'Reload',
                        child: const Icon(Icons.refresh_rounded, size: 15, color: VColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: VSpace.xs - 2),
              VCircleButton(icon: Icons.add_rounded, size: 32, tooltip: 'New Tab', onTap: _newTab),
              const SizedBox(width: VSpace.xxs),
              VCircleButton(
                icon: Icons.filter_none_rounded,
                size: 32,
                tooltip: 'Open Windows & Tabs',
                selected: _overview,
                onTap: () => setState(() => _overview = !_overview),
              ),
            ],
          ),
        ),
        const SizedBox(height: VSpace.sm),
        SizedBox(
          height: h,
          child: VGlass(
            material: VMaterial.work,
            radius: VRadius.xl,
            child: _overview ? _tabsOverview() : _page(tab),
          ),
        ),
        const SizedBox(height: VSpace.sm),
        const VWindowBar(),
      ],
    ),
    );
  }

  Widget _page(BrowserTab tab) {
    return ClipRRect(
      key: ValueKey('page-${tab.url}-$_reload'),
      borderRadius: BorderRadius.circular(VRadius.xl),
      child: WebFrame(key: ValueKey('${tab.url}#$_reload'), url: _reload == 0 ? tab.url : '${tab.url}${tab.url.contains('?') ? '&' : '?'}_r=$_reload'),
    );
  }

  Widget _tabsOverview() {
    return LayoutBuilder(
      key: const ValueKey('tabs'),
      builder: (context, c) {
        final cols = c.maxWidth < 420 ? 2 : 3;
        return Padding(
          padding: const EdgeInsets.all(VSpace.sm),
          child: EdgeFade(fadeHeight: 24, child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.9),
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
          )),
        );
      },
    );
  }
}