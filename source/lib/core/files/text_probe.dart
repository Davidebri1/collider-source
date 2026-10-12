// Shared text decode for stored files (tiles want the first lines, the reader
// wants the whole thing). One decoder so a CSV tile and a CSV reader never
// disagree about what the file says.
import 'dart:convert';
import 'dart:typed_data';

/// A BOM, if the bytes start with one. UTF-8 is the default; UTF-16 files
/// (Windows "Unicode text") are common enough to be worth real handling.
enum _Bom { none, utf8, utf16le, utf16be }

_Bom _bomOf(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) return _Bom.utf8;
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return _Bom.utf16le;
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return _Bom.utf16be;
  return _Bom.none;
}

/// Decodes text bytes, honouring a BOM and falling back to Latin-1 when the
/// bytes are not valid UTF-8 (a mislabelled .txt should still open).
String decodeText(Uint8List bytes) {
  final bom = _bomOf(bytes);
  switch (bom) {
    case _Bom.utf8:
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    case _Bom.utf16le:
      return _utf16(bytes, 2, little: true);
    case _Bom.utf16be:
      return _utf16(bytes, 2, little: false);
    case _Bom.none:
      try {
        return utf8.decode(bytes, allowMalformed: false);
      } on FormatException {
        return latin1.decode(bytes, allowInvalid: true);
      }
  }
}

String _utf16(Uint8List b, int start, {required bool little}) {
  if (b.length <= start) return '';
  final units = <int>[];
  for (var i = start; i + 1 < b.length; i += 2) {
    units.add(little ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
  }
  return String.fromCharCodes(units);
}

/// Normalises line endings and drops a trailing newline run. Every probe that
/// produces lines for the UI funnels through here so line counts are honest.
List<String> splitLines(String text) {
  var t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  while (t.endsWith('\n')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.isEmpty) return const [];
  return t.split('\n');
}

/// The first [max] non-empty-ish lines, for a tile that shows a preview.
List<String> head(String text, {int max = 8}) {
  final all = splitLines(text);
  if (all.length <= max) return all;
  return all.sublist(0, max);
}