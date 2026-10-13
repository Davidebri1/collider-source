import '../core/media/theme_catalog.dart';

/// Rewrites a filename-shaped title into something a person would have typed.
///
/// Drive imports are named after their source file, so `name` arrives as
/// `0251d1e0-16a1-49ad-9807-19d1bceac3e9_1080_hd` or
/// `5899755_Landscape_Lake_1920x1080`. A curated title such as `Spatial
/// Drift` has none of the filename markers and is returned untouched.
///
/// Detects a filename by underscores, a hyphened slug, a media extension or
/// an explicit resolution pair, then drops the extension, UUID/hex prefix,
/// resolution and copy/export markers, long digit runs and date stamps.
String humanizeThemeName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return 'Untitled Theme';

  final shaped = name.contains('_') ||
      name.contains('-') ||
      RegExp(r'\.[a-z0-9]{2,4}$', caseSensitive: false).hasMatch(name) ||
      RegExp(r'\d{3,4}\s*[x\u00d7]\s*\d{3,4}', caseSensitive: false).hasMatch(name);
  if (!shaped) return name;

  // Some names are pure id - `0251d1e0-16a1-...`, `138588-770315514_medium`.
  // Keep a short stable tag so a list of them stays distinguishable instead
  // of printing "Untitled Theme" five times over.
  final tag = RegExp(r'[0-9a-f]{6,}|\d{4,}', caseSensitive: false).firstMatch(name)?.group(0);
  final untitled = tag == null || tag.length < 4 ? 'Untitled Theme' : 'Untitled ${tag.substring(0, 4).toUpperCase()}';

  var s = name
      .replaceAll(RegExp(r'\.[a-z0-9]{2,4}$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*[-_]\s*Copy(\s*\d+)?$', caseSensitive: false), '')
      // A copy counter carries no meaning on its own: "medium (1)" -> "medium".
      .replaceAll(RegExp(r'\(\s*\d+\s*\)'), ' ')
      // A leading index the uploader added: "0_Gold_Glitter" -> "Gold_Glitter".
      .replaceFirst(RegExp(r'^\d{1,2}[_\s]+'), '')
      // A leading UUID or long hex run, e.g. 0251d1e0-16a1-49ad-...
      .replaceAll(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', caseSensitive: false), '')
      .replaceAll(RegExp(r'^[0-9a-f]{10,}', caseSensitive: false), '')
      .replaceAll(RegExp(r'\d{3,4}\s*[x\u00d7]\s*\d{3,4}', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'[_\u00d7]', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s*-\s*'), ' ')
      .replaceAll(RegExp(r'\b\d{3,}\b', caseSensitive: false), ' ')
      .replaceAll(
          RegExp(
              r'\b(copy|final|export|hd|uhd|sd|4k|8k|fps|raw|master|medium|small|large|original|preview|draft|temp|img|image|video|audio|file|wallpaper)\b',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (s.isEmpty || RegExp(r'^[\d\s()]+$').hasMatch(s)) return untitled;

  // Title-case only all-lowercase words: that tidies `bedroom_overlooking`
  // without flattening an intentional `GettyImages`.
  s = s
      .split(' ')
      .map((w) => w.isEmpty
          ? w
          : (RegExp(r'[A-Z]').hasMatch(w.substring(1))
              ? w
              : w[0].toUpperCase() + w.substring(1)))
      .join(' ');
  return s;
}

/// v9.1.4 (playtest #10): a title a person would have chosen, or [fallback].
/// An id-shaped name ("0251d1e0-16a1-…") tidies into letter salad such as
/// "D E A Ad D Bceac E"; those, and "Untitled …", give way to the fallback.
String displayTitle(String raw, String fallback) {
  final h = humanizeThemeName(raw);
  final words = h.split(' ').where((w) => w.isNotEmpty).toList();
  final short = words.where((w) => w.length <= 2).length;
  final hexy = RegExp(r'^[0-9a-f]{4,}$', caseSensitive: false);
  final bad = h.startsWith('Untitled') || words.isEmpty || short * 2 >= words.length || words.any((w) => hexy.hasMatch(w) && RegExp(r'\d').hasMatch(w));
  return bad ? fallback : h;
}

/// One track in a theme pack's 5-track soundscape.
class AmbientTrack {
  final int number;
  final String title;
  final String duration;
  final String mood;

  /// Optional streamable audio URL (absolute). Null when the pack ships titles only.
  final String? audioUrl;

  const AmbientTrack({
    required this.number,
    required this.title,
    required this.duration,
    this.mood = 'Ambient',
    this.audioUrl,
  });

  factory AmbientTrack.fromJson(Map<String, dynamic> j, {Uri? base}) {
    final t = (j['title'] as String?) ?? '';
    return AmbientTrack(
        number: (j['number'] as num?)?.toInt() ?? 0,
        // A blank title stays blank: the player drops untitled tracks, and
        // naming them would put "Untitled Theme" in the queue.
        title: t.trim().isEmpty ? '' : humanizeThemeName(t),
        duration: (j['duration'] as String?) ?? '',
        mood: (j['mood'] as String?) ?? 'Ambient',
        audioUrl: ThemeCatalog.resolve(j['audio'] as String?, base),
      );
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'title': title,
        'duration': duration,
        'mood': mood,
        if (audioUrl != null) 'audio': audioUrl,
      };
}

/// A wallpaper theme (free still or premium live pack).
///
/// Media fields hold either an absolute https URL (streamed from the
/// collider-media host) or a bundled asset path. Use [ThemeMedia.isNetwork]
/// to tell them apart; the widgets in `features/theme/theme_living_media.dart`
/// handle both.
class WallpaperTheme {
  final String id;
  final String name;

  /// Poster image (about 720px wide). Used for covers, thumbnails, and as the
  /// first frame while [videoPath] streams in. Historically named assetPath.
  final String assetPath;

  /// Optional looping live wallpaper (H.264 mp4, 720p, muted).
  final String? videoPath;
  /// v9.1: tags from the R2 bucket (content, resolution, type, file type).
  final List<String> tags;

  /// Optional higher resolution still for full-bleed use (free themes).
  final String? stillPath;

  final bool isPremium;
  final String creator;
  final String tier;
  final String collection;
  final List<AmbientTrack> tracks;
  final String? productId;
  final String? priceLabel;

  const WallpaperTheme({
    required this.id,
    required this.name,
    required this.assetPath,
    this.videoPath,
    this.tags = const [],
    this.stillPath,
    this.isPremium = false,
    this.creator = 'Studio Nebula',
    this.tier = 'Standard Spatial',
    this.collection = 'Spatial Ambient Series',
    this.productId,
    this.priceLabel,
    this.tracks = const [],
  });

  /// Slug in the media catalog (same as [id]).
  String get slug => id;

  /// Poster URL or asset path.
  String get posterUrl => assetPath;

  /// Video URL or asset path, when the theme is live.
  String? get videoUrl => videoPath;

  /// Best source for a full-bleed still: [stillPath] when present, else poster.
  String get wallpaperStill => stillPath ?? assetPath;

  bool get isLive => videoPath != null && videoPath!.isNotEmpty;

  factory WallpaperTheme.fromJson(Map<String, dynamic> j, {Uri? base}) {
    final premium = j['premium'] == true;
    final tracks = (j['tracks'] as List? ?? const [])
        .whereType<Map>()
        .map((t) => AmbientTrack.fromJson(t.cast<String, dynamic>(), base: base))
        .toList(growable: false);
    return WallpaperTheme(
      id: j['slug'] as String,
      name: humanizeThemeName((j['name'] as String?) ?? (j['slug'] as String)),
      assetPath: ThemeCatalog.resolve(j['poster'] as String?, base) ?? '',
      videoPath: ThemeCatalog.resolve(j['video'] as String?, base),
      stillPath: ThemeCatalog.resolve(j['still'] as String?, base),
      isPremium: premium,
      creator: (j['creator'] as String?) ?? 'Collider Studio',
      tier: (j['tier'] as String?) ?? (premium ? 'Elite 4K Live Pack' : 'Free Spatial Canvas'),
      collection: (j['collection'] as String?) ?? 'Spatial Ambient Series',
      productId: (j['productId'] as String?) ?? (premium ? 'collider.theme.${j['slug']}' : null),
      priceLabel: j['price'] as String?,
      tracks: tracks,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': id,
        'name': name,
        'collection': collection,
        'creator': creator,
        'tier': tier,
        'premium': isPremium,
        'price': priceLabel,
        'productId': productId,
        'poster': assetPath,
        'video': videoPath,
        if (stillPath != null) 'still': stillPath,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };
}

/// Compatibility facade over [ThemeCatalog] (runtime-loaded catalog).
/// Existing call sites keep working; new code should use ThemeCatalog.instance.
class WallpaperCatalog {
  WallpaperCatalog._();

  static List<WallpaperTheme> get freeThemes => ThemeCatalog.instance.freeThemes;
  static List<WallpaperTheme> get premiumThemes => ThemeCatalog.instance.premiumThemes;
  static WallpaperTheme get defaultTheme => ThemeCatalog.instance.defaultTheme;
}
