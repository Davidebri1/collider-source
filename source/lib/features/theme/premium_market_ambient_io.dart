import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../models/theme_def.dart';
import 'premium_market_ambient.dart' show AmbientGlass;
import 'theme_living_media.dart';

/// Native: the live wallpaper renders to a texture, so Flutter filters apply.
/// SimpleBackgroundVideo.tsx:70-71, CSS order blur(20px) -> brightness(0.5)
/// -> contrast(1.2), then opacity 0.7 (0.3 while loading is not tracked here).
/// Owned themes lift to brightness 1 / opacity 1 (DEVIATIONS.md D5).
/// Native glass ([glass]) is Flutter BackdropFilter in the market view.
///
/// Bug 1: the theme swap is a crossfade, not a rebuild. A selection used to
/// dispose the outgoing controller immediately, which left the incoming
/// poster frozen and dim while its loop initialised, then snapped the video in.
/// Here the outgoing theme stays mounted underneath for the length of the
/// fade, so the change is one continuous move.
class AmbientMedia extends StatelessWidget {
  final WallpaperTheme theme;
  final bool owned;
  final Size viewport;
  final List<AmbientGlass> glass;

  /// How long one theme change takes to crossfade.
  static const Duration crossfade = Duration(milliseconds: 620);

  const AmbientMedia({
    super.key,
    required this.theme,
    this.owned = false,
    this.viewport = Size.zero,
    this.glass = const [],
  });

  static ColorFilter _brightness(double b) => ColorFilter.matrix(<double>[
        b, 0, 0, 0, 0,
        0, b, 0, 0, 0,
        0, 0, b, 0, 0,
        0, 0, 0, 1, 0,
      ]);

  // contrast(1.2): c*x + (0.5 - 0.5*c)  ->  offset -0.1 * 255 = -25.5
  static const ColorFilter _contrast = ColorFilter.matrix(<double>[
    1.2, 0, 0, 0, -25.5,
    0, 1.2, 0, 0, -25.5,
    0, 0, 1.2, 0, -25.5,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: owned ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: ImageFiltered(
        imageFilter:
            ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.clamp),
        // The outgoing theme stays mounted and playing underneath the incoming
        // one for the whole fade. AnimatedSwitcher is what makes the change
        // read as a deliberate transition rather than a swap to a frozen poster.
        child: AnimatedSwitcher(
          duration: crossfade,
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          // Both loops are silent and both are blurred identically, so a plain
          // crossfade needs no slide or scale to read as depth.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: <Widget>[...previous, if (current != null) current],
          ),
          child: ThemeLivingBackdrop(key: ValueKey(theme.id), theme: theme, preferVideo: true),
        ),
      ),
      builder: (context, t, child) => Opacity(
        opacity: 0.7 + 0.3 * t,
        child: ColorFiltered(
          colorFilter: _contrast,
          child: ColorFiltered(colorFilter: _brightness(0.5 + 0.5 * t), child: child),
        ),
      ),
    );
  }
}
