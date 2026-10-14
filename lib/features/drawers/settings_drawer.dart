import '../../core/vision/materialize.dart';
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
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose, child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18 * Materialize.of(context), sigmaY: 18 * Materialize.of(context)), child: const ColoredBox(color: Color(0x14000000)))))),
        // v8.6: Figma 10:2193 (visionOS Settings, 1179 x 877) built at its
        // own size and scaled as one unit to 30 % (David: 25-33 %).
        Center(
          child: SizedBox(
            width: panel.width,
            height: panel.height,
            child: FittedBox(
              child: SizedBox(
                width: 1179,
                height: 877,
                child: ListenableBuilder(
                  listenable: Listenable.merge([FloatingMusic.enabled, ThemeCatalog.instance]),
                  builder: (_, __) => _VisionSettings(
                    onAccount: onAccount,
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
          ),
        ),
      ],
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

class _VisionSettings extends StatelessWidget {
  final List<_Row> rows;
  final VoidCallback? onAccount;
  const _VisionSettings({required this.rows, this.onAccount});

  Widget _icon(IconData i, Color c, {double s = 36}) => Container(
        width: s, height: s,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Icon(i, size: s * 0.55, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    const w = TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600);
    // v8.7: suspended frost: lighter fill, perimeter dissolves, no outline.
    return SuspendedFrost(edge: 0.04, child: ClipRRect(
      borderRadius: BorderRadius.circular(46),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40 * Materialize.of(context), sigmaY: 40 * Materialize.of(context)),
        child: Container(
          color: const Color(0x33808080),
          child: Row(children: [
            // Sidebar 375 px: search, account card, setting rows.
            Container(
              width: 375,
              color: const Color(0x1A000000),
              padding: const EdgeInsets.fromLTRB(28, 24, 12, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(21)),
                  child: const Row(children: [Icon(Icons.mic_rounded, color: Colors.white60, size: 20), SizedBox(width: 10), Text('Search', style: TextStyle(color: Colors.white60, fontSize: 17))]),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: onAccount,
                  child: Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      _icon(Icons.person_rounded, const Color(0xFF3A3A3C), s: 50),
                      const SizedBox(width: 14),
                      const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('David Ebri', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                        Text('Collider Account', style: TextStyle(color: Colors.white70, fontSize: 15)),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 34),
                for (final r in rows)
                  GestureDetector(
                    onTap: r.onTap,
                    child: Container(
                      height: 59,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(color: r.on ? const Color(0x26FFFFFF) : null, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [_icon(r.icon, r.color), const SizedBox(width: 14), Text(r.label, style: w)]),
                    ),
                  ),
              ]),
            ),
            // Detail pane: title, avatar, name, grouped rows.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(64, 24, 64, 24),
                child: Column(children: [
                  const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 40),
                  _icon(Icons.person_rounded, const Color(0xFF3A3A3C), s: 130),
                  const SizedBox(height: 18),
                  const Text('David Ebri', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Collider', style: TextStyle(color: Colors.white60, fontSize: 15)),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: Color(0x1FFFFFFF), indent: 24),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: rows[i].onTap,
                          child: SizedBox(
                            height: 62,
                            child: Row(children: [
                              const SizedBox(width: 24),
                              _icon(rows[i].icon, const Color(0x33FFFFFF), s: 34),
                              const SizedBox(width: 16),
                              Expanded(child: Text(rows[i].label, style: w)),
                              Switch(value: rows[i].on, onChanged: rows[i].onTap == null ? null : (_) => rows[i].onTap!(), activeColor: Colors.white, activeTrackColor: const Color(0xFF34C759)),
                              const SizedBox(width: 18),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 40),
                  if (onAccount != null)
                    GestureDetector(
                      onTap: onAccount,
                      child: Container(
                        height: 62,
                        decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          const SizedBox(width: 24),
                          _icon(Icons.person_outline_rounded, const Color(0xFF0A84FF), s: 34),
                          const SizedBox(width: 16),
                          const Expanded(child: Text('Account', style: w)),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 28),
                          const SizedBox(width: 18),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),)
    );
  }
}
