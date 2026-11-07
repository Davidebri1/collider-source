// Browser + ticker regressions (fix/browser-ticker, Nov 6, 2026).
import 'package:collider_flutter/core/api/media_gen.dart';
import 'package:collider_flutter/features/browser/page_markup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('browser page markup', () {
    test('keeps the proxy base (final address after redirects) and adds the link script', () {
      const html = '<!doctype html><html><head><base href="https://www.wikipedia.org/"><title>Wikipedia</title></head><body><a href="/wiki">x</a></body></html>';
      final out = preparePageMarkup(html, 'https://wikipedia.org');
      expect(RegExp('<base ').allMatches(out).length, 1);
      expect(out, contains('<base href="https://www.wikipedia.org/">$pageNavScript'));
      expect(out.indexOf('<base'), lessThan(out.indexOf('<title>')));
    });

    test('adds a base for the typed address when the proxy gave none', () {
      final out = preparePageMarkup('<html><head></head><body></body></html>', 'https://example.org/a');
      expect(out, contains('<head><base href="https://example.org/a">'));
      expect(out, contains(pageNavPrefix));
    });

    test('works without <head> or <html>', () {
      expect(preparePageMarkup('<p>hi</p>', 'https://x.org'), startsWith('<base href="https://x.org">'));
    });

    test('link script routes links and GET forms through Collider', () {
      expect(pageNavScript, contains('parent.postMessage("$pageNavPrefix"+u'));
      expect(pageNavScript, contains('addEventListener("click"'));
      expect(pageNavScript, contains('addEventListener("submit"'));
    });

    test('only http(s) navigation messages are accepted', () {
      expect(pageNavTarget('${pageNavPrefix}https://en.wikipedia.org/wiki/Canberra'), 'https://en.wikipedia.org/wiki/Canberra');
      expect(pageNavTarget('${pageNavPrefix}javascript:alert(1)'), isNull);
      expect(pageNavTarget('${pageNavPrefix}file:///etc/passwd'), isNull);
      expect(pageNavTarget('https://x.org'), isNull);
      expect(pageNavTarget({'colliderNav': 'https://x.org'}), isNull);
      expect(pageNavTarget(null), isNull);
    });
  });

  group('ticker provider chains', () {
    final mg = MediaGen.instance;
    const ticker = [
      'free/glm-5-3-flash', 'free/laguna-s-2-1', 'free/laguna-xs-2-1', 'free/ling-3-1-flash',
      'free/nemotron-3-5-lightning', 'pro/glm-5-3', 'pro/deepseek-4-1-flash', 'pro/minimax-m3',
      'pro/mimo-v2-6-flash', 'pro/nemotron-3-ultra', 'elite/kimi-k3',
    ];

    test('every ticker model has a chain the Worker can carry', () {
      for (final id in ticker) {
        expect(mg.textAttempts(id), isNotEmpty, reason: id);
        expect(mg.hasCredentials(id), isTrue, reason: id);
      }
    });

    test('no attempt the providers answer 404/410 for (checked Nov 6, 2026)', () {
      const dead = {
        ('nv', 'z-ai/glm-5.3'), ('nv', 'moonshotai/kimi-k3'), ('nv', 'poolside/laguna-s-2.1'),
        ('cr', 'laguna-s-2.1'), ('cr', 'laguna-xs-2.1'), ('cr', 'ling-3.1-flash'),
        ('cr', 'nemotron-3.5-lightning'), ('cr', 'nemotron-3-ultra'),
      };
      for (final id in ticker) {
        for (final a in mg.textAttempts(id)!) {
          expect(dead.contains(a), isFalse, reason: '$id $a');
        }
      }
    });

    test('DeepSeek (consensus agent 2) asks CrazyRouter before NVIDIA (NVIDIA 524s at the Worker)', () {
      expect(mg.textAttempts('pro/deepseek-4-1-flash')!.first, ('cr', 'deepseek-v4.1-flash'));
    });

    test('MiniMax M3.1 Flash (consensus agent 1, Genie) falls to the same model on NVIDIA', () {
      final a = mg.textAttempts('pro/minimax-m3')!;
      expect(a.first, ('mm', 'MiniMax-M3.1-Flash'));
      expect(a[1], ('nv', 'minimaxai/minimax-m3.1-flash'));
      // No other model answers under the MiniMax M3.1 Flash name.
      expect(a.every((x) => x.$2.toLowerCase().contains('m3.1-flash')), isTrue);
    });
  });
}
