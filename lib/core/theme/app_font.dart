import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// AUTHORITY S-C13. Apple uses SF Pro through the system font. Every other
/// platform uses the bundled Inter variable font. Regular text is weight 510.
String? get kAppFont {
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
    return null;
  }
  return 'Inter';
}

double _weightAxis(FontWeight? weight) {
  if (weight == FontWeight.w700 || weight == FontWeight.w800 || weight == FontWeight.w900) return 700;
  if (weight == FontWeight.w600) return 600;
  if (weight == FontWeight.w300 || weight == FontWeight.w200 || weight == FontWeight.w100) return 400;
  return 510;
}

TextStyle appFont({TextStyle? textStyle, double? fontSize, FontWeight? fontWeight, Color? color, double? height, double? letterSpacing, TextDecoration? decoration}) {
  final axis = _weightAxis(fontWeight ?? textStyle?.fontWeight);
  return (textStyle ?? const TextStyle()).copyWith(
    fontFamily: kAppFont,
    fontFamilyFallback: const ['Inter', 'Helvetica Neue', 'Arial'],
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontVariations: [FontVariation('wght', axis)],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
}
