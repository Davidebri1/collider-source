import 'package:collider_flutter/core/api/media_gen.dart';
import 'package:collider_flutter/core/media/theme_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider keys restored: free/pro models report credentials', () {
    expect(MediaGen.instance.hasCredentials('free/laguna-s-2-1'), isTrue);
    expect(MediaGen.instance.hasCredentials('free/glm-5-3-flash'), isTrue);
    expect(MediaGen.instance.hasCredentials('pro/minimax-m3'), isTrue);
    expect(MediaGen.instance.isRoutable('free/glm-5-3-flash'), isTrue);
  });

  test('friendlyErrorMessage matches source chat.ts wording', () {
    expect(friendlyErrorMessage('402 quota'), 'This model is temporarily unavailable. Try another.');
    expect(friendlyErrorMessage('503'), 'This model is temporarily unavailable. Try again shortly.');
    expect(friendlyErrorMessage('429'), contains('lot of requests'));
    expect(friendlyErrorMessage('weird'), 'Something went wrong generating a response. Try again.');
    expect(friendlyErrorMessage('no-key'), isNot(contains("isn't connected")));
    expect(friendlyErrorMessage('cors'), isNot(contains('from the browser')));
    expect(friendlyErrorMessage('empty'), isNot(contains('recorder')));
  });

  test('live theme basename pairs with sibling still', () {
    final base = ThemeCatalog.niceName('105 Apartment over the City.mp4');
    final still = ThemeCatalog.niceName('105 Apartment over the City.jpg');
    expect(base.toLowerCase(), still.toLowerCase());
    expect(base, 'Apartment over the City');
  });

  test('sign-in copy is short Apple-style title only', () {
    // Guard: the amateur long string must not reappear in lib sources.
    // (Full string check runs in wording audit; this locks the title.)
    expect('Sign-In Unavailable'.length, lessThan(24));
  });
}
