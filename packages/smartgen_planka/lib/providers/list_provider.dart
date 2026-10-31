import 'package:flutter/material.dart';
import '../local/planka_store.dart';
import '../models/card_models/planka_attachment.dart';
import '../models/card_models/planka_card_membership.dart';
import '../models/card_models/planka_label.dart';
import '../models/card_models/planka_task.dart';
import '../models/planka_list.dart';
import '../models/planka_card.dart';
import '../models/planka_user.dart';
import 'auth_provider.dart';

class ListProvider with ChangeNotifier {
  List<PlankaList> _lists = [];
  final AuthProvider authProvider;

  ListProvider(this.authProvider);

  List<PlankaList> get lists => _lists;

  Future<void> fetchLists({required String boardId, required BuildContext context}) async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final responseData = store.boardDetailPayload(boardId);
    final included = Map<String, dynamic>.from((responseData['included'] as Map?) ?? {});

    final List<PlankaTask> allTasks = ((included['tasks'] as List?) ?? const [])
        .map((json) => PlankaTask.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    final Map<String, List<PlankaTask>> taskMap = {};
    for (var task in allTasks) {
      taskMap.putIfAbsent(task.cardId, () => []).add(task);
    }

    final List<PlankaLabel> allLabels = ((included['labels'] as List?) ?? const [])
        .map((json) => PlankaLabel.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    final Map<String, List<PlankaLabel>> labelMap = {};
    for (var label in allLabels) {
      labelMap.putIfAbsent(label.boardId, () => []).add(label);
    }

    // card-specific labels via cardLabels join
    final cardLabelRows = ((included['cardLabels'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final labelById = {for (final l in allLabels) l.id: l};

    final List<PlankaCardMembership> allCardMemberships =
        ((included['cardMemberships'] as List?) ?? const [])
            .map((json) => PlankaCardMembership.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
    final Map<String, List<PlankaCardMembership>> cardMembershipMap = {};
    for (var membership in allCardMemberships) {
      cardMembershipMap.putIfAbsent(membership.cardId, () => []).add(membership);
    }

    final List<PlankaAttachment> allCardAttachments =
        ((included['attachments'] as List?) ?? const [])
            .map((json) => PlankaAttachment.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
    final Map<String, List<PlankaAttachment>> cardAttachmentMap = {};
    for (var attachment in allCardAttachments) {
      cardAttachmentMap.putIfAbsent(attachment.cardId, () => []).add(attachment);
    }

    final List<PlankaUser> allCardUsers = ((included['users'] as List?) ?? const [])
        .map((json) => PlankaUser.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    final Map<String, PlankaUser> cardUsersMap = {for (var u in allCardUsers) u.id: u};

    final List<PlankaCard> boardCards = ((included['cards'] as List?) ?? const []).map((json) {
      final m = Map<String, dynamic>.from(json as Map);
      final String cardId = m['id'] as String;
      final String cardBoardId = m['boardId'] as String;
      final List<PlankaTask> cardTasks = taskMap[cardId] ?? [];
      // Only labels assigned to this card (never fall back to all board labels).
      final List<PlankaLabel> cardLabels = cardLabelRows
          .where((cl) => cl['cardId'] == cardId)
          .map((cl) => labelById[cl['labelId'] as String?])
          .whereType<PlankaLabel>()
          .toList();
      final List<PlankaCardMembership> cardMemberships = cardMembershipMap[cardId] ?? [];
      final List<PlankaAttachment> cardAttachments = cardAttachmentMap[cardId] ?? [];
      final List<PlankaUser> cardUsers = cardMemberships
          .map((membership) => cardUsersMap[membership.userId])
          .whereType<PlankaUser>()
          .toList();
      final stopwatchTotal = m['stopwatch'] is Map ? (m['stopwatch'] as Map)['total'] : null;
      final startedRaw = m['stopwatch'] is Map ? (m['stopwatch'] as Map)['startedAt'] : null;
      final stopwatchStartedAt = startedRaw != null ? DateTime.tryParse('$startedRaw') : null;

      return PlankaCard(
        id: cardId,
        boardId: cardBoardId,
        name: m['name'] as String? ?? '',
        listId: m['listId'] as String? ?? '',
        position: (m['position'] as num?) ?? 0,
        description: m['description'] as String?,
        dueDate: m['dueDate'] as String?,
        isSubscribed: m['isSubscribed'] == true,
        coverAttachmentId: m['coverAttachmentId'] as String?,
        creatorUserId: m['creatorUserId'] as String? ?? store.localUserId,
        tasks: cardTasks,
        labels: cardLabels,
        cardMemberships: cardMemberships,
        cardAttachment: cardAttachments,
        cardUsers: cardUsers,
        stopwatchTotal: stopwatchTotal is num ? stopwatchTotal.toInt() : null,
        stopwatchStartedAt: stopwatchStartedAt,
      );
    }).toList();

    // filter / sort
    final q = (store.filterQuery ?? '').trim().toLowerCase();
    var filtered = boardCards;
    if (q.isNotEmpty) {
      filtered = boardCards.where((c) {
        final hay = '${c.name} ${c.description ?? ''}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    final sortBy = store.sortBy;
    if (sortBy == 'name') {
      filtered = [...filtered]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortBy == 'dueDate') {
      filtered = [...filtered]..sort((a, b) => ('${a.dueDate ?? ''}').compareTo('${b.dueDate ?? ''}'));
    }

    _lists = ((included['lists'] as List?) ?? const []).map((json) {
      final m = Map<String, dynamic>.from(json as Map);
      final listCards = filtered.where((card) => card.listId == m['id']).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return PlankaList.fromJson(m, listCards);
    }).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    notifyListeners();
  }

  Future<void> reorderCard({
    required BuildContext context,
    required String cardId,
    required int newPosition,
    required String newListId,
  }) async {
    PlankaStore.instance.updateCard(cardId, {'position': newPosition, 'listId': newListId});
    notifyListeners();
  }

  Future<void> createLabelOnBoard({
    required String labelName,
    required String boardId,
    required BuildContext context,
    String color = 'berry-red',
  }) async {
    PlankaStore.instance.createLabel(boardId: boardId, name: labelName, color: color);
    await fetchLists(boardId: boardId, context: context);
  }

  Future<void> reorderList({
    required BuildContext context,
    required String listId,
    required String boardId,
    required int newPosition,
  }) async {
    PlankaStore.instance.updateListPosition(listId, newPosition);
    await fetchLists(boardId: boardId, context: context);
  }

  Future<void> createList({
    required String newListName,
    required String boardId,
    required BuildContext context,
    required String newPos,
  }) async {
    PlankaStore.instance.createList(
      boardId: boardId,
      name: newListName,
      position: num.tryParse(newPos) ?? 65535,
    );
    await fetchLists(boardId: boardId, context: context);
  }

  Future<bool> deleteList(String listIdToDelete) async {
    PlankaStore.instance.deleteList(listIdToDelete);
    _lists.removeWhere((l) => l.id == listIdToDelete);
    notifyListeners();
    return true;
  }

  Future<bool> updateListName(PlankaList list, String newListName) async {
    PlankaStore.instance.updateListName(list.id, newListName);
    final index = _lists.indexWhere((element) => element.id == list.id);
    if (index != -1) {
      _lists[index] = PlankaList(
        id: list.id,
        name: newListName,
        cards: list.cards,
        position: list.position,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> createCard({
    required String newCardName,
    required String listId,
    required BuildContext context,
    required String boardId,
    required String newPos,
  }) async {
    PlankaStore.instance.createCard(
      listId: listId,
      boardId: boardId,
      name: newCardName,
      position: num.tryParse(newPos) ?? 65535,
    );
    await fetchLists(boardId: boardId, context: context);
    return true;
  }

  Future<Map<dynamic, dynamic>?> createCardForNewAttachment({
    required String newCardName,
    required String listId,
    required BuildContext context,
    required String boardId,
    required String newPos,
  }) async {
    final c = PlankaStore.instance.createCard(
      listId: listId,
      boardId: boardId,
      name: newCardName,
      position: num.tryParse(newPos) ?? 65535,
    );
    notifyListeners();
    return {'item': c};
  }
}
