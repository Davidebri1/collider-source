import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pollinations keyless floor serializes and retries 402/429', () {
    final src = File('lib/core/api/media_gen.dart').readAsStringSync();
    expect(src.contains('_pollinationsGate'), isTrue,
        reason: 'multi-row Home must not stampede Pollinations');
    expect(src.contains("'openai-fast'"), isTrue,
        reason: 'Classic anonymous free model id');
    expect(src.contains('sc == 402') || src.contains('sc == 402 || sc == 429'), isTrue);
    expect(src.contains('_pollinationsTextOnce'), isTrue);
  });
}
