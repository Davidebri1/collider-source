import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/files/file_store.dart';

/// What the model actually receives for one attachment.
enum AttachmentDisposition { image, text, imageSkipped, nameOnly }

/// Attachments the parsers can read: images, PDF (Syncfusion), DOCX
/// (docx_to_text), XLSX (excel), and text that decodes as text (CSV, Markdown,
/// JSON, code). A binary file sends its name and size only. An image over
/// 4 MB is not sent. Neither case is treated as the model having read the file.
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
  final Map<String, AttachmentDisposition> dispositions;
  const AttachedPrompt(this.text, this.imageDataUris, [this.dispositions = const {}]);
}

({String text, AttachmentDisposition disposition, String? imageUri}) classifyAttachment(String name, Uint8List bytes) {
  final mime = imageMimeFor(name);
  if (mime != null) {
    if (bytes.length <= kAttachedImageMaxBytes) {
      return (text: '[image attached]', disposition: AttachmentDisposition.image, imageUri: 'data:$mime;base64,${base64Encode(bytes)}');
    }
    return (text: '[image not sent; file is over 4 MB]', disposition: AttachmentDisposition.imageSkipped, imageUri: null);
  }
  final t = extractText(name, bytes);
  if (t == null) {
    return (text: '[${bytes.length} bytes; name and size only]', disposition: AttachmentDisposition.nameOnly, imageUri: null);
  }
  return (text: t, disposition: AttachmentDisposition.text, imageUri: null);
}

Future<AttachedPrompt> promptWithAttachments(String prompt, List<String> names) async {
  if (names.isEmpty) return AttachedPrompt(prompt, const []);
  final store = FileStore.instance;
  final texts = <(String, String)>[];
  final images = <String>[];
  final dispositions = <String, AttachmentDisposition>{};
  for (final n in names) {
    StoredFile? f;
    for (final s in store.files) {
      if (s.name == n) f = s;
    }
    if (f == null) continue;
    final bytes = await store.bytesOf(f.id);
    if (bytes == null) continue;
    final classified = classifyAttachment(f.name, bytes);
    texts.add((f.name, classified.text));
    dispositions[f.name] = classified.disposition;
    final uri = classified.imageUri;
    if (uri != null) images.add(uri);
  }
  return AttachedPrompt(composeWithAttachments(prompt, texts), images, dispositions);
}

/// Text-only form, kept for callers that send no images.
Future<String> promptWithAttachedText(String prompt, List<String> names) async =>
    (await promptWithAttachments(prompt, names)).text;
