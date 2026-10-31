import 'package:flutter/material.dart';
import '../local/planka_store.dart';
import '../models/planka_card_actions.dart';
import 'auth_provider.dart';

class CardActionsProvider with ChangeNotifier {
  List<PlankaCardAction> _cardActions = [];
  final AuthProvider authProvider;

  CardActionsProvider(this.authProvider);

  List<PlankaCardAction> get cardActions => _cardActions;

  Future<void> fetchCardComment(String cardId) async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final items = store.commentsFor(cardId);
    final included = {'users': store.users};
    _cardActions = items
        .map((actionJson) => PlankaCardAction.fromJson(actionJson, included))
        .toList();
    notifyListeners();
  }

  Future<void> deleteComment(String commentId) async {
    PlankaStore.instance.deleteComment(commentId);
    _cardActions.removeWhere((a) => a.id == commentId);
    notifyListeners();
  }

  Future<void> createComment(String cardId, String newCommentBody) async {
    PlankaStore.instance.createComment(cardId, newCommentBody);
    await fetchCardComment(cardId);
  }

  Future<void> updateComment(String commentId, String newCommentBody) async {
    PlankaStore.instance.updateComment(commentId, newCommentBody);
    notifyListeners();
  }
}
