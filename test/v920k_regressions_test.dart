import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 Home reload: persist effective summary + expand restored thread', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains("t.conversation.isNotEmpty ? t.conversation.last.text : _currentPrompt"), isTrue,
        reason: 'persist must store last message/prompt when summary blank');
    expect(src.contains('await _persistLocalHistory()'), isTrue,
        reason: 'persist-on-send must be awaited before answers');
    expect(src.contains('..add(openId)'), isTrue,
        reason: 'reload must open the restored conversation thread');
    expect(src.contains("queryParameters['cat']"), isTrue,
        reason: 'restore must not steal ?cat= media deep links');
    expect(src.contains('setState(() => _restoreActiveFromSession(_globalHistorySessions.first))'), isTrue,
        reason: 'History fallback restore must trigger setState');
  });

  test('V2 Smart Gen view chips: one horizontal swipe row, Align in header', () {
    final pane = File('lib/features/smartgen/sg_pane.dart').readAsStringSync();
    final chips = pane.split('Widget _viewChips(SgBoard b)')[1].split('Widget _glassChoice')[0];
    expect(chips.contains('Wrap('), isFalse, reason: 'view chips must not Wrap into multiple rows');
    expect(chips.contains('scrollDirection: Axis.horizontal'), isTrue);
    expect(chips.contains('SgScroll()'), isTrue, reason: 'no scrollbar');
    final header = pane.split('Widget _header(SgBoard b)')[1].split('Widget _viewChips')[0];
    expect(header.contains('Align to grid') || header.contains('Free place'), isTrue,
        reason: 'Align stays reachable in board chrome');
  });

  test('W5 Media: phone MediaTicker + Generated image semantics + magic bytes', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('MediaTicker('), isTrue, reason: 'phone media stage must use stacked MediaTicker');
    expect(main.contains('width < 768'), isTrue);
    final view = File('lib/features/mediagen/media_view.dart').readAsStringSync();
    expect(view.contains("label: 'Generated image'"), isTrue);
    final gen = File('lib/core/api/media_gen.dart').readAsStringSync();
    expect(gen.contains('_looksLikeImage'), isTrue);
    expect(gen.contains('_imageMime'), isTrue);
    expect(gen.contains('url: fallback'), isTrue,
        reason: 'pollinations byte-fetch must fall back to Image.network URL');
  });

  test('Files video thumb: ThumbView / FileThumbs for every type', () {
    final files = File('lib/features/files/screens/files_screen.dart').readAsStringSync();
    expect(files.contains('ThumbView(file:'), isTrue);
    expect(files.contains('class _Thumb'), isFalse, reason: 'raw Image.memory thumb removed');
    final tile = files.split('Widget _tile(StoredFile f)')[1].split('Future<void> _alert')[0];
    expect(tile.contains('ThumbView(file: f)'), isTrue);
    expect(tile.contains('FileStore.isImage(f.name)'), isFalse,
        reason: 'grid tile must not gate thumbnail to images only');
    final thumbs = File('lib/core/files/file_thumbs.dart').readAsStringSync();
    final web = File('lib/core/files/thumb_codec_web.dart').readAsStringSync();
    expect(thumbs.contains('videoFrame(bytes'), isTrue);
    expect(web.contains("type: 'video/mp4'"), isTrue,
        reason: 'web videoFrame must hint video/mp4 for Chromium decode');
  });
}
