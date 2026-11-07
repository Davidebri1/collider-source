import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collider_flutter/features/prompt/attached_text.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<String> _ask(String prompt) async {
  final req = await HttpClient().postUrl(Uri.parse('https://collider-keys.ebridavid.workers.dev/api/p?u=crazyrouter'));
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Origin', 'https://davidebri1.github.io');
  req.headers.set('User-Agent', 'Mozilla/5.0');
  req.add(utf8.encode(jsonEncode({
    'model': 'glm-5.3-flash',
    'max_tokens': 40,
    'messages': [
      {'role': 'user', 'content': prompt},
    ],
  })));
  final res = await req.close().timeout(const Duration(seconds: 60));
  final body = await res.transform(utf8.decoder).join();
  final decoded = jsonDecode(body);
  if (decoded is! Map) return 'status ${res.statusCode}';
  final msg = (decoded['choices'] as List?)?.first;
  if (msg is! Map) return 'status ${res.statusCode}';
  final message = msg['message'];
  if (message is! Map) return 'status ${res.statusCode}';
  final content = message['content'];
  if (content is String && content.trim().isNotEmpty) return content.trim();
  final reasoning = message['reasoning_content'];
  return (reasoning is String ? reasoning : 'empty').trim();
}

void main() {
  test('PDF DOCX and XLSX text is what a model is asked, and it can repeat the marker', () async {
    final pdf = PdfDocument();
    pdf.pages.add().graphics.drawString('PELICAN', PdfStandardFont(PdfFontFamily.helvetica, 18));
    final pdfBytes = Uint8List.fromList(pdf.saveSync());
    pdf.dispose();
    final pdfText = extractText('bird.pdf', pdfBytes);
    expect(pdfText, contains('PELICAN'));

    const docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>TANGERINE</w:t></w:r></w:p></w:body></w:document>''';
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'))
      ..addFile(ArchiveFile.string('word/document.xml', docXml));
    final docxBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);
    final docxText = extractText('fruit.docx', docxBytes);
    expect(docxText, contains('TANGERINE'));

    final book = Excel.createExcel();
    book['Sheet1'].updateCell(CellIndex.indexByString('A1'), TextCellValue('KILIMANJARO'));
    final xlsxBytes = Uint8List.fromList(book.encode()!);
    final xlsxText = extractText('peak.xlsx', xlsxBytes);
    expect(xlsxText, contains('KILIMANJARO'));

    final replies = <String, String>{};
    for (final (name, text) in [('pdf', pdfText!), ('docx', docxText!), ('xlsx', xlsxText!)]) {
      replies[name] = await _ask('The attachment text follows. Reply with only the marker word in it.\n\n--- file ---\n$text');
    }
    File('/tmp/attachment-replies.json').writeAsStringSync(jsonEncode(replies));
    expect(replies['pdf']!.toUpperCase(), contains('PELICAN'));
    expect(replies['docx']!.toUpperCase(), contains('TANGERINE'));
    expect(replies['xlsx']!.toUpperCase(), contains('KILIMANJARO'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
