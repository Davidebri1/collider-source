import 'dart:ui' as ui;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// v9.1: floating elements materialize in and dissolve out with spring
/// physics: scale, blur and opacity driven by one critically-damped-ish spring.
class Materialize extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Alignment origin;
  final VoidCallback? onHidden;
  const Materialize({super.key, required this.child, this.visible = true, this.origin = Alignment.center, this.onHidden});
  // v9.1.6: in: a lively spring with a little settle; out: critically damped,
  // so a dissolve never overshoots, snaps or pops.
  static final SpringDescription spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.82);
  static final SpringDescription springOut = SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 1.0);
  /// 0..1 progress of the nearest enclosing materialize, for backdrop blurs
  /// (a BackdropFilter ignores the Opacity above it, so it must scale itself).
  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_MatScope>()?.v ?? 1;
  @override
  State<Materialize> createState() => _MaterializeState();
}

class _MatScope extends InheritedWidget {
  final double v;
  const _MatScope({required this.v, required super.child});
  @override
  bool updateShouldNotify(_MatScope old) => old.v != v;
}

class _MaterializeState extends State<Materialize> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 0);
  @override
  void initState() {
    super.initState();
    _go();
  }
  @override
  void didUpdateWidget(covariant Materialize old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) _go();
  }
  void _go() {
    final f = _c.animateWith(SpringSimulation(widget.visible ? Materialize.spring : Materialize.springOut, _c.value, widget.visible ? 1 : 0, _c.velocity));
    if (!widget.visible) {
      f.whenCompleteOrCancel(() {
        if (mounted && !widget.visible) widget.onHidden?.call();
      });
    }
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) {
          final v = _c.value;
          final o = v.clamp(0.0, 1.0);
          final b = (1 - o) * 10;
          // One stable tree in every frame (the filter is enabled/disabled, never
          // inserted/removed), so the subtree is never rebuilt mid-animation:
          // that rebuild was the flicker on open.
          // v9.1.6 (root cause of the grey slab after History): a
          // BackdropFilter inside a nearly transparent layer still paints its
          // blur on web, so a dissolved pane left a frosted ghost. Once a
          // dissolve is visually done, nothing is painted at all.
          if (!widget.visible && o < 0.03) return const SizedBox.shrink();
          return IgnorePointer(
            ignoring: !widget.visible,
            child: Opacity(
              opacity: o,
              child: ImageFiltered(
                enabled: b > 0.05,
                imageFilter: ui.ImageFilter.blur(sigmaX: b, sigmaY: b),
                child: Transform.scale(
                  scale: 0.9 + 0.1 * v,
                  alignment: widget.origin,
                  child: _MatScope(v: o, child: child!),
                ),
              ),
            ),
          );
        },
      );
}

/// Keeps [child] mounted while it dissolves out after [show] turns false.
/// v9.1.6c ROOT CAUSE of the grey slab: on web, when a frosted pane dissolves
/// out over the ticker, the ticker's cached layer is not repainted and keeps
/// the pane's frost (proved: one wheel tick or resize clears it). Every pane
/// that finishes hiding bumps this so the ticker rebuilds its layer.
final ValueNotifier<int> paneHiddenTick = ValueNotifier<int>(0);

class MaterializeSwitch extends StatefulWidget {
  final bool show;
  final WidgetBuilder builder;
  const MaterializeSwitch({super.key, required this.show, required this.builder});
  @override
  State<MaterializeSwitch> createState() => _MaterializeSwitchState();
}

class _MaterializeSwitchState extends State<MaterializeSwitch> {
  bool _mounted = false;
  Widget? _last;
  @override
  Widget build(BuildContext context) {
    if (widget.show) {
      _mounted = true;
      _last = widget.builder(context);
    }
    if (!_mounted || _last == null) return const SizedBox.shrink();
    return Materialize(
      visible: widget.show,
      onHidden: () {
        if (mounted && !widget.show) {
          setState(() => _mounted = false);
          WidgetsBinding.instance.addPostFrameCallback((_) => paneHiddenTick.value++);
        }
      },
      child: _last!,
    );
  }
}
