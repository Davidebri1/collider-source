import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'first_frame.dart';
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
        title: (a['title'] as String?) ?? 'Track',
        audioUrl: audio,
        artUrl: ThemeCatalog.resolve(a['art'] as String?, base) ?? '',
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

  static const String mediaBaseUrl = 'https://pub-6263d41408f145baa5b058378744d787.r2.dev/';
  static const String remoteCatalogUrl = '${mediaBaseUrl}themes.json';


  static const String _prefsKey = 'theme_list_r2_v2';

  static const WallpaperTheme _builtinDefault = WallpaperTheme(
    id: 'starbridge',
    name: '',
    assetPath: '',
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

  List<WallpaperTheme> get _all => _themes;
  List<WallpaperTheme> get allThemes => List.unmodifiable(_themes);
  List<WallpaperTheme> get premiumThemes => List.unmodifiable(_themes.where((t) => t.isPremium));
  List<WallpaperTheme> get freeThemes => List.unmodifiable(_themes.where((t) => !t.isPremium));
  List<CatalogAmbientTrack> get ambientTracks => List.unmodifiable(_ambient);

  WallpaperTheme get defaultTheme => bySlug(_defaultSlug) ?? (freeThemes.isNotEmpty ? freeThemes.first : _builtinDefault);

  WallpaperTheme? bySlug(String slug) {
    for (final t in _all) {
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

  /// No bundled catalogue any more: every theme, cover, loop and song comes
  /// from the R2 Worker list ([themesUrl]). Kept as a no-op for callers.
  Future<void> loadBundled() async {}

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefsKey);
      if (s != null && s.isNotEmpty) {
        final l = jsonDecode(s);
        if (l is List) _applyR2(l, 'cache');
      }
    } catch (e) {
      debugPrint('ThemeCatalog: cached catalog ignored: $e');
    }
  }

  /// Fetches themes.json from the media host. Safe to call repeatedly.
  Future<void> refreshRemote({Duration timeout = const Duration(seconds: 8)}) {
    return _remoteInFlight ??= _fetchRemote(timeout).whenComplete(() => _remoteInFlight = null);
  }

  // v8.8: live wallpapers = every video in the R2 bucket "collider-themes",
  // listed by the collider-themes Worker ([{name,url,size}]) and
  // played from r2.dev at original quality. Posters are each video's own first
  // frame (FirstFrames). The bundled catalog only supplies songs (theme packs'
  // tracks + ambientTracks) and premium themes, exactly as before.
  static const String themesUrl = String.fromEnvironment('COLLIDER_THEMES', defaultValue: 'https://collider-themes.ebridavid.workers.dev/');
  List<WallpaperTheme> _songThemes = const [];
  List<WallpaperTheme> _premium = const [];

  /// Bundled themes that carry songs (for the music library).
  List<WallpaperTheme> get songThemes => _songThemes;
  WallpaperTheme? songThemeBySlug(String slug) {
    for (final t in _songThemes) {
      if (t.id == slug) return t;
    }
    return null;
  }

  /// A stock file with no words in its name is named from its content tags.
  static String _nameOr(String n, List<String> tags) {
    // v9.1.6: hand-written titles for files with no words (R2 tag "title:…").
    for (final t in tags) {
      if (t.startsWith('title:') && t.length > 6) return t.substring(6);
    }
    if (n != 'Untitled') return n;
    // v9.1.6: tags are now category + subcategory; name from the
    // subcategories ("Night City Streets"), never from the bare category.
    const words = {'nature': 'Nature', 'ocean': 'Ocean', 'space': 'Space', 'city': 'City', 'rain': 'Rain', 'cozy': 'Cozy', 'fantasy': 'Fantasy', 'abstract': 'Abstract'};
    final c = [for (final t in _content(tags)) if (words[t.toLowerCase()] != null) words[t.toLowerCase()]!].take(2).toList();
    return c.isEmpty ? 'Untitled' : c.join(' ');
  }

  static String niceName(String file) {
    final base = file.split('/').last;
    final dot = base.lastIndexOf('.');
    final b = (dot > 0 ? base.substring(0, dot) : base).replaceAll(RegExp(r'[_\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    // v9.1: drop stock-site ids and resolution/fps tags ("4572947 Coastline
    // Ocean 1280x720" -> "Coastline Ocean").
    final c = b
        .replaceAll(RegExp(r'\b[0-9a-f]{8}( [0-9a-f]{4}){3} [0-9a-f]{12}\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(medium|copy|coll|hd|\d{9,})\b|\(\d+\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b\d{6,}\b'), '')
        .replaceAll(RegExp(r'^\d+\s+'), '')
        .replaceAll(RegExp(r'\b\d{3,4}\s*x\s*\d{3,4}\b|\b(4k|8k|hd|uhd|\d+fps|\d{3,4}p)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Nothing human left (a bare stock id): give it a plain name.
    return c.replaceAll(RegExp(r'^\d+\s*'), '').isEmpty ? 'Untitled' : c;
  }

  List<WallpaperTheme> _fromList(List list) {
    final all = [for (final o in list.whereType<Map>()) if ((o['url'] as String?)?.isNotEmpty == true) o];
    // v9.1.6g: full-resolution posters (qa/make_posters.py, frame at 1 s,
    // ffmpeg) live under posters/; they are covers, never themes.
    _posters = {for (final o in all) if ('${o['name']}'.startsWith('posters/')) '${o['name']}'.substring(8).replaceAll(RegExp(r'\.jpg$'), ''): o['url'] as String};
    final maps = [for (final o in all) if (!'${o['name']}'.startsWith('posters/') && !'${o['name']}'.startsWith('thumbs/')) o];
    final songs = [for (final o in maps) if (_kind(o) == 'audio') o];
    // Sibling stills (same basename as a .mp4) are the sharp posters for live themes.
    // Without this, live themes fell through to FirstFrames (often blank until capture).
    final stillByBase = <String, String>{
      for (final o in maps)
        if (_kind(o) == 'image')
          niceName('${o['name']}').toLowerCase(): o['url'] as String,
    };
    final themes = [for (final o in maps) if (_kind(o) != 'audio') _r2Theme(o, songs, stillByBase)];
    // v9.1: every R2 song is in the music library, with the art of the
    // wallpaper it shares the most tags with.
    _r2Songs = [
      for (final o in songs)
        () {
          final mine = _content(_tagsOf(o));
          WallpaperTheme? best;
          var n = 0;
          for (final t in themes) {
            final k = _content(t.tags).intersection(mine).length;
            if (k > n) { n = k; best = t; }
          }
          return CatalogAmbientTrack(
              title: niceName('${o['name']}').replaceAll(RegExp(r'\s+song$'), ''),
              audioUrl: o['url'] as String,
              // No shared tag: borrow a stable wallpaper so no row is a blank tile.
              artUrl: () {
                bool img(String u) => RegExp(r'\.(png|jpe?g|webp|avif)(\?|$)', caseSensitive: false).hasMatch(u);
                if (best != null && img(best.assetPath)) return best.assetPath;
                // v9.1.1: else the best-matching still (most shared tags).
                WallpaperTheme? still;
                var m = 0;
                for (final t in themes) {
                  if (!img(t.assetPath)) continue;
                  final k = _content(t.tags).intersection(mine).length;
                  if (k > m) { m = k; still = t; }
                }
                if (still != null) return still.assetPath;
                final pics = [for (final t in themes) if (img(t.assetPath)) t.assetPath];
                return pics.isEmpty ? (best?.assetPath ?? '') : pics['${o['name']}'.hashCode.abs() % pics.length];
              }());
        }(),
    ];
    return themes;
  }

  List<CatalogAmbientTrack> _r2Songs = const [];
  /// v9.1: all songs in the R2 bucket.
  List<CatalogAmbientTrack> get r2Songs => _r2Songs;

  /// v8.7: a flat bucket of videos (live wallpapers), images (wallpapers)
  /// and audio (songs), each with tags. Songs attach to a live wallpaper
  /// through shared content tags (at least two in common).
  static final _img = RegExp(r'\.(jpe?g|png|webp|avif|gif)$', caseSensitive: false);
  static final _aud = RegExp(r'\.(m4a|mp3|aac|ogg|opus|wav|flac)$', caseSensitive: false);
  static const _autoTags = {'4K', '1440p', '1080p', '720p', 'SD', 'live wallpaper', 'wallpaper', 'song'};
  static const _fileTypes = {'mp4', 'm4v', 'mov', 'webm', 'jpg', 'jpeg', 'png', 'webp', 'avif', 'gif', 'm4a', 'mp3', 'aac', 'ogg', 'opus', 'wav', 'flac'};
  static Set<String> _content(List<String> t) =>
      {for (final x in t) if (!_autoTags.contains(x) && !_fileTypes.contains(x) && !x.startsWith('title:')) x};
  static List<String> _tagsOf(Map o) => [for (final x in (o['tags'] as List? ?? const [])) '$x'];
  String _kind(Map o) {
    final k = o['kind'];
    if (k is String) return k;
    final n = '${o['name']}';
    return _aud.hasMatch(n) ? 'audio' : _img.hasMatch(n) ? 'image' : 'video';
  }

  // The included starter = the default wallpaper. Ocean Reflection's source file
  // has streaked frames (checked by ffmpeg frame extract outside the app), so
  // the default is Reflection Lake.
  static bool _starter(String file) => niceName(file).toLowerCase().contains('reflection lake');
  static String _priceFor(List<String> tags) {
    if (tags.contains('4K')) return r'$7.99';
    if (tags.contains('1440p')) return r'$6.99';
    if (tags.contains('1080p')) return r'$4.99';
    if (tags.contains('720p')) return r'$3.99';
    return r'$2.99';
  }

  Map<String, String> _posters = const {};

  /// 48px placeholder (qa/make_thumbs.py) for any R2 image URL, or null.
  static String? thumbFor(String url) {
    if (!url.startsWith(mediaBaseUrl)) return null;
    final rest = Uri.decodeComponent(url.substring(mediaBaseUrl.length).split('?').first);
    if (rest.startsWith('thumbs/')) return null;
    final base = rest.split('/').last;
    if (!RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(base)) return null;
    return '${mediaBaseUrl}thumbs%2F${Uri.encodeComponent(base)}.jpg';
  }

  WallpaperTheme _r2Theme(Map o, [List<Map> songs = const [], Map<String, String> stillByBase = const {}]) {
    final url = o['url'] as String;
    final name = '${o['name']}';
    final still = _kind(o) == 'image';
    final tags = _tagsOf(o);
    final mine = _content(tags);
    final tracks = <AmbientTrack>[];
    if (!still) {
      for (final s in songs) {
        if (_content(_tagsOf(s)).intersection(mine).length >= 2) {
          tracks.add(AmbientTrack(
              number: tracks.length + 1,
              title: niceName('${s['name']}').replaceAll(RegExp(r'\s+song$'), ''),
              duration: '',
              mood: '',
              audioUrl: s['url'] as String));
        }
      }
    }
    return WallpaperTheme(
      id: 'r2-$name',
      name: _nameOr(niceName(name), tags),
      // Sharp poster: posters/ map, else sibling still (same title), else first-frame capture.
      assetPath: still
          ? url
          : (_posters[name] ??
              stillByBase[niceName(name).toLowerCase()] ??
              FirstFrames.srcFor(url)),
      videoPath: still ? null : url,
      creator: 'David Ebri',
      // v9.1.6 (PRD "Wallpapers & Music"): live loops are premium, sold one
      // by one in the $2.99-$7.99 band (priced by source quality); stills
      // are free.
      // The starter wallpaper (the default, Ocean Reflection) is included.
      tier: still ? 'Free Still' : (_starter(name) ? 'Included Live Loop' : 'Premium Live Loop'),
      isPremium: !still && !_starter(name),
      priceLabel: still || _starter(name) ? null : _priceFor(tags),
      collection: 'Collider Themes',
      tags: tags,
      tracks: tracks,
    );
  }

  void _applyR2(List list, String source) {
    final t = _fromList(list);
    if (t.isEmpty) return;
    t.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _themes = t;
    // Playtest #8: preload every 48px placeholder, and the first covers in full.
    var n = 0;
    for (final x in t) {
      final th = thumbFor(x.assetPath);
      if (th != null) DefaultCacheManager().getSingleFile(th).ignore();
      if (n++ < 12 && x.assetPath.startsWith('http')) DefaultCacheManager().getSingleFile(x.assetPath).ignore();
    }
    _songThemes = t.where((x) => x.tracks.isNotEmpty).toList();
    // Default: a portrait ocean loop (fits the phone, decodes everywhere tested).
    WallpaperTheme? pick(String n) => t.where((x) => x.name.toLowerCase().contains(n)).firstOrNull;
    _defaultSlug = (pick('reflection lake') ?? pick('ocean reflection') ?? t.where((x) => x.isLive).firstOrNull ?? t.first).id;
    _source = source;
    notifyListeners();
  }

  Future<void> _fetchRemote(Duration timeout) async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout, responseType: ResponseType.plain));
      final res = await dio.get<String>(themesUrl);
      final body = res.data;
      if (res.statusCode != 200 || body == null || body.isEmpty) return;
      final list = jsonDecode(body);
      if (list is! List || list.isEmpty) return;
      _applyR2(list, 'r2');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, body);
    } catch (e) {
      debugPrint('ThemeCatalog: theme list unavailable, keeping $_source: $e');
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
