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
List<SideRailEntry> sideRailEntries(ActiveWorkSurface s, {bool musicOpen = false}) => switch (s) {
      ActiveWorkSurface.chat => const [
          SideRailEntry('new', Icons.add_rounded, 'New'),
          SideRailEntry('local', Icons.history_rounded, 'Local'),
          SideRailEntry('global', Icons.public_rounded, 'Global'),
          // PRD R14 / Surfaces (Ticker): model select on the side nav.
          SideRailEntry('models', Icons.tune_rounded, 'Models'),
          // #126 (David, Oct 15): the consensus entry ('Roundup') is not in
          // the PRD; it came in with the v9 import. Removed.
        ],
      // v9.1.7 (#24): Smart Gen's own tools (were a bottom ornament).
      ActiveWorkSurface.smartgen => const [
          SideRailEntry('tasks', Icons.view_kanban_outlined, 'Tasks'),
          SideRailEntry('projects', Icons.folder_outlined, 'Projects'),
          SideRailEntry('reminders', Icons.alarm_rounded, 'Remind'),
          SideRailEntry('memories', Icons.psychology_outlined, 'Memory'),
          SideRailEntry('artifacts', Icons.description_outlined, 'Outputs'),
        ],
      // R27: Discover is the image market. The Imagine layout is a row of
      // pictures, a row of labeled looks, then a two-column feed. So the side
      // nav is Search, Library and Looks, and nothing else. The old prompts /
      // visuals / video / audio / gallery shelves were a prompt shelf, clips
      // and songs, which R27 and X5 both exclude.
      // v9.1.7 (#24): the side nav carries the Discover feeds.
      // PRD Surfaces (Discover Market): Search, Library, Looks. Images only.
      ActiveWorkSurface.market => const [
          SideRailEntry('search', Icons.search_rounded, 'Search'),
          SideRailEntry('library', Icons.photo_library_outlined, 'Library'),
          SideRailEntry('looks', Icons.style_outlined, 'Looks'),
        ],
      ActiveWorkSurface.themes => [
          const SideRailEntry('premium', Icons.workspace_premium_rounded, 'Market'),
          const SideRailEntry('gallery', Icons.collections_rounded, 'Gallery'),
          // No songs in the catalog: no Music entry (v8.3, D46).
          if (MusicPlayer.library.isNotEmpty) const SideRailEntry('music', Icons.library_music_rounded, 'Music'),
          // v9.1.7 (#24): Music's collections (pack songs, ambient tracks).
          if (musicOpen && MusicPlayer.library.isNotEmpty) ...const [
            SideRailEntry('music_themes', Icons.collections_bookmark_outlined, 'Packs'),
            SideRailEntry('music_ambient', Icons.waves_rounded, 'Ambient'),
          ],
        ],
      ActiveWorkSurface.browser => const [
          SideRailEntry('tabs', Icons.tab_rounded, 'Tabs'),
          SideRailEntry('engine', Icons.travel_explore_rounded, 'Engine'),
          SideRailEntry('clear', Icons.cleaning_services_outlined, 'Clear'),
        ],
      // v9.1.7 (#24): the Files sidebar's own types, same order and icons,
      // as the overlaying rail.
      ActiveWorkSurface.files => const [
          SideRailEntry('all', Icons.schedule_rounded, 'Recent'),
          SideRailEntry('image', Icons.image_outlined, 'Images'),
          SideRailEntry('video', Icons.movie_outlined, 'Videos'),
          SideRailEntry('document', Icons.description_outlined, 'Docs'),
          SideRailEntry('writing', Icons.notes_rounded, 'Text'),
          SideRailEntry('data', Icons.table_chart_outlined, 'Data'),
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
    this.musicOpen = false,
  });
  /// v9.1.7 (#24): Music's collections show only while Music is open.
  final bool musicOpen;

  static const double _railWidth = 58;
  static const double _dot = 34;

  @override
  Widget build(BuildContext context) {
    final entries = sideRailEntries(surface, musicOpen: musicOpen);
    final active = entries.indexWhere((e) => e.key == activeKey);
    return Recede(child: AnimatedSize(
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
    ));
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
                  fontSize: 11,
                  height: 1.1,
                  letterSpacing: -0.05,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: Colors.white, // v9.1.4 (playtest #15): readable over bright wallpaper
                  shadows: const [Shadow(color: Color(0xB3000000), blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v9.1.2: the rail recedes (smaller, faded) until touched, then comes
/// forward for a few seconds.
class Recede extends StatefulWidget {
  final Widget child;
  const Recede({super.key, required this.child});
  @override
  State<Recede> createState() => RecedeState();
}

class RecedeState extends State<Recede> {
  bool _on = false;
  int _gen = 0;
  void _wake() {
    final g = ++_gen;
    setState(() => _on = true);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && g == _gen) setState(() => _on = false);
    });
  }
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _wake(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: _on ? 1 : 0.38,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            scale: _on ? 1 : 0.82,
            alignment: Alignment.centerLeft,
            child: widget.child,
          ),
        ),
      );
}
