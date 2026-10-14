import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Draws the video's first frame to a canvas (CORS: R2 allows it) and
/// returns a JPEG, at most 1080 px wide.
Future<Uint8List?> captureFirstFrame(String url) async {
  final v = web.HTMLVideoElement()
    ..crossOrigin = 'anonymous'
    ..muted = true
    ..preload = 'auto'
    ..playsInline = true;
  final done = Completer<Uint8List?>();
  void grab() {
    if (done.isCompleted) return;
    try {
      final w = v.videoWidth, h = v.videoHeight;
      if (w == 0 || h == 0) return done.complete(null);
      final s = w > 1080 ? 1080 / w : 1.0;
      final c = web.HTMLCanvasElement()
        ..width = (w * s).round()
        ..height = (h * s).round();
      (c.getContext('2d') as web.CanvasRenderingContext2D).drawImage(v, 0, 0, c.width.toDouble(), c.height.toDouble());
      c.toBlob(((web.Blob? b) {
        if (b == null) return done.complete(null);
        b.arrayBuffer().toDart.then((ab) => done.complete(ab.toDart.asUint8List()), onError: (_) => done.complete(null));
      }).toJS, 'image/jpeg', 0.85.toJS);
    } catch (_) {
      done.complete(null);
    }
  }
  // v9.1.6: many loops fade in from black, so the poster is taken a moment
  // in (1 s, or 10 % of a short clip), not at frame 0.
  var seeking = false;
  v.addEventListener('loadeddata', ((web.Event _) {
    final d = v.duration;
    final t = d.isFinite && d > 0 ? (d * 0.1 < 1 ? d * 0.1 : 1.0) : 0.0;
    if (t <= 0) return grab();
    seeking = true;
    v.currentTime = t;
  }).toJS);
  v.addEventListener('seeked', ((web.Event _) { if (seeking) grab(); }).toJS);
  v.addEventListener('error', ((web.Event _) { if (!done.isCompleted) done.complete(null); }).toJS);
  v.src = url;
  v.load();
  final r = await done.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
  v.removeAttribute('src');
  v.load();
  return r;
}
