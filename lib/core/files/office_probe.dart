// Office formats are zip containers (docx/odt/pptx/xlsx) or plain-ish RTF.
// This reads the zip central directory directly (no package dependency) and
// pulls the text out of the parts that carry it.
import 'dart:convert';
import 'dart:typed_data';

import 'thumb_codec.dart';

/// One entry of a zip archive, located from the central directory.
class ZipEntry {
  final String name;
  final int method; // 0 = stored, 8 = deflate
  final int compSize;
  final int localOffset;
  const ZipEntry({required this.name, required this.method, required this.compSize, required this.localOffset});
}

/// Reads the central directory at the end of the file. Returns an empty list
/// when this is not a zip.
List<ZipEntry> readZipCentralDirectory(Uint8List bytes) {
  final out = <ZipEntry>[];
  // Find the end-of-central-directory signature 0x06054b50.
  var eocd = -1;
  final minEocd = bytes.length < 22 ? 0 : bytes.length - 22;
  for (var i = bytes.length - 22; i >= minEocd && i >= 0; i--) {
    if (bytes[i] == 0x50 && bytes[i + 1] == 0x4b && bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0 || eocd + 22 > bytes.length) return out;
  final count = _le16(bytes, eocd + 10);
  var at = _le32(bytes, eocd + 16);
  for (var i = 0; i < count; i++) {
    if (at + 46 > bytes.length) break;
    if (bytes[at] != 0x50 || bytes[at + 1] != 0x4b || bytes[at + 2] != 0x01 || bytes[at + 3] != 0x02) break;
    final method = _le16(bytes, at + 10);
    final compSize = _le32(bytes, at + 20);
    final nameLen = _le16(bytes, at + 28);
    final extraLen = _le16(bytes, at + 30);
    final commentLen = _le16(bytes, at + 32);
    final localOffset = _le32(bytes, at + 42);
    final nameStart = at + 46;
    if (nameStart + nameLen > bytes.length) break;
    final name = String.fromCharCodes(bytes.sublist(nameStart, nameStart + nameLen));
    out.add(ZipEntry(name: name, method: method, compSize: compSize, localOffset: localOffset));
    at = nameStart + nameLen + extraLen + commentLen;
  }
  return out;
}

/// Extracts one entry's bytes, inflating the deflate payload if needed.
Future<Uint8List?> readZipEntry(Uint8List zip, ZipEntry e) async {
  final lo = e.localOffset;
  if (lo + 30 > zip.length) return null;
  // Local header: name length at +26, extra at +28, data follows both.
  final nameLen = _le16(zip, lo + 26);
  final extraLen = _le16(zip, lo + 28);
  final dataStart = lo + 30 + nameLen + extraLen;
  if (dataStart + e.compSize > zip.length) return null;
  final raw = Uint8List.sublistView(zip, dataStart, dataStart + e.compSize);
  if (e.method == 0) return Uint8List.fromList(raw);
  if (e.method == 8) return inflate(Uint8List.fromList(raw));
  return null;
}

int _le16(Uint8List b, int at) => b[at] | (b[at + 1] << 8);
int _le32(Uint8List b, int at) => b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);

/// The first zip entry whose name contains [needle] (case-insensitive).
Future<Uint8List?> _findPart(Uint8List zip, List<ZipEntry> dir, String needle) async {
  final lower = needle.toLowerCase();
  for (final e in dir) {
    if (e.name.toLowerCase().contains(lower)) return readZipEntry(zip, e);
  }
  return null;
}

/// Extracts readable text from an office file by extension. Returns null when
/// the format carries no text we can reach.
Future<List<String>?> probeOffice(Uint8List bytes, String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'rtf' => Future.value(_rtfText(bytes)),
    'docx' => _docxText(bytes),
    'odt' => _odtText(bytes),
    'pptx' => _pptxText(bytes),
    'xlsx' || 'xlsm' => _xlsxText(bytes),
    _ => Future.value(null),
  };
}

Future<List<String>?> _docxText(Uint8List zip) async {
  final dir = readZipCentralDirectory(zip);
  final xml = await _findPart(zip, dir, 'word/document.xml');
  if (xml == null) return null;
  return _xmlText(xml, paragraphTag: 'w:p', runTag: 'w:t');
}

Future<List<String>?> _odtText(Uint8List zip) async {
  final dir = readZipCentralDirectory(zip);
  final xml = await _findPart(zip, dir, 'content.xml');
  if (xml == null) return null;
  return _xmlText(xml, paragraphTag: 'text:p', runTag: null);
}

Future<List<String>?> _pptxText(Uint8List zip) async {
  final dir = readZipCentralDirectory(zip);
  final slides = dir.where((e) {
    final n = e.name.toLowerCase();
    return n.startsWith('ppt/slides/slide') && n.endsWith('.xml');
  }).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  if (slides.isEmpty) return null;
  final out = <String>[];
  for (final s in slides) {
    final xml = await readZipEntry(zip, s);
    if (xml == null) continue;
    final lines = _xmlText(xml, paragraphTag: 'a:p', runTag: 'a:t');
    out.addAll(lines.isEmpty ? const [''] : lines);
  }
  return out;
}

Future<List<String>?> _xlsxText(Uint8List zip) async {
  final dir = readZipCentralDirectory(zip);
  // Shared strings carry the text; when absent, fall back to inline strings in
  // the first worksheet.
  final shared = await _findPart(zip, dir, 'sharedstrings.xml');
  final strings = <String>[];
  if (shared != null) {
    strings.addAll(_allTags(shared, 'si'));
  }
  final sheet = _firstWhere(dir, (n) {
    return n.startsWith('xl/worksheets/') && n.endsWith('.xml');
  });
  if (sheet != null) {
    final xml = await readZipEntry(zip, sheet);
    if (xml != null) {
      final cells = _allTags(xml, 't');
      for (final c in cells) {
        strings.add(c);
      }
    }
  }
  if (strings.isEmpty) return null;
  return strings;
}

/// Concatenates the text of each [paragraphTag], optionally joining the text of
/// [runTag] children within it.
List<String> _xmlText(Uint8List xml, {required String paragraphTag, String? runTag}) {
  final body = latin1.decode(xml, allowInvalid: true);
  final paras = RegExp('<$paragraphTag[^>]*>(.*?)</$paragraphTag>', dotAll: true)
      .allMatches(body)
      .map((m) => m.group(1) ?? '')
      .toList();
  // If the paragraph regex found nothing, grab every text tag directly.
  if (paras.isEmpty) return _allTags(xml, runTag ?? paragraphTag);
  return paras.map((p) {
    if (runTag == null) return _stripTags(p);
    final runs = RegExp('<$runTag[^>]*>(.*?)</$runTag>', dotAll: true).allMatches(p).map((m) => _stripTags(m.group(1) ?? '')).join();
    return runs;
  }).where((s) => s.trim().isNotEmpty).toList();
}

/// Every text under <[tag]>...</[tag]>, stripped.
List<String> _allTags(Uint8List xml, String tag) {
  final body = latin1.decode(xml, allowInvalid: true);
  return RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true)
      .allMatches(body)
      .map((m) => _stripTags(m.group(1) ?? ''))
      .where((s) => s.trim().isNotEmpty)
      .toList();
}

String _stripTags(String s) => s
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// RTF: strip control words, keep the readable runs.
List<String> _rtfText(Uint8List bytes) {
  var s = latin1.decode(bytes, allowInvalid: true);
  // Drop the header group and font/color tables.
  s = s.replaceAll(RegExp(r'\{\\fonttbl.*?\}', dotAll: true), '');
  s = s.replaceAll(RegExp(r'\{\\colortbl.*?\}', dotAll: true), '');
  s = s.replaceAll(RegExp(r'\{\\\*.*?\}', dotAll: true), '');
  // \par, \line and \tab are real breaks/spaces.
  s = s.replaceAll(RegExp(r'\\par[d]?\b'), '\n');
  s = s.replaceAll(RegExp(r'\\line\b'), '\n');
  s = s.replaceAll(RegExp(r'\\tab\b'), '\t');
  // Hex escapes: \'hh
  s = s.replaceAllMapped(RegExp(r"\\'([0-9a-fA-F]{2})"), (m) {
    final code = int.tryParse(m.group(1)!, radix: 16);
    return code == null ? '' : String.fromCharCode(code);
  });
  // Remaining control words (\word, optional numeric arg) go away.
  s = s.replaceAll(RegExp(r'\\[a-zA-Z]+-?\d*\s?'), '');
  s = s.replaceAll('{', '').replaceAll('}', '');
  final lines = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  return lines;
}

ZipEntry? _firstWhere(List<ZipEntry> entries, bool Function(String name) test) {
  for (final e in entries) {
    if (test(e.name.toLowerCase())) return e;
  }
  return null;
}