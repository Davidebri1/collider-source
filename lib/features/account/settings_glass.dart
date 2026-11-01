import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/vision/materialize.dart';
import '../../core/vision/vision_kit.dart';

/// Dense Settings-matched glass — content behind the pane must not be readable.
class SettingsGlassPane extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const SettingsGlassPane({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 16),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return SuspendedFrost(
      edge: 0.04,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 40 * Materialize.of(context),
            sigmaY: 40 * Materialize.of(context),
          ),
          child: Container(
            color: const Color(0xC8505050),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
