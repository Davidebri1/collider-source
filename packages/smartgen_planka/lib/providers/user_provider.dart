import 'package:flutter/material.dart';
import 'package:planka_app/models/planka_user.dart';
import '../local/planka_store.dart';
import 'auth_provider.dart';

class UserProvider with ChangeNotifier {
  final List<PlankaUser> _users = [];
  PlankaUser _specificUser = PlankaUser(id: 'u_local', email: 'you@local', name: 'You', username: 'you');
  final AuthProvider authProvider;

  UserProvider(this.authProvider);

  List<PlankaUser> get users => _users;
  PlankaUser get specificUser => _specificUser;

  Future<void> fetchUsers() async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    _users
      ..clear()
      ..addAll(store.users.map((u) => PlankaUser.fromJson(u)));
    notifyListeners();
  }

  Future<void> fetchSpecificUser(String userId) async {
    final store = PlankaStore.instance;
    await store.ensureLoaded();
    final u = store.users.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id'] == userId,
          orElse: () => store.users.isNotEmpty ? store.users.first : null,
        );
    if (u != null) {
      _specificUser = PlankaUser.fromJson(u);
      notifyListeners();
    }
  }
}
