import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features do not persist outside AccountSync', () {
    final root = Directory.current;
    final script = File('${root.path}/tool/check_account_sync_persistence.sh');
    expect(script.existsSync(), isTrue, reason: 'guard script missing');
    final r = Process.runSync('bash', [script.path], workingDirectory: root.path);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });
}
