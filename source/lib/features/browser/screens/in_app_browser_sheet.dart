import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/vision/vision_kit.dart';
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
  final Map<String, List<String>> _back = {};
  int _reload = 0;
  String? _shownUrl;

  BrowserTab get _tab => widget.tabs.firstWhere((t) => t.id == _activeTabId, orElse: () => widget.tabs.first);

  @override
  void initState() {
    super.initState();
    _activeTabId = widget.initialTabId;
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

  /// Address bar: a web address opens directly; anything else is searched.
  void _go(String input) {
    final q = input.trim();
    if (q.isEmpty) return;
    final isUrl = !q.contains(' ') && (q.contains('.') || q.startsWith('http'));
    final url = isUrl ? (q.startsWith('http') ? q : 'https://$q') : browserSearchUrl(q);
    final tab = _tab;
    (_back[tab.id] ??= []).add(tab.url);
    widget.onTabUpdated?.call(tab.copyWith(url: url, title: isUrl ? _host(url) : q));
    setState(() => _overview = false);
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
    final w = math.max(VOverlay.toolWidth(context), 300.0);
    final h = VOverlay.toolMaxHeight(context) - 60;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(VSpace.sm, 56, VSpace.sm, VSpace.sm),
      child: SizedBox(
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Address bar ornament
            VOrnament(
              padding: const EdgeInsets.all(VSpace.xxs + 1),
              child: Row(
                children: [
                  VCircleButton(icon: Icons.close_rounded, size: 32, tooltip: 'Close', onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: VSpace.xs - 2),
                  if ((_back[tab.id] ?? const []).isNotEmpty) ...[
                    VCircleButton(icon: Icons.arrow_back_rounded, size: 32, tooltip: 'Back', onTap: _goBack),
                    const SizedBox(width: VSpace.xs - 2),
                  ],
                  Expanded(
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
                      decoration: BoxDecoration(color: VColors.fillRecessed, borderRadius: BorderRadius.circular(VRadius.full)),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 13, color: VColors.textSecondary),
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
                child: AnimatedSwitcher(
                  duration: VMotion.base,
                  child: _overview ? _tabsOverview() : _page(tab),
                ),
              ),
            ),
            const SizedBox(height: VSpace.sm),
            const VWindowBar(),
          ],
        ),
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
          child: GridView.builder(
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
          ),
        );
      },
    );
  }
}
