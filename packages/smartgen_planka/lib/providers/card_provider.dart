import 'package:flutter/material.dart';
import 'package:planka_app/providers/list_provider.dart';
import 'package:provider/provider.dart';
import '../local/planka_store.dart';
import '../models/planka_fCard.dart';
import 'auth_provider.dart';

class CardProvider with ChangeNotifier {
  PlankaFullCard? _card;
  final AuthProvider authProvider;

  CardProvider(this.authProvider);

  PlankaFullCard? get card => _card;

  Future<PlankaFullCard> fetchCard({required String cardId, required BuildContext context}) async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final payload = store.cardDetailPayload(cardId);
    final plankaFullCardCard = PlankaFullCard.fromJson(payload);
    _card = plankaFullCardCard;
    notifyListeners();
    return plankaFullCardCard;
  }

  Future<void> updateCardTitle({required BuildContext context, required String cardId, required String newCardTitle}) async {
    PlankaStore.instance.updateCard(cardId, {'name': newCardTitle});
    if (_card?.id == cardId) _card!.name = newCardTitle;
    notifyListeners();
  }

  Future<void> updateStopwatch({
    required BuildContext context,
    required String cardId,
    required int stopwatchTotal,
    String? stopwatchStartedAt,
  }) async {
    PlankaStore.instance.updateCard(cardId, {
      'stopwatch': {
        'total': stopwatchTotal,
        if (stopwatchStartedAt != null) 'startedAt': stopwatchStartedAt,
      },
    });
    notifyListeners();
  }

  Future<void> deleteStopwatch({required BuildContext context, required String cardId}) async {
    PlankaStore.instance.updateCard(cardId, {'stopwatch': null});
    notifyListeners();
  }

  Future<void> updateCardDueDate({required String cardId, required String newDueDate}) async {
    PlankaStore.instance.updateCard(cardId, {'dueDate': newDueDate.isEmpty ? null : newDueDate});
    if (_card?.id == cardId) _card!.dueDate = newDueDate.isEmpty ? null : newDueDate;
    notifyListeners();
  }

  Future<void> addCardLabel({required BuildContext context, required String cardId, required String labelId}) async {
    PlankaStore.instance.addCardLabel(cardId, labelId);
    notifyListeners();
  }

  Future<void> addCardMember({required BuildContext context, required String cardId, required String userId}) async {
    PlankaStore.instance.addCardMember(cardId, userId);
    notifyListeners();
  }

  Future<void> removeCardMember({required BuildContext context, required String cardId, required String userId}) async {
    PlankaStore.instance.removeCardMember(cardId, userId);
    notifyListeners();
  }

  Future<void> removeCardLabel({required BuildContext context, required String cardId, required String labelId}) async {
    PlankaStore.instance.removeCardLabel(cardId, labelId);
    notifyListeners();
  }

  Future<void> deleteCard({required BuildContext context, required String cardId}) async {
    final boardId = _card?.boardId;
    PlankaStore.instance.deleteCard(cardId);
    _card = null;
    if (boardId != null && context.mounted) {
      await Provider.of<ListProvider>(context, listen: false).fetchLists(boardId: boardId, context: context);
    }
    notifyListeners();
  }

  Future<void> updateCardDescription({required BuildContext context, required String cardId, required String newCardDesc}) async {
    PlankaStore.instance.updateCard(cardId, {'description': newCardDesc});
    if (_card?.id == cardId) _card!.description = newCardDesc;
    notifyListeners();
  }

  Future<void> updateCardCoverAttachId({required BuildContext context, required String cardId, required String? newCardCoverAttachId}) async {
    PlankaStore.instance.updateCard(cardId, {'coverAttachmentId': newCardCoverAttachId});
    notifyListeners();
  }

  Future<void> addTask({required BuildContext context, required String cardId, required String taskText, required String newPos}) async {
    PlankaStore.instance.addTask(cardId: cardId, name: taskText, position: num.tryParse(newPos) ?? 65535);
    await fetchCard(cardId: cardId, context: context);
  }

  Future<void> removeTask({required BuildContext context, required String taskId}) async {
    PlankaStore.instance.removeTask(taskId);
    notifyListeners();
  }

  Future<void> toggleTaskCompletion({required BuildContext context, required String taskId, required bool isCompleted}) async {
    PlankaStore.instance.updateTask(taskId, {'isCompleted': isCompleted});
    notifyListeners();
  }

  Future<void> reorderTask({required BuildContext context, required String taskId, required int newPosition}) async {
    PlankaStore.instance.updateTask(taskId, {'position': newPosition});
    notifyListeners();
  }

  Future<void> renameTask({required BuildContext context, required String taskId, required String newTaskName}) async {
    PlankaStore.instance.updateTask(taskId, {'name': newTaskName});
    notifyListeners();
  }
}
