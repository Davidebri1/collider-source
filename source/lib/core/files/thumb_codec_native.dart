// Native (iOS / Android) thumbnail codecs: dart:io zlib for inflate, a real
// WAV/AIFF PCM pass for the waveform. No video frame: there is no
// video_thumbnail dependency available, so video tiles use the plate.
import 'dart:io';
import 'dart:typed_data';

/// Inflates a zlib/deflate stream. Returns null when the bytes are not a
/// stream this platform can inflate, so callers fall back rather than throw.
Future<Uint8List?> inflate(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  // Zip members hold a raw deflate stream (no zlib header); PDF FlateDecode is
  // usually zlib-wrapped. Try both framings, most likely first. Note that the
  // raw decoder returns an EMPTY list for junk instead of throwing, so a
  // zero-length result counts as a failed framing, not a success.
  for (final raw in [false, true]) {
    try {
      final out = ZLibDecoder(raw: raw).convert(bytes);
      if (out.isNotEmpty) return Uint8List.fromList(out);
    } catch (_) {
      // try the next framing
    }
  }
  return null;
}

/// A decoded audio frame: mono samples normalised to 0..1, one value per
/// bucket across [buckets] slots.
class Waveform {
  final Float32List samples;
  const Waveform(this.samples);

  int get length => samples.length;
}

/// Reads a WAV (RIFF) or AIFF container and reduces the PCM payload to
/// [buckets] normalised peaks. Returns null when the container is not one of
/// those or the payload is not raw PCM.
Future<Waveform?> pcmWaveform(Uint8List bytes, {int buckets = 96}) async {
  if (_isWav(bytes)) return _wav(bytes, buckets);
  if (_isAiff(bytes)) return _aiff(bytes, buckets);
  return null;
}

bool _ascii(Uint8List b, int at, String s) {
  if (at + s.length > b.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[at + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

bool _isWav(Uint8List b) => _ascii(b, 0, 'RIFF') && _ascii(b, 8, 'WAVE');
bool _isAiff(Uint8List b) => _ascii(b, 0, 'FORM') && _ascii(b, 8, 'AIFF');

/// Little-endian reader: every WAV field is LE.
int _le32(Uint8List b, int at) => b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);
int _le16(Uint8List b, int at) => b[at] | (b[at + 1] << 8);
/// Big-endian reader: AIFF is BE throughout.
int _be32(Uint8List b, int at) => (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
int _be16(Uint8List b, int at) => (b[at] << 8) | b[at + 1];

/// Finds the `data` chunk of a RIFF body, honouring odd chunk padding.
({int offset, int length})? _wavData(Uint8List b) {
  var at = 12;
  while (at + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(at, at + 4));
    final size = _le32(b, at + 4);
    final body = at + 8;
    if (id == 'data') {
      return (offset: body, length: size > b.length - body ? b.length - body : size);
    }
    // Chunks are word aligned.
    at = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

Waveform? _wav(Uint8List b, int buckets) {
  final data = _wavData(b);
  if (data == null || data.length < 2) return null;
  // Bits per sample lives in the `fmt ` chunk; assume 16-bit when unreadable,
  // which is the overwhelmingly common case.
  var bits = 16;
  var channels = 1;
  var fmt = 12;
  while (fmt + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(fmt, fmt + 4));
    final size = _le32(b, fmt + 4);
    if (id == 'fmt ' && size >= 16) {
      channels = _le16(b, fmt + 10);
      bits = _le16(b, fmt + 22);
      break;
    }
    fmt = fmt + 8 + size + (size.isOdd ? 1 : 0);
  }
  final bytesPerSample = (bits / 8).round().clamp(1, 4);
  final frameSize = bytesPerSample * (channels < 1 ? 1 : channels);
  final frames = data.length ~/ frameSize;
  if (frames < 2) return null;
  return _reduce(b, data.offset, frames, frameSize, bytesPerSample, little: true, buckets: buckets);
}

Waveform? _aiff(Uint8List b, int buckets) {
  // AIFF: FORM ... COMM chunk holds numChannels(2) numSampleFrames(4) bits(2).
  var at = 12;
  var bits = 16;
  var channels = 1;
  var frames = 0;
  int? dataOffset;
  int? dataLength;
  while (at + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(at, at + 4));
    final size = _be32(b, at + 4);
    final body = at + 8;
    if (id == 'COMM' && size >= 18) {
      channels = _be16(b, body);
      frames = _be32(b, body + 2);
      bits = _be16(b, body + 6);
    } else if (id == 'SSND') {
      final offsetField = _be32(b, body);
      dataOffset = body + 8 + offsetField;
      dataLength = size - 8 - offsetField;
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  final off = dataOffset;
  final len = dataLength;
  if (off == null || len == null || frames < 2 || bits != 16) return null;
  final frameSize = 2 * (channels < 1 ? 1 : channels);
  final avail = len > b.length - off ? b.length - off : len;
  final usable = frames * frameSize > avail ? avail ~/ frameSize : frames;
  if (usable < 2) return null;
  return _reduce(b, off, usable, frameSize, 2, little: false, buckets: buckets);
}

/// One pass: for each bucket take the peak absolute sample, normalised. This is
/// a real reading of the audio, not a decorative squiggle.
Waveform _reduce(Uint8List b, int offset, int frames, int frameSize, int bytesPerSample, {required bool little, required int buckets}) {
  final n = buckets < frames ? buckets : frames;
  final out = Float32List(n);
  for (var k = 0; k < n; k++) {
    final start = (frames * k) ~/ n;
    final end = ((frames * (k + 1)) ~/ n).clamp(start + 1, frames);
    var peak = 0.0;
    for (var f = start; f < end; f++) {
      final at = offset + f * frameSize;
      if (at + bytesPerSample > b.length) break;
      int raw;
      if (bytesPerSample == 1) {
        // 8-bit WAV is unsigned.
        raw = (b[at] - 128) << 8;
      } else if (bytesPerSample == 2) {
        raw = little ? _le16(b, at) : _be16(b, at);
      } else {
        raw = little ? _le32(b, at) : _be32(b, at);
      }
      final norm = (raw.abs() / (bytesPerSample == 1 ? 128 : bytesPerSample == 2 ? 32768 : 2147483648)).toDouble();
      if (norm > peak) peak = norm;
    }
    out[k] = peak.clamp(0.0, 1.0);
  }
  return Waveform(out);
}

/// No native frame extractor is available without a new native dependency; the
/// video tile falls back to its plate.
Future<Uint8List?> videoFrame(Uint8List bytes, {int atSeconds = 1}) async => null;

/// Decodes compressed audio to a waveform. Only raw PCM containers are handled
/// natively; mp3/m4a/ogg fall back to the cover art plate.
Future<Waveform?> decodedWaveform(Uint8List bytes, {String ext = '', int buckets = 96}) async {
  if (ext.isEmpty) return pcmWaveform(bytes, buckets: buckets);
  return pcmWaveform(bytes, buckets: buckets);
}