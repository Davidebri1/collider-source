// A real (if small) PDF probe: walks the object table, inflates FlateDecode
// content streams and pulls the text-showing operators out so a tile and the
// reader show what the page actually says, plus the real /MediaBox aspect.
import 'dart:convert';
import 'dart:typed_data';

import 'text_probe.dart';
import 'thumb_codec.dart';

class PdfDoc {
  /// Pages in document order (empty when the probe found none).
  final List<PdfPage> pages;
  const PdfDoc(this.pages);

  int get pageCount => pages.length;
  bool get isEmpty => pages.isEmpty;
}

/// One page: its real aspect (w/h) and the text we could recover.
class PdfPage {
  final double width;
  final double height;
  final List<String> lines;
  const PdfPage({required this.width, required this.height, required this.lines});

  double get aspect => height <= 0 ? 0.7727 : width / height;
}

/// Parses [bytes]. Returns an empty doc rather than throwing: a PDF we cannot
/// read should still get a designed plate, not a crash.
Future<PdfDoc> probePdf(Uint8List bytes) async {
  final objects = _scanObjects(bytes);
  if (objects.isEmpty) return const PdfDoc([]);

  // Page geometry: /MediaBox per page object, falling back to the first one we
  // can find, then to US Letter.
  _Box? fallbackBox;

  // Collect every decompressed content stream, then pull text out of them in
  // object order (good enough to be faithful for a preview).
  final streams = <List<int>>[];
  for (final entry in objects.entries) {
    final body = _bodyOf(bytes, objects, entry.key);
    if (body == null) continue;
    if (_contains(body, '/MediaBox')) {
      final box = _mediaBox(body);
      if (box != null && box.width > 0 && box.height > 0) {
        fallbackBox ??= box;
        _boxes[entry.key] = box;
      }
    }
    if (_contains(body, 'stream')) {
      final raw = _streamData(body);
      if (raw != null && raw.isNotEmpty) {
        final inflated = await inflate(Uint8List.fromList(raw));
        streams.add(inflated ?? raw);
      }
    }
  }

  // Count /Type /Page to know the page count (Page nodes, not Pages nodes).
  var pageCount = 0;
  for (final body in objects.values) {
    if (_contains(body, '/Page') && !_contains(body, '/Pages')) pageCount++;
  }

  final text = streams.map(_textFromStream).where((l) => l.isNotEmpty).toList();
  final box = fallbackBox ?? const _Box(612, 792);

  if (pageCount <= 1) {
    return PdfDoc([
      PdfPage(width: box.width, height: box.height, lines: text.isEmpty ? const [] : text.first),
    ]);
  }

  // Many pages: give each page the stream text nearest to its object index when
  // we can, otherwise share the extracted text. Layout fidelity is out of scope;
  // real words are not.
  final pages = <PdfPage>[];
  for (var i = 0; i < pageCount; i++) {
    final lines = (i < streams.length) ? _textFromStream(streams[i]) : <String>[];
    pages.add(PdfPage(
      width: box.width,
      height: box.height,
      lines: lines.isNotEmpty ? lines : (text.isEmpty ? const [] : text.first),
    ));
  }
  return PdfDoc(pages);
}

/// /MediaBox per page object, filled during the scan.
final Map<int, _Box> _boxes = {};
void _resetBoxes() => _boxes.clear();

class _Box {
  final double width;
  final double height;
  const _Box(this.width, this.height);
}

/// Scans `N 0 obj ... endobj` headers, returning object number -> header bytes.
Map<int, Uint8List> _scanObjects(Uint8List bytes) {
  _resetBoxes();
  final out = <int, Uint8List>{};
  final text = latin1.decode(bytes, allowInvalid: true);
  // allMatches, not matchAsPrefix: the header (%PDF-1.x) precedes the first
  // object, so the scan has to search forward rather than match at position 0.
  final re = RegExp(r'(\d+)\s+(\d+)\s+obj');
  for (final m in re.allMatches(text)) {
    final num = int.tryParse(m.group(1)!) ?? 0;
    final start = m.end;
    final end = text.indexOf('endobj', start);
    final stop = end < 0 ? text.length : end;
    // Later definitions of the same object number win (incremental updates).
    out[num] = Uint8List.fromList(latin1.encode(text.substring(start, stop)));
  }
  return out;
}

/// Everything between `obj` and `endobj` is already the header+body; for a
/// stream object we also want the raw bytes after `stream`.
Uint8List? _bodyOf(Uint8List bytes, Map<int, Uint8List> objects, int num) => objects[num];

bool _contains(Uint8List b, String needle) => latin1.decode(b, allowInvalid: true).contains(needle);

/// The bytes between `stream\r\n` (or `stream\n`) and `endstream`.
List<int>? _streamData(Uint8List body) {
  final s = latin1.decode(body, allowInvalid: true);
  final i = s.indexOf('stream');
  if (i < 0) return null;
  var at = i + 'stream'.length;
  if (at < s.length && s[at] == '\r') at++;
  if (at < s.length && s[at] == '\n') at++;
  final j = s.indexOf('endstream', at);
  final stop = j < 0 ? s.length : j;
  if (stop <= at) return null;
  return latin1.encode(s.substring(at, stop));
}

/// `/MediaBox [0 0 w h]` (or [x y w h]); take width/height as the last pair.
_Box? _mediaBox(Uint8List body) {
  final s = latin1.decode(body, allowInvalid: true);
  final m = RegExp(r'/MediaBox\s*\[\s*([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*\]').firstMatch(s);
  if (m == null) return null;
  final x0 = double.tryParse(m.group(1)!);
  final y0 = double.tryParse(m.group(2)!);
  final x1 = double.tryParse(m.group(3)!);
  final y1 = double.tryParse(m.group(4)!);
  if (x1 == null || y1 == null) return null;
  return _Box((x1 - (x0 ?? 0)).abs(), (y1 - (y0 ?? 0)).abs());
}

/// Pulls readable text out of a content stream: every `(...) Tj` / `[...] TJ`
/// string, in order, with Tj/TJ separated into lines.
List<String> _textFromStream(List<int> bytes) {
  final s = latin1.decode(bytes, allowInvalid: true);
  final out = <String>[];
  final re = RegExp(r'\((?:\\.|[^\\()])*\)');
  var last = 0;
  for (final m in re.allMatches(s)) {
    final raw = m.group(0)!;
    final inner = raw.substring(1, raw.length - 1);
    // Operators between the previous string and this one decide the break.
    final between = s.substring(last, m.start);
    if (RegExp(r'\bT[dD*]\b').hasMatch(between)) out.add('');
    out.add(_unescapePdf(inner));
    last = m.end;
  }
  return splitLines(out.join('\n'));
}

/// PDF string escapes: \( \) \\ \n \r \t \b \f, \ooo octal.
String _unescapePdf(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c != r'\') {
      b.write(c);
      continue;
    }
    i++;
    if (i >= s.length) break;
    final n = s[i];
    switch (n) {
      case 'n':
        b.write('\n');
      case 'r':
        b.write('\r');
      case 't':
        b.write('\t');
      case 'b':
        b.write('\b');
      case 'f':
        b.write('\f');
      case '(':
      case ')':
      case r'\':
        b.write(n);
      default:
        if (RegExp(r'[0-7]').hasMatch(n)) {
          var oct = n;
          var k = 0;
          while (k < 2 && i + 1 < s.length && RegExp(r'[0-7]').hasMatch(s[i + 1])) {
            i++;
            oct += s[i];
            k++;
          }
          b.writeCharCode(int.tryParse(oct, radix: 8) ?? 32);
        } else {
          b.write(n);
        }
    }
  }
  return b.toString();
}