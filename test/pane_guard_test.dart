import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pane guard: no screen paints its own glass, blur, shadow or width', () {
    final r = Process.runSync('dart', ['run', 'tool/pane_guard.dart']);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });
}
