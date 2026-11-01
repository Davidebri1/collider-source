import 'account_sync.dart';

/// Drop-in helpers so feature code does not call SharedPreferences for user data.
/// Device-only / layer-internal prefs stay in AccountSync itself.
abstract final class SyncedPrefs {
  static Future<String?> getString(String key) => AccountSync.instance.getString(key);

  static Future<void> setString(String key, String value) =>
      AccountSync.instance.setString(key, value);

  static Future<bool?> getBool(String key) => AccountSync.instance.getBool(key);

  static Future<void> setBool(String key, bool value) =>
      AccountSync.instance.setBool(key, value);

  static Future<List<String>?> getStringList(String key) =>
      AccountSync.instance.getStringList(key);

  static Future<void> setStringList(String key, List<String> value) =>
      AccountSync.instance.setStringList(key, value);

  static Future<void> remove(String key) => AccountSync.instance.removeKey(key);
}
