import 'package:flutter/material.dart';
import 'package:planka_app/models/card_models/planka_membership.dart';
import 'package:planka_app/models/planka_board.dart';
import 'package:planka_app/models/planka_user.dart';
import '../local/planka_store.dart';
import 'auth_provider.dart';

class BoardProvider with ChangeNotifier {
  final List<PlankaBoard> _boards = [];
  final AuthProvider authProvider;
  final Map<String, List<PlankaUser>> _boardUsersMap = {};
  final Map<String, List<BoardMembership>> _boardMembershipsMap = {};

  BoardProvider(this.authProvider);

  List<PlankaBoard> get boards => _boards;
  Map<String, List<PlankaUser>> get boardUsersMap => _boardUsersMap;
  Map<String, List<BoardMembership>> get boardMembershipsMap => _boardMembershipsMap;
  List<PlankaUser> getBoardUsers(String boardId) => _boardUsersMap[boardId] ?? [];

  Future<void> fetchBoards({required String projectId, required BuildContext context}) async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final responseData = store.projectDetailPayload(projectId);
    final includedData = Map<String, dynamic>.from((responseData['included'] as Map?) ?? {});
    _boards.clear();
    if (includedData.containsKey('boards')) {
      for (var boardJson in includedData['boards'] as List) {
        _boards.add(PlankaBoard.fromJson(Map<String, dynamic>.from(boardJson as Map), includedData));
      }
    }
    notifyListeners();
  }

  Future<void> fetchBoardUsersAndMemberships({required String boardId, required BuildContext context}) async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final responseData = store.boardDetailPayload(boardId);
    final includedData = Map<String, dynamic>.from((responseData['included'] as Map?) ?? {});
    List<PlankaUser> users = [];
    List<BoardMembership> memberships = [];
    if (includedData.containsKey('users')) {
      users = (includedData['users'] as List).map((u) => PlankaUser.fromJson(Map<String, dynamic>.from(u as Map))).toList();
    }
    if (includedData.containsKey('boardMemberships')) {
      memberships = (includedData['boardMemberships'] as List)
          .map((m) => BoardMembership.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    }
    _boardUsersMap[boardId] = users;
    _boardMembershipsMap[boardId] = memberships;
    notifyListeners();
  }

  Future<String> createBoard({
    required String newBoardName,
    required String projectId,
    required BuildContext context,
    required String newPos,
  }) async {
    final b = PlankaStore.instance.createBoard(
      projectId: projectId,
      name: newBoardName,
      position: num.tryParse(newPos) ?? 65535,
    );
    await fetchBoards(projectId: projectId, context: context);
    return b['id'] as String;
  }

  Future<void> deleteBoard(String boardIdToDelete, String projectId, BuildContext context) async {
    PlankaStore.instance.deleteBoard(boardIdToDelete);
    await fetchBoards(projectId: projectId, context: context);
  }

  Future<bool> updateBoardName(String boardIdToUpdate, String newBoardName) async {
    PlankaStore.instance.updateBoardName(boardIdToUpdate, newBoardName);
    final boardIndex = boards.indexWhere((board) => board.id == boardIdToUpdate);
    if (boardIndex != -1) {
      boards[boardIndex].name = newBoardName;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> addBoardMember({required BuildContext context, required String boardId, required String userId}) async {
    PlankaStore.instance.addBoardMember(boardId, userId);
    await fetchBoardUsersAndMemberships(boardId: boardId, context: context);
  }

  Future<void> removeBoardMember({required BuildContext context, required String id}) async {
    PlankaStore.instance.removeBoardMember(id);
    notifyListeners();
  }

  Future<void> updateLabel(String labelIdToUpdate, String newLabelName, String labelColor) async {
    PlankaStore.instance.updateLabel(labelIdToUpdate, name: newLabelName, color: labelColor);
    notifyListeners();
  }
}
