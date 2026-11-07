import 'dart:typed_data';

import 'package:collider_flutter/core/api/media_gen.dart';
import 'package:collider_flutter/features/prompt/attached_text.dart';
import 'package:collider_flutter/features/smartgen/reminder_sync.dart';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canvas objects keep the type name and a frame through JSON', () {
    final s = SgStore()..ensureStarter();
    expect(s.addCanvas('Notebook', 'Notebook'), isTrue);
    final c = s.board!.canvases.single;
    expect(c.name, 'Notebook');
    expect(c.kind, 'Notebook');
    expect(c.x, isNonNegative);
    final card = s.addCard(SgType.note)!;
    expect(card.canvasId, c.id);
    s.transferCard(card.id, boardId: s.board!.id, canvasId: c.id, fx: 0.2, fy: 0.3);
    final back = SgBoard.fromJson(s.board!.toJson());
    expect(back.canvases.single.name, 'Notebook');
    expect(back.cards.single.fx, 0.2);
    expect(back.cards.single.canvasId, c.id);
    expect(back.kind, SgBoardKind.desk);
  });

  test('moving a card onto another board leaves the first board', () {
    final s = SgStore()..ensureStarter();
    final a = s.board!;
    final card = s.addCard(SgType.task)!;
    final b = s.createBoard('Bench', goHome: false);
    s.openBoard(a.id);
    s.transferCard(card.id, boardId: b.id);
    expect(a.cards.where((c) => c.id == card.id), isEmpty);
    expect(b.cards.single.id, card.id);
  });

  test("David's Oct 11 consensus list is unchanged", () {
    expect(consensusChain.map((e) => '${e.model}|${e.wire}|${e.remote}').toList(), [
      'MiniMax M3.1|mm|MiniMax-M3.1-Flash',
      'MiniMax M3|cc|minimax/minimax-m3',
      'MiniMax M3|oc|minimax-m3',
      'Kimi K3|nv|moonshotai/kimi-k3',
      'DeepSeek 4.1 Flash|nv|deepseek-ai/deepseek-v4.1-flash',
      'GLM 5.3|nv|z-ai/glm-5.3',
      'GLM 5.3 Flash|nv|z-ai/glm-5.3-flash',
      'Nemotron Ultra|nv|nvidia/nemotron-3-ultra-550b-a55b',
      'Nemotron Nano|nv|nvidia/nemotron-nano-3-30b-a3b',
    ]);
    expect(smartGenChain, consensusChain);
  });

  test('binary files send name and size only; oversized images are not sent', () {
    final bin = classifyAttachment('clip.bin', Uint8List.fromList(List.filled(32, 0)));
    expect(bin.disposition, AttachmentDisposition.nameOnly);
    expect(bin.text, contains('name and size only'));
    expect(bin.imageUri, isNull);
    final big = classifyAttachment('photo.png', Uint8List(kAttachedImageMaxBytes + 1));
    expect(big.disposition, AttachmentDisposition.imageSkipped);
    expect(big.imageUri, isNull);
    expect(big.text, contains('over 4 MB'));
    final note = classifyAttachment('note.txt', Uint8List.fromList('hello board'.codeUnits));
    expect(note.disposition, AttachmentDisposition.text);
    expect(note.text, 'hello board');
  });

  test('calendar sync plans create, update, remote-wins, and delete', () {
    final t0 = DateTime.utc(2026, 11, 1);
    final local = [
      LocalReminder(id: 'a', title: 'A', description: '', start: t0, updated: t0.add(const Duration(hours: 2))),
      LocalReminder(id: 'b', title: 'B', description: '', start: t0, updated: t0),
    ];
    final remote = [
      RemoteCalEvent(id: 'rb', colliderId: 'b', summary: 'B remote', start: t0.add(const Duration(days: 1)), updated: t0.add(const Duration(hours: 3))),
      RemoteCalEvent(id: 'rg', colliderId: 'gone', summary: 'Gone', start: t0, updated: t0),
    ];
    final plan = planReminderSync(local, remote);
    expect(plan.map((p) => p.action), [CalAction.create, CalAction.takeRemote, CalAction.delete]);
    expect(rruleFor('weekly'), 'RRULE:FREQ=WEEKLY');
    expect(rruleFor(null), isNull);
  });
}
