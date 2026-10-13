import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';
import 'contextual_side_nav.dart';

/// One affordance on the side nav. [key] is what the surface acts on.
class SideRailEntry {
  final String key;
  final IconData icon;
  final String label;
  const SideRailEntry(this.key, this.icon, this.label);
}

/// Master Spec §6.2: the side nav reshapes to the active work surface.
/// Surfaces themselves are reached from the Apps overlay, never from here.
///
/// Labels are short on purpose. The rail is a 58pt column; anything longer
/// ellipsised into mush, which is what made it look broken.
List<SideRailEntry> sideRailEntries(ActiveWorkSurface s) => switch (s) {
      ActiveWorkSurface.chat => const [
          SideRailEntry('new', Icons.add_rounded, 'New'),
          SideRailEntry('local', Icons.history_rounded, 'Local'),
          SideRailEntry('global', Icons.public_rounded, 'Global'),
          SideRailEntry('consensus', Icons.balance_rounded, 'Roundup'),
        ],
      ActiveWorkSurface.smartgen => const [
          SideRailEntry('cards', Icons.style_rounded, 'Cards'),
          SideRailEntry('boards', Icons.dashboard_rounded, 'Boards'),
          SideRailEntry('canvas', Icons.crop_free_rounded, 'Canvas'),
          SideRailEntry('genie', Icons.assistant_rounded, 'Genie'),
        ],
      // R27: Discover is the image market. The Imagine layout is a row of
      // pictures, a row of labeled looks, then a two-column feed. So the side
      // nav is Search, Library and Looks, and nothing else. The old prompts /
      // visuals / video / audio / gallery shelves were a prompt shelf, clips
      // and songs, which R27 and X5 both exclude.
      ActiveWorkSurface.market => const [
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('library', Icons.photo_library_outlined, 'Library'),
          // Not Icons.auto_awesome_outlined: sparkle-shaped glyphs are banned. "Looks"
// is a set of curated appearances, so it reads as a filter, not a wish.
          SideRailEntry('looks', Icons.filter_list_rounded, 'Looks'),
        ],
      ActiveWorkSurface.themes => [
          const SideRailEntry('premium', Icons.workspace_premium_rounded, 'Market'),
          const SideRailEntry('gallery', Icons.collections_rounded, 'Gallery'),
          // No songs in the catalog: no Music entry (v8.3, D46).
          if (MusicPlayer.library.isNotEmpty) const SideRailEntry('music', Icons.library_music_rounded, 'Music'),
        ],
      ActiveWorkSurface.browser => const [
          SideRailEntry('tabs', Icons.tab_rounded, 'Tabs'),
          SideRailEntry('engine', Icons.travel_explore_rounded, 'Engine'),
          SideRailEntry('clear', Icons.cleaning_services_outlined, 'Clear'),
        ],
      ActiveWorkSurface.files => const [
          SideRailEntry('all', Icons.folder_open_rounded, 'All'),
          SideRailEntry('artifacts', Icons.inventory_2_outlined, 'Artifacts'),
          SideRailEntry('attachments', Icons.attach_file_rounded, 'Files'),
          SideRailEntry('outputs', Icons.output_rounded, 'Outputs'),
          SideRailEntry('system', Icons.settings_suggest_outlined, 'System'),
        ],
    };

/// Vertical tab-bar ornament on the left edge, as in every visionOS app.
///
/// v9 fix — this used to be an `AnimatedSwitcher` around the rail. AnimatedSwitcher
/// stacks the outgoing and incoming child centre-aligned, so on every surface
/// change (3 items here, 5 there) the capsule visibly shrank toward its middle
/// while two rails cross-faded on top of each other. That was the "it teleports,
/// it moves around" behaviour. It now resizes from a fixed top origin and swaps
/// contents in place, so the rail only ever grows downward.
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

  static const double _railWidth = 58;
  static const double _dot = 34;

  @override
  Widget build(BuildContext context) {
    final entries = sideRailEntries(surface);
    final active = entries.indexWhere((e) => e.key == activeKey);
    return AnimatedSize(
      duration: VMotion.base,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: _railWidth,
        child: VOrnament(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 1),
                _RailButton(
                  entry: entries[i],
                  selected: i == active,
                  dot: _dot,
                  onTap: () => onSelect(entries[i].key),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final SideRailEntry entry;
  final bool selected;
  final double dot;
  final VoidCallback onTap;

  const _RailButton({
    required this.entry,
    required this.selected,
    required this.dot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: entry.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: VMotion.base,
                curve: Curves.easeOutCubic,
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.10),
                ),
                child: Icon(
                  entry.icon,
                  size: dot * 0.46,
                  color: selected ? const Color(0xFF0B0D12) : Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 3),
              // Named family, not GoogleFonts: this must never depend on a
              // network fetch to render in the same face as everything else.
              Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'GoogleSansFlex',
                  fontSize: 8.5,
                  height: 1.1,
                  letterSpacing: -0.05,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}