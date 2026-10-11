import 'dart:math' as math;
import 'package:flutter/material.dart';

/// v8.3.1 ambient layer: slow, GPU-cheap touches that never move controls.

/// Breathing light emittance behind a child (a soft coloured shadow whose
/// strength rises and falls). Paint-only: layout never changes.
class AmbientGlow extends StatefulWidget {
  final Color color;
  final Widget child;
  final double radius;
  final Duration period;
  final double min, max;
  final double phase;
  const AmbientGlow({super.key, required this.color, required this.child, this.radius = 18, this.period = const Duration(milliseconds: 3600), this.min = 0.10, this.max = 0.32, this.phase = 0});
  @override
  State<AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<AmbientGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)
    ..value = widget.phase % 1
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) {
        final t = Curves.easeInOutSine.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: widget.min + (widget.max - widget.min) * t), blurRadius: 14 + 10 * t, spreadRadius: -2)],
          ),
          child: child,
        );
      },
    );
  }
}

/// A faint specular band that sweeps across a surface every [period]
/// (most of the time it rests off-surface). Ignores pointers.
class SpecularSweep extends StatefulWidget {
  final Widget child;
  final double radius;
  final Duration period;
  final double strength;
  const SpecularSweep({super.key, required this.child, this.radius = 30, this.period = const Duration(seconds: 9), this.strength = 0.10});
  @override
  State<SpecularSweep> createState() => _SpecularSweepState();
}

class _SpecularSweepState extends State<SpecularSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  // Sweep during the first 28% of the cycle, rest otherwise.
                  final p = (_c.value / 0.28).clamp(0.0, 1.0);
                  if (p >= 1.0) return const SizedBox.expand();
                  final x = -1.6 + 3.2 * Curves.easeInOutCubic.transform(p);
                  final a = math.sin(p * math.pi) * widget.strength;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(x - 0.5, -1),
                        end: Alignment(x + 0.5, 1),
                        colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slow light drift along a panel's edge: a hairline whose bright spot
/// travels around the border. Paint-only overlay.
class EdgeLightDrift extends StatefulWidget {
  final Widget child;
  final double radius;
  const EdgeLightDrift({super.key, required this.child, this.radius = 30});
  @override
  State<EdgeLightDrift> createState() => _EdgeLightDriftState();
}

class _EdgeLightDriftState extends State<EdgeLightDrift> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _EdgePainter(_c.value, widget.radius)),
          ),
        ),
      ),
    ]);
  }
}

class _EdgePainter extends CustomPainter {
  final double t, r;
  _EdgePainter(this.t, this.r);
  @override
  void paint(Canvas canvas, Size s) {
    final rr = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(r)).deflate(0.5);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = SweepGradient(
        transform: GradientRotation(t * 2 * math.pi),
        colors: const [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
        stops: const [0.0, 0.08, 0.18, 1.0],
      ).createShader(Offset.zero & s);
    canvas.drawRRect(rr, p);
  }

  @override
  bool shouldRepaint(_EdgePainter o) => o.t != t;
}
