import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:planka_app/local/planka_store.dart';

/// Ported from the ARGON 8474 AppFlowy Smart Gen backup
/// (lib/features/smartgen/widgets/counterpart_boards.dart,
/// SmartGenPhysicalCardTile, R74): 180° 3D flip that shows the card's
/// private notes on its back. The notes live on the card record
/// (`privateNotes`) in PlankaStore, so they persist with the board.
/// Not a security boundary.
class PrivateNotesFlip extends StatefulWidget {
  const PrivateNotesFlip({super.key, required this.cardId, required this.front});
  final String cardId;
  final Widget front;

  /// Which cards are showing their back (kept while Smart Gen is open).
  static final Set<String> flipped = {};

  static String notesOf(String cardId) {
    for (final c in PlankaStore.instance.cards) {
      if (c['id'] == cardId) return '${c['privateNotes'] ?? ''}';
    }
    return '';
  }

  @override
  State<PrivateNotesFlip> createState() => _PrivateNotesFlipState();
}

class _PrivateNotesFlipState extends State<PrivateNotesFlip> {
  bool get _isFlipped => PrivateNotesFlip.flipped.contains(widget.cardId);

  void _flip() => setState(() {
        if (!PrivateNotesFlip.flipped.remove(widget.cardId)) PrivateNotesFlip.flipped.add(widget.cardId);
      });

  @override
  Widget build(BuildContext context) {
    final notes = PrivateNotesFlip.notesOf(widget.cardId);
    if (notes.isEmpty && !_isFlipped) return widget.front;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _isFlipped ? math.pi : 0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, angle, _) {
        final showBack = angle > (math.pi / 2);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _buildBackSide(notes),
                )
              : Stack(children: [
                  widget.front,
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_android_rounded, size: 18),
                      tooltip: 'Flip Card to Private Notes (3D)',
                      onPressed: _flip,
                    ),
                  ),
                ]),
        );
      },
    );
  }

  Widget _buildBackSide(String notes) {
    return Card(
      elevation: 3,
      color: const Color(0xFFFFF8EC),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFE6852A)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Private Notes & Hidden Fields',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.flip_to_front_rounded, size: 18),
                  tooltip: 'Flip Back to Card Front',
                  onPressed: _flip,
                ),
              ],
            ),
            Text(
              notes.isNotEmpty ? notes : 'No private notes recorded.',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
