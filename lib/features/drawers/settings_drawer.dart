import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/vision/vision_kit.dart';
import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../music/floating_music.dart';

/// Settings (map row 26, VisionOS Autolayout Menu 0-1): a glass menu of
/// icon + label rows; a highlighted row is a setting that is on. Tap a row to
/// switch it. No title, no server-status lines (v8.3, D47).
class SettingsDrawer extends StatelessWidget {
  /// v8.7: Settings is the largest overlay; nothing opened from it is bigger.
  static const Size panel = Size(1179 * 0.30, 877 * 0.30);

  final VoidCallback onClose;
  final bool incognito;
  final bool autosave;
  final ValueChanged<bool> onIncognito;
  final ValueChanged<bool> onAutosave;
  /// Opens Account (map row 18).
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
        // Figma 1:2 has no dimming behind the menu: a clear tap-to-close layer.
        // v9.1 one dim convention: overlays get VOverlay.scrim, unblurred.
        Positioned.fill(child: VScrim(onTap: onClose)),
        // v9.1.4 (playtest #7): one compact column, ~2/3 of the screen wide,
        // 15 pt+ text, each option once, a 44 pt close, blurred background.
        Center(
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.68,
            child: ListenableBuilder(
              listenable: Listenable.merge([FloatingMusic.enabled, ThemeCatalog.instance]),
              builder: (_, __) => _CompactSettings(
                onAccount: onAccount,
                onClose: onClose,
                rows: [
                  _Row(Icons.visibility_off_rounded, const Color(0xFF8E8E93), 'Incognito', incognito, () => onIncognito(!incognito)),
                  _Row(Icons.history_rounded, const Color(0xFF0A84FF), 'Save to History', autosave && !incognito, incognito ? null : () => onAutosave(!autosave)),
                  if (MusicPlayer.library.isNotEmpty)
                    _Row(Icons.music_note_rounded, const Color(0xFFFF375F), 'Music widget', FloatingMusic.enabled.value, () => FloatingMusic.setEnabled(!FloatingMusic.enabled.value)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactSettings extends StatelessWidget {
  final List<_Row> rows;
  final VoidCallback? onAccount;
  final VoidCallback onClose;
  const _CompactSettings({required this.rows, required this.onClose, this.onAccount});

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500);
    Widget icon(IconData i, Color c) => Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: Icon(i, size: 16, color: Colors.white),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: VFrost.blur, sigmaY: VFrost.blur),
        child: Container(
          color: VFrost.tint,
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              VCloseButton(onTap: onClose),
            ]),
            for (final r in rows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: r.onTap,
                child: SizedBox(
                  height: 48,
                  child: Row(children: [
                    icon(r.icon, r.color),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.label, style: st.copyWith(color: r.onTap == null ? Colors.white54 : Colors.white))),
                    Transform.scale(scale: 0.8, child: Switch(value: r.on, onChanged: r.onTap == null ? null : (_) => r.onTap!(), activeColor: Colors.white, activeTrackColor: const Color(0xFF34C759))),
                  ]),
                ),
              ),
            if (onAccount != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAccount,
                child: SizedBox(
                  height: 48,
                  child: Row(children: [
                    icon(Icons.person_rounded, const Color(0xFF3A3A3C)),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Account', style: st)),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 24),
                    const SizedBox(width: 8),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _Row {
  final IconData icon;
  final Color color;
  final String label;
  final bool on;
  final VoidCallback? onTap;
  const _Row(this.icon, this.color, this.label, this.on, this.onTap);
}

