import 'package:collider_flutter/features/prompt/attached_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no attachments leaves the prompt as typed', () {
    expect(composeWithAttachments('Hi', const []), 'Hi');
  });
  test('attached text follows the prompt under its file name', () {
    expect(composeWithAttachments('Summarise', const [('a.txt', 'alpha')]), 'Summarise\n\n--- a.txt ---\nalpha');
  });
  test('long text is capped', () {
    final out = composeWithAttachments('p', [('b.txt', 'x' * (kAttachedTextMaxChars + 50))]);
    expect(out.endsWith('\n…'), isTrue);
    expect(out.length, lessThan(kAttachedTextMaxChars + 40));
  });
}
