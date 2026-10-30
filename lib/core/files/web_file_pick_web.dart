import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

/// Web pick that keeps the <input type=file> in the DOM until change/cancel.
/// Upstream file_picker removes the input immediately after click(), which
/// races Puppeteer/CDP FileChooser and can cancel the dialog in headless Chrome.
Future<FilePickerResult?> pickFilesWebFriendly({bool allowMultiple = true}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = allowMultiple;
  input.style.display = 'none';
  web.document.body!.appendChild(input);

  final done = Completer<FilePickerResult?>();
  var settled = false;

  void finish(FilePickerResult? r) {
    if (settled) return;
    settled = true;
    try {
      input.remove();
    } catch (_) {}
    if (!done.isCompleted) done.complete(r);
  }

  Future<void> onChange() async {
    final list = input.files;
    if (list == null || list.length == 0) {
      finish(null);
      return;
    }
    final out = <PlatformFile>[];
    for (var i = 0; i < list.length; i++) {
      final f = list.item(i);
      if (f == null) continue;
      final bytes = await _readBytes(f);
      if (bytes == null) continue;
      out.add(PlatformFile(name: f.name, size: bytes.length, bytes: bytes));
    }
    finish(out.isEmpty ? null : FilePickerResult(out));
  }

  input.addEventListener('change', ((web.Event _) { unawaited(onChange()); }).toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);

  void onFocus(web.Event _) {
    web.window.removeEventListener('focus', onFocus.toJS);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!settled) finish(null);
    });
  }
  web.window.addEventListener('focus', onFocus.toJS);

  input.click();
  return done.future;
}

Future<Uint8List?> _readBytes(web.File file) {
  final c = Completer<Uint8List?>();
  final reader = web.FileReader();
  reader.onloadend = ((web.Event _) {
    final result = reader.result;
    if (result == null) {
      c.complete(null);
      return;
    }
    // FileReader.readAsArrayBuffer → JSArrayBuffer
    final buf = (result as JSArrayBuffer).toDart;
    c.complete(buf.asUint8List());
  }).toJS;
  reader.onerror = ((web.Event _) => c.complete(null)).toJS;
  reader.readAsArrayBuffer(file);
  return c.future;
}
