import 'package:flutter/material.dart';
import 'edge_fade.dart';

// GLM (Z.ai) — conjured-element primitives, glm/spatial-consistency.
// "Small, demure elements floating, embedded in air, conjured": no hard
// container edges, suspension shadow far below, content dissolving at its
// edges, and materialization (assemble from 0.94 scale + fade + bloom)
// instead of sliding in.

/// Elliptical perimeter fade per VisionAutolayoutMenu §41:
/// mask-image: radial-gradient(ellipse at center, black 70%, transparent 100%).
class VVignette extends StatelessWidget {
  final Widget child;

  /// Fraction of the radius where the mask is still fully opaque.
  final double solid;

  const VVignette({super.key, required this.child, this.solid = 0.70});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        if (rect.width <= 0 || rect.height <= 0) {
          return const RadialGradient(colors: [Color(0xFFFFFFFF)])
              .createShader(rect);
        }
        // Scale the gradient's y axis by h/w so the circular gradient maps to
        // an ellipse matching the element's aspect (radius 0.5 then reaches
        // the edge midpoints; corners fade to fully transparent).
        final f = rect.height / rect.width;
        return RadialGradient(
          radius: 0.5,
          colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [solid * 0.5, 0.5],
          transform: _ScaleYTransform(f),
        ).createShader(rect);
      },
      child: child,
    );
  }
}

class _ScaleYTransform extends GradientTransform {
  final double f;
  const _ScaleYTransform(this.f);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.diagonal3Values(1.0, f, 1.0);
}

/// A conjured floating element: the element reads as suspended in the lit
/// volume rather than sitting in a card.
///
/// - [suspension]: a soft shadow far below the element (light from above,
///   nothing touching the surface). Never a tight card shadow.
/// - [fadeEdges]: content dissolves at the top/bottom edges (12% per end,
///   the VisionSpatialChatBox §35 mask) so nothing ends on a hard line.
/// - [vignette]: elliptical perimeter fade (§41) instead of linear fades.
/// - [materialize]: assembles in place — fade up from 94% scale with a
///   light bloom — over [materialize]; [Duration.zero] disables.
class VConjured extends StatefulWidget {
  final Widget child;
  final List<BoxShadow>? suspension;
  final bool fadeEdges;
  final bool vignette;
  final Duration materialize;
  final bool listenable;

  const VConjured({
    super.key,
    required this.child,
    this.suspension,
    this.fadeEdges = true,
    this.vignette = false,
    this.materialize = const Duration(milliseconds: 260),
    this.listenable = false,
  });

  @override
  State<VConjured> createState() => _VConjuredState();
}

class _VConjuredState extends State<VConjured> {
  /// [listenable] mode re-runs the assembly every time the widget re-enters
  /// the tree with a new identity (carousel pages, ticker slides).
  Key _materialKey = UniqueKey();

  @override
  void didUpdateWidget(covariant VConjured old) {
    super.didUpdateWidget(old);
    if (widget.listenable && old.child.runtimeType != widget.child.runtimeType) {
      _materialKey = UniqueKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body = widget.child;

    if (widget.fadeEdges) {
      body = EdgeFade(fadeTopFraction: 0.12, fadeBottomFraction: 0.12, child: body);
    }
    if (widget.vignette) {
      body = VVignette(child: body);
    }

    body = DecoratedBox(
      // Suspension: light comes from above, the element floats — the shadow
      // sits far below with a wide, soft radius. A faint white underglow
      // keeps the element lit against dark wallpapers.
      decoration: BoxDecoration(
        boxShadow: widget.suspension ?? const [
          BoxShadow(color: Color(0x40000000), blurRadius: 32, offset: Offset(0, 18)),
          BoxShadow(color: Color(0x14FFFFFF), blurRadius: 20),
        ],
      ),
      child: body,
    );

    if (widget.materialize <= Duration.zero) return body;

    return TweenAnimationBuilder<double>(
      key: _materialKey,
      tween: Tween(begin: 0, end: 1),
      duration: widget.materialize,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final settling = t < 1;
        final bloom = settling
            ? BoxShadow(
                color: const Color(0x33FFFFFF).withValues(alpha: (1 - t) * 0.35),
                blurRadius: 24 * (1 - t) + 4)
            : null;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.94 + 0.06 * t,
            child: DecoratedBox(
              // Light bloom on assembly: a glow that dies as the element
              // settles, so it appears conjured out of the air.
              decoration: BoxDecoration(
                boxShadow: bloom == null ? const <BoxShadow>[] : <BoxShadow>[bloom],
              ),
              child: child,
            ),
          ),
        );
      },
      child: body,
    );
  }
}
