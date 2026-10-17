import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../files/file_blobs.dart';
import 'first_frame_capture.dart';

/// v8.8: a live wallpaper's poster is its own first frame, captured in the
/// app (no stored poster, no default). Cached in memory and app storage.
class FirstFrames {
  FirstFrames._();
  static const String scheme = 'frame:';
  static final Map<String, Future<Uint8List?>> _mem = {};
  static int _active = 0;
  static final List<Completer<void>> _wait = [];

  static String srcFor(String videoUrl) => '$scheme$videoUrl';
  static bool isFrame(String? src) => src != null && src.startsWith(scheme);

  static Future<Uint8List?> get(String videoUrl) => _mem[videoUrl] ??= _load(videoUrl);

  static Future<Uint8List?> _load(String url) async {
    final key = 'poster2:$url';
    try {
      final hit = await FileBlobs.get(key);
      if (hit != null && hit.isNotEmpty) return hit;
    } catch (_) {}
    while (_active >= 3) {
      final c = Completer<void>();
      _wait.add(c);
      await c.future;
    }
    _active++;
    try {
      final b = await captureFirstFrame(url);
      if (b != null) unawaited(FileBlobs.put(key, b).then((_) {}, onError: (_) {}));
      return b;
    } finally {
      _active--;
      if (_wait.isNotEmpty) _wait.removeAt(0).complete();
    }
  }
}

/// ImageProvider over [FirstFrames] so every poster consumer (covers,
/// reflections, precache) works unchanged.
@immutable
class FirstFrameImage extends ImageProvider<FirstFrameImage> {
  final String videoUrl;
  const FirstFrameImage(this.videoUrl);
  @override
  Future<FirstFrameImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(FirstFrameImage key, ImageDecoderCallback decode) => MultiFrameImageStreamCompleter(
        codec: () async {
          final b = await FirstFrames.get(videoUrl);
          if (b == null) throw StateError('no first frame for $videoUrl');
          return decode(await ui.ImmutableBuffer.fromUint8List(b));
        }(),
        scale: 1,
      );
  @override
  bool operator ==(Object other) => other is FirstFrameImage && other.videoUrl == videoUrl;
  @override
  int get hashCode => videoUrl.hashCode;
}
