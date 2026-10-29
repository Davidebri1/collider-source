// Kanban DnD surface built on PowerSync Trello BoardView (CC0).
// See thirdparty/POWER_SYNC_TRELLO_LICENSE.

import 'package:flutter/material.dart';

import '../../core/theme/app_font.dart';
import 'sg_model.dart';
import 'sg_views.dart';
import 'thirdparty/board_item.dart';
import 'thirdparty/board_list.dart';
import 'thirdparty/boardview.dart';
import 'thirdparty/boardview_controller.dart';

class SgPowerKanban extends StatefulWidget {
  const SgPowerKanban({
    super.key,
    required this.store,
    required this.onOpen,
    this.multi = false,
    this.selected = const {},
    this.onSelect,
  });

  final SgStore store;
  final void Function(SgCard) onOpen;
  final bool multi;
  final Set<String> selected;
  final void Function(SgCard)? onSelect;

  @override
  State<SgPowerKanban> createState() => _SgPowerKanbanState();
}

class _SgPowerKanbanState extends State<SgPowerKanban> {
  final BoardViewController _controller = BoardViewController();

  SgStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final b = store.board;
    if (b == null) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width * 0.72;
    final lists = <BoardList>[];
    final ordered = b.orderedLists;
    for (var li = 0; li < ordered.length; li++) {
      final list = ordered[li];
      final cards = b.cardsIn(list.id);
      lists.add(BoardList(
        index: li,
        backgroundColor: const Color(0xCC1C1C1E),
        headerBackgroundColor: const Color(0xCC1C1C1E),
        header: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
              child: Text(list.title, style: appFont(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
        items: [
          for (var ci = 0; ci < cards.length; ci++)
            BoardItem(
              index: ci,
              draggable: !widget.multi,
              onTapItem: (_, __, ___) {
                final c = cards[ci];
                if (widget.multi) {
                  widget.onSelect?.call(c);
                } else {
                  widget.onOpen(c);
                }
              },
              onDropItem: (listIndex, itemIndex, oldListIndex, oldItemIndex, _) {
                if (listIndex == null || oldListIndex == null || oldItemIndex == null) return;
                final fromList = ordered[oldListIndex];
                final toList = ordered[listIndex];
                final moving = b.cardsIn(fromList.id);
                if (oldItemIndex < 0 || oldItemIndex >= moving.length) return;
                final card = moving[oldItemIndex];
                store.moveCard(card.id, toList.id, beforeIndex: itemIndex);
                setState(() {});
              },
              item: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.selected.contains(cards[ci].id) ? Colors.white : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: SgFace(card: cards[ci], board: b, compact: true),
                ),
              ),
            ),
        ],
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
          child: TextButton(
            style: TextButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size(double.infinity, 40)),
            onPressed: () {
              final c = store.addCard(SgType.task);
              if (c != null) {
                store.moveCard(c.id, list.id, beforeIndex: b.cardsIn(list.id).length);
                store.touch(() => c.title = 'Card');
                widget.onOpen(c);
              }
            },
            child: Text('+ Add a card', style: appFont(fontSize: 14, color: Colors.white70)),
          ),
        ),
      ));
    }
    lists.add(BoardList(
      index: ordered.length,
      backgroundColor: const Color(0x661C1C1E),
      header: [
        Expanded(
          child: TextButton(
            onPressed: () {
              store.addList('List');
              setState(() {});
            },
            child: Text('+ Add list', style: appFont(fontSize: 14, color: Colors.white)),
          ),
        ),
      ],
      items: const [],
    ));

    return ScrollConfiguration(
      behavior: const SgScroll(),
      child: BoardView(
        boardViewController: _controller,
        lists: lists,
        width: width,
        scrollbar: false,
        dragDelay: 180,
      ),
    );
  }
}
