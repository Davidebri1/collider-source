import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';
import 'side_nav_rail.dart' show Recede;

/// REQ-12 / G6 Permanent 3-icon bottom dock (Settings | Compose | Apps), shown on
/// every screen including the Premium Theme Market — a compact glass capsule ornament
/// (WeChat visionOS 0:639). Swipe up summons the composer, swipe down tucks it.
class PermanentNavBar extends StatelessWidget {
  final bool isComposerSummoned;
  final VoidCallback onToggleComposer;
  final VoidCallback onHome;
  final VoidCallback onApps;
  final VoidCallback onSettings;
  final String? activeDrawer;

  const PermanentNavBar({
    super.key,
    required this.isComposerSummoned,
    required this.onToggleComposer,
    required this.onHome,
    required this.onApps,
    required this.onSettings,
    this.activeDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if (velocity == null) return;
        if (velocity < -200 && !isComposerSummoned) {
          onToggleComposer();
        } else if (velocity > 200 && isComposerSummoned) {
          onToggleComposer();
        }
      },
      child: Recede(child: VOrnament(
        padding: const EdgeInsets.all(VSpace.xs - 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VCircleButton(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              size: 36,
              selected: activeDrawer == 'settings',
              onTap: onSettings,
            ),
            const SizedBox(height: VSpace.xs),
            // v9.1.3: no chat button; the composer is always docked.
            VCircleButton(
              icon: Icons.apps_rounded,
              tooltip: 'Apps',
              size: 36,
              selected: activeDrawer == 'apps',
              onTap: onApps,
            ),
          ],
        ),
      )),
    );
  }
}
