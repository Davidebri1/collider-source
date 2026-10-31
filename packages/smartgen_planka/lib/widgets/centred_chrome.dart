import 'package:flutter/material.dart';

/// Centred screen / sheet / section title. Leading and trailing sit at the
/// edges; the label stays in the middle. Data fields stay left-aligned.
class CentredChromeTitle extends StatelessWidget {
  const CentredChromeTitle(
    this.text, {
    super.key,
    this.style,
    this.leading,
    this.trailing,
    this.height = 44,
  });

  final String text;
  final TextStyle? style;
  final Widget? leading;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final side = (leading != null || trailing != null) ? 48.0 : 0.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (leading != null) Align(alignment: Alignment.centerLeft, child: leading!),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing!),
        ],
      ),
    );
  }
}
