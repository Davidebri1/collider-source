import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Build-failing guard: Smart Gen headers stay centred (David).
void main() {
  test('appBarTheme centres titles; centerTitle false only with TextField', () {
    final root = Directory.current.path.contains('packages/smartgen_planka')
        ? Directory.current.parent.parent
        : Directory.current;
    final script = File('${root.path}/tool/check_smartgen_headers.sh');
    expect(script.existsSync(), isTrue, reason: 'missing ${script.path}');
    final r = Process.runSync('bash', [script.path], workingDirectory: root.path);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });
}
