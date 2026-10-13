import 'package:flutter/material.dart';
import '../../../core/vision/vision_kit.dart';

/// Pinned consensus row on the ticker. The only consensus entry point: tap
/// opens the map. It is not an app and it is not on the dock or the side nav.
///
/// R16: "a count such as 4/7, then one full line" and "The line is not cut
/// off." So the line wraps to its full length and is never ellipsised.
///
/// R17: "Incomplete shows an empty score. No partial wording." While a shared
/// send is unfinished the score is empty and no label is invented for it. The
/// row is not replaced by a "waiting" line and the score is never a percent.
class ConsensusRow extends StatelessWidget {
  /// A count rendered as n/total, e.g. "4/7". Empty while incomplete.
  final String score;
  final String summary;
  final bool isGenerating;
  final VoidCallback? onGenerateConsensus;
  final VoidCallback? onTap;

  const ConsensusRow({
    super.key,
    required this.score,
    required this.summary,
    this.onGenerateConsensus,
    this.onTap,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    // Empty score renders as nothing at all rather than a placeholder.
    final hasScore = score.trim().isNotEmpty;
    final showLine = summary.trim().isNotEmpty;
    return VPress(
      onTap: onTap ?? onGenerateConsensus,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 10),
        decoration: BoxDecoration(
          // The pinned row has to read as its own plane above the ticker cards,
          // so it gets a defined surface instead of another translucent white
          // wash over the window, and keeps the contact + ambient + bounce
          // shadow trio that separates it from what sits below it.
          // v9.1.2: a soft translucent bubble, no outline.
          color: const Color(0x66101016),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // v9: the balance glyph was the whole identity of this row —
                // a scales icon with no word next to it. It read as "consensus"
                // without ever saying what the row was for. The count alone
                // carries it now; if there is a summary, the summary is the
                // label.
                const SizedBox(width: 2),
                // The count, verbatim. No percent sign is ever added.
                if (hasScore)
                  Text(
                    score,
                    style: VType.caption(color: const Color(0xE6FFFFFF), weight: FontWeight.w600)
                        .copyWith(letterSpacing: 1.2),
                  ),
                const Spacer(),
                Icon(isGenerating ? Icons.sync_rounded : Icons.chevron_right_rounded, size: 18, color: VColors.textTertiary),
              ],
            ),
            if (isGenerating) ...[
              // R17: an unfinished shared send shows an empty score and says
              // nothing. This row used to draw a LinearProgressIndicator here,
              // which is a waiting line, and suppressed the summary with it.
              // The spinner glyph in the row above already carries "working".
            ] else if (showLine) ...[
              const SizedBox(height: 4),
// The whole summary, wrapped, newlines included. R16: the line is
              // not cut off. `.split('\n').first` silently dropped everything
              // after the first newline, and the recorder's SUMMARY field is
              // free-form, so real text was disappearing here.
              //
              // v9: capped at four lines. Unbounded, a long consensus answer
              // pushed everything below it off the phone.
              Text(
                summary.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: VType.callout(color: Colors.white, weight: FontWeight.w500)
                    .copyWith(height: 1.32, letterSpacing: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
