// Map row 18 (Settings → Account), Figma Vision OS Design System 417:8552:
// a grey sheet with a close circle and a centred title, the profile row,
// a single row with a trailing value and chevron, a grouped list, and a
// standalone row. Filled from the source's Account tab
// (components/SettingsPane.tsx: Plan / Credits / Pool, Upgrade, Sign in)
// and screens/UpgradeScreen.tsx (Free / Pro / Elite with the source prices
// and perks, Continue, Restore). Payments and sign-in need the native
// stores and an auth backend that this link does not have: those actions
// answer inline that they are not available here (H10, D60).
import 'package:flutter/material.dart';
import '../drawers/settings_drawer.dart';

import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';

class AccountSheet extends StatefulWidget {
  final ModelTier tier;
  final VoidCallback onClose;
  const AccountSheet({super.key, required this.tier, required this.onClose});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  bool _plans = false;

  @override
  Widget build(BuildContext context) {
    // v9: was `width - 2*VSpace.md`, which on a 430pt phone is nearly the full
    // width — a sheet flush to both edges reads as a fullscreen page and loses
    // the floating-panel depth the rest of the app is built on. Inset it.
    final w = (MediaQuery.sizeOf(context).width - 2 * VSpace.lg).clamp(0.0, 420.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        // v8.7: no scrim; Settings stays visible, stepped back behind.
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 70),
            // v8.7: a pane opened from Settings never exceeds Settings
            // (the largest overlay): scaled as one unit to fit inside it.
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: SettingsDrawer.panel.width * 0.92, maxHeight: SettingsDrawer.panel.height * 0.92),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: w,
                  child: AnimatedSwitcher(
                    duration: VMotion.base,
                    child: _plans
                        ? UpgradePlans(key: const ValueKey('plans'), tier: widget.tier, onBack: () => setState(() => _plans = false))
                        : _account(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _account() {
    final info = TierInfo.all[widget.tier]!;
    return _GreySheet(
      key: const ValueKey('account'),
      title: 'Account',
      leading: VCircleButton(icon: Icons.close_rounded, size: 44, tooltip: 'Close', onTap: widget.onClose),
      children: [
        _Group(rows: [
          _Row(
            leading: const CircleAvatar(radius: 20, backgroundColor: Color(0x33FFFFFF), child: Icon(Icons.person_rounded, color: Colors.white70)),
            title: 'Sign in',
            onTap: () => showVAlert(context, icon: Icons.person_outline_rounded, title: "Sign-in isn't available on this link", actions: const [VAlertChoice('OK')]),
          ),
        ]),
        const SizedBox(height: VSpace.sm),
        _Group(rows: [
          _Row(title: 'Plan', value: info.label, onTap: () => setState(() => _plans = true)),
        ]),
        const SizedBox(height: VSpace.sm),
        _Group(rows: [
          _Row(title: 'Manage Subscription', onTap: () => setState(() => _plans = true)),
          _Row(title: 'Credits', value: '${info.pool}'),
          _Row(title: 'Monthly pool', value: '${info.pool}'),
        ]),
      ],
    );
  }
}

/// UpgradeScreen.tsx: the three plans with the source's prices and perks.
class UpgradePlans extends StatefulWidget {
  final ModelTier tier;
  final VoidCallback onBack;
  const UpgradePlans({super.key, required this.tier, required this.onBack});
  @override
  State<UpgradePlans> createState() => _UpgradePlansState();
}

class _UpgradePlansState extends State<UpgradePlans> {
  static const _perks = {
    ModelTier.free: ['Unlimited general chat', '3 models on the board', 'No media generation'],
    ModelTier.pro: ['Unlimited general', 'Image, video, audio', '3,000 media credits / mo'],
    ModelTier.elite: ['Every model', 'Sora, Veo, coding agents', '7,500 media credits / mo'],
  };
  late ModelTier _picked = widget.tier == ModelTier.free ? ModelTier.pro : widget.tier;
  String? _note;

  @override
  Widget build(BuildContext context) {
    return _GreySheet(
      title: 'Manage Subscription',
      leading: VCircleButton(icon: Icons.chevron_left_rounded, size: 44, tooltip: 'Back', onTap: widget.onBack),
      children: [
        for (final t in ModelTier.values) ...[
          VPress(
            onTap: () => setState(() {
              _picked = t;
              _note = null;
            }),
            child: AnimatedContainer(
              duration: VMotion.fast,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: _picked == t ? VColors.fillActive : VColors.fillCell,
                borderRadius: BorderRadius.circular(VRadius.md),
                border: Border.all(color: _picked == t ? Colors.white70 : Colors.transparent, width: 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(TierInfo.all[t]!.label, style: VType.headline()),
                  if (widget.tier == t) ...[
                    const SizedBox(width: 8),
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: VColors.accentGreen, shape: BoxShape.circle)),
                  ],
                  const Spacer(),
                  Text(TierInfo.all[t]!.price, style: VType.callout(weight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                for (final p in _perks[t]!) Text(p, style: VType.footnote()),
              ]),
            ),
          ),
          const SizedBox(height: VSpace.xs),
        ],
        const SizedBox(height: VSpace.xs),
        if (_picked != ModelTier.free)
          VButton(
            label: 'Continue with ${TierInfo.all[_picked]!.label}',
            variant: VButtonVariant.primary,
            expand: true,
            onTap: () => setState(() => _note = "Purchases aren't available on this link"),
          ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _note = "Purchases aren't available on this link"),
            child: Text('Restore Purchases', style: VType.callout(color: VColors.textSecondary)),
          ),
        ),
        if (_note != null) Center(child: Text(_note!, textAlign: TextAlign.center, style: VType.footnote(color: VColors.textPrimary))),
      ],
    );
  }
}

class _GreySheet extends StatelessWidget {
  final String title;
  final Widget leading;
  final List<Widget> children;
  const _GreySheet({super.key, required this.title, required this.leading, required this.children});
  @override
  Widget build(BuildContext context) => VGlass(
        material: VMaterial.modal,
        radius: VRadius.sheet,
        // v9: this fill was 0xB3 (70% opaque), so the panel behind the sheet
        // stayed legible straight through it and the two layers read as one
        // smear. A sheet is a layer: it has to occlude. Dimmed glass is still
        // there at the rim, the body is not see-through.
        fill: const Color(0xF012141A),
        padding: const EdgeInsets.fromLTRB(VSpace.md, VSpace.sm + 2, VSpace.md, VSpace.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.66),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 38,
                  child: Stack(alignment: Alignment.center, children: [
                    Align(alignment: Alignment.centerLeft, child: leading),
                    // v9: was 19/w700, which is larger than the home screen's
                    // own titles. A sheet heading is a caption, not a banner.
                    Text(title, style: VType.headline().copyWith(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                  ]),
                ),
                const SizedBox(height: VSpace.sm),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _Group extends StatelessWidget {
  final List<_Row> rows;
  const _Group({required this.rows});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(VRadius.md),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 16, color: Color(0x33FFFFFF)),
            rows[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  const _Row({this.leading, required this.title, this.value, this.onTap});
  @override
  Widget build(BuildContext context) {
    final body = Container(
      // v9: rows were 52 tall with 10/16 padding, which made a five-row list
      // taller than the screen. Tightened to match the reference density.
      color: VColors.fillCell,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(child: Text(title, style: VType.body(weight: FontWeight.w500))),
        if (value != null) Text(value!, style: VType.body(color: VColors.textSecondary)),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: VColors.textSecondary, size: 22),
        ],
      ]),
    );
    return onTap == null ? body : VPress(onTap: onTap, child: body);
  }
}
