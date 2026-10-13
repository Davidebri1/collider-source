import 'dart:ui' as ui;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// v9.1: floating elements materialize in and dissolve out with spring
/// physics: scale, blur and opacity driven by one critically-damped-ish spring.
class Materialize extends StatefulWidget {
  final Widget child;
  final bool visible;
  final Alignment origin;
  const Materialize({super.key, required this.child, this.visible = true, this.origin = Alignment.center});
  static final SpringDescription spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.82);
  @override
  State<Materialize> createState() => _MaterializeState();
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
  void _go() => _c.animateWith(SpringSimulation(Materialize.spring, _c.value, widget.visible ? 1 : 0, _c.velocity));
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
          Widget w = Transform.scale(scale: 0.9 + 0.1 * v, alignment: widget.origin, child: child);
          if (b > 0.2) w = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: b, sigmaY: b), child: w);
          return IgnorePointer(ignoring: !widget.visible, child: Opacity(opacity: o, child: w));
        },
      );
}

/// Keeps [child] mounted while it dissolves out after [show] turns false.
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
    } else if (_mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !widget.show) setState(() => _mounted = false);
      });
    }
    if (!_mounted || _last == null) return const SizedBox.shrink();
    return Materialize(visible: widget.show, child: _last!);
  }
}
