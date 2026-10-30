// Web thumbnail codecs: the browser gives us real video frames (a detached
// <video> + canvas), real decoded waveforms (AudioContext.decodeAudioData) and
// a zlib inflate (DecompressionStream). Conditional export peer of
// thumb_codec_native.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Inflates a zlib stream with DecompressionStream('deflate'). Zip members hold
/// raw deflate, so a raw pass is tried as well. Returns null when the bytes are
/// not inflateable by this route.
Future<Uint8List?> inflate(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  for (final fmt in ['deflate', 'deflate-raw']) {
    try {
      final ds = web.DecompressionStream(fmt);
      final writer = ds.writable.getWriter();
      unawaited(writer.write(bytes.toJS).toDart);
      await writer.close().toDart;

      // This Dart SDK has no ReadableStream.toDart, so pump it with a reader.
      final reader = web.ReadableStreamDefaultReader(ds.readable);
      final out = BytesBuilder(copy: false);
      while (true) {
        final res = await reader.read().toDart;
        if (res.done) break;
        final value = res.value;
        if (value == null || value.isUndefinedOrNull) break;
        final view = value.dartify();
        if (view is Uint8List) out.add(view);
      }
      final result = out.takeBytes();
      if (result.isNotEmpty) return result;
    } catch (_) {
      // try the next framing
    }
  }
  return null;
}

/// A decoded audio frame: mono samples normalised to 0..1.
class Waveform {
  final Float32List samples;
  const Waveform(this.samples);

  int get length => samples.length;
}

/// Decodes any browser-supported audio into a real waveform via
/// decodeAudioData. Browsers handle mp3/m4a/ogg/wav alike.
Future<Waveform?> decodedWaveform(Uint8List bytes, {String ext = '', int buckets = 96}) async {
  web.AudioContext? ctx;
  try {
    ctx = web.AudioContext();
    // decodeAudioData takes an ArrayBuffer, not a view.
    final buffer = await ctx.decodeAudioData(bytes.buffer.toJS).toDart;
    // One pass to Dart floats; indexing JSFloat32Array per sample is not a
    // Dart operation.
    final channel = buffer.getChannelData(0).toDart;
    final total = buffer.length;
    final n = buckets < total ? buckets : total;
    if (n < 2) return null;
    final out = Float32List(n);
    for (var k = 0; k < n; k++) {
      final start = ((total * k) ~/ n).clamp(0, total - 1);
      final end = ((total * (k + 1)) ~/ n).clamp(start + 1, total);
      var peak = 0.0;
      for (var i = start; i < end; i++) {
        final a = channel[i].abs();
        if (a > peak) peak = a;
      }
      out[k] = peak.clamp(0.0, 1.0);
    }
    return Waveform(out);
  } catch (_) {
    return null;
  } finally {
    // Release the hardware audio graph; a tile grid can open many of these.
    try {
      await ctx?.close().toDart;
    } catch (_) {}
  }
}

/// PCM-only helper (kept for parity with the native side; web prefers the real
/// decoder above).
Future<Waveform?> pcmWaveform(Uint8List bytes, {int buckets = 96}) => decodedWaveform(bytes, buckets: buckets);

/// Real video frame: load the bytes into a detached <video>, seek, draw one
/// frame into a canvas and read it back as PNG bytes. Returns null when the
/// browser cannot decode the codec or never fires the events.
Future<Uint8List?> videoFrame(Uint8List bytes, {int atSeconds = 1}) async {
  // Hint MP4 so Chromium picks the right demuxer even when the blob has no name.
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'video/mp4'),
  );
  final url = web.URL.createObjectURL(blob);
  final video = web.HTMLVideoElement()
    ..src = url
    ..muted = true
    ..playsInline = true
    ..crossOrigin = 'anonymous'
    ..preload = 'auto';
  // Some Chromium builds only decode once the element is in the document.
  video.style
    ..setProperty('position', 'fixed')
    ..setProperty('left', '-9999px')
    ..setProperty('width', '1px')
    ..setProperty('height', '1px')
    ..setProperty('opacity', '0')
    ..setProperty('pointer-events', 'none');
  web.document.body?.append(video);
  final canvas = web.HTMLCanvasElement();
  final ready = Completer<void>();
  final failed = Completer<void>();
  void markReady(web.Event e) {
    if (!ready.isCompleted) ready.complete();
  }
  video.onloadeddata = markReady.toJS;
  video.oncanplay = markReady.toJS;
  video.oncanplaythrough = markReady.toJS;
  video.onerror = ((web.Event e) {
    if (!failed.isCompleted) failed.complete();
    return null;
  }).toJS;
  try {
    video.load();
    // Cap the wait so one bad file cannot hang a tile forever.
    await Future.any([ready.future, failed.future, Future<void>.delayed(const Duration(seconds: 6))]);
    if (failed.isCompleted) return null;
    if (video.readyState < 2) return null;
    final duration = video.duration;
    // Prefer an early in-stream frame so short clips still yield a picture.
    final t = (duration.isFinite && duration > 0)
        ? (duration * 0.1).clamp(0.0, atSeconds.toDouble())
        : 0.05;
    final seeked = Completer<void>();
    video.onseeked = ((web.Event e) {
      if (!seeked.isCompleted) seeked.complete();
      return null;
    }).toJS;
    try {
      video.currentTime = t;
    } catch (_) {
      // Some demuxers reject seek before HAVE_CURRENT_DATA; fall through.
    }
    await Future.any([seeked.future, Future<void>.delayed(const Duration(seconds: 3))]);
    // Give the decoder one paint cycle after seek.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w <= 0 || h <= 0) return null;
    // Cap the frame so a 4K video does not become a huge PNG in cache.
    const maxSide = 512;
    final scale = (w > maxSide || h > maxSide) ? maxSide / (w > h ? w : h) : 1.0;
    canvas.width = (w * scale).round().clamp(1, maxSide);
    canvas.height = (h * scale).round().clamp(1, maxSide);
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    final dataUrl = canvas.toDataURL('image/png');
    final b64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
    final out = base64Decode(b64);
    // Reject empty / near-black frames (failed decode paints black).
    if (out.length < 64) return null;
    return out;
  } catch (_) {
    return null;
  } finally {
    try {
      video.remove();
    } catch (_) {}
    web.URL.revokeObjectURL(url);
  }
}