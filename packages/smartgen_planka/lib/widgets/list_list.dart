import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';
import 'package:planka_app/models/planka_card.dart';
import 'package:planka_app/screens/ui/fullscreen_card.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

import '../models/planka_board.dart';
import '../models/planka_list.dart';
import '../models/planka_fCard.dart';
import '../models/card_models/planka_label.dart';
import '../models/card_models/planka_attachment.dart';
import '../models/card_models/planka_task.dart';
import '../models/planka_user.dart';
import '../providers/list_provider.dart';
import '../local/planka_store.dart';
import '../providers/card_provider.dart';
import '../providers/attachment_provider.dart';
import '../widgets/parts/stopwatch_display.dart';

import '../packages/kanban_board_package/custom/board.dart';
import '../packages/kanban_board_package/models/inputs.dart';
import '../features/free_drag/free_drag_board.dart';

class ListList extends StatefulWidget {
  final List<PlankaList> lists;
  final PlankaBoard currentBoard;
  final VoidCallback? onRefresh;

  const ListList(this.lists, this.currentBoard, {super.key, this.onRefresh});

  @override
  _ListListState createState() => _ListListState();
}

class _ListListState extends State<ListList> {
  final Map<String, TextEditingController> _listNameControllers = {};
  final Map<String, TextEditingController> _listNewCardControllers = {};
  // Add FocusNode to control focus on the TextField
  final Map<String, FocusNode> _focusNodesListTitle = {};
  final Map<String, FocusNode> _focusNodesListNewCard = {};
  final Map<String, Future<PlankaFullCard>> _cardFutures = {};

  // A simple in-memory cache to store data
  Map<String, Image?> imageCache = {};
  Map<String, String> dueDateCache = {};
  final Map<String, double> progressCache = {};
  final Map<String, int> completedTasksCache = {};
  final Map<String, int> totalTasksCache = {};

  final ImagePicker _picker = ImagePicker();

  Map<String, Color> labelColors = {};

  @override
  void initState() {
    super.initState();

    loadLabelColors();

    // Initialize focus nodes and controllers
    for (var list in widget.lists) {
      _listNameControllers[list.id] = TextEditingController(text: list.name);
      _focusNodesListTitle[list.id] = FocusNode();
    }

    for (var list in widget.lists) {
      _listNewCardControllers[list.id] = TextEditingController();
      _focusNodesListNewCard[list.id] = FocusNode();
    }
  }

  void _openFCardScreen(PlankaCard selectedCard) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FCardScreen(
          currentBoard: widget.currentBoard,
          card: selectedCard, // Pass the card to edit
        ),
      ),
    );

    // Check if the result indicates a refresh is needed
    if (result == 'refresh') {
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    }
  }

  void createListInBetween(String name, num currentPosition, int index, bool toLeft) {
    // Determine the position based on the neighboring lists
    double newPosition;

    if (toLeft) {
      // Create list to the left: take middle position between left and current
      if (index > 0) {
        final leftPosition = widget.lists[index - 1].position;
        newPosition = (leftPosition + currentPosition) / 2;
      } else {
        // If it's the first list, place it at a smaller position than current
        newPosition = currentPosition - 1000; // Arbitrary value for the leftmost
      }
    } else {
      // Create list to the right: take middle position between current and right
      if (index < widget.lists.length - 1) {
        final rightPosition = widget.lists[index + 1].position;
        newPosition = (currentPosition + rightPosition) / 2;
      } else {
        // If it's the last list, place it at a larger position than current
        newPosition = currentPosition + 1000; // Arbitrary value for the rightmost
      }
    }

    // Call your function to create the new list with the calculated position
    _createList(name, newPosition.toString());
  }

  void _createList(String newName, String position) {
    Provider.of<ListProvider>(context, listen: false).createList(
      newListName: newName,
      boardId: widget.currentBoard.id,
      context: context,
      newPos: position,
    ).then((_) {
      /// Call the onRefresh callback if it exists
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ListProvider>(
      builder: (context, listProvider, child) {
        final store = PlankaStore.instance;
        // Align off → free-drag canvas; Align on → column board.
        if (!store.snapAlign) {
          return FreeDragBoard(
            lists: widget.lists,
            onOpenCard: _openFCardScreen,
          );
        }
        return KanbanBoard(
          _generateBoardListsData(),

          ///Reorder Card
          onItemReorder: (oldCardIndex, newCardIndex, oldListIndex, newListIndex) {
            _moveCard(oldListIndex!, newListIndex!, oldCardIndex!, newCardIndex!);
          },

          ///Reorder List
          onListReorder: (oldListIndex, newListIndex) {
            _moveList(oldListIndex!, newListIndex!);
          },

          onListCreate: (newName) {
            if (newName != null && newName.isNotEmpty) {
              _createListFromDialog(newName);
            } else {
              showTopSnackBar(
                Overlay.of(context),
                CustomSnackBar.error(
                  message: 'not_empty_name'.tr(),
                ),
              );
            }
          },
          onRequestCreateList: _showCreateListDialog,

          backgroundColor: Colors.transparent,
        );
      },
    );
  }

  void _showCreateListDialog() {
    // Clear board focus first so the dialog field owns Flutter's text input
    // (otherwise Enter activates Cancel while the browser input holds the typed name).
    FocusManager.instance.primaryFocus?.unfocus();
    final listNameController = TextEditingController();
    // Stock: append after the last list (Create List tile sits at the end).
    final newPos = widget.lists.isEmpty
        ? '1000'
        : (widget.lists.last.position + 1000).toString();

    void submit(BuildContext ctx, String value) {
      final name = value.trim().isEmpty ? listNameController.text.trim() : value.trim();
      if (name.isEmpty) return;
      // Mirror Create Board: create then pop.
      Provider.of<ListProvider>(ctx, listen: false).createList(
        newListName: name,
        boardId: widget.currentBoard.id,
        context: ctx,
        newPos: newPos,
      ).then((_) {
        widget.onRefresh?.call();
        if (ctx.mounted) Navigator.of(ctx).pop();
      });
    }

    showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text('create_list'.tr()),
          content: TextField(
            controller: listNameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'List name',
            ),
            onSubmitted: (value) => submit(ctx, value),
          ),
          actions: [
            // ExcludeFocus so Enter never lands on Cancel (matches Create Board + David's rule).
            ExcludeFocus(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('cancel'.tr()),
              ),
            ),
            ExcludeFocus(
              child: Semantics(
                button: true,
                label: 'Confirm Create List',
                child: TextButton(
                  onPressed: () => submit(ctx, listNameController.text),
                  child: Text('create'.tr()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _createListFromDialog(String newName) {
    if (newName.trim().isEmpty) return;
    final newPos = widget.lists.isEmpty
        ? '1000'
        : (widget.lists.last.position + 1000).toString();
    Provider.of<ListProvider>(context, listen: false).createList(
      newListName: newName.trim(),
      boardId: widget.currentBoard.id,
      context: context,
      newPos: newPos,
    ).then((_) => widget.onRefresh?.call());
  }

  // Method to convert PlankaLists to BoardListsData for KanbanBoard
  List<BoardListsData> _generateBoardListsData() {
    return widget.lists.map((list) {
      // Use a local boolean to track editing state
      bool isEditingTitle = false;
      bool isEditingNewCardName = false;

      final listColorName = PlankaStore.instance.listColors[list.id];
      Color? listBg;
      if (listColorName != null && labelColors.containsKey(listColorName)) {
        listBg = labelColors[listColorName]!.withValues(alpha: 0.35);
      }

      return BoardListsData(
        width: MediaQuery.of(context).size.width * 0.9,
        backgroundColor: listBg ?? const Color.fromARGB(255, 247, 248, 252),
        headerBackgroundColor: listBg ?? const Color.fromARGB(255, 247, 248, 252),

        header: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return GestureDetector(
              onTap: () {
                // When tapping, switch to editing mode
                setState(() {
                  isEditingTitle = true;
                  // Focus the TextField when editing mode is enabled
                  _focusNodesListTitle[list.id]!.requestFocus();
                });
              },
              child: isEditingTitle
                  ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.9,
                      child: TextField(
                    controller: _listNameControllers[list.id],
                    focusNode: _focusNodesListTitle[list.id], // Use the focus node
                    autofocus: true,
                    onSubmitted: (newName) {
                      // On submit, disable editing mode and fire onRenameList
                      setState(() {
                        isEditingTitle = false;
                      });
                      _renameList(list.id, newName);
                    },
                    onTapOutside: (newName) {
                      // On submit, disable editing mode and fire onRenameList
                      setState(() {
                        isEditingTitle = false;
                      });
                    },
                    onEditingComplete: () {
                      // Disable editing mode when editing is complete
                      setState(() {
                        isEditingTitle = false;
                      });
                    },
                    ),
                  ),
                  )
                  : Container(
                width: MediaQuery.of(context).size.width * 0.9,
                color: Colors.grey[200],
                padding: const EdgeInsets.only(left: 5, bottom: 5, top: 5, right: 0),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                      list.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                    ),
                    SizedBox(
                      width: 40,
                      child: PopupMenuButton<int>(
                        padding: EdgeInsets.zero,
                        iconSize: 22,
                        icon: const Icon(Icons.menu_rounded),
                        onSelected: (value) async {
                          if (value == 2) {
                            PlankaStore.instance.sortBy = PlankaStore.instance.sortBy == 'name' ? 'position' : 'name';
                            widget.onRefresh?.call();
                          }
                          if (value == 4) {
                            PlankaStore.instance.archiveCardsInList(list.id);
                            widget.onRefresh?.call();
                          }
                          if (value == 8) {
                            // list colour — cycle palette keys
                            final keys = labelColors.keys.toList();
                            if (keys.isNotEmpty) {
                              final cur = PlankaStore.instance.listColors[list.id];
                              final i = cur == null ? 0 : (keys.indexOf(cur) + 1) % keys.length;
                              PlankaStore.instance.setListColor(list.id, keys[i]);
                              widget.onRefresh?.call();
                            }
                          }
                          if (value == 9) {
                            PlankaStore.instance.archiveList(list.id);
                            widget.onRefresh?.call();
                          }
                          if(value == 7) {
                            _showDeleteConfirmationDialog(context, list);
                          }
                          if (value == 5) {
                            final index = widget.lists.indexOf(list);
                            createListInBetween('new_list'.tr(), list.position, index, true);
                          }
                          if (value == 6) {
                            final index = widget.lists.indexOf(list);
                            createListInBetween('new_list'.tr(), list.position, index, false);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                          PopupMenuItem<int>(
                            value: 2,
                            child: Text('sort_after'.tr()),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<int>(
                            value: 3,
                            child: Text('move_all_from_list'.tr()),
                          ),
                          PopupMenuItem<int>(
                            value: 4,
                            child: Text('archive_all_from_list'.tr()),
                          ),
                          PopupMenuItem<int>(
                            value: 8,
                            child: const Icon(Icons.palette_outlined),
                          ),
                          PopupMenuItem<int>(
                            value: 9,
                            child: const Icon(Icons.archive_outlined),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<int>(
                            value: 5,
                            child: Text('create_list_left'.tr()),
                          ),
                          PopupMenuItem<int>(
                            value: 6,
                            child: Text('create_list_right'.tr()),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem<int>(
                            value: 7,
                            child: Text('delete_list'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        footer: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: const EdgeInsets.only(right: 5, left: 5, top: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                child: Semantics(
                  button: true,
                  label: 'Add Card',
                  child: GestureDetector(
                  onTap: () {
                    /// When tapping, switch to editing mode
                    setState(() {
                      isEditingNewCardName = true;
                      /// Focus the TextField when editing mode is enabled
                      _focusNodesListNewCard[list.id]!.requestFocus();
                    });
                  },

                  child: isEditingNewCardName ? Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: TextField(
                        controller: _listNewCardControllers[list.id],
                        focusNode: _focusNodesListNewCard[list.id],
                        autofocus: true,
                        onSubmitted: (newName) {
                          /// On submit, disable editing mode and fire onRenameList
                          setState(() {
                            isEditingNewCardName = false;
                          });

                          ///CREATE NEW CARD
                          Provider.of<ListProvider>(context, listen: false).createCard(
                            newCardName: _listNewCardControllers[list.id]!.text,
                            listId: list.id,
                            context: context,
                            boardId: widget.currentBoard.id,
                            newPos: list.cards.isNotEmpty
                                ? (list.cards.last.position + 1000).toString()
                                : "1000",
                          ).then((_) {
                            // Call the onRefresh callback if it exists
                            if (widget.onRefresh != null) {
                              widget.onRefresh!();
                            }
                          });

                          _listNewCardControllers[list.id]!.clear();
                        },
                        onTapOutside: (newName) {
                          // On submit, disable editing mode and fire onRenameList
                          setState(() {
                            isEditingNewCardName = false;
                          });
                        },
                      ),
                    ),
                  ) :
                  Text(
                    'create_card'.tr(),
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo),
                  ),
                ),
                ),
                ),
                if(isEditingNewCardName == false)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () {
                      _showFileSelectionOptions(list);
                    },
                    icon: const Icon(Icons.image_search_rounded),
                  ),
              ],
            ),
          );
        }),
        items: list.cards.map((card) {
          // Convert each card to a widget
          return _buildCardWidget(context, card);
        }).toList(),
      );
    }).toList();
  }

  // Build custom card widget for each PlankaCard
  Widget _buildCardWidget(BuildContext context, PlankaCard card) {
    final cardFuture = _cardFutures.putIfAbsent(card.id, () =>
        Provider.of<CardProvider>(context, listen: false).fetchCard(cardId: card.id, context: context),);
    final coverTint = PlankaStore.instance.cardCoverColors[card.id];
    final cardColor = coverTint != null ? Color(coverTint) : Colors.white;

    return Card(
      elevation: 3,
      color: cardColor,
      key: ValueKey('card_${card.id}'),
      margin: const EdgeInsets.symmetric(vertical: 0.0),
      child: Column(
        children: [
          if (card.coverAttachmentId != null)
            GestureDetector(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10.0)),
                child: SizedBox(
                  width: double.infinity,
                  child: buildCoverAttachmentImage(context, card.coverAttachmentId!, card.cardAttachment),
                ),
              ),
              onTap: () {
                _openFCardScreen(card);
              },
            ),

          ListTile(
              onTap: () {
                _openFCardScreen(card);
              },
              onLongPress: () async {
                const palette = [0xFFEA8385, 0xFFE6AE76, 0xFF72B3C6, 0xFFEA9EB0, 0xFF8BBF8A, 0xFFB0A3E0, 0x00000000];
                final picked = await showModalBottomSheet<int>(
                  context: context,
                  builder: (_) => SizedBox(
                    height: 72,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final c in palette)
                          GestureDetector(
                            onTap: () => Navigator.pop(context, c),
                            child: CircleAvatar(backgroundColor: c == 0 ? Colors.white : Color(c), radius: 16,
                              child: c == 0 ? const Icon(Icons.format_color_reset, size: 14) : null),
                          ),
                      ],
                    ),
                  ),
                );
                if (picked != null) {
                  PlankaStore.instance.setCardCoverColor(card.id, picked == 0 ? null : picked);
                  widget.onRefresh?.call();
                }
              },

              /// Labels and Card Name
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ///show padding if there is no attachment preview, otherwise no padding (looks good)
                  if(card.coverAttachmentId == null)
                    const SizedBox(height: 5,),

                  FutureBuilder<PlankaFullCard>(
                    future: cardFuture,
                    builder: (ctx, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData) {
                        return Center(child: Text('card_not_found'.tr()));
                      } else {
                        final card2 = snapshot.data!;

                        return Wrap(
                          spacing: 1.0,
                          runSpacing: 1.0,
                          children: _buildLabelWidgets(card.labels, (card2.cardLabels ?? const []), labelColors),
                        );
                      }
                    },
                  ),

                  Text(card.name, style: const TextStyle(fontSize: 13),),
                ],
              ),

              /// Due Date, Timer and Users
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if(card.tasks.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 3),
                        child: buildTaskWidget(card.id, card.tasks)
                    ),

                  ///Due Date and Stopwatch
                  Wrap(
                    spacing: 8.0,  // Horizontal space between items
                    runSpacing: 4.0,  // Vertical space between rows when wrapping occurs
                    alignment: WrapAlignment.start,  // Align items to the start of the row
                    children: [
                      if (card.dueDate != null && card.dueDate!.isNotEmpty)
                        IntrinsicWidth(
                          child: IgnorePointer(
                            child: buildDueDateWidgetPreview(card.dueDate!, card.id),
                          ),
                        ),
                      if (card.stopwatchTotal != null || card.stopwatchStartedAt != null)
                        IntrinsicWidth(
                          child: StopwatchDisplay(
                            cardId: card.id,
                            initialTotalSeconds: card.stopwatchTotal ?? 0,
                            startedAt: card.stopwatchStartedAt,
                          ),
                        ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ...card.cardMemberships.take(3).map((membership) {
                              var user = card.cardUsers.firstWhere(
                                    (user) => user.id == membership.userId,
                                orElse: () => PlankaUser(id: "", email: "", name: "", username: ""),
                              );

                              String initials = user.name.length >= 2 ? user.name.substring(0, 2) : user.name;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CircleAvatar(
                                  radius: 15,
                                  backgroundImage: user.avatarUrl != null
                                      ? NetworkImage(user.avatarUrl!)
                                      : null,
                                  child: user.avatarUrl == null ? Text(initials) : null,
                                ),
                              );
                            }).toList(),
                            if (card.cardMemberships.length > 3)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  '...',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            if (card.description != null) const Icon(Icons.short_text_rounded),
                            if (card.cardAttachment != null && card.cardAttachment.isNotEmpty) const Icon(Icons.attach_file_rounded),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              )
          ),
        ],
      ),
    );
  }

  // Load colors from JSON and store as Color objects
  Future<void> loadLabelColors() async {
    try {
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('packages/planka_app/assets/labelColors.json');
      } catch (_) {
        jsonString = await rootBundle.loadString('assets/labelColors.json');
      }
      // debugPrint(jsonString); // Log JSON content for debugging

      // Parse JSON and convert each color to a Color object
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      setState(() {
        final next = <String, Color>{};
        jsonMap.forEach((key, value) {
          final hex = value is String ? value : (value == null ? '' : '$value');
          if (hex.isEmpty) return;
          try {
            next[key] = _parseColor(hex);
          } catch (_) {}
        });
        if (next.isNotEmpty) labelColors = next;
      });
    } catch (e) {
      debugPrint('Error loading or parsing colors: $e');
    }
  }

  // Convert hex color string to Color object
  Color _parseColor(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add opacity if missing
    }
    return Color(int.parse(hexColor, radix: 16));
  }


  List<Widget> _buildLabelWidgets(List<PlankaLabel> cardLabels, List<CardLabel> previewLabels, Map<String, Color> labelColors) {
    if (cardLabels.isEmpty || previewLabels.isEmpty) {
      return [];
    }

    final validLabelIds = previewLabels.map((label) => label.labelId).toSet();
    final filteredLabels = cardLabels.where((label) => validLabelIds.contains(label.id)).toList();

    return filteredLabels.map((label) {
      // Retrieve the color for this label from labelColors
      final color = labelColors[label.color] ?? Colors.indigo; // Fallback to indigo if not found

      return Container(
        margin: const EdgeInsets.only(right: 4.0, bottom: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: Text(
          label.name,
          style: const TextStyle(color: Colors.white, fontSize: 12.0),
        ),
      );
    }).toList();
  }

  Widget buildTaskWidget(String cardId, List<PlankaTask> tasks){

    // Calculate task data
    final int completedTasks = tasks.where((task) => task.isCompleted).length;
    final int totalTasks = tasks.length;
    final double progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    // Check cache first
    if (progressCache.containsKey(cardId) &&
        completedTasksCache.containsKey(cardId) &&
        totalTasksCache.containsKey(cardId)) {
      return Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 7),
              child: LinearProgressIndicator(
                value: progress,
                color: (completedTasks / totalTasks == 1)
                    ? Colors.green
                    : Colors.indigo,
                minHeight: 8,
                borderRadius: const BorderRadius.all(Radius.circular(5)),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Text('$completedTasks/$totalTasks'),
        ],
      );
    }

    /// Cache the results
    progressCache[cardId] = progress;
    completedTasksCache[cardId] = completedTasks;
    totalTasksCache[cardId] = totalTasks;

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 7),
            child: LinearProgressIndicator(
              value: progress,
              color: (completedTasks / totalTasks == 1)
                  ? Colors.green
                  : Colors.indigo,
              minHeight: 8,
              borderRadius: const BorderRadius.all(Radius.circular(5)),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Text('$completedTasks/$totalTasks'),
      ],
    );
  }

  Widget buildDueDateWidgetPreview(String newDueDate, String cardId){
    DateTime dueDate = DateTime.parse(newDueDate);
    DateTime now = DateTime.now();
    bool isOverdue = dueDate.isBefore(now);

    Duration difference = dueDate.difference(now);
    String formattedDate = "${dueDate.day.toString().padLeft(2, '0')}.${dueDate.month.toString().padLeft(2, '0')}.${dueDate.year}";

    String result;
    if (difference.isNegative) {
      result = formattedDate;
    } else {
      result = formattedDate;
    }


    // Check if the due date result is already in the cache
    if (dueDateCache.containsKey(dueDate)) {
      // Cache the calculated due date result
      dueDateCache[dueDate.toString()] = result;
    }

    return GestureDetector(
      onTap: () async {
        final DateTime? dateTime = await showOmniDateTimePicker(
            context: context,
            initialDate: dueDate
        );

        ///Update Card Due Date
        if(dateTime != null) {
          await Provider.of<CardProvider>(context, listen: false).updateCardDueDate(cardId: cardId, newDueDate: dateTime.toString()).then((_) {
            // Call the onRefresh callback if it exists
            if (widget.onRefresh != null) {
              widget.onRefresh!();
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 4.0, bottom: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isOverdue ? Colors.red[100] : Colors.green[100],
          borderRadius: BorderRadius.circular(5.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Icon(Icons.calendar_month_rounded),
            const SizedBox(width: 5,),
            Text(
              result,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCoverAttachmentImage(BuildContext context, String coverAttachmentId, List<PlankaAttachment> cardAttachments) {
    final coverAttachment = cardAttachments.firstWhere(
          (attachment) => attachment.id == coverAttachmentId,
      orElse: () => PlankaAttachment(id: '', createdAt: '', name: '', cardId: '', creatorUserId: ''),
    );

    if (coverAttachment.coverUrl != null) {
      // Check if the image is already in the cache
      if (imageCache.containsKey(coverAttachment.coverUrl!)) {
        // Return the cached image
        return imageCache[coverAttachment.coverUrl!] ?? const SizedBox.shrink();
      }

      // Fetch and cache the image if it's not already cached
      return FutureBuilder<Image?>(
        future: Provider.of<AttachmentProvider>(context, listen: false)
            .fetchAttachmentImage(
          myUrl: coverAttachment.coverUrl!,
          context: context,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          } else if (snapshot.hasError) {
            return const SizedBox.shrink();
          } else if (snapshot.hasData) {
            // Cache the fetched image
            imageCache[coverAttachment.coverUrl!] = snapshot.data!;
            return snapshot.data!;
          } else {
            return const SizedBox.shrink();
          }
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _moveCard(int oldListIndex, int newListIndex, int oldCardIndex, int newCardIndex) async {
    // Ensure card is defined before moving
    var card;

    // Validate the list and card indices to avoid out-of-bounds errors
    if (oldListIndex < 0 || oldListIndex >= widget.lists.length ||
        newListIndex < 0 || newListIndex >= widget.lists.length) {
      debugPrint('Invalid list index');
      return;
    }

    if (oldCardIndex < 0 || oldCardIndex >= widget.lists[oldListIndex].cards.length ||
        newCardIndex < 0 || newCardIndex > widget.lists[newListIndex].cards.length) { // Allow newCardIndex to be equal to the list length (inserting at the end)
      debugPrint('Invalid card index');
      return;
    }

    // Safely remove the card from the old list and insert it into the new list
    setState(() {
      card = widget.lists[oldListIndex].cards.removeAt(oldCardIndex);
      widget.lists[newListIndex].cards.insert(newCardIndex, card);
    });

    // Ensure the card has a valid ID
    if (card == null || card.id == null) {
      debugPrint('Invalid card data');
      return;
    }

    String cardId = card.id;

    // Determine the new position based on the cards above and below the moved card
    num posAbove = newCardIndex > 0 ? widget.lists[newListIndex].cards[newCardIndex - 1].position ?? 0 : 0;
    num posBelow = newCardIndex < widget.lists[newListIndex].cards.length - 1
        ? widget.lists[newListIndex].cards[newCardIndex + 1].position ?? widget.lists[newListIndex].cards.last.position + 1000
        : widget.lists[newListIndex].cards.last.position + 1000;

    double newPosDouble = (posAbove + posBelow) / 2;
    int newPosFinal = newPosDouble.ceil();

    // Try to update the backend with the new card position
    try {
      await Provider.of<ListProvider>(context, listen: false).reorderCard(
        context: context,
        cardId: cardId,
        newListId: widget.lists[newListIndex].id,
        newPosition: newPosFinal,
      );
    } catch (error) {
      debugPrint('Error reordering card: $error');

      // Rollback changes in case of failure
      setState(() {
        // Revert the card to the original position in the old list
        widget.lists[newListIndex].cards.removeAt(newCardIndex);
        widget.lists[oldListIndex].cards.insert(oldCardIndex, card);
      });
    }

    setState(() {
      Provider.of<ListProvider>(context, listen: false).fetchLists(boardId: widget.lists[newListIndex].cards[0].boardId, context: context);
    });
  }

  Future<void> _moveList(int oldIndex, int newIndex) async {
    // Check if the indices are valid before attempting the move
    if (oldIndex < 0 || oldIndex >= widget.lists.length || newIndex < 0 || newIndex >= widget.lists.length) {
      log("Invalid indices: oldIndex = $oldIndex, newIndex = $newIndex");
      return;
    }

    String listId = widget.lists[oldIndex].id;

    // Safely update the UI state
    setState(() {
      // Move the list within the widget.lists array
      final list = widget.lists.removeAt(oldIndex);
      widget.lists.insert(newIndex, list);
    });

    log("Moved list with ID $listId from index $oldIndex to $newIndex");

    // Calculate positions based on the new index
    num posLeft = (newIndex > 0 && widget.lists[newIndex - 1].position != null)
        ? widget.lists[newIndex - 1].position
        : 0; // Handle edge case where it's the first item

    num posRight = (newIndex < widget.lists.length - 1 && widget.lists[newIndex + 1].position != null)
        ? widget.lists[newIndex + 1].position
        : widget.lists.last.position + 1000; // Handle edge case where it's the last item

    double newPosDouble = (posLeft + posRight) / 2;
    int newPosFinal = newPosDouble.ceil();

    log("Calculated new position: $newPosFinal");

    // Send the HTTP request to reorder the list
    try {
      await Provider.of<ListProvider>(context, listen: false).reorderList(
        context: context,
        listId: listId,
        boardId: widget.currentBoard.id,
        newPosition: newPosFinal,
      );
      log("Successfully reordered list $listId to new position $newPosFinal");
    } catch (error) {
      log("Error reordering list: $error");

      // Rollback the UI change in case of error
      setState(() {
        final list = widget.lists.removeAt(newIndex);
        widget.lists.insert(oldIndex, list);
      });
      log("Rolled back list movement due to error");
    }
  }

  Future<void> _renameList(String listId, String newName) async {
    final listProvider = Provider.of<ListProvider>(context, listen: false);

    // Update the list name on the server
    await listProvider.updateListName(listProvider.lists.firstWhere((list) => list.id == listId), newName).then((_) {
      // Call the onRefresh callback if it exists
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    });
  }

  void _showDeleteConfirmationDialog(BuildContext context, PlankaList list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_list_confirmation.0'.tr(), textAlign: TextAlign.center),
        content: Text('delete_list_confirmation.1'.tr()),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Provider.of<ListProvider>(context, listen: false)
                  .deleteList(list.id).then((_) {
                // Call the onRefresh callback if it exists
                if (widget.onRefresh != null) {
                  widget.onRefresh!();
                }
              });
              Navigator.of(ctx).pop();
            },
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  void _showFileSelectionOptions(PlankaList list) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('file_picker.from_gallery'.tr()),
                onTap: () async {
                  await pickImageFromGalleryAndAttach(context, list.id, widget.currentBoard.id, 'new_card'.tr(), (list.cards.last.position + 1000).toString());
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('file_picker.from_photo'.tr()),
                onTap: () async {
                  await takePhotoAndAttach(context, list.id, widget.currentBoard.id, 'new_card'.tr(), (list.cards.last.position + 1000).toString());
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text('file_picker.from_file'.tr()),
                onTap: () async {
                  await pickFileAndAttach(context, list.id, widget.currentBoard.id, 'new_card'.tr(), (list.cards.last.position + 1000).toString());
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> createCardAndAttachFile({
    required BuildContext context,
    required String listId,
    required String boardId,
    required String newCardName,
    required String newPos,
    required Future<({String name, Uint8List bytes})?> Function() pickFileFunction,
  }) async {
    try {
      final cardData = await context.read<ListProvider>().createCardForNewAttachment(
        newCardName: newCardName,
        listId: listId,
        context: context,
        boardId: boardId,
        newPos: newPos,
      );
      if (cardData == null || !cardData.containsKey('item') || cardData['item'] == null || !cardData['item'].containsKey('id') || cardData['item']['id'] == null) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.info(message: 'error_creating_card_missing_id'.tr()));
        return;
      }
      final String cardId = cardData['item']['id'].toString();
      final picked = await pickFileFunction();
      if (picked == null) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.info(message: 'no_file_selected'.tr()));
        return;
      }
      await context.read<AttachmentProvider>().createAttachment(
        context: context, cardId: cardId, name: picked.name, bytes: picked.bytes,
      );
      await context.read<CardProvider>().updateCardCoverAttachId(
        context: context, cardId: cardId, newCardCoverAttachId: null,
      );
      if (widget.onRefresh != null) widget.onRefresh!();
      if (context.mounted) Navigator.of(context).pop();
      showTopSnackBar(Overlay.of(context), CustomSnackBar.success(message: 'added_attachment'.tr()));
    } catch (e) {
      showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: "${'error'.tr()}: $e."));
    }
  }

  Future<void> pickImageFromGalleryAndAttach(BuildContext context, String listId, String boardId, String newCardName, String newPos) async {
    await createCardAndAttachFile(
      context: context, listId: listId, boardId: boardId, newCardName: newCardName, newPos: newPos,
      pickFileFunction: () async {
        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
        if (pickedFile == null) return null;
        return (name: pickedFile.name, bytes: await pickedFile.readAsBytes());
      },
    );
  }

  Future<void> takePhotoAndAttach(BuildContext context, String listId, String boardId, String newCardName, String newPos) async {
    await createCardAndAttachFile(
      context: context, listId: listId, boardId: boardId, newCardName: newCardName, newPos: newPos,
      pickFileFunction: () async {
        final pickedFile = await _picker.pickImage(source: ImageSource.camera);
        if (pickedFile == null) return null;
        return (name: pickedFile.name, bytes: await pickedFile.readAsBytes());
      },
    );
  }

  Future<void> pickFileAndAttach(BuildContext context, String listId, String boardId, String newCardName, String newPos) async {
    await createCardAndAttachFile(
      context: context, listId: listId, boardId: boardId, newCardName: newCardName, newPos: newPos,
      pickFileFunction: () async {
        final result = await FilePicker.platform.pickFiles(withData: true);
        if (result == null || result.files.isEmpty) return null;
        final f = result.files.single;
        return (name: f.name, bytes: f.bytes ?? Uint8List(0));
      },
    );
  }
}
