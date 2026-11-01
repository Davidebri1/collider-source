import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/music_player.dart';
import '../../core/media/theme_catalog.dart';
import '../../core/vision/materialize.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import '../account/account_sheet.dart';
import '../account/settings_glass.dart';
import '../music/floating_music.dart';

/// Settings (map row 26). Account is an iOS-style drill-down in the same pane
/// (Back top-left) — never a second translucent card over Settings.
class SettingsDrawer extends StatefulWidget {
  /// v8.7: Settings is the largest overlay; nothing opened from it is bigger.
  static const Size panel = Size(1179 * 0.30, 877 * 0.30);

  final VoidCallback onClose;
  final bool incognito;
  final bool autosave;
  final ValueChanged<bool> onIncognito;
  final ValueChanged<bool> onAutosave;
  final ModelTier tier;

  const SettingsDrawer({
    super.key,
    required this.onClose,
    required this.incognito,
    required this.autosave,
    required this.onIncognito,
    required this.onAutosave,
    this.tier = ModelTier.free,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

enum _SettingsPage { root, account, plans }

class _SettingsDrawerState extends State<SettingsDrawer> {
  _SettingsPage _page = _SettingsPage.root;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_page != _SettingsPage.root) {
                setState(() => _page = _SettingsPage.root);
              } else {
                widget.onClose();
              }
            },
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 18 * Materialize.of(context),
                  sigmaY: 18 * Materialize.of(context),
                ),
                child: const ColoredBox(color: Color(0x14000000)),
              ),
            ),
          ),
        ),
        // Vertically centred — same as other panes (no bottom offset).
        Center(
          child: ListenableBuilder(
            listenable: Listenable.merge([FloatingMusic.enabled, ThemeCatalog.instance]),
            builder: (context, __) {
              final phone = MediaQuery.sizeOf(context).width < 700;
              final paneW = phone
                  ? (MediaQuery.sizeOf(context).width * 0.82).clamp(280.0, 360.0)
                  : SettingsDrawer.panel.width;

              final body = switch (_page) {
                _SettingsPage.root => _RootSettings(
                    compact: phone,
                    incognito: widget.incognito,
                    autosave: widget.autosave,
                    onIncognito: widget.onIncognito,
                    onAutosave: widget.onAutosave,
                    onAccount: () => setState(() => _page = _SettingsPage.account),
                  ),
                _SettingsPage.account => AccountPaneBody(
                    tier: widget.tier,
                    onBack: () => setState(() => _page = _SettingsPage.root),
                    onOpenPlans: () => setState(() => _page = _SettingsPage.plans),
                  ),
                _SettingsPage.plans => UpgradePlansBody(
                    tier: widget.tier,
                    onBack: () => setState(() => _page = _SettingsPage.account),
                  ),
              };

              if (phone) {
                return SizedBox(
                  width: paneW,
                  child: SettingsGlassPane(child: body),
                );
              }
              // Wide: keep Figma frame scale for root only; account/plans use readable phone-scale pane.
              if (_page != _SettingsPage.root) {
                return SizedBox(
                  width: (MediaQuery.sizeOf(context).width * 0.36).clamp(320.0, 420.0),
                  child: SettingsGlassPane(child: body),
                );
              }
              return SizedBox(
                width: SettingsDrawer.panel.width,
                height: SettingsDrawer.panel.height,
                child: FittedBox(
                  child: SizedBox(
                    width: 1179,
                    height: 877,
                    child: _WideGlass(child: body),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WideGlass extends StatelessWidget {
  final Widget child;
  const _WideGlass({required this.child});
  @override
  Widget build(BuildContext context) {
    return SuspendedFrost(
      edge: 0.04,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(46),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 40 * Materialize.of(context),
            sigmaY: 40 * Materialize.of(context),
          ),
          child: Container(color: const Color(0xC8505050), child: child),
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

class _RootSettings extends StatelessWidget {
  final List<_Row> Function() _rows;
  final VoidCallback onAccount;
  final bool compact;
  final bool incognito;
  final bool autosave;
  final ValueChanged<bool> onIncognito;
  final ValueChanged<bool> onAutosave;

  _RootSettings({
    required this.compact,
    required this.incognito,
    required this.autosave,
    required this.onIncognito,
    required this.onAutosave,
    required this.onAccount,
  }) : _rows = (() => [
          _Row(Icons.visibility_off_rounded, const Color(0xFF8E8E93), 'Incognito', incognito, () => onIncognito(!incognito)),
          _Row(Icons.history_rounded, const Color(0xFF0A84FF), 'Save to History', autosave && !incognito, incognito ? null : () => onAutosave(!autosave)),
          if (MusicPlayer.library.isNotEmpty)
            _Row(Icons.music_note_rounded, const Color(0xFFFF375F), 'Music widget', FloatingMusic.enabled.value, () => FloatingMusic.setEnabled(!FloatingMusic.enabled.value)),
        ]);

  Widget _icon(IconData i, Color c, {double s = 36}) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        child: Icon(i, size: s * 0.55, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    if (compact) return _compact(context, rows);
    return _wide(context, rows);
  }

  Widget _compact(BuildContext context, List<_Row> rows) {
    const w = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      _icon(Icons.person_rounded, const Color(0xFF3A3A3C), s: 64),
      const SizedBox(height: 8),
      const Text('David Ebri', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const Text('Collider', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0x33FFFFFF), indent: 52),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: rows[i].onTap,
              child: SizedBox(
                height: 50,
                child: Row(children: [
                  const SizedBox(width: 12),
                  _icon(rows[i].icon, rows[i].color, s: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(rows[i].label, style: w)),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: rows[i].on,
                      onChanged: rows[i].onTap == null ? null : (_) => rows[i].onTap!(),
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF34C759),
                    ),
                  ),
                  const SizedBox(width: 4),
                ]),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: onAccount,
        child: Container(
          height: 50,
          decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const SizedBox(width: 12),
            _icon(Icons.person_outline_rounded, const Color(0xFF0A84FF), s: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Account', style: w)),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
            const SizedBox(width: 10),
          ]),
        ),
      ),
    ]);
  }

  Widget _wide(BuildContext context, List<_Row> rows) {
    const w = TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600);
    return Row(children: [
      Container(
        width: 375,
        color: const Color(0x33000000),
        padding: const EdgeInsets.fromLTRB(28, 24, 12, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(21)),
            child: const Row(children: [
              Icon(Icons.mic_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Text('Search', style: TextStyle(color: Colors.white70, fontSize: 17)),
            ]),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onAccount,
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: const Color(0x44FFFFFF), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                _icon(Icons.person_rounded, const Color(0xFF3A3A3C), s: 50),
                const SizedBox(width: 14),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('David Ebri', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                    Text('Collider Account', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
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
                decoration: BoxDecoration(color: r.on ? const Color(0x33FFFFFF) : null, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [_icon(r.icon, r.color), const SizedBox(width: 14), Text(r.label, style: w)]),
              ),
            ),
        ]),
      ),
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
            const Text('Collider', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: Color(0x33FFFFFF), indent: 24),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: rows[i].onTap,
                    child: SizedBox(
                      height: 62,
                      child: Row(children: [
                        const SizedBox(width: 24),
                        _icon(rows[i].icon, const Color(0x55FFFFFF), s: 34),
                        const SizedBox(width: 16),
                        Expanded(child: Text(rows[i].label, style: w)),
                        Switch(
                          value: rows[i].on,
                          onChanged: rows[i].onTap == null ? null : (_) => rows[i].onTap!(),
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF34C759),
                        ),
                        const SizedBox(width: 18),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onTap: onAccount,
              child: Container(
                height: 62,
                decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const SizedBox(width: 24),
                  _icon(Icons.person_outline_rounded, const Color(0xFF0A84FF), s: 34),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Account', style: w)),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
                  const SizedBox(width: 18),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
