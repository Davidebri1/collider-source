// Real thumbnails for stored files, and the cache in front of them.
//
// One entry point: FileThumbs.of(file) -> Future<ThumbResult>. It works out
// what kind of thumbnail the file can honestly have, builds it at most once
// (in-flight work is shared), runs at most [maxConcurrent] builds at a time,
// and evicts past [maxEntries] so a big library cannot grow without bound.
//
// The cache key is id|sizeBytes|addedAtMs — the store's stand-in for
// (path, mtime): if any of the three change, the bytes are different and the
// entry is rebuilt.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'audio_art.dart';
import 'file_store.dart';
import 'office_probe.dart';
import 'pdf_probe.dart';
import 'text_probe.dart';
import 'thumb_codec.dart';

/// What a thumbnail actually is. The UI switches on this; a `kind` result is a
/// designed plate, not a failure.
sealed class ThumbResult {
  const ThumbResult();
}

/// Decoded image bytes (a real photograph, a real video frame, cover art).
class ThumbImage extends ThumbResult {
  final Uint8List bytes;
  const ThumbImage(this.bytes);
}

/// Real text: the first lines of a text/office file, or a PDF's words.
class ThumbLines extends ThumbResult {
  final List<String> lines;
  const ThumbLines(this.lines);
}

/// A real decoded waveform (peaks 0..1) for audio.
class ThumbWave extends ThumbResult {
  final Float32List peaks;
  const ThumbWave(this.peaks);
}

/// Nothing to extract from this file: render the type plate.
class ThumbKind extends ThumbResult {
  /// The type family, for choosing the plate's icon and label.
  final String family;
  const ThumbKind(this.family);
}

class FileThumbs {
  FileThumbs._();

  /// Two at a time: enough to keep a grid filling, few enough that a folder of
  /// 200 videos does not stall the UI isolate's event loop.
  static const int maxConcurrent = 2;
  /// LRU cap. Each entry is a thumbnail, not the whole file, so this is cheap.
  static const int maxEntries = 128;

  static final Map<String, ThumbResult> _cache = <String, ThumbResult>{};
  static final Map<String, Future<ThumbResult>> _inflight = <String, Future<ThumbResult>>{};
  static int _running = 0;
  /// FIFO of build closures waiting for a slot.
  static final List<void Function()> _pending = <void Function()>[];

  /// Builds (or returns) the thumbnail for [file].
  static Future<ThumbResult> of(StoredFile file) {
    final key = _key(file);
    final hit = _cache[key];
    if (hit != null) {
      // Touch for LRU.
      _cache.remove(key);
      _cache[key] = hit;
      return Future<ThumbResult>.value(hit);
    }
    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _schedule(() async {
      try {
        final bytes = await FileStore.instance.bytesOf(file.id);
        final result = (bytes == null) ? ThumbKind(_family(file)) : await build(file, bytes);
        _cache[key] = result;
        while (_cache.length > maxEntries) {
          _cache.remove(_cache.keys.first);
        }
        return result;
      } catch (e) {
        debugPrint('FileThumbs: ${file.name}: $e');
        return ThumbKind(_family(file));
      } finally {
        _inflight.remove(key);
      }
    });
    _inflight[key] = future;
    return future;
  }

  /// Drops a deleted file's entry so the bytes are not kept alive.
  static void forget(StoredFile file) {
    _cache.remove(_key(file));
    _inflight.remove(_key(file));
  }

  static String _key(StoredFile f) => '${f.id}|${f.sizeBytes}|${f.addedAtMs}';

  /// Queues work behind the concurrency gate: at most [maxConcurrent] builds
  /// run at once, the rest wait in FIFO order and are released as slots free.
  static Future<ThumbResult> _schedule(Future<ThumbResult> Function() job) {
    final completer = Completer<ThumbResult>();
    void waiter() {
      _running++;
      job().then(completer.complete, onError: completer.completeError).whenComplete(_release);
    }

    if (_running < maxConcurrent) {
      waiter();
    } else {
      _pending.add(waiter);
    }
    return completer.future;
  }

  static void _release() {
    _running--;
    if (_pending.isNotEmpty) {
      _pending.removeAt(0)();
    }
  }

  /// Builds the thumbnail for bytes we already hold. Public so the readers and
  /// the harness can call the probes directly.
  static Future<ThumbResult> build(StoredFile file, Uint8List bytes) async {
    final name = file.name;
    if (FileStore.isImage(name)) return ThumbImage(bytes);

    if (FileStore.isVideo(name)) {
      final frame = await videoFrame(bytes, atSeconds: 1);
      return frame == null ? const ThumbKind('Video') : ThumbImage(frame);
    }

    if (FileStore.isAudio(name)) {
      final ext = _ext(name);
      final art = coverArt(bytes, ext: ext);
      if (art != null && art.isNotEmpty) return ThumbImage(art);
      final wave = await decodedWaveform(bytes, ext: ext);
      return wave == null ? const ThumbKind('Audio') : ThumbWave(wave.samples);
    }

    if (FileStore.isPdf(name)) {
      final doc = await probePdf(bytes);
      if (!doc.isEmpty) {
        final lines = doc.pages.first.lines;
        if (lines.isNotEmpty) return ThumbLines(lines);
      }
      return const ThumbKind('PDF');
    }

    if (FileStore.isOfficeText(name) || FileStore.isRtf(name)) {
      final lines = await probeOffice(bytes, name);
      if (lines != null && lines.isNotEmpty) return ThumbLines(lines);
      return const ThumbKind('Document');
    }

    if (FileStore.isText(name)) {
      return ThumbLines(head(decodeText(bytes), max: 8));
    }

    return ThumbKind(_family(file));
  }

  static String _ext(String name) => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  static String _family(StoredFile f) {
    if (FileStore.isImage(f.name)) return 'Image';
    if (FileStore.isVideo(f.name)) return 'Video';
    if (FileStore.isAudio(f.name)) return 'Audio';
    if (FileStore.isPdf(f.name)) return 'PDF';
    if (FileStore.isText(f.name)) return 'Text';
    if (FileStore.isOfficeText(f.name)) return 'Document';
    if (f.type == 'Data') return 'Data';
    return 'Document';
  }
}