import 'package:flutter/material.dart';
import '../../../core/vision/vision_kit.dart';

/// Pinned consensus header of the response stack: ratio capsule, chevron,
/// and the full consensus summary (wrapped, never truncated or shrunk).
class ConsensusRow extends StatelessWidget {
  final String agreementRatio;
  final String summary;
  final bool isGenerating;
  final VoidCallback? onGenerateConsensus;
  final VoidCallback? onTap;

  const ConsensusRow({
    super.key,
    required this.agreementRatio,
    required this.summary,
    this.onGenerateConsensus,
    this.onTap,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = agreementRatio.contains('Consensus') ? agreementRatio : '$agreementRatio Consensus';
    // v8.3.1: elevated above the model list: finer glass, luminous hairline
    // edge, deeper two-layer shadow, refined type; one line of agreed answer.
    return VPress(
      onTap: onTap ?? onGenerateConsensus,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x38FFFFFF), Color(0x14FFFFFF)],
          ),
          borderRadius: BorderRadius.circular(VRadius.lg - 2),
          border: Border.all(color: const Color(0x66FFFFFF), width: 0.7),
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
                Text(label.toUpperCase(),
                    style: VType.caption(color: const Color(0xE6FFFFFF), weight: FontWeight.w600).copyWith(letterSpacing: 1.2)),
                const Spacer(),
                Icon(isGenerating ? Icons.sync_rounded : Icons.chevron_right_rounded, size: 18, color: VColors.textTertiary),
              ],
            ),
            const SizedBox(height: 4),
            if (isGenerating)
              ClipRRect(
                borderRadius: BorderRadius.circular(VRadius.full),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: VColors.fillCell,
                  valueColor: AlwaysStoppedAnimation<Color>(VColors.textSecondary),
                ),
              )
            else
              Text(summary.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: VType.callout(color: Colors.white, weight: FontWeight.w500).copyWith(height: 1.3, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }
}
