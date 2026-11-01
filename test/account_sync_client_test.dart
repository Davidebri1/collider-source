import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two-device sim: Smart Gen + Files + history sync + LWW', () async {
    final r = await Process.run(
      'node',
      ['server/worker/scripts/two_device_sim.mjs'],
      workingDirectory: Directory.current.path,
    );
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout.toString(), contains('"ok":true'));
  });
}
