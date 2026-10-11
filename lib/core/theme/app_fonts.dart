import 'package:flutter/material.dart';
import 'dart:ui' as ui show FontFeature, Shadow;

/// Offline-safe bundled typography.
///
/// Drop-in replacement for the runtime `google_fonts` dependency: the same
/// two families the app uses (Instrument Sans for UI, Cormorant Garamond for
/// cinematic display), served from bundled assets instead of the network so
/// text renders identically with or without connectivity.
///
/// The named parameters mirror [TextStyle]'s constructor so every former
/// `GoogleFonts.*` call site keeps working unchanged.
class AppFonts {
  AppFonts._();

  static TextStyle instrumentSans({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    ui.Shadow? shadow,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<String>? fontFamilyFallback,
    String? debugLabel,
    Locale? locale,
  }) {
    return TextStyle(
      inherit: inherit,
      fontFamily: 'InstrumentSans',
      fontFamilyFallback: fontFamilyFallback,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      shadows: shadows ?? (shadow == null ? null : [shadow]),
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
      locale: locale,
    );
  }

  static TextStyle cormorantGaramond({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    ui.Shadow? shadow,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<String>? fontFamilyFallback,
    String? debugLabel,
    Locale? locale,
  }) {
    return TextStyle(
      inherit: inherit,
      fontFamily: 'CormorantGaramond',
      fontFamilyFallback: fontFamilyFallback,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      shadows: shadows ?? (shadow == null ? null : [shadow]),
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
      locale: locale,
    );
  }

  static TextStyle inter({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    ui.Shadow? shadow,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    List<String>? fontFamilyFallback,
    String? debugLabel,
    Locale? locale,
  }) {
    return TextStyle(
      inherit: inherit,
      fontFamily: 'Inter',
      fontFamilyFallback: fontFamilyFallback,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      shadows: shadows ?? (shadow == null ? null : [shadow]),
      fontFeatures: fontFeatures,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
      locale: locale,
    );
  }

  /// Applies the bundled Instrument Sans family across a text theme.
  static TextTheme instrumentSansTextTheme([TextTheme? base]) {
    return (base ?? ThemeData.dark().textTheme)
        .apply(fontFamily: 'InstrumentSans');
  }
}
