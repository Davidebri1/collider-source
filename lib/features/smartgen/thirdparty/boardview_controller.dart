// Ported from powersync-supabase-trello (CC0 1.0). See POWER_SYNC_TRELLO_LICENSE.
// Scrollbars disabled for Collider (no scrollbars / no progress bars).

import 'package:flutter/animation.dart';

import 'boardview.dart';

class BoardViewController {
  BoardViewController();

  late BoardViewState state;

  Future<void> animateTo(int index, {Duration? duration, Curve? curve}) async {
    double offset = index * state.widget.width;
    if (state.boardViewController.hasClients) {
      await state.boardViewController
          .animateTo(offset, duration: duration!, curve: curve!);
    }
  }
}
