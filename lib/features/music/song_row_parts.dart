// Song row parts shared by every song list (v8.3, DEVIATIONS.md D37): the
// per-row play / pause button and the fade-clipped title.
//
// Button geometry from the Figma music widget rows (file YEuK4CL2uyECUhvGEcgCNS,
// node 4461:2197 "Recently Played", rows 4461:2220/2230/2240): a 28 px circle,
// white 10 % fill, a 10.3 x 11.6 play glyph, in a fixed column at the row's
// end. The circle is the app's play button (VCircleButton look) scaled to
// 28 px; its hit target is 44 x 44.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/vision/vision_kit.dart';

class SongPlayButton extends StatefulWidget {
  /// This row's song is the one playing: shows pause.
  final bool playing;
  final VoidCallback? onTap;
  final IconData? icon; // overrides play / pause (the carousel's skip)
  final String? tooltip;
  const SongPlayButton({super.key, required this.playing, this.onTap, this.icon, this.tooltip});

  /// Fixed column width = hit target.
  static const double hit = 44;
  static const double size = 28;

  @override
  State<SongPlayButton> createState() => _SongPlayButtonState();
}

class _SongPlayButtonState extends State<SongPlayButton> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    if (isDismissTooltip(widget.tooltip)) return const SizedBox.shrink();
    final enabled = widget.onTap != null;
    final fill = !enabled
        ? const Color(0x0DFFFFFF)
        : _down
            ? const Color(0x47FFFFFF)
            : _hover
                ? const Color(0x2EFFFFFF)
                : widget.playing
                    ? VColors.fillActive
                    : const Color(0x1AFFFFFF); // Figma: white 10 %
    final icon = widget.icon ?? (widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded);
    final label = widget.tooltip ?? (widget.playing ? 'Pause' : 'Play');
    return Semantics(
      button: true,
      label: label,
      // Keyboard focus: Tab reaches the button, Enter / Space press it, and a
      // focus ring shows around the circle.
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: enabled
              ? (_) {
                  setState(() => _down = true);
                  HapticFeedback.selectionClick();
                }
              : null,
          onTapUp: enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: enabled ? () => setState(() => _down = false) : null,
          child: SizedBox(
            width: SongPlayButton.hit,
            height: SongPlayButton.hit,
            child: Center(
              child: AnimatedScale(
                scale: _down ? 0.9 : 1,
                duration: VMotion.fast,
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: VMotion.fast,
                  width: SongPlayButton.size,
                  height: SongPlayButton.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(
                      color: _focus
                          ? const Color(0xE6FFFFFF)
                          : widget.playing
                              ? VColors.borderHeavy
                              : VColors.borderLight,
                      width: _focus ? 2 : 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  // Material play glyph: 14/24 of the box is the triangle, so
                  // 20 px draws the Figma 11.6 px glyph.
                  child: Icon(icon, size: 20, color: enabled ? VColors.textPrimary : VColors.textTertiary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line title that never ellipsizes: [align] when it fits; otherwise
/// start-aligned and faded out over the last [fade] px of its own column.
class FadeTitle extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Alignment align;
  final double fade;
  final String? semanticsLabel;
  const FadeTitle(this.text, {super.key, required this.style, this.align = Alignment.centerLeft, this.fade = 24, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    // Playtest: titles wrap, never cut or fade.
    return Align(alignment: align, child: Text(text, maxLines: 2, softWrap: true, textAlign: align.x > 0.5 ? TextAlign.right : (align.x.abs() < 0.5 ? TextAlign.center : TextAlign.left), style: style, semanticsLabel: semanticsLabel));
  }
}

/// A song row from the Figma library list (file YEuK4CL2uyECUhvGEcgCNS,
/// "Your Library" rows in node 417:6219: 64 px art radius 5, gap 14, title
/// 20 / subtitle 18 #BDBDBD with gap 7, pitch 82) at a phone scale of
/// 398 / 524, with the row's own play / pause button in a fixed end column.
class LibrarySongRow extends StatelessWidget {
  final Widget art;
  final String title;
  final String? subtitle;
  final bool current;
  final bool playing;
  final VoidCallback? onPlay;
  final String? tooltip;
  final TextStyle? titleStyle;
  const LibrarySongRow({
    super.key,
    required this.art,
    required this.title,
    this.subtitle,
    this.current = false,
    required this.playing,
    this.onPlay,
    this.tooltip,
    this.titleStyle,
  });

  static const double scale = 398 / 524;
  static const double height = 82 * scale;

  @override
  Widget build(BuildContext context) {
    const s = scale;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(5), child: SizedBox.square(dimension: 64 * s, child: art)),
          const SizedBox(width: 14 * s),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(constraints: BoxConstraints(minHeight: 24 * s), child: FadeTitle(
                    title,
                    style: titleStyle ??
                        VType.body(weight: current ? FontWeight.w600 : FontWeight.w400).copyWith(fontSize: 20 * s, height: 1.2),
                    semanticsLabel: playing ? '$title, playing' : null,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 7 * s),
                  ConstrainedBox(constraints: BoxConstraints(minHeight: 22 * s), child: FadeTitle(subtitle!, style: VType.footnote(color: const Color(0xFFBDBDBD)).copyWith(fontSize: 18 * s, height: 1.2)),
                  ),
                ],
              ],
            ),
          ),
          // row tap plays; no redundant per-row play button
        ],
      ),
    );
  }
}
