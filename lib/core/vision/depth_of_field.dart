import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Cinematic falloff. [distance] is 0 on the focal item and 1 at the farthest
/// off-focus item. The blur grows with that distance. A focal item (distance
/// 0 and [nearSigma] under half a pixel) is left untouched, so a gallery
/// preview and a centred cover stay sharp.
class DepthOfField extends StatelessWidget {
  final Widget child;
  final double distance;
  final double nearSigma;
  final double farSigma;

  const DepthOfField({
    super.key,
    required this.child,
    required this.distance,
    this.nearSigma = 0,
    this.farSigma = 12,
  });

  @override
  Widget build(BuildContext context) {
    final t = distance.clamp(0.0, 1.0);
    final sigma = nearSigma + (farSigma - nearSigma) * t;
    if (sigma < 0.45) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
      child: child,
    );
  }
}
