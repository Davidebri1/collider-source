import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/theme_def.dart';

/// A track in the music drawer / floating player (not tied to one pack).
class CatalogAmbientTrack {
  final String title;
  final String audioUrl;
  final String artUrl;
  const CatalogAmbientTrack({required this.title, required this.audioUrl, required this.artUrl});
}

/// Parsed contents of themes.json.
class ThemeCatalogData {
  final int schema;
  final String updated;
  final String defaultSlug;
  final List<WallpaperTheme> themes;
  final List<CatalogAmbientTrack> ambientTracks;

  const ThemeCatalogData({
    required this.schema,
    required this.updated,
    required this.defaultSlug,
    required this.themes,
    required this.ambientTracks,
  });

  /// Parses themes.json. Relative media paths resolve against `baseUrl` in the
  /// JSON, or [fallbackBase] when absent.
  factory ThemeCatalogData.parse(String source, {Uri? fallbackBase}) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    final baseStr = j['baseUrl'] as String?;
    final base = baseStr != null ? Uri.parse(baseStr) : (fallbackBase ?? Uri.parse(ThemeCatalog.mediaBaseUrl));
    final themes = <WallpaperTheme>[];
    for (final t in (j['themes'] as List? ?? const [])) {
      if (t is! Map || t['slug'] is! String) continue;
      try {
        themes.add(WallpaperTheme.fromJson(t.cast<String, dynamic>(), base: base));
      } catch (e) {
        debugPrint('ThemeCatalog: skipped malformed theme ${t['slug']}: $e');
      }
    }
    final ambient = <CatalogAmbientTrack>[];
    for (final a in (j['ambientTracks'] as List? ?? const [])) {
      if (a is! Map) continue;
      final audio = ThemeCatalog.resolve(a['audio'] as String?, base);
      if (audio == null) continue;
      ambient.add(CatalogAmbientTrack(
        title: humanizeThemeName((a['title'] as String?) ?? 'Track'),
        audioUrl: audio,
        artUrl: ThemeCatalog.resolve(a['art'] as String?, base) ?? ThemeCatalog.offlineWallpaperAsset,
      ));
    }
    return ThemeCatalogData(
      schema: (j['schema'] as num?)?.toInt() ?? 1,
      updated: (j['updated'] as String?) ?? '',
      defaultSlug: (j['defaultSlug'] as String?) ?? 'starbridge',
      themes: themes,
      ambientTracks: ambient,
    );
  }
}

/// Runtime theme catalog.
///
/// Load order: bundled fallback JSON (instant, offline-safe) -> last good
/// remote copy from SharedPreferences -> live themes.json from the media host.
/// New themes are added by publishing media + editing themes.json in the
/// collider-media repo; no app rebuild needed.
class ThemeCatalog extends ChangeNotifier {
  ThemeCatalog._();
  static final ThemeCatalog instance = ThemeCatalog._();

  static const String mediaBaseUrl = 'https://davidebri1.github.io/collider-media/';
  static const String remoteCatalogUrl = '${mediaBaseUrl}themes.json';
  static const String bundledCatalogAsset = 'assets/catalog/themes.json';

  /// Tiny bundled wallpaper used for offline start and as image placeholder.
  static const String offlineWallpaperAsset = 'assets/wallpapers/default_wallpaper.webp';

  static const String _prefsKey = 'theme_catalog_json_v1';

  static const WallpaperTheme _builtinDefault = WallpaperTheme(
    id: 'starbridge',
    name: 'Star Bridge',
    assetPath: offlineWallpaperAsset,
    tier: 'Free Spatial Canvas',
  );

  List<WallpaperTheme> _themes = const [_builtinDefault];
  List<CatalogAmbientTrack> _ambient = const [];
  String _defaultSlug = 'starbridge';
  String _source = 'builtin';
  String _updated = '';
  Future<void>? _remoteInFlight;

  /// Where the current data came from: builtin | bundled | cache | remote.
  String get source => _source;
  String get updated => _updated;

  List<WallpaperTheme> get allThemes => List.unmodifiable(_themes);
  List<WallpaperTheme> get premiumThemes => List.unmodifiable(_themes.where((t) => t.isPremium));
  List<WallpaperTheme> get freeThemes => List.unmodifiable(_themes.where((t) => !t.isPremium));
  List<CatalogAmbientTrack> get ambientTracks => List.unmodifiable(_ambient);

  /// The first thing anyone sees, so it has to be a deliberate choice.
///
/// A catalog can arrive with a `defaultSlug` that points at a raw Drive
/// import - the published catalog shipped
/// `0251d1e0-16a1-49ad-9807-19d1bceac3e9_1080_hd` as its default, which is how
/// the app came up on somebody's artwork with no way to tell it apart from
/// the other 148. A machine-named default is never used; the bundled curated
/// default is preferred, then a real product name, then anything free.
WallpaperTheme get defaultTheme {
    final t = bySlug(_defaultSlug);
    if (t != null && !_machineNamed(t.id)) return t;
    for (final curated in const ['starbridge']) {
      final c = bySlug(curated);
      if (c != null && !_machineNamed(c.id)) return c;
    }
    for (final th in _themes) {
      if (!_machineNamed(th.id)) return th;
    }
    return freeThemes.isNotEmpty ? freeThemes.first : _builtinDefault;
  }

  /// True for slugs that are clearly a filename or an id rather than a product
  /// name: a UUID / hash prefix, a leading digit, or resolution and copy
  /// markers.
  static bool _machineNamed(String slug) {
    final s = slug.toLowerCase();
    if (RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-').hasMatch(s)) return true;
    if (RegExp(r'^\d+[-_]').hasMatch(s)) return true;
    if (RegExp(r'_(4k|8k|hd|uhd|sd)(\W|$)').hasMatch(s)) return true;
    if (RegExp(r'\d{3,4}\s*[x\u00d7]\s*\d{3,4}').hasMatch(s)) return true;
    if (RegExp(r'[-_]copy(\W|$)').hasMatch(s)) return true;
    return false;
  }

  WallpaperTheme? bySlug(String slug) {
    for (final t in _themes) {
      if (t.id == slug) return t;
    }
    return null;
  }

  /// Resolves a catalog media path against [base]. Absolute URLs and bundled
  /// `assets/` paths pass through unchanged.
  static String? resolve(String? path, Uri? base) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('assets/')) return path;
    final u = Uri.parse(path);
    if (u.hasScheme) return path;
    return (base ?? Uri.parse(mediaBaseUrl)).resolve(path).toString();
  }

  /// Call once before runApp: bundled JSON, then cached remote copy.
  /// Starts the remote refresh in the background.
  Future<void> init() async {
    await loadBundled();
    await _loadCached();
    unawaited(refreshRemote());
  }

  Future<void> loadBundled() async {
    try {
      final s = await rootBundle.loadString(bundledCatalogAsset);
      _apply(ThemeCatalogData.parse(s), 'bundled', notify: false);
    } catch (e) {
      debugPrint('ThemeCatalog: bundled catalog unavailable: $e');
    }
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefsKey);
      if (s != null && s.isNotEmpty) _apply(ThemeCatalogData.parse(s), 'cache', notify: false);
    } catch (e) {
      debugPrint('ThemeCatalog: cached catalog ignored: $e');
    }
  }

  /// Fetches themes.json from the media host. Safe to call repeatedly.
  Future<void> refreshRemote({Duration timeout = const Duration(seconds: 8)}) {
    return _remoteInFlight ??= _fetchRemote(timeout).whenComplete(() => _remoteInFlight = null);
  }

  Future<void> _fetchRemote(Duration timeout) async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout, responseType: ResponseType.plain));
      // Cache-bust so a just-published catalog shows up on the next launch
      // instead of after the CDN / browser cache expires.
      final res = await dio.get<String>(remoteCatalogUrl,
          queryParameters: {'t': DateTime.now().millisecondsSinceEpoch ~/ 60000});
      final body = res.data;
      if (res.statusCode != 200 || body == null || body.isEmpty) return;
      final data = ThemeCatalogData.parse(body);
      if (data.themes.isEmpty) return;
      _apply(data, 'remote');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, body);
    } catch (e) {
      debugPrint('ThemeCatalog: remote refresh failed, keeping $_source: $e');
    }
  }

  void _apply(ThemeCatalogData d, String source, {bool notify = true}) {
    if (d.themes.isEmpty) return;
    _themes = d.themes;
    _ambient = d.ambientTracks;
    _defaultSlug = d.defaultSlug;
    _updated = d.updated;
    _source = source;
    if (notify) notifyListeners();
  }
}
