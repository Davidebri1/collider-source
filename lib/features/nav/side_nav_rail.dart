import 'package:flutter/material.dart';
import '../../core/kit/collider_kit.dart';
import '../../core/vision/vision_kit.dart';
import 'contextual_side_nav.dart';

/// One affordance on the side nav. [key] is what the surface acts on.
class SideRailEntry {
  final String key;
  final IconData icon;
  final String label;
  const SideRailEntry(this.key, this.icon, this.label);
}

/// The rail contract (user directive, 2026-10-10): the side nav is the
/// module's control surface. Item 1 is always the search of the active face —
/// chat searches history, files searches files, themes search the catalog,
/// the browser opens its address bar, the market opens its search view.
/// The rest are that surface's major local controls. Surfaces themselves are
/// reached from the Apps overlay, never from here.
List<SideRailEntry> sideRailEntries(ActiveWorkSurface s) => switch (s) {
      ActiveWorkSurface.chat => const [
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('new', Icons.add_rounded, 'New Chat'),
          SideRailEntry('local', Icons.history_rounded, 'Local History'),
          SideRailEntry('global', Icons.public_rounded, 'Global History'),
          SideRailEntry('consensus', Icons.balance_rounded, 'Consensus'),
          SideRailEntry('models', Icons.hub_outlined, 'Models'),
        ],
      ActiveWorkSurface.smartgen => const [
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('cards', Icons.style_rounded, 'Cards'),
          SideRailEntry('boards', Icons.dashboard_rounded, 'Boards'),
          SideRailEntry('canvas', Icons.crop_free_rounded, 'Canvas'),
          SideRailEntry('genie', Icons.assistant_rounded, 'Genie'),
          SideRailEntry('new', Icons.add_rounded, 'New Card'),
        ],
      ActiveWorkSurface.market => const [
          // 'search' is the market's own search view (R20): live filters by
          // type and model. Discover is the Imagine-layout feed.
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('discover', Icons.play_arrow_rounded, 'Discover'),
          SideRailEntry('mine', Icons.bookmark_rounded, 'My Generations'),
          SideRailEntry('gallery', Icons.collections_rounded, 'Theme Gallery'),
        ],
      ActiveWorkSurface.themes => const [
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('premium', Icons.workspace_premium_rounded, 'Premium'),
          SideRailEntry('gallery', Icons.collections_rounded, 'Gallery'),
          // Always present (v8.4): the catalog ships real tracks; an entry's
          // place must not depend on transient content.
          SideRailEntry('music', Icons.library_music_rounded, 'Music'),
        ],
      ActiveWorkSurface.browser => const [
          // Item 1 opens the address bar (the start page is the search home).
          // Find on Page is its own button (user directive): the web build
          // frames cross-origin pages, so find works in the app build and
          // says so quietly on web.
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('find', Icons.find_in_page_rounded, 'Find on Page'),
          SideRailEntry('tabs', Icons.tab_rounded, 'Tabs'),
          SideRailEntry('engine', Icons.travel_explore_rounded, 'Search Engine'),
          SideRailEntry('clear', Icons.cleaning_services_outlined, 'Clear Cache'),
        ],
      ActiveWorkSurface.files => const [
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          // Categories opens the panel with the source filters — the rail
          // itself stays four items, like the references.
          SideRailEntry('categories', Icons.category_rounded, 'Categories'),
          SideRailEntry('upload', Icons.file_upload_outlined, 'Add Files'),
          SideRailEntry('music', Icons.library_music_rounded, 'Music'),
        ],
    };

/// Vertical tab-bar ornament on the left edge, as in every visionOS app.
class SideNavRail extends StatelessWidget {
  final ActiveWorkSurface surface;
  final String? activeKey;
  final ValueChanged<String> onSelect;
  final bool compact;

  const SideNavRail({
    super.key,
    required this.surface,
    required this.activeKey,
    required this.onSelect,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final entries = sideRailEntries(surface);
    // The rail is a nav, not an ornament: its targets are the same controls as
    // the dock's. At 36 they read as half-size decoration next to a 44pt dock,
    // which is why the rail looked laughably small - the dock was the reference
    // and the rail was not sized against it.
    return AnimatedSwitcher(
      duration: VMotion.base,
      child: VOrnamentRail(
        key: ValueKey(surface),
        size: compact ? Kit.controlCircle : Kit.controlCircle,
        items: [for (final e in entries) VRailItem(e.icon, e.label)],
        active: entries.indexWhere((e) => e.key == activeKey),
        onSelect: (i) => onSelect(entries[i].key),
      ),
    );
  }
}
