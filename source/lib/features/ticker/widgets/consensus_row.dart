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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF272736), Color(0xFF191922)],
          ),
          borderRadius: BorderRadius.circular(VRadius.lg - 2),
          border: Border.all(color: const Color(0x4DFFFFFF), width: 0.7),
          boxShadow: const [
            BoxShadow(color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 14)),
            BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
            BoxShadow(color: Color(0x1FFFFFFF), blurRadius: 10, spreadRadius: -4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.balance_rounded, size: 13, color: Color(0xE6FFFFFF)),
                const SizedBox(width: 6),
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
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.full),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: VColors.fillCell,
                  valueColor: AlwaysStoppedAnimation<Color>(VColors.textSecondary),
                ),
              ),
            ] else if (showLine) ...[
              const SizedBox(height: 4),
              // Full line, wrapped. R16: the line is not cut off.
              Text(
                summary.split('\n').first,
                style: VType.callout(color: Colors.white, weight: FontWeight.w500)
                    .copyWith(height: 1.3, letterSpacing: 0.1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
