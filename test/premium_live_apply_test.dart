import 'dart:convert';
import 'dart:io';

import 'package:collider_flutter/core/media/theme_catalog.dart';
import 'package:collider_flutter/features/theme/theme_pack_store.dart';
import 'package:collider_flutter/models/theme_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web preview treats premium live themes as settable (purchases off)', () {
    expect(ThemePackStore.purchasesAvailable, isFalse);

    final live = WallpaperTheme(
      id: 'r2-Aurora Live.mp4',
      name: 'Aurora Live',
      assetPath: 'frame:https://example.com/a.mp4',
      videoPath: 'https://example.com/a.mp4',
      creator: 'David Ebri',
      tier: 'Premium Live Loop',
      isPremium: true,
      priceLabel: r'$4.99',
      collection: 'Collider Themes',
      tags: const ['live wallpaper'],
    );
    expect(live.isLive, isTrue);
    expect(live.videoUrl, isNotNull);
    expect(themeIsSettable(live), isTrue);
  });

  test('R2 live video object answers a ranged browser GET', () async {
    final client = HttpClient();
    try {
      final listReq = await client.getUrl(Uri.parse(ThemeCatalog.themesUrl));
      listReq.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      final listRes = await listReq.close().timeout(const Duration(seconds: 25));
      expect(listRes.statusCode, 200);
      final body = await listRes.transform(utf8.decoder).join();
      final items = (jsonDecode(body) as List).cast<Map>().map((e) => e.cast<String, Object?>()).toList();
      final vid = items.firstWhere(
        (o) => o['kind'] == 'video' || '${o['url']}'.toLowerCase().endsWith('.mp4'),
      );
      final url = vid['url']! as String;
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1023');
      final res = await req.close().timeout(const Duration(seconds: 25));
      expect(res.statusCode, anyOf(200, 206));
      final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      expect(bytes.length, greaterThan(0));
    } finally {
      client.close(force: true);
    }
  });
}
