import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';
import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../music/floating_music.dart';

/// Settings from glyph-cluster (the market-row21 menu). The room behind the
/// menu is clear: a tap outside closes it. The only fade is the menu's own
/// edge. The panel is glass. Labels are Google Sans Flex via [GlassMenu].
class SettingsDrawer extends StatelessWidget {
  final VoidCallback onClose;
  final bool incognito;
  final bool autosave;
  final ValueChanged<bool> onIncognito;
  final ValueChanged<bool> onAutosave;
  final VoidCallback? onAccount;

  const SettingsDrawer({
    this.onAccount,
    super.key,
    required this.onClose,
    required this.incognito,
    required this.autosave,
    required this.onIncognito,
    required this.onAutosave,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose)),
        Center(
          child: ListenableBuilder(
            listenable: Listenable.merge([FloatingMusic.enabled, ThemeCatalog.instance]),
            builder: (_, __) => EdgeFade(
              fadeHeight: 18,
              child: GlassMenu(
                rows: [
                  if (onAccount != null) GlassMenuRow(icon: Icons.person_outline_rounded, label: 'Account', onTap: onAccount, toggle: false),
                  GlassMenuRow(icon: Icons.visibility_off_outlined, label: 'Incognito', on: incognito, onTap: () => onIncognito(!incognito)),
                  GlassMenuRow(icon: Icons.history_rounded, label: 'Save to History', on: autosave && !incognito, onTap: incognito ? null : () => onAutosave(!autosave)),
                  if (MusicPlayer.library.isNotEmpty)
                    GlassMenuRow(
                      icon: Icons.music_note_rounded,
                      label: 'Music widget',
                      on: FloatingMusic.enabled.value,
                      onTap: () => FloatingMusic.setEnabled(!FloatingMusic.enabled.value),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
