import 'dart:convert';

import '../../core/files/file_store.dart';

/// Text of the files attached in the composer goes to the models with the
/// prompt; without it an attachment chip would be decoration only. Text files
/// are sent as text (capped); other files are not readable as text and are
/// left out.
const int kAttachedTextMaxChars = 20000;

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

/// Reads the newest stored file with each attached name.
Future<String> promptWithAttachedText(String prompt, List<String> names) async {
  if (names.isEmpty) return prompt;
  final store = FileStore.instance;
  final out = <(String, String)>[];
  for (final n in names) {
    StoredFile? f;
    for (final s in store.files) {
      if (s.name == n) f = s;
    }
    if (f == null || !FileStore.isText(f.name)) continue;
    final bytes = await store.bytesOf(f.id);
    if (bytes == null) continue;
    out.add((f.name, utf8.decode(bytes, allowMalformed: true)));
  }
  return composeWithAttachments(prompt, out);
}
