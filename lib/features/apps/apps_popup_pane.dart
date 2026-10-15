import 'package:flutter/material.dart';
import '../../core/audio/music_player.dart';
import '../../core/vision/vision_kit.dart';

/// REQ-01 App Grid (Vision OS Design System 2:6774, visionOS Home 97:34752):
/// circular app icons float directly over the dimmed environment in offset
/// rows â€” no platter. Escapes: scrim tap and the floating close circle.
class AppsPopupPane extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenSmartGen;
  final VoidCallback onOpenDiscoverMarket;
  final VoidCallback onOpenThemeGallery;
  final VoidCallback onOpenPremiumMarketplace;
  final VoidCallback onOpenFiles;
  final VoidCallback onOpenMusicPlayer;
  final VoidCallback onOpenBrowser;
  final VoidCallback onOpenSettings;

  const AppsPopupPane({
    super.key,
    required this.onClose,
    required this.onOpenSmartGen,
    required this.onOpenDiscoverMarket,
    required this.onOpenThemeGallery,
    required this.onOpenPremiumMarketplace,
    required this.onOpenFiles,
    required this.onOpenMusicPlayer,
    required this.onOpenBrowser,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final apps = [
      // v8.3 (D45, D48): one-word names (an icon alone is ambiguous in a
      // launcher); full-colour icons and a Settings app, as in Figma 97-34752.
      _App('Smart Gen', Icons.view_kanban_outlined, const [Color(0xFFC4B5FD), Color(0xFF7C3AED)], onOpenSmartGen),
      // PRD R13: seven apps (Smart Gen, Discover Market, Theme Gallery,
      // Premium Theme Marketplace, Files, Music Player, Browser). Settings is
      // on the dock, not in the platter. R40: "Discover" is the user word.
      _App('Discover', Icons.explore_rounded, const [Color(0xFFFDBA74), Color(0xFFEA580C)], onOpenDiscoverMarket),
      _App('Gallery', Icons.landscape_rounded, const [Color(0xFF6EE7B7), Color(0xFF059669)], onOpenThemeGallery),
      _App('Premium', Icons.diamond_rounded, const [Color(0xFFFDE68A), Color(0xFFD97706)], onOpenPremiumMarketplace),
      _App('Files', Icons.folder_rounded, const [Color(0xFF93C5FD), Color(0xFF2563EB)], onOpenFiles),
      // No songs in the catalog: no Music app (v8.3, D46).
      if (MusicPlayer.library.isNotEmpty) _App('Music', Icons.music_note_rounded, const [Color(0xFFFF7A90), Color(0xFFF2213B)], onOpenMusicPlayer),
      _App('Browser', Icons.explore_outlined, const [Color(0xFF7DD3FC), Color(0xFF0369A1)], onOpenBrowser),
    ];

    final width = MediaQuery.of(context).size.width;
    final perRow = width < 480 ? 4 : 4;
    final iconSize = width < 480 ? 58.0 : 72.0;
    final cell = iconSize + 22;

    final rows = <List<_App>>[];
    for (int i = 0; i < apps.length; i += perRow) {
      rows.add(apps.sublist(i, (i + perRow).clamp(0, apps.length)));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VScrim(onTap: onClose, blur: false), // ticker stays visible, blurred by its own gate
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: VSpace.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in rows[r])
                      SizedBox(
                        width: cell,
                        child: _AppIcon(
                          index: apps.indexOf(a),
                          app: a,
                          size: iconSize,
                          onTap: () {
                            onClose();
                            a.onTap();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Positioned(
          top: VSpace.md,
          right: VSpace.md,
          child: SafeArea(
            child: VCircleButton(icon: Icons.close_rounded, tooltip: 'Close Apps', floating: true, onTap: onClose),
          ),
        ),
      ],
    );
  }
}

class _App {
  final String label;
  final IconData icon;
  /// Top and bottom of the icon's colour fill.
  final List<Color> colors;
  final VoidCallback onTap;
  final Color glyph;
  const _App(this.label, this.icon, this.colors, this.onTap, {this.glyph = Colors.white});
}

class _AppIcon extends StatelessWidget {
  final _App app;
  final double size;
  final int index;
  final VoidCallback onTap;
  const _AppIcon({required this.app, required this.size, required this.onTap, this.index = 0});

  @override
  Widget build(BuildContext context) {
    // Icons rise into place one after another when the overlay is summoned.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 45),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: Transform.scale(scale: 0.85 + 0.15 * t, child: child)),
      ),
      child: VPress(
        onTap: onTap,
        tooltip: app.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // visionOS home icon: an opaque full-colour disc, a soft top
            // highlight and a drop shadow (Figma 97-34752).
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: app.colors),
                boxShadow: VElev.e6,
              ),
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
                ),
              ),
              child: Icon(app.icon, size: size * 0.5, color: app.glyph),
            ),
            const SizedBox(height: VSpace.xs - 2),
            Text(
              app.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: VType.caption(color: VColors.textPrimary, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
