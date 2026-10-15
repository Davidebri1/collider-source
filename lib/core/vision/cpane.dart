import 'dart:ui' show ImageFilter;
import 'package:flutter/widgets.dart';
import 'materialize.dart';
import 'vision_kit.dart';
import 'vision_tokens.dart';

/// v9.1.7 (David, Oct 15 5:08 AM): the ONLY way to show a pane.
///
/// Always centred. Width and max height come from [CPaneTokens] (on a phone
/// every pane has the same width). One glass material ([VFrost]) and the
/// elevation map by layer ([CLayer]). There are deliberately no width,
/// alignment, blur, colour or shadow parameters: a pane cannot be built full
/// width, off-centre, or with a hand-made shadow. tool/pane_guard.dart fails
/// the build if lib/features paints its own glass, blur or shadow.
enum CLayer { base, panel, floating, modal }

extension CLayerX on CLayer {
  List<BoxShadow> get elevation => switch (this) {
        CLayer.base => VElev.e0,
        CLayer.panel => VElev.e2,
        CLayer.floating => VElev.e6,
        CLayer.modal => VElev.e12,
      };
}

/// fill: the pane takes the whole height the shell allows (Discover, Files);
/// hug: as tall as its content, up to that height (menus, Account).
enum CPaneFit { fill, hug }

class CPaneTokens {
  CPaneTokens._();
  static bool phone(BuildContext c) => MediaQuery.sizeOf(c).width < 768;
  static double width(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return phone(c) ? (w - 104).clamp(260.0, 300.0) : (w * 0.46).clamp(480.0, 640.0);
  }
  static const double topGap = 40;
  static const double radius = VRadius.xl;
}

/// What the shell reserves at the bottom of the screen: the docked ticker
/// band and the composer, measured once in the shell. Every pane inherits it.
class CShell extends InheritedWidget {
  final double bottomReserve;
  const CShell({super.key, required this.bottomReserve, required super.child});
  static double reserveOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<CShell>()?.bottomReserve ?? 110;
  @override
  bool updateShouldNotify(CShell old) => old.bottomReserve != bottomReserve;
}

class CPane extends StatelessWidget {
  final Widget child;
  final CLayer layer;
  final CPaneFit fit;
  const CPane({super.key, required this.child, this.layer = CLayer.floating, this.fit = CPaneFit.fill});

  /// The rectangle a pane occupies, for screens that must lay out inside it.
  static double maxHeight(BuildContext c) {
    final m = MediaQuery.of(c);
    return (m.size.height - m.padding.top - CPaneTokens.topGap - CShell.reserveOf(c)).clamp(160.0, 2000.0);
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(CPaneTokens.radius);
    final mat = Materialize.of(context);
    final w = CPaneTokens.width(context);
    final maxH = maxHeight(context);
    final glass = DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: layer.elevation),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: VFrost.blur * mat, sigmaY: VFrost.blur * mat),
          child: DecoratedBox(decoration: BoxDecoration(color: VFrost.tint, borderRadius: r), child: child),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + CPaneTokens.topGap),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: w,
          height: fit == CPaneFit.fill ? maxH : null,
          child: fit == CPaneFit.fill ? glass : ConstrainedBox(constraints: BoxConstraints(maxHeight: maxH), child: glass),
        ),
      ),
    );
  }
}

/// A [CPane] with the visionOS window header (leading circle, title,
/// trailing circles): the replacement for VWindow in screens. No width,
/// height, material or shadow parameters.
class CPaneWindow extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget child;
  final CLayer layer;
  final CPaneFit fit;
  const CPaneWindow({super.key, this.title, this.leading, this.actions = const [], required this.child, this.layer = CLayer.floating, this.fit = CPaneFit.hug});

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(VSpace.sm, VSpace.sm, VSpace.sm, VSpace.xs),
      child: SizedBox(
        height: 40,
        child: Stack(alignment: Alignment.center, children: [
          if (title != null)
            Positioned.fill(
              left: leading != null ? 48 : VSpace.xxs,
              right: actions.length * 42.0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: VType.headline()),
              ),
            ),
          if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
          if (actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (int i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 6), actions[i]],
              ]),
            ),
        ]),
      ),
    );
    return CPane(
      layer: layer,
      fit: fit,
      child: Column(
        mainAxisSize: fit == CPaneFit.hug ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Flexible(fit: fit == CPaneFit.fill ? FlexFit.tight : FlexFit.loose, child: Padding(padding: const EdgeInsets.fromLTRB(VSpace.md, 0, VSpace.md, VSpace.md), child: child)),
        ],
      ),
    );
  }
}
