import 'package:flutter/painting.dart';

/// v9.1.1: one bundled family, Google Sans Flex (static 400–700 instances).
const String kAppFont = 'GoogleSansFlex';

TextStyle appFont({TextStyle? textStyle, double? fontSize, FontWeight? fontWeight, Color? color, double? height, double? letterSpacing, TextDecoration? decoration}) =>
    (textStyle ?? const TextStyle()).copyWith(fontFamily: kAppFont, fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, letterSpacing: letterSpacing, decoration: decoration);
