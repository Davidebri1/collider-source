/// Signed-in account session (client-side copy of Worker session).
class AccountSession {
  final String userId;
  final String email;
  final String displayName;
  final String provider; // google | apple | dev
  final String accessToken;
  final DateTime expiresAt;

  const AccountSession({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.accessToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, Object?> toJson() => {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'provider': provider,
        'accessToken': accessToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  static AccountSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final token = j['accessToken'];
    final uid = j['userId'];
    final exp = j['expiresAt'];
    if (token is! String || uid is! String || exp is! String) return null;
    return AccountSession(
      userId: uid,
      email: (j['email'] as String?) ?? '',
      displayName: (j['displayName'] as String?) ?? '',
      provider: (j['provider'] as String?) ?? 'google',
      accessToken: token,
      expiresAt: DateTime.tryParse(exp) ?? DateTime.now(),
    );
  }
}
