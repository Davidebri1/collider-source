import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'account_session.dart';
import 'sync_record.dart';

/// HTTP client for the Collider account Worker.
class AccountSyncClient {
  AccountSyncClient({required this.baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final Dio _dio;

  String get _root => baseUrl.replaceAll(RegExp(r'/$'), '');

  Options _auth(String token) => Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

  Future<AccountSession?> signInWithIdToken({
    required String provider,
    required String idToken,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_root/auth/$provider',
      data: {'id_token': idToken},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    if (res.statusCode != 200 || res.data == null) {
      debugPrint('AccountSync auth failed: ${res.statusCode}');
      return null;
    }
    return AccountSession.fromJson(res.data);
  }

  /// Local / wrangler-dev only. Worker must have DEV_AUTH=1.
  Future<AccountSession?> signInDev({required String email, String? name}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$_root/auth/dev',
      data: {'email': email, if (name != null) 'name': name},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    if (res.statusCode != 200 || res.data == null) return null;
    return AccountSession.fromJson(res.data);
  }

  Future<void> signOut(String token) async {
    await _dio.post('$_root/auth/signout', options: _auth(token));
  }

  Future<AccountSession?> me(String token) async {
    final res = await _dio.get<Map<String, dynamic>>('$_root/auth/me', options: _auth(token));
    if (res.statusCode != 200 || res.data == null) return null;
    final s = AccountSession.fromJson(res.data);
    // Server may omit accessToken; keep the one we sent.
    if (s == null) return null;
    return AccountSession(
      userId: s.userId,
      email: s.email,
      displayName: s.displayName,
      provider: s.provider,
      accessToken: token,
      expiresAt: s.expiresAt,
    );
  }

  Future<List<SyncRecord>> pullRecords(String token, {int sinceMs = 0}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_root/v1/records',
      queryParameters: {'since': sinceMs},
      options: _auth(token),
    );
    if (res.statusCode != 200 || res.data == null) return const [];
    final items = res.data!['items'];
    if (items is! List) return const [];
    return [for (final x in items) SyncRecord.fromJson(x)].whereType<SyncRecord>().toList();
  }

  Future<bool> putRecord(String token, SyncRecord record) async {
    final res = await _dio.put(
      '$_root/v1/records/${Uri.encodeComponent(record.collection)}/${Uri.encodeComponent(record.id)}',
      data: record.toJson(),
      options: _auth(token),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<bool> deleteRecord(String token, String collection, String id, int updatedAtMs) async {
    final res = await _dio.delete(
      '$_root/v1/records/${Uri.encodeComponent(collection)}/${Uri.encodeComponent(id)}',
      queryParameters: {'updatedAtMs': updatedAtMs},
      options: _auth(token),
    );
    return res.statusCode == 200 || res.statusCode == 204;
  }

  Future<bool> putBlob(String token, String id, Uint8List bytes, int updatedAtMs) async {
    final res = await _dio.put(
      '$_root/v1/blobs/${Uri.encodeComponent(id)}',
      data: bytes,
      options: Options(headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'X-Updated-At': '$updatedAtMs',
      }),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<Uint8List?> getBlob(String token, String id) async {
    final res = await _dio.get<List<int>>(
      '$_root/v1/blobs/${Uri.encodeComponent(id)}',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        responseType: ResponseType.bytes,
      ),
    );
    if (res.statusCode != 200 || res.data == null) return null;
    return Uint8List.fromList(res.data!);
  }

  Future<bool> deleteBlob(String token, String id) async {
    final res = await _dio.delete(
      '$_root/v1/blobs/${Uri.encodeComponent(id)}',
      options: _auth(token),
    );
    return res.statusCode == 200 || res.statusCode == 204;
  }

  Future<List<Map<String, Object?>>> listBlobMeta(String token, {int sinceMs = 0}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_root/v1/blobs',
      queryParameters: {'since': sinceMs},
      options: _auth(token),
    );
    if (res.statusCode != 200 || res.data == null) return const [];
    final items = res.data!['items'];
    if (items is! List) return const [];
    return [
      for (final x in items)
        if (x is Map) Map<String, Object?>.from(x),
    ];
  }

  /// Health check (no auth).
  Future<bool> health() async {
    try {
      final res = await _dio.get('$_root/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
