// Files the user actually added to Collider (v8.2 fix pass, DEVIATIONS D22).
//
// Every file picked in Files (+), attached in the composer, or attached to a
// model pill is recorded here with its real name, size and time (index in
// SharedPreferences) and, on web, its contents in IndexedDB (FileBlobs,
// v8.2 round 3, D32), so it opens again after a reload. Files lists only
// these: there are no sample entries. Caps: 25 MB a file, 250 MB in total.
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_blobs.dart';

class StoredFile {
  final String id;
  final String name;
  final int sizeBytes;
  final String type; // Document | Writing | Image | Video | Audio | Data
  final int addedAtMs;
  final String source; // files | composer | model

  const StoredFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.type,
    required this.addedAtMs,
    required this.source,
  });

  DateTime get addedAt => DateTime.fromMillisecondsSinceEpoch(addedAtMs);

  Map<String, Object> toJson() =>
      {'id': id, 'name': name, 'size': sizeBytes, 'type': type, 'at': addedAtMs, 'src': source};

  static StoredFile? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = j['name'];
    if (name is! String || name.isEmpty) return null;
    return StoredFile(
      id: (j['id'] as String?) ?? name,
      name: name,
      sizeBytes: (j['size'] as num?)?.toInt() ?? 0,
      // The name is authoritative: records written before audio/office had
      // their own type saved every one of them as 'Document', so re-derive.
      type: FileStore.typeFor(name),
      addedAtMs: (j['at'] as num?)?.toInt() ?? 0,
      source: (j['src'] as String?) ?? 'files',
    );
  }
}

class FileStore extends ChangeNotifier {
  FileStore._();
  static final FileStore instance = FileStore._();
  static const String _prefsKey = 'collider_files_v1';
  static const int maxFileBytes = 25 * 1024 * 1024;
  /// Videos may be bigger (map row 19, D55).
  static const int maxVideoBytes = 100 * 1024 * 1024;
  static int capFor(String name) => isVideo(name) ? maxVideoBytes : maxFileBytes;
  static const int maxTotalBytes = 250 * 1024 * 1024;

  /// A quiet one-line note about the last add (e.g. a file over the cap);
  /// Files shows it under its search field.
  final ValueNotifier<String?> notice = ValueNotifier<String?>(null);

  final List<StoredFile> _files = [];
  bool _loaded = false;
  Future<void>? _loading;

  /// Newest first.
  List<StoredFile> get files => List.unmodifiable(_files);

  /// The lower-case extension, or '' when the name has none.
  static String extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static String typeFor(String name) {
    final ext = extOf(name);
    if (const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'heic', 'svg', 'bmp'].contains(ext)) return 'Image';
    if (_videoExt.contains(ext)) return 'Video';
    if (_audioExt.contains(ext)) return 'Audio';
    if (const ['json', 'csv', 'tsv', 'yaml', 'yml', 'xml', 'xlsx', 'xls', 'parquet', 'sqlite'].contains(ext)) return 'Data';
    if (const ['txt', 'md', 'markdown', 'doc', 'docx', 'rtf', 'odt', 'pages'].contains(ext)) return 'Writing';
    return 'Document';
  }

  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final s = (await SharedPreferences.getInstance()).getString(_prefsKey);
      if (s != null && s.isNotEmpty) {
        final list = jsonDecode(s);
        if (list is List) {
          _files
            ..clear()
            ..addAll(list.map(StoredFile.fromJson).whereType<StoredFile>());
        }
      }
      if (_files.isNotEmpty) {
        // Only files whose contents are really stored (records from the
        // metadata-only build, or cleared site data, cannot be opened).
        final keys = await FileBlobs.keys();
        final before = _files.length;
        _files.removeWhere((f) => !keys.contains(f.id));
        if (_files.length != before) await _save();
      }
    } catch (e) {
      debugPrint('FileStore: ignored unreadable store: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  bool get loaded => _loaded;

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_prefsKey, jsonEncode([for (final f in _files) f.toJson()]));
    } catch (_) {}
  }

  int get totalBytes => _files.fold(0, (a, f) => a + f.sizeBytes);

  /// Records and stores files the user just picked ([source]: files |
  /// composer | model). Returns a quiet note for anything not kept (over the
  /// cap, unreadable, or storage failed), also published on [notice].
  Future<String?> addPicked(List<PlatformFile> picked, String source) async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;
    final skipped = <String>[];
    var tooBig = false;
    var i = 0;
    for (final f in picked) {
      if (f.name.isEmpty) continue;
      final id = '$now-${i++}-${f.name}';
      if (f.size > capFor(f.name) || totalBytes + f.size > maxTotalBytes) {
        skipped.add(f.name);
        tooBig = true;
        continue;
      }
      final Uint8List? bytes = f.bytes;
      if (bytes == null || !await FileBlobs.put(id, bytes)) {
        skipped.add(f.name);
        continue;
      }
      _files.insert(
        0,
        StoredFile(id: id, name: f.name, sizeBytes: f.size, type: typeFor(f.name), addedAtMs: now, source: source),
      );
    }
    notifyListeners();
    await _save();
    String? note;
    if (skipped.isNotEmpty) {
      final what = skipped.length == 1 ? skipped.first : '${skipped.length} files';
      note = tooBig ? '$what not kept: too big' : '$what could not be kept';
    }
    notice.value = note;
    return note;
  }

  /// Saves app-made content (e.g. a model answer) as a file the user owns.
  Future<String?> addBytes(String name, Uint8List bytes, String source) =>
      addPicked([PlatformFile(name: name, size: bytes.length, bytes: bytes)], source);

  /// The stored contents, or null (not found).
  Future<Uint8List?> bytesOf(String id) => FileBlobs.get(id);

  /// v9.1 bulk delete.
  Future<void> removeMany(Iterable<String> ids) async {
    final set = ids.toSet();
    _files.removeWhere((f) => set.contains(f.id));
    notifyListeners();
    await _save();
    for (final id in set) {
      await FileBlobs.delete(id);
    }
  }

  /// v9.1 bulk edit: rename (a shared base name; extensions kept, numbered).
  Future<void> renameMany(List<String> ids, String base) async {
    base = base.trim();
    if (base.isEmpty) return;
    var n = 0;
    for (var i = 0; i < _files.length; i++) {
      final f = _files[i];
      if (!ids.contains(f.id)) continue;
      n++;
      final dot = f.name.lastIndexOf('.');
      final ext = dot > 0 ? f.name.substring(dot) : '';
      final name = ids.length == 1 ? '$base$ext' : '$base $n$ext';
      _files[i] = StoredFile(id: f.id, name: name, sizeBytes: f.sizeBytes, type: f.type, addedAtMs: f.addedAtMs, source: f.source);
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _files.removeWhere((f) => f.id == id);
    notifyListeners();
    await _save();
    await FileBlobs.delete(id);
  }

  static String mimeFor(String name) {
    return const {
          'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'webp': 'image/webp', 'gif': 'image/gif',
          'bmp': 'image/bmp', 'svg': 'image/svg+xml', 'pdf': 'application/pdf', 'txt': 'text/plain', 'md': 'text/markdown',
          'csv': 'text/csv', 'json': 'application/json', 'xml': 'application/xml', 'html': 'text/html',
          'mp4': 'video/mp4', 'm4v': 'video/mp4', 'mov': 'video/quicktime', 'webm': 'video/webm', 'ogv': 'video/ogg',
          // Audio used to fall through to octet-stream, which is what made an
          // mp3 open as a download rather than a file.
          'mp3': 'audio/mpeg', 'm4a': 'audio/mp4', 'aac': 'audio/aac', 'wav': 'audio/wav', 'wave': 'audio/wav',
          'ogg': 'audio/ogg', 'oga': 'audio/ogg', 'opus': 'audio/opus', 'flac': 'audio/flac', 'm4b': 'audio/mp4',
          'weba': 'audio/webm', 'aiff': 'audio/aiff', 'aif': 'audio/aiff',
          // Documents.
          'rtf': 'application/rtf', 'doc': 'application/msword',
          'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'odt': 'application/vnd.oasis.opendocument.text',
          'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'xls': 'application/vnd.ms-excel',
          'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'yaml': 'text/yaml', 'yml': 'text/yaml', 'tsv': 'text/tab-separated-values', 'log': 'text/plain',
        }[extOf(name)] ??
        'application/octet-stream';
  }

  /// Opens in-app as text (plain-text formats).
  static bool isText(String name) {
    final ext = extOf(name);
    return const ['txt', 'md', 'markdown', 'csv', 'tsv', 'json', 'yaml', 'yml', 'xml', 'log', 'dart', 'py', 'js', 'ts', 'html', 'css']
        .contains(ext);
  }

  static const _videoExt = ['mp4', 'm4v', 'mov', 'webm', 'ogv'];
  static const _audioExt = ['mp3', 'm4a', 'aac', 'wav', 'wave', 'ogg', 'oga', 'opus', 'flac', 'm4b', 'weba', 'aiff', 'aif'];

  /// Plays in the in-app video player (map row 19).
  static bool isVideo(String name) => _videoExt.contains(extOf(name));

  /// Plays in the in-app audio player.
  static bool isAudio(String name) => _audioExt.contains(extOf(name));

  static bool isPdf(String name) => extOf(name) == 'pdf';

  /// Markdown, rendered as markdown rather than dumped as source.
  static bool isMarkdown(String name) => const ['md', 'markdown'].contains(extOf(name));

  /// Source and tabular text: shown with line numbers, not as prose.
  static bool isCode(String name) => const ['json', 'csv', 'tsv', 'yaml', 'yml', 'xml', 'dart', 'py', 'js', 'ts', 'html', 'css', 'log'].contains(extOf(name));

  /// Office formats we can read text out of with the zip probe.
  static bool isOfficeText(String name) => const ['docx', 'odt', 'pptx', 'xlsx', 'xlsm'].contains(extOf(name));

  static bool isRtf(String name) => extOf(name) == 'rtf';

  /// Opens in-app as an image (formats Flutter decodes).
  static bool isImage(String name) => const ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'].contains(extOf(name));

  /// Anything Files has a real in-app viewer for. Everything else gets the
  /// unsupported plate, which still offers "Open with another app".
  static bool isSupportedInApp(String name) =>
      isImage(name) || isVideo(name) || isAudio(name) || isText(name) || isPdf(name) || isOfficeText(name) || isRtf(name);

  static String sizeLabel(int b) {
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }
}
