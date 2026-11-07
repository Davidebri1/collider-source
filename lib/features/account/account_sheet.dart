import 'dart:async';
// Account content for Settings drill-down (preferred) and standalone host.
// Provider buttons use official Google G + Apple logo assets (branding guidelines).
import 'package:flutter/material.dart';

import '../../core/account_sync/account_sync.dart';
import '../../core/vision/vision_kit.dart';
import '../../models/model_def.dart';
import 'settings_glass.dart';

/// Standalone Account host (Settings closed). Same pane size/glass as Settings.
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
    final paneW = VPane.width(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onClose),
        // Vertically centred like Settings (no bottom nudge).
        Center(
          child: SizedBox(
            width: paneW,
            child: SettingsGlassPane(
              child: AnimatedSwitcher(
                duration: VMotion.base,
                child: _plans
                    ? UpgradePlansBody(
                        key: const ValueKey('plans'),
                        tier: widget.tier,
                        onBack: () => setState(() => _plans = false),
                      )
                    : AccountPaneBody(
                        key: const ValueKey('account'),
                        tier: widget.tier,
                        onBack: widget.onClose,
                        onOpenPlans: () => setState(() => _plans = true),
                        backIsClose: true,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared Account list — used inside Settings drill-down and standalone sheet.
class AccountPaneBody extends StatefulWidget {
  final ModelTier tier;
  final VoidCallback onBack;
  final VoidCallback onOpenPlans;
  /// When true, leading control is × (standalone); else chevron Back (drill-down).
  final bool backIsClose;

  const AccountPaneBody({
    super.key,
    required this.tier,
    required this.onBack,
    required this.onOpenPlans,
    this.backIsClose = false,
  });

  @override
  State<AccountPaneBody> createState() => _AccountPaneBodyState();
}

class _AccountPaneBodyState extends State<AccountPaneBody> {
  @override
  void initState() {
    super.initState();
    // Refresh /health when Account opens — silent if unreachable.
    unawaited(AccountSync.instance.refreshApiAvailability());
  }

  @override
  Widget build(BuildContext context) {
    final info = TierInfo.all[widget.tier]!;
    final sync = AccountSync.instance;
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final signedIn = sync.isSignedIn;
        final session = sync.session;
        final apiUp = sync.apiAvailable;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _paneHeader(
              title: 'Account',
              onLeading: widget.onBack,
              leadingIcon: widget.backIsClose ? Icons.close_rounded : Icons.chevron_left_rounded,
              leadingTooltip: widget.backIsClose ? 'Close' : 'Back',
            ),
            const SizedBox(height: 14),
            if (signedIn) ...[
              _avatar(
                label: (session?.displayName.isNotEmpty == true)
                    ? session!.displayName
                    : (session?.email ?? 'Account'),
                sub: session?.email,
              ),
              const SizedBox(height: 16),
              _group([
                _tile(
                  title: 'Sign out',
                  onTap: () async {
                    await AccountSync.instance.signOut();
                    if (mounted) setState(() {});
                  },
                ),
              ]),
            ] else if (apiUp) ...[
              const ContinueWithGoogleButton(),
              const SizedBox(height: 10),
              const ContinueWithAppleButton(),
            ] else ...[
              // Same as main today when no account API: Sign in → Apple unavailable.
              _group([
                _tile(
                  leading: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0x33FFFFFF),
                    child: Icon(Icons.person_rounded, color: Colors.white70),
                  ),
                  title: 'Sign in',
                  onTap: () => showVAlert(
                    context,
                    icon: Icons.person_outline_rounded,
                    title: 'Sign in with Apple is unavailable',
                    actions: const [VAlertChoice('OK')],
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            _group([
              _tile(title: 'Plan', value: info.label, onTap: widget.onOpenPlans),
            ]),
            const SizedBox(height: 12),
            _group([
              _tile(title: 'Manage Subscription', onTap: widget.onOpenPlans),
              _tile(title: 'Credits', value: '${info.pool}'),
              _tile(title: 'Monthly pool', value: '${info.pool}'),
            ]),
          ],
        );
      },
    );
  }
}

class UpgradePlansBody extends StatefulWidget {
  final ModelTier tier;
  final VoidCallback onBack;
  const UpgradePlansBody({super.key, required this.tier, required this.onBack});
  @override
  State<UpgradePlansBody> createState() => _UpgradePlansBodyState();
}

class _UpgradePlansBodyState extends State<UpgradePlansBody> {
  static const _perks = {
    ModelTier.free: ['Unlimited general chat', '3 models on the board', 'No media generation'],
    ModelTier.pro: ['Unlimited general', 'Image, video, audio', '3,000 media credits / mo'],
    ModelTier.elite: ['Every model', 'Sora, Veo, coding agents', '7,500 media credits / mo'],
  };
  late ModelTier _picked = widget.tier == ModelTier.free ? ModelTier.pro : widget.tier;
  String? _note;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _paneHeader(
          title: 'Manage Subscription',
          onLeading: widget.onBack,
          leadingIcon: Icons.chevron_left_rounded,
          leadingTooltip: 'Back',
        ),
        const SizedBox(height: 14),
        for (final t in ModelTier.values) ...[
          GestureDetector(
            onTap: () => setState(() {
              _picked = t;
              _note = null;
            }),
            child: AnimatedContainer(
              duration: VMotion.fast,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: _picked == t ? const Color(0x44FFFFFF) : const Color(0x33000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _picked == t ? Colors.white70 : Colors.transparent),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(TierInfo.all[t]!.label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  if (widget.tier == t) ...[
                    const SizedBox(width: 8),
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                  ],
                  const Spacer(),
                  Text(TierInfo.all[t]!.price, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                for (final p in _perks[t]!)
                  Text(p, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_picked != ModelTier.free)
          GestureDetector(
            onTap: () => setState(() => _note = "Purchases aren't available on this link"),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFF0A84FF), borderRadius: BorderRadius.circular(16)),
              child: Text(
                'Continue with ${TierInfo.all[_picked]!.label}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _note = "Purchases aren't available on this link"),
            child: const Text('Restore Purchases', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        if (_note != null)
          Center(child: Text(_note!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// Google Identity branding: white button, official multicolour G, "Continue with Google".
class ContinueWithGoogleButton extends StatelessWidget {
  const ContinueWithGoogleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _continueWithGoogle(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4), // Google guideline corner for standard button
          border: Border.all(color: const Color(0xFF747775), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/branding/google_g.png', width: 20, height: 20, filterQuality: FilterQuality.high),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                color: Color(0xFF1F1F1F),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Apple Sign in with Apple: black button, official Apple logo, "Continue with Apple".
class ContinueWithAppleButton extends StatelessWidget {
  const ContinueWithAppleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _continueWithApple(context),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8), // Apple pill-ish minimum
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/branding/apple_logo_white.png', width: 18, height: 18, filterQuality: FilterQuality.high),
            const SizedBox(width: 10),
            const Text(
              'Continue with Apple',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _continueWithGoogle(BuildContext context) async {
  final base = AccountSync.instance.baseUrl;
  final local = base.contains('localhost') || base.contains('127.0.0.1');
  if (local) {
    final ok = await AccountSync.instance.signInDev(email: 'user@collider.app', name: 'Collider');
    if (!ok && context.mounted) {
      await showVAlert(
        context,
        icon: Icons.person_outline_rounded,
        title: 'Sign in is unavailable',
        actions: const [VAlertChoice('OK')],
      );
    }
  } else if (context.mounted) {
    await showVAlert(
      context,
      icon: Icons.person_outline_rounded,
      title: 'Continue with Google',
      actions: const [VAlertChoice('OK')],
    );
  }
}

Future<void> _continueWithApple(BuildContext context) async {
  await showVAlert(
    context,
    icon: Icons.person_outline_rounded,
    title: 'Continue with Apple',
    actions: const [VAlertChoice('OK')],
  );
}

Widget _paneHeader({
  required String title,
  required VoidCallback onLeading,
  required IconData leadingIcon,
  required String leadingTooltip,
}) {
  return SizedBox(
    height: 44,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onLeading,
            child: Tooltip(
              message: leadingTooltip,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: Color(0x55000000), shape: BoxShape.circle),
                child: Icon(leadingIcon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

Widget _avatar({required String label, String? sub}) {
  return Column(children: [
    Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(color: Color(0xFF3A3A3C), shape: BoxShape.circle),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
    ),
    const SizedBox(height: 8),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    if (sub != null && sub.isNotEmpty && sub != label)
      Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
  ]);
}

Widget _group(List<Widget> tiles) => Container(
      decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: Color(0x33FFFFFF), indent: 16),
          tiles[i],
        ],
      ]),
    );

Widget _tile({Widget? leading, required String title, String? value, VoidCallback? onTap}) {
  const style = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600);
  final row = SizedBox(
    height: 50,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (leading != null) ...[leading, const SizedBox(width: 12)],
        Expanded(child: Text(title, style: style)),
        if (value != null) Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        if (onTap != null) ...[
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
        ],
      ]),
    ),
  );
  if (onTap == null) return row;
  return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
}
