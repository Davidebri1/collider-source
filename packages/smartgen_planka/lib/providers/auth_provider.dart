import 'package:flutter/material.dart';

/// Local-only auth for Collider Smart Gen. No server URL / login / logout.
class AuthProvider with ChangeNotifier {
  String _token = 'local';
  String _domain = 'local';
  String _selectedProtocol = 'local';

  String get token => _token;
  String get domain => _domain;
  String get selectedProtocol => _selectedProtocol;

  bool get isLocal => true;

  Future<void> login(String selectedProtocol, String emailOrUsername, String password, String domain, BuildContext context) async {
    _token = 'local';
    _domain = 'local';
    _selectedProtocol = 'local';
    notifyListeners();
  }

  Future<bool> logout(BuildContext context) async {
    // No-op for local store — keep session so routes stay usable.
    return true;
  }

  Future<void> seedPreview() async {
    _token = 'local';
    _domain = 'local';
    _selectedProtocol = 'local';
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    // Already local — do not notify (ProxyProviders recreate and wipe fetched lists).
    if (_token == 'local' && _domain == 'local' && _selectedProtocol == 'local') return;
    _token = 'local';
    _domain = 'local';
    _selectedProtocol = 'local';
    notifyListeners();
  }
}
