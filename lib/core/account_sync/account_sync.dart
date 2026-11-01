/// Account-level persistence for Collider.
///
/// Every feature reads and writes through [AccountSync]. Local cache always
/// works signed-out. When signed in, changes sync to the Collider Worker on
/// the same origin (relative `/api` or configured [baseUrl]).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../files/file_blobs.dart';
import 'account_session.dart';
import 'account_sync_client.dart';
import 'sync_record.dart';

export 'account_session.dart';
export 'sync_record.dart';

/// Collections used across the app (stable string ids).
abstract final class SyncCollections {
  static const kv = 'kv'; // simple string prefs as {value: "..."}
  static const filesIndex = 'files_index';
  static const history = 'history';
  static const activeChat = 'active_chat';
  static const smartgen = 'smartgen';
  static const theme = 'theme';
  static const music = 'music';
}

class AccountSync extends ChangeNotifier {
  AccountSync._();
  static final AccountSync instance = AccountSync._();

  static const _sessionKey = 'account_sync_session_v1';
  static const _cursorKey = 'account_sync_cursor_ms_v1';
  static const _pendingRecordsKey = 'account_sync_pending_records_v1';
  static const _pendingBlobsKey = 'account_sync_pending_blobs_v1';
  static const _migratedKey = 'account_sync_migrated_v1';

  /// Default: same-origin `/api` when hosted on the Worker; override for local wrangler.
  String baseUrl = '/api';
  AccountSyncClient? _client;
  AccountSession? _session;
  bool _ready = false;
  bool _syncing = false;
  bool _apiAvailable = false;
  Timer? _debounce;

  AccountSession? get session => _session;
  bool get isSignedIn => _session != null && !_session!.isExpired;
  bool get ready => _ready;
  bool get syncing => _syncing;
  /// True only after a successful GET /health on [baseUrl]. Silent when offline.
  bool get apiAvailable => _apiAvailable;

  AccountSyncClient get client =>
      _client ??= AccountSyncClient(baseUrl: baseUrl);

  Future<void> init({String? baseUrl}) async {
    if (baseUrl != null && baseUrl.isNotEmpty) this.baseUrl = baseUrl;
    _client = AccountSyncClient(baseUrl: this.baseUrl);
    await _restoreSession();
    _ready = true;
    notifyListeners();
    unawaited(refreshApiAvailability());
    if (isSignedIn) unawaited(syncNow());
  }

  /// Probe Worker health. Failures stay silent — local storage keeps working.
  Future<bool> refreshApiAvailability() async {
    final ok = await client.health();
    if (ok != _apiAvailable) {
      _apiAvailable = ok;
      notifyListeners();
    } else {
      _apiAvailable = ok;
    }
    return _apiAvailable;
  }

  // ——— Auth ———

  Future<bool> signInWithIdToken({
    required String provider,
    required String idToken,
  }) async {
    final s = await client.signInWithIdToken(provider: provider, idToken: idToken);
    if (s == null) return false;
    await _setSession(s);
    await _migrateLocalIfNeeded();
    await syncNow();
    return true;
  }

  /// wrangler-dev / tests only (Worker DEV_AUTH=1).
  Future<bool> signInDev({required String email, String? name}) async {
    final s = await client.signInDev(email: email, name: name);
    if (s == null) return false;
    await _setSession(s);
    await _migrateLocalIfNeeded();
    await syncNow();
    return true;
  }

  Future<void> signOut() async {
    final t = _session?.accessToken;
    if (t != null) {
      try {
        await client.signOut(t);
      } catch (_) {}
    }
    _session = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> _setSession(AccountSession s) async {
    _session = s;
    final p = await SharedPreferences.getInstance();
    await p.setString(_sessionKey, jsonEncode(s.toJson()));
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_sessionKey);
      if (raw == null || raw.isEmpty) return;
      final s = AccountSession.fromJson(jsonDecode(raw));
      if (s == null || s.isExpired) {
        await p.remove(_sessionKey);
        return;
      }
      _session = s;
      // Refresh profile; drop session if server rejects.
      final me = await client.me(s.accessToken);
      if (me == null) {
        _session = null;
        await p.remove(_sessionKey);
      } else {
        _session = me;
        await p.setString(_sessionKey, jsonEncode(me.toJson()));
      }
    } catch (_) {}
  }

  // ——— KV (string prefs) ———

  Future<String?> getString(String key) async {
    final rec = await _localGet(SyncCollections.kv, key);
    if (rec == null || rec.deleted) return null;
    final v = rec.data['value'];
    return v is String ? v : null;
  }

  Future<void> setString(String key, String value, {bool sync = true}) async {
    await _localPut(
      SyncRecord(
        collection: SyncCollections.kv,
        id: key,
        data: {'value': value},
        updatedAtMs: _now(),
      ),
      sync: sync,
    );
  }

  Future<bool?> getBool(String key) async {
    final s = await getString(key);
    if (s == null) return null;
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }

  Future<void> setBool(String key, bool value, {bool sync = true}) =>
      setString(key, value ? 'true' : 'false', sync: sync);

  Future<List<String>?> getStringList(String key) async {
    final s = await getString(key);
    if (s == null || s.isEmpty) return null;
    try {
      final j = jsonDecode(s);
      if (j is List) return [for (final x in j) x.toString()];
    } catch (_) {}
    return null;
  }

  Future<void> setStringList(String key, List<String> value, {bool sync = true}) =>
      setString(key, jsonEncode(value), sync: sync);

  Future<void> removeKey(String key, {bool sync = true}) async {
    await _localPut(
      SyncRecord(
        collection: SyncCollections.kv,
        id: key,
        data: const {},
        updatedAtMs: _now(),
        deleted: true,
      ),
      sync: sync,
    );
  }

  // ——— JSON documents ———

  Future<Map<String, Object?>?> getJson(String collection, String id) async {
    final rec = await _localGet(collection, id);
    if (rec == null || rec.deleted) return null;
    return rec.data;
  }

  Future<void> putJson(
    String collection,
    String id,
    Map<String, Object?> data, {
    bool sync = true,
  }) async {
    await _localPut(
      SyncRecord(
        collection: collection,
        id: id,
        data: data,
        updatedAtMs: _now(),
      ),
      sync: sync,
    );
  }

  Future<void> deleteJson(String collection, String id, {bool sync = true}) async {
    await _localPut(
      SyncRecord(
        collection: collection,
        id: id,
        data: const {},
        updatedAtMs: _now(),
        deleted: true,
      ),
      sync: sync,
    );
  }

  // ——— Blobs (FileBlobs + sync queue) ———

  Future<bool> putBlob(String id, Uint8List bytes, {bool sync = true}) async {
    final ok = await FileBlobs.put(id, bytes);
    if (!ok) return false;
    if (sync) {
      await _enqueueBlob(id, deleted: false);
      _scheduleSync();
    }
    return true;
  }

  Future<Uint8List?> getBlob(String id) => FileBlobs.get(id);

  Future<void> deleteBlob(String id, {bool sync = true}) async {
    await FileBlobs.delete(id);
    if (sync) {
      await _enqueueBlob(id, deleted: true);
      _scheduleSync();
    }
  }

  Future<Set<String>> blobKeys() => FileBlobs.keys();

  // ——— Sync engine ———

  void _scheduleSync() {
    if (!isSignedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(syncNow());
    });
  }

  Future<void> syncNow() async {
    if (!isSignedIn || _syncing) return;
    final token = _session!.accessToken;
    _syncing = true;
    notifyListeners();
    try {
      await _pushPending(token);
      await _pullRemote(token);
    } catch (e) {
      debugPrint('AccountSync sync: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushPending(String token) async {
    final p = await SharedPreferences.getInstance();
    // Records
    final raw = p.getString(_pendingRecordsKey);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw);
      if (list is List) {
        final left = <Map<String, Object?>>[];
        for (final x in list) {
          final rec = SyncRecord.fromJson(x);
          if (rec == null) continue;
          final ok = rec.deleted
              ? await client.deleteRecord(token, rec.collection, rec.id, rec.updatedAtMs)
              : await client.putRecord(token, rec);
          if (!ok) left.add(rec.toJson());
        }
        await p.setString(_pendingRecordsKey, jsonEncode(left));
      }
    }
    // Blobs
    final braw = p.getString(_pendingBlobsKey);
    if (braw != null && braw.isNotEmpty) {
      final list = jsonDecode(braw);
      if (list is List) {
        final left = <Map<String, Object?>>[];
        for (final x in list) {
          if (x is! Map) continue;
          final id = x['id'] as String?;
          if (id == null) continue;
          final deleted = x['deleted'] == true;
          final ts = (x['updatedAtMs'] as num?)?.toInt() ?? _now();
          bool ok;
          if (deleted) {
            ok = await client.deleteBlob(token, id);
          } else {
            final bytes = await FileBlobs.get(id);
            if (bytes == null) {
              ok = true; // gone locally
            } else {
              ok = await client.putBlob(token, id, bytes, ts);
            }
          }
          if (!ok) left.add(Map<String, Object?>.from(x));
        }
        await p.setString(_pendingBlobsKey, jsonEncode(left));
      }
    }
  }

  Future<void> _pullRemote(String token) async {
    final p = await SharedPreferences.getInstance();
    final since = p.getInt(_cursorKey) ?? 0;
    final records = await client.pullRecords(token, sinceMs: since);
    var maxTs = since;
    for (final rec in records) {
      if (rec.updatedAtMs > maxTs) maxTs = rec.updatedAtMs;
      await _applyRemoteRecord(rec);
    }
    final metas = await client.listBlobMeta(token, sinceMs: since);
    for (final m in metas) {
      final id = m['id'] as String?;
      if (id == null) continue;
      final ts = (m['updatedAtMs'] as num?)?.toInt() ?? 0;
      if (ts > maxTs) maxTs = ts;
      if (m['deleted'] == true) {
        await FileBlobs.delete(id);
        continue;
      }
      final local = await FileBlobs.get(id);
      // Last-writer-wins: fetch if missing or older (we track blob ts in kv meta).
      final metaKey = 'blob_ts:$id';
      final localTs = int.tryParse(await getString(metaKey) ?? '') ?? 0;
      if (local == null || ts > localTs) {
        final bytes = await client.getBlob(token, id);
        if (bytes != null) {
          await FileBlobs.put(id, bytes);
          await setString(metaKey, '$ts', sync: false);
        }
      }
    }
    if (maxTs > since) await p.setInt(_cursorKey, maxTs);
  }

  Future<void> _applyRemoteRecord(SyncRecord remote) async {
    final local = await _localGet(remote.collection, remote.id);
    if (local != null && local.updatedAtMs > remote.updatedAtMs) {
      // Local newer — keep local, will push later.
      return;
    }
    await _writeLocalOnly(remote);
  }

  // ——— Local record store (prefs-backed index) ———

  String _recKey(String collection, String id) => 'asrec:$collection:$id';

  Future<SyncRecord?> _localGet(String collection, String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_recKey(collection, id));
    if (raw == null || raw.isEmpty) return null;
    try {
      return SyncRecord.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _localPut(SyncRecord rec, {required bool sync}) async {
    await _writeLocalOnly(rec);
    if (sync) {
      await _enqueueRecord(rec);
      _scheduleSync();
    }
  }

  Future<void> _writeLocalOnly(SyncRecord rec) async {
    final p = await SharedPreferences.getInstance();
    if (rec.deleted) {
      await p.remove(_recKey(rec.collection, rec.id));
    } else {
      await p.setString(_recKey(rec.collection, rec.id), jsonEncode(rec.toJson()));
    }
    // Mirror well-known kv keys into legacy SharedPreferences keys so a
    // half-migrated build still reads them, and so migration can find them.
    if (rec.collection == SyncCollections.kv && !rec.deleted) {
      final v = rec.data['value'];
      if (v is String) await p.setString(rec.id, v);
    }
    notifyListeners();
  }

  Future<void> _enqueueRecord(SyncRecord rec) async {
    final p = await SharedPreferences.getInstance();
    final list = <Map<String, Object?>>[];
    final raw = p.getString(_pendingRecordsKey);
    if (raw != null && raw.isNotEmpty) {
      final j = jsonDecode(raw);
      if (j is List) {
        for (final x in j) {
          if (x is Map) {
            final existing = SyncRecord.fromJson(x);
            if (existing != null &&
                !(existing.collection == rec.collection && existing.id == rec.id)) {
              list.add(existing.toJson());
            }
          }
        }
      }
    }
    list.add(rec.toJson());
    await p.setString(_pendingRecordsKey, jsonEncode(list));
  }

  Future<void> _enqueueBlob(String id, {required bool deleted}) async {
    final p = await SharedPreferences.getInstance();
    final ts = _now();
    await setString('blob_ts:$id', '$ts', sync: false);
    final list = <Map<String, Object?>>[];
    final raw = p.getString(_pendingBlobsKey);
    if (raw != null && raw.isNotEmpty) {
      final j = jsonDecode(raw);
      if (j is List) {
        for (final x in j) {
          if (x is Map && x['id'] != id) list.add(Map<String, Object?>.from(x));
        }
      }
    }
    list.add({'id': id, 'deleted': deleted, 'updatedAtMs': ts});
    await p.setString(_pendingBlobsKey, jsonEncode(list));
  }

  /// One-time: copy existing SharedPreferences / FileBlobs user data into the
  /// sync layer and queue upload.
  Future<void> _migrateLocalIfNeeded() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_migratedKey) == true) return;

    const legacyKeys = <String>[
      'collider.wallpaper.themeId',
      'collider_local_history_v1',
      'collider_active_chat_v1',
      'collider_files_v1',
      'theme_pack_unlocked_ids',
      'theme_store_subscription_active',
      'music_widget_pos_v1',
      'music_widget_on_v1',
      'hist_hidden_v1',
      'hist_titles_v1',
    ];
    for (final k in legacyKeys) {
      final v = p.getString(k);
      if (v != null) {
        await setString(k, v, sync: true);
        continue;
      }
      final b = p.getBool(k);
      if (b != null) await setBool(k, b, sync: true);
      final list = p.getStringList(k);
      if (list != null) await setStringList(k, list, sync: true);
    }

    // Smart Gen + Files blobs: enqueue every local blob for upload.
    final keys = await FileBlobs.keys();
    for (final id in keys) {
      // Skip regenerable first-frame cache if named that way; still fine to sync.
      await _enqueueBlob(id, deleted: false);
    }

    await p.setBool(_migratedKey, true);
    _scheduleSync();
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;
}
