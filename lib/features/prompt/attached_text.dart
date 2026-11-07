import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/files/file_store.dart';

/// Every file attached in the composer goes to the models with the prompt:
/// - images as images (vision models see them; MediaGen describes them for
///   text-only models),
/// - PDF (Syncfusion PDF), DOCX (docx_to_text), XLSX (excel) and CSV / any
///   other text as their text,
/// - anything else as its text when it decodes as text; otherwise only its
///   name and size are sent.
const int kAttachedTextMaxChars = 20000;

/// Largest image sent inline (bytes before base64).
const int kAttachedImageMaxBytes = 4 * 1024 * 1024;

String composeWithAttachments(String prompt, List<(String name, String text)> files) {
  if (files.isEmpty) return prompt;
  final b = StringBuffer(prompt);
  for (final (name, text) in files) {
    final cut = text.length > kAttachedTextMaxChars;
    b
      ..write('\n\n--- ')
      ..write(name)
      ..write(' ---\n')
      ..write(cut ? '${text.substring(0, kAttachedTextMaxChars)}\n…' : text);
  }
  return b.toString();
}

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i < 0 ? '' : name.substring(i + 1).toLowerCase();
}

const _imageMime = {
  'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'gif': 'image/gif',
  'webp': 'image/webp', 'bmp': 'image/bmp',
};

String? imageMimeFor(String name) => _imageMime[_ext(name)];

/// Text of a document, or null when it is not a format we can read.
String? extractText(String name, Uint8List bytes) {
  final ext = _ext(name);
  try {
    switch (ext) {
      case 'pdf':
        final doc = PdfDocument(inputBytes: bytes);
        try {
          return PdfTextExtractor(doc).extractText();
        } finally {
          doc.dispose();
        }
      case 'docx':
        return docxToText(bytes);
      case 'xlsx':
        final x = Excel.decodeBytes(bytes);
        final b = StringBuffer();
        for (final sheet in x.tables.keys) {
          b.writeln('[$sheet]');
          for (final row in x.tables[sheet]!.rows) {
            b.writeln(row.map((c) => c?.value?.toString() ?? '').join(','));
          }
        }
        return b.toString();
    }
  } catch (_) {
    return null;
  }
  // CSV, Markdown, code, JSON, plain text, or any file that decodes as text.
  final s = utf8.decode(bytes, allowMalformed: true);
  final bad = '\uFFFD'.allMatches(s).length + RegExp(r'[\x00-\x08\x0E-\x1F]').allMatches(s).length;
  if (s.isEmpty || bad > s.length * 0.02) return null;
  return s;
}

/// The prompt with every attachment's text, and the attached images.
class AttachedPrompt {
  final String text;
  final List<String> imageDataUris;
  const AttachedPrompt(this.text, this.imageDataUris);
}

Future<AttachedPrompt> promptWithAttachments(String prompt, List<String> names) async {
  if (names.isEmpty) return AttachedPrompt(prompt, const []);
  final store = FileStore.instance;
  final texts = <(String, String)>[];
  final images = <String>[];
  for (final n in names) {
    StoredFile? f;
    for (final s in store.files) {
      if (s.name == n) f = s;
    }
    if (f == null) continue;
    final bytes = await store.bytesOf(f.id);
    if (bytes == null) continue;
    final mime = imageMimeFor(f.name);
    if (mime != null) {
      if (bytes.length <= kAttachedImageMaxBytes) {
        images.add('data:$mime;base64,${base64Encode(bytes)}');
        texts.add((f.name, '[image attached]'));
      }
      continue;
    }
    final t = extractText(f.name, bytes);
    texts.add((f.name, t ?? '[${bytes.length} bytes; not readable as text]'));
  }
  return AttachedPrompt(composeWithAttachments(prompt, texts), images);
}

/// Text-only form, kept for callers that send no images.
Future<String> promptWithAttachedText(String prompt, List<String> names) async =>
    (await promptWithAttachments(prompt, names)).text;
