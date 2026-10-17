import 'package:collider_flutter/models/theme_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('humanizeThemeName', () {
    test('curated titles pass through untouched', () {
      for (final n in ['Spatial Drift', 'Slow Orbit', 'Starbridge', 'Cyber Fog']) {
        expect(humanizeThemeName(n), n, reason: n);
      }
    });

    test('Drive filename shapes are rewritten', () {
      expect(humanizeThemeName('0_Gold_Glitter_Sparkles_1280x720'), 'Gold Glitter Sparkles');
      expect(humanizeThemeName('5899755_Landscape_Lake_1920x1080'), 'Landscape Lake');
      expect(
        humanizeThemeName('Bedroom_overlooking_neon_cityscape_202606150103'),
        'Bedroom Overlooking Neon Cityscape',
      );
      expect(humanizeThemeName('7020349_Template_Artwork_1280x720'), 'Template Artwork');
      expect(humanizeThemeName('4954776_Coll_halloween_Realistic_1280x720 - Copy'), 'Coll Halloween Realistic');
      expect(humanizeThemeName('Cats_blinking_and_twitching_slowly_202606151532'), 'Cats Blinking And Twitching Slowly');
    });

    test('a name that is only an id stays distinguishable', () {
      expect(humanizeThemeName('0251d1e0-16a1-49ad-9807-19d1bceac3e9_1080_hd'), 'Untitled 0251');
      expect(humanizeThemeName('25520a42-ed66-4e2e-ae2b-8f80eb53942f_1080_hd'), 'Untitled 2552');
      // A copy counter is not a title.
      expect(humanizeThemeName('16160-269534741_medium (1)'), 'Untitled 1616');
      expect(humanizeThemeName(''), 'Untitled Theme');
    });

    test('mixed-case words are not flattened', () {
      expect(humanizeThemeName('GettyImages-121668776'), 'GettyImages');
    });
  });
}