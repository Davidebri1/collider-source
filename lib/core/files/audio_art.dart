// Embedded cover art: ID3v2 (2.2/2.3/2.4 APIC), MP4/M4A (ilst/covr),
// FLAC (PICTURE block) and Ogg (METADATA_BLOCK_PICTURE comment). All of these
// are read straight off the stored bytes — no decoder, just structure.
import 'dart:convert';
import 'dart:typed_data';

/// The embedded image bytes, or null when the file carries none.
Uint8List? coverArt(Uint8List bytes, {String ext = ''}) {
  try {
    if (_hasId3(bytes)) return _id3Art(bytes);
    final e = ext.toLowerCase();
    if (e == 'm4a' || e == 'mp4' || e == 'm4b' || e == 'aac') return _mp4Art(bytes);
    if (e == 'flac') return _flacArt(bytes);
    if (e == 'ogg' || e == 'oga' || e == 'opus') return _oggArt(bytes);
    // Sniff: ISO base media (ftyp) or FLAC/OGG magic.
    if (_ascii(bytes, 4, 'ftyp')) return _mp4Art(bytes);
    if (_ascii(bytes, 0, 'fLaC')) return _flacArt(bytes);
    if (_ascii(bytes, 0, 'OggS')) return _oggArt(bytes);
    return null;
  } catch (_) {
    // A malformed tag must never take the tile down; fall back to the plate.
    return null;
  }
}

bool _ascii(Uint8List b, int at, String s) {
  if (at + s.length > b.length) return false;
  for (var i = 0; i < s.length; i++) {
    if (b[at + i] != s.codeUnitAt(i)) return false;
  }
  return true;
}

int _be32(Uint8List b, int at) => (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
int _be24(Uint8List b, int at) => (b[at] << 16) | (b[at + 1] << 8) | b[at + 2];
int _be64(Uint8List b, int at) {
  var v = 0;
  for (var i = 0; i < 8; i++) {
    v = (v << 8) | b[at + i];
  }
  return v;
}

bool _hasId3(Uint8List b) => b.length > 10 && _ascii(b, 0, 'ID3');

// ---------------------------------------------------------------------------
// ID3v2
// ---------------------------------------------------------------------------

/// Walks the APIC/PIC frames of an ID3v2 tag.
Uint8List? _id3Art(Uint8List b) {
  if (!_hasId3(b)) return null;
  final major = b[3];
  final flags = b[5];
  final size = _syncSafe(b, 6);
  var at = 10;
  // An extended header sits after the 10-byte header when the flag is set.
  if (flags & 0x40 != 0) {
    if (major == 4) {
      final ext = _syncSafe(b, at);
      at += ext;
    } else {
      final ext = _be32(b, at);
      at += ext + 4;
    }
  }
  final end = (10 + size).clamp(0, b.length);
  while (at + 6 < end) {
    // v2.2 uses 3-character frame ids; v2.3/2.4 use 4.
    final idLen = major == 2 ? 3 : 4;
    final id = String.fromCharCodes(b.sublist(at, at + idLen));
    final frameSize = major == 2 ? _be24(b, at + 3) : _syncSafe(b, at + 4);
    final headerLen = major == 2 ? 6 : 10;
    final body = at + headerLen;
    if (body + frameSize > b.length) break;
    if (id == 'APIC' || id == 'PIC') {
      final art = _apicPayload(b, body, body + frameSize, major);
      if (art != null && art.isNotEmpty) return art;
    }
    // v2.4 frames may carry a data-length indicator (syncsafe, +4) and a
    // compression flag; a plain +frameSize step is the safe common path.
    at = body + frameSize;
  }
  return null;
}

/// APIC payload: encoding(1) mime\0 [description\0] pictureType(1) data.
///
/// The description is what makes this subtle: v2.3/v2.4 use a null-terminated
/// string whose terminator is *one byte* in ISO-8859-1 but *two* (BOM 0xFF 0xFE
/// / 0xFE 0xFF) in UTF-16, and v2.2 descriptions are one byte. Getting this
/// wrong shifts every later field and loses the picture — the bug this file is
/// written around. Note the order: description first, then the picture-type
/// byte, then the data.
Uint8List? _apicPayload(Uint8List b, int start, int end, int major) {
  if (start >= end) return null;
  final encoding = b[start];
  var at = start + 1;
  // MIME type, null-terminated.
  final mimeEnd = _indexOfZero(b, at, end);
  if (mimeEnd < 0) return null;
  at = mimeEnd + 1;
  // Description terminator width depends on the text encoding.
  final wide = (encoding == 1 || encoding == 2);
  if (wide) {
    // UTF-16: consume 2 bytes at a time until a double-null.
    while (at + 1 < end) {
      if (b[at] == 0 && b[at + 1] == 0) {
        at += 2;
        break;
      }
      at += 2;
    }
  } else {
    final d = _indexOfZero(b, at, end);
    if (d < 0) return null;
    at = d + 1;
  }
  // Picture type byte.
  if (at >= end) return null;
  at++;
  if (at >= end) return null;
  return Uint8List.sublistView(b, at, end);
}

int _indexOfZero(Uint8List b, int from, int to) {
  for (var i = from; i < to; i++) {
    if (b[i] == 0) return i;
  }
  return -1;
}

/// A 7-bit sync-safe integer (each byte uses its low 7 bits).
int _syncSafe(Uint8List b, int at) {
  if (at + 4 > b.length) return 0;
  return ((b[at] & 0x7f) << 21) | ((b[at + 1] & 0x7f) << 14) | ((b[at + 2] & 0x7f) << 7) | (b[at + 3] & 0x7f);
}

// ---------------------------------------------------------------------------
// MP4 / M4A  (this is the ilst-recursion fix)
// ---------------------------------------------------------------------------

/// Recursively walks ISO base-media boxes. The `moov > udta > meta > ilst >
/// covr > data` chain only resolves if we recurse into container boxes, so
/// every known container is descended into.
Uint8List? _mp4Art(Uint8List b) => _mp4Boxes(b, 0, b.length);

Uint8List? _mp4Boxes(Uint8List b, int start, int end) {
  var at = start;
  while (at + 8 <= end) {
    // Box size: 32-bit, or 1 then a 64-bit size. 0 runs to the end.
    var size = _be32(b, at);
    final type = String.fromCharCodes(b.sublist(at + 4, at + 8));
    var bodyStart = at + 8;
    if (size == 1) {
      size = _be64(b, bodyStart);
      bodyStart += 8;
    } else if (size == 0) {
      size = end - at;
    }
    if (size < 8 || at + size > end) return null;

    // covr is a leaf: its child `data` holds the image.
    if (type == 'covr') {
      final art = _mp4DataPayload(b, bodyStart, at + size);
      if (art != null && art.isNotEmpty) return art;
    }
    // Container boxes: descend. ilst is the one that was previously missed.
    if (_mp4Containers.contains(type)) {
      // meta is a full box: 4 bytes of version/flags before its children.
      final childStart = type == 'meta' ? bodyStart + 4 : bodyStart;
      final found = _mp4Boxes(b, childStart, at + size);
      if (found != null) return found;
    }
    at += size;
  }
  return null;
}

const _mp4Containers = {'moov', 'udta', 'meta', 'ilst', 'trak', 'mdia', 'minf', 'stbl'};

/// Reads a `data` box payload (4-byte type + 4-byte locale, then bytes).
Uint8List? _mp4DataPayload(Uint8List b, int start, int end) {
  var at = start;
  while (at + 8 <= end) {
    final size = _be32(b, at);
    final type = String.fromCharCodes(b.sublist(at + 4, at + 8));
    if (size < 8 || at + size > end) return null;
    if (type == 'data') {
      final bodyStart = at + 8 + 8; // size+type+type(4)+locale(4)
      if (bodyStart < at + size) return Uint8List.sublistView(b, bodyStart, at + size);
      return null;
    }
    at += size;
  }
  return null;
}

// ---------------------------------------------------------------------------
// FLAC
// ---------------------------------------------------------------------------

/// METADATA_BLOCK_PICTURE: block type 6, big-endian length, then the picture
/// block (mime\0 desc\0 width height depth colours dataLen data).
Uint8List? _flacArt(Uint8List b) {
  if (!_ascii(b, 0, 'fLaC')) return null;
  var at = 4;
  while (at + 4 <= b.length) {
    final header = b[at];
    final last = header & 0x80 != 0;
    final type = header & 0x7f;
    var len = _be24(b, at + 1);
    at += 4;
    if (at + len > b.length) return null;
    if (type == 6) {
      // First four bytes of the block repeat the picture length.
      final blockStart = at;
      if (blockStart + 8 <= b.length) {
        // Walk the picture block properly: mime\0, desc\0, then 16 bytes of
        // dimensions, then a 32-bit data length and the data.
        var p = blockStart + 4; // skip the redundant length
        final mimeEnd = _indexOfZero(b, p, blockStart + len);
        if (mimeEnd < 0) return null;
        p = mimeEnd + 1;
        final descEnd = _indexOfZero(b, p, blockStart + len);
        if (descEnd < 0) return null;
        p = descEnd + 1 + 16; // 4 width/height/depth/colours
        if (p + 4 > b.length) return null;
        final size = _be32(b, p);
        p += 4;
        if (p + size > b.length) return null;
        final out = Uint8List.fromList(b.sublist(p, p + size));
        return out.isEmpty ? null : out;
      }
      return null;
    }
    at += len;
    if (last) break;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Ogg
// ---------------------------------------------------------------------------

/// Flac-in-Ogg or Vorbis comment `METADATA_BLOCK_PICTURE=<base64>`. The base64
/// payload is a full picture block; reuse the same walk.
Uint8List? _oggArt(Uint8List b) {
  final idx = _indexOfAscii(b, 0, 'METADATA_BLOCK_PICTURE=');
  if (idx < 0) return null;
  var at = idx + 'METADATA_BLOCK_PICTURE='.length;
  final sb = StringBuffer();
  while (at < b.length) {
    final c = b[at];
    if (c == 0 || c == 0x0a || c == 0x0d) break;
    sb.writeCharCode(c);
    at++;
  }
  try {
    final raw = base64Decode(sb.toString());
    // The decoded block starts with its own 32-bit length; skip it and read the
    // picture payload.
    if (raw.length < 4) return null;
    var p = 4;
    final mimeEnd = _indexOfZero(raw, p, raw.length);
    if (mimeEnd < 0) return null;
    p = mimeEnd + 1;
    final descEnd = _indexOfZero(raw, p, raw.length);
    if (descEnd < 0) return null;
    p = descEnd + 1 + 16;
    if (p + 4 > raw.length) return null;
    final size = _be32(raw, p);
    p += 4;
    if (p + size > raw.length) return null;
    final out = Uint8List.fromList(raw.sublist(p, p + size));
    return out.isEmpty ? null : out;
  } catch (_) {
    return null;
  }
}

int _indexOfAscii(Uint8List b, int from, String needle) {
  final n = needle.codeUnits;
  outer:
  for (var i = from; i + n.length <= b.length; i++) {
    for (var j = 0; j < n.length; j++) {
      if (b[i + j] != n[j]) continue outer;
    }
    return i;
  }
  return -1;
}