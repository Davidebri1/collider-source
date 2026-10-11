import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import '../../models/theme_def.dart';
import '../../models/ticker_item.dart';
import '../browser/models/browser_tab.dart';
import '../smartgen/kanban_store.dart';
import '../theme/theme_living_media.dart';

enum ActiveWorkSurface {
  chat,
  smartgen,
  market,
  themes,
  browser,
  files,
}

enum SideNavTab { local, global, consensus }

/// REQ-21 contextual panel beside the rail — the visionOS menu panel
/// (visionOS Apps 97:34752 "Home / People / Environments"): a glass panel of
/// icon-circle rows, selected row lit as a capsule; content follows the surface.
class ContextualSideNav extends StatefulWidget {
  final ActiveWorkSurface activeSurface;

  // AI Chat props
  final ModelCategory activeCategory;
  final List<String> selectedModelIds;
  final Map<String, List<ConversationHistorySession>> localHistory;
  final List<ConversationHistorySession> globalHistory;
  final String consensusRatio;
  final String consensusSummary;
  final String? expandedModelId;
  final ValueChanged<ModelCategory> onSelectCategory;
  final ValueChanged<String> onToggleModel;
  final ValueChanged<ConversationHistorySession> onSelectSession;
  final VoidCallback onOpenConsensus;
  final VoidCallback onNewConversation;
  final String chatSection; // local | global | consensus | models

  // Smart Gen props
  final String activeSmartGenView;
  final String activeSmartGenBoardType;
  final ValueChanged<String>? onSelectSmartGenView;
  final ValueChanged<String>? onSelectSmartGenBoardType;

  // Market props
  final String activeMarketCategory;
  final ValueChanged<String>? onSelectMarketCategory;

  // Themes props
  final String activeThemeSection;
  final ValueChanged<String>? onSelectThemeSection;
  /// Theme search result tapped: preview it in the gallery.
  final ValueChanged<WallpaperTheme>? onPreviewTheme;

  // Browser props
  final List<BrowserTab>? browserTabs;
  final String? activeBrowserTabId;
  final ValueChanged<String>? onSelectBrowserTab;
  final ValueChanged<String>? onCloseBrowserTab;
  final VoidCallback? onClearBrowserCache;

  // Files props
  final String activeFilesCategory;
  final ValueChanged<String>? onSelectFilesCategory;

  final ValueChanged<ActiveWorkSurface>? onRequestSwitchSurface;
  final VoidCallback onPaneInteraction;
  final VoidCallback? onClose;

  const ContextualSideNav({
    super.key,
    this.activeSurface = ActiveWorkSurface.chat,
    required this.activeCategory,
    required this.selectedModelIds,
    required this.localHistory,
    required this.globalHistory,
    required this.consensusRatio,
    required this.consensusSummary,
    required this.expandedModelId,
    required this.onSelectCategory,
    required this.onToggleModel,
    required this.onSelectSession,
    required this.onOpenConsensus,
    required this.onNewConversation,
    this.chatSection = 'global',
    this.activeSmartGenView = 'cards',
    this.activeSmartGenBoardType = 'kanban',
    this.onSelectSmartGenView,
    this.onSelectSmartGenBoardType,
    this.activeMarketCategory = 'prompts',
    this.onSelectMarketCategory,
    this.activeThemeSection = 'gallery',
    this.onSelectThemeSection,
    this.onPreviewTheme,
    this.browserTabs,
    this.activeBrowserTabId,
    this.onSelectBrowserTab,
    this.onCloseBrowserTab,
    this.onClearBrowserCache,
    this.activeFilesCategory = 'all',
    this.onSelectFilesCategory,
    this.onRequestSwitchSurface,
    required this.onPaneInteraction,
    this.onClose,
  });

  @override
  State<ContextualSideNav> createState() => _ContextualSideNavState();
}

class _ContextualSideNavState extends State<ContextualSideNav> {
  final TextEditingController _chatSearchCtrl = TextEditingController();
  String _chatQuery = '';

  @override
  void dispose() {
    _chatSearchCtrl.dispose();
    super.dispose();
  }

  List<ConversationHistorySession> _sessions() {
    final q = _chatQuery.toLowerCase().trim();
    // 'search' spans both stores — the rail's item 1 searches the whole face.
    final source = switch (widget.chatSection) {
      'local' => widget.localHistory.entries
          .expand((e) => e.value)
          .where((s) => widget.selectedModelIds.contains(s.targetModelId))
          .toList(),
      'search' => [
          ...widget.localHistory.entries.expand((e) => e.value).where((s) => widget.selectedModelIds.contains(s.targetModelId)),
          ...widget.globalHistory,
        ],
      _ => widget.globalHistory,
    };
    if (q.isEmpty) return source;
    return source
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.summary.toLowerCase().contains(q) ||
            s.messages.any((m) => m.text.toLowerCase().contains(q)))
        .toList();
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final width = isMobile ? math.min(240.0, size.width - 104) : 260.0;
    final maxHeight = math.min(440.0, size.height * 0.52);

    final (title, _) = switch (widget.activeSurface) {
      ActiveWorkSurface.chat => (switch (widget.chatSection) {
          'local' => 'Local History',
          'search' => 'Search',
          'consensus' => 'Consensus History',
          'models' => 'Models',
          _ => 'Global History',
        }, 0),
      ActiveWorkSurface.smartgen => ('Search', 0),
      // v8.3 (D45): one or two words, only to tell the panels apart.
      ActiveWorkSurface.market => ('Market', 0),
      ActiveWorkSurface.themes => (widget.activeThemeSection == 'search' ? 'Search' : 'Themes', 0),
      ActiveWorkSurface.browser => ('Tabs', 0),
      ActiveWorkSurface.files => ('Categories', 0),
    };

    return SizedBox(
      width: width,
      height: maxHeight,
      child: VGlass(
        material: VMaterial.elevated,
        radius: VRadius.card,
        padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  const SizedBox(width: VSpace.xxs),
                  Expanded(child: Text(title, style: VType.headline())),
                  if (widget.onClose != null)
                    VCircleButton(icon: Icons.close_rounded, size: 32, tooltip: 'Close', onTap: widget.onClose),
                ],
              ),
            ),
            const SizedBox(height: VSpace.xs),
            Expanded(
              child: AnimatedSwitcher(
                duration: VMotion.base,
                child: KeyedSubtree(key: ValueKey(widget.activeSurface), child: _content()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() => switch (widget.activeSurface) {
        ActiveWorkSurface.chat => _chat(),
        ActiveWorkSurface.themes => widget.activeThemeSection == 'search' ? _themesSearch() : _themes(),
        ActiveWorkSurface.browser => _browser(),
        // v8.4 (user directive, 2026-10-10): the rail's item 1 is search, and
        // Categories opens the source-filter panel. Both are wired — the D31
        // deletion removed panels whose rows selected nothing; these do.
        ActiveWorkSurface.smartgen => _smartgenSearch(),
        ActiveWorkSurface.files => _files(),
        ActiveWorkSurface.market => const SizedBox.shrink(),
      };

  // ---------------- AI Chat ----------------
  Widget _chat() {
    if (widget.chatSection == 'consensus') return _consensus();
    if (widget.chatSection == 'models') return _models();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSearchField(controller: _chatSearchCtrl, hint: 'Search', height: 34, onChanged: (v) => setState(() => _chatQuery = v)),
        const SizedBox(height: VSpace.xs),
        Expanded(child: _history()),
      ],
    );
  }

  Widget _models() {
    final models = ModelRoster.forCategory(widget.activeCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // models.ts CATEGORIES: General, Image, Video, Audio, Coding (D35 revoked).
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: ModelCategory.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: VSpace.xs),
            itemBuilder: (_, i) {
              final c = ModelCategory.values[i];
              return VChip(
                label: c.label,
                selected: c == widget.activeCategory,
                onTap: () {
                  widget.onPaneInteraction();
                  widget.onSelectCategory(c);
                },
              );
            },
          ),
        ),
        const SizedBox(height: VSpace.sm),
        Expanded(
          child: EdgeFade(
            fadeHeight: 12,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                for (final m in models)
                  VSidebarItem(
                    icon: widget.selectedModelIds.contains(m.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                    label: m.label,
                    selected: widget.selectedModelIds.contains(m.id),
                    onTap: () {
                      widget.onPaneInteraction();
                      widget.onToggleModel(m.id);
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _history() {
    final sessions = _sessions();
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }
    return EdgeFade(
      fadeHeight: 12,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: VSpace.xxs),
        itemBuilder: (_, i) {
          final s = sessions[i];
          return VPress(
            onTap: () => widget.onSelectSession(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: VSpace.xs),
              decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600))),
                    const SizedBox(width: 6),
                    Text(s.relativeTime, style: VType.caption()),
                  ]),
                  const SizedBox(height: 2),
                  Text(s.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.caption(color: VColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _consensus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(VSpace.sm),
          decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.balance_rounded, size: 15, color: VColors.textPrimary),
                const SizedBox(width: 6),
                Text('${widget.consensusRatio} Convergence', style: VType.callout(weight: FontWeight.w600)),
              ]),
              const SizedBox(height: VSpace.xs),
              Text(widget.consensusSummary, style: VType.footnote()),
            ],
          ),
        ),
        const SizedBox(height: VSpace.sm),
        VButton(label: 'Open 3D Celestial Map', dense: true, expand: true, onTap: widget.onOpenConsensus),
      ],
    );
  }

  // ---------------- Smart Gen (search) ----------------
  /// The rail's item 1: search the user's cards. The board is the store;
  /// a result tap goes to Cards.
  Widget _smartgenSearch() {
    return ListenableBuilder(
      listenable: KanbanStore.instance,
      builder: (context, _) {
        final q = _chatQuery.toLowerCase().trim();
        final cards = KanbanStore.instance.all.where((c) => c.title.isNotEmpty || c.notes.isNotEmpty).toList();
        final hits = q.isEmpty
            ? cards
            : cards
                .where((c) => c.title.toLowerCase().contains(q) || c.notes.toLowerCase().contains(q))
                .toList();
        if (hits.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(VSpace.sm),
              child: Text('No cards yet.', style: VType.footnote(color: VColors.textSecondary)),
            ),
          );
        }
        return EdgeFade(
          fadeHeight: 12,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
            itemCount: hits.length,
            separatorBuilder: (_, __) => const SizedBox(height: VSpace.xxs),
            itemBuilder: (_, i) {
              final c = hits[i];
              return VPress(
                onTap: () {
                  widget.onPaneInteraction();
                  widget.onSelectSmartGenView?.call('cards');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: VSpace.xs),
                  decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title.isEmpty ? '(untitled)' : c.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600)),
                      if (c.notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(c.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: VType.caption(color: VColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------- Files (categories) ----------------
  /// The Categories panel: where the files came from. The rows select the
  /// Files surface's source filter (R33) — wired, unlike the D31-era panel.
  Widget _files() {
    final rows = [
      ('all', 'All Files', Icons.folder_open_rounded),
      ('files', 'Added Here', Icons.download_rounded),
      ('composer', 'Attachments', Icons.attach_file_rounded),
      ('model', 'Model Outputs', Icons.smart_toy_rounded),
      if (MusicPlayer.library.isNotEmpty) ('music', 'Music', Icons.library_music_rounded),
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final (key, label, icon) in rows)
          VSidebarItem(
            icon: icon,
            label: label,
            selected: widget.activeFilesCategory == key,
            onTap: () {
              widget.onPaneInteraction();
              widget.onSelectFilesCategory?.call(key);
            },
          ),
      ],
    );
  }

  // ---------------- Themes (search) ----------------
  /// The rail's item 1 for the themes face: search the catalog. A result tap
  /// previews the theme in the gallery.
  Widget _themesSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VSearchField(controller: _chatSearchCtrl, hint: 'Search themes', height: 34, onChanged: (v) => setState(() => _chatQuery = v)),
        const SizedBox(height: VSpace.xs),
        Expanded(
          child: Builder(builder: (context) {
            final q = _chatQuery.toLowerCase().trim();
            final themes = ThemeCatalog.instance.allThemes;
            final hits = q.isEmpty
                ? themes
                : themes
                    .where((t) =>
                        t.name.toLowerCase().contains(q) ||
                        t.collection.toLowerCase().contains(q) ||
                        t.creator.toLowerCase().contains(q))
                    .toList();
            if (hits.isEmpty) {
              return Center(child: Text('Nothing matches.', style: VType.footnote(color: VColors.textSecondary)));
            }
            return EdgeFade(
              fadeHeight: 12,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: VSpace.xxs),
                itemCount: hits.length,
                separatorBuilder: (_, __) => const SizedBox(height: VSpace.xxs),
                itemBuilder: (_, i) {
                  final t = hits[i];
                  return VPress(
                    onTap: () {
                      widget.onPaneInteraction();
                      widget.onPreviewTheme?.call(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: VColors.fillCell, borderRadius: BorderRadius.circular(VRadius.md)),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(VRadius.sm),
                          child: SizedBox(
                            width: 34,
                            height: 48,
                            child: Image(
                              image: ThemeMedia.provider(t.posterUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(color: VColors.fillCell),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.callout(weight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                t.isPremium ? '${t.collection} · ${t.priceLabel ?? ''}' : t.collection,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VType.caption(color: VColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (t.isPremium) const Icon(Icons.diamond_rounded, size: 13, color: VColors.textSecondary),
                      ]),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---------------- Themes ----------------
  Widget _themes() {
    final sections = [
      ('gallery', 'Theme Gallery', Icons.collections_rounded),
      ('premium', 'Premium Market', Icons.workspace_premium_rounded),
      if (MusicPlayer.library.isNotEmpty) ('music', 'Music Collection', Icons.graphic_eq_rounded),
    ];
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        for (final s in sections)
          VSidebarItem(
            icon: s.$3,
            label: s.$2,
            selected: widget.activeThemeSection == s.$1,
            onTap: () => widget.onSelectThemeSection?.call(s.$1),
          ),
      ],
    );
  }

  // ---------------- Browser ----------------
  Widget _browser() {
    final tabs = widget.browserTabs ?? const <BrowserTab>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: tabs.isEmpty
              ? const SizedBox.shrink()
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (final t in tabs)
                      VSidebarItem(
                        icon: t.isModelAssigned ? Icons.terminal_rounded : Icons.person_outline_rounded,
                        label: t.title.isEmpty ? t.url : t.title,
                        selected: widget.activeBrowserTabId == t.id,
                        onTap: () => widget.onSelectBrowserTab?.call(t.id),
                        trailing: widget.onCloseBrowserTab == null
                            ? null
                            : VCircleButton(icon: Icons.close_rounded, size: 24, tooltip: 'Close tab', onTap: () => widget.onCloseBrowserTab!(t.id)),
                      ),
                  ],
                ),
        ),
        VButton(label: 'Clear Browser Cache', dense: true, expand: true, variant: VButtonVariant.ghost, onTap: widget.onClearBrowserCache),
      ],
    );
  }
}
