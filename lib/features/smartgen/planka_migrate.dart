import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:planka_app/local/planka_store.dart';

import '../../core/account_sync/account_sync.dart';

/// Legacy Smart Gen FileBlobs used on live main (9d86a02).
const kLegacyBoardsBlob = 'smartgen/boards.json';
const kLegacyKanbanBlob = 'smartgen/kanban.json';
const kPlankaBlob = 'smartgen/planka.json';

/// If [PlankaStore] has no boards yet, import user data from legacy blobs.
/// Never deletes legacy blobs. Returns true when anything was imported.
Future<bool> migrateLegacySmartGenIntoPlanka() async {
  final store = PlankaStore.instance;
  if (store.boards.isNotEmpty) return false;

  var imported = false;
  store.runWithoutUndo(() {
    try {
      // sync placeholder — real work below after loads
    } catch (_) {}
  });
  try {
    final boardsRaw = await AccountSync.instance.getBlob(kLegacyBoardsBlob);
    if (boardsRaw != null && boardsRaw.isNotEmpty) {
      final j = jsonDecode(utf8.decode(boardsRaw));
      if (j is Map) {
        store.runWithoutUndo(() {
          imported = _importSgStore(store, Map<String, dynamic>.from(j)) || imported;
        });
      }
    }
  } catch (e) {
    debugPrint('planka_migrate: boards.json skipped: $e');
  }

  if (store.boards.isEmpty) {
    try {
      final kanbanRaw = await AccountSync.instance.getBlob(kLegacyKanbanBlob);
      if (kanbanRaw != null && kanbanRaw.isNotEmpty) {
        final j = jsonDecode(utf8.decode(kanbanRaw));
        if (j is Map) {
          store.runWithoutUndo(() {
            imported = _importKanbanStore(store, Map<String, dynamic>.from(j)) || imported;
          });
        }
      }
    } catch (e) {
      debugPrint('planka_migrate: kanban.json skipped: $e');
    }
  }

  if (imported) {
    await store.persist();
    try {
      await AccountSync.instance.putBlob(
        kPlankaBlob,
        Uint8List.fromList(utf8.encode(jsonEncode(store.toJson()))),
      );
    } catch (_) {}
  }
  return imported;
}

bool _importSgStore(PlankaStore store, Map<String, dynamic> j) {
  final list = j['boards'];
  final boards = <Map<String, dynamic>>[];
  if (list is List) {
    for (final b in list) {
      if (b is Map) boards.add(Map<String, dynamic>.from(b));
    }
  } else if (j['board'] is Map) {
    boards.add(Map<String, dynamic>.from(j['board'] as Map));
  }
  if (boards.isEmpty) return false;

  store.snapAlign = j['snapAlign'] == true;
  var any = false;
  for (final b in boards) {
    // Only kanban-type surfaces go into Planka; every other kind stays in
    // smartgen/boards.json and opens via the live SgPane screens.
    final surface = '${b['surface'] ?? 'kanban'}';
    if (surface != 'kanban') continue;
    any = _importOneSgBoard(store, b) || any;
  }
  return any;
}

bool _importOneSgBoard(PlankaStore store, Map<String, dynamic> b) {
  final name = (b['name'] as String?)?.trim();
  final proj = store.createProject(name?.isNotEmpty == true ? name! : 'Project');
  final board = store.createBoard(
    projectId: proj['id'] as String,
    name: name?.isNotEmpty == true ? name! : 'Board',
    position: 65535,
  );
  final bid = board['id'] as String;

  store.snapAlign = b['snapAlign'] == true || store.snapAlign;

  // Lists
  final sgLists = (b['lists'] as List?) ?? const [];
  final listIdMap = <String, String>{}; // old -> new
  var li = 0;
  for (final raw in sgLists) {
    if (raw is! Map) continue;
    final oldId = '${raw['id'] ?? ''}';
    final title = (raw['title'] as String?)?.trim();
    final l = store.createList(
      boardId: bid,
      name: title?.isNotEmpty == true ? title! : 'List',
      position: (raw['position'] as num?) ?? (li + 1) * 65535,
    );
    if (oldId.isNotEmpty) listIdMap[oldId] = l['id'] as String;
    li++;
  }
  if (listIdMap.isEmpty) {
    // Ensure three default lists so orphan cards still land somewhere.
    for (final (i, t) in ['To Do', 'Doing', 'Done'].indexed) {
      final l = store.createList(boardId: bid, name: t, position: (i + 1) * 65535);
      listIdMap['__default_$i'] = l['id'] as String;
    }
  }
  final fallbackListId = listIdMap.values.first;

  // Labels
  final labelIdMap = <String, String>{};
  final sgLabels = (b['labels'] as List?) ?? const [];
  var labPos = 0;
  for (final raw in sgLabels) {
    if (raw is! Map) continue;
    final oldId = '${raw['id'] ?? ''}';
    final labName = (raw['name'] as String?)?.trim() ?? 'Label';
    final color = _nearestLabelColor((raw['color'] as num?)?.toInt());
    final lab = store.createLabel(
      boardId: bid,
      name: labName.isEmpty ? 'Label' : labName,
      color: color,
      position: ++labPos,
    );
    if (oldId.isNotEmpty) labelIdMap[oldId] = lab['id'] as String;
  }

  // Cards
  final sgCards = (b['cards'] as List?) ?? const [];
  var pos = 0;
  for (final raw in sgCards) {
    if (raw is! Map) continue;
    final oldList = '${raw['listId'] ?? ''}';
    final listId = listIdMap[oldList] ?? fallbackListId;
    final title = (raw['title'] as String?)?.trim() ?? '';
    if (title.isEmpty && ((raw['description'] as String?) ?? '').trim().isEmpty) continue;
    final card = store.createCard(
      listId: listId,
      boardId: bid,
      name: title.isEmpty ? 'Card' : title,
      position: (raw['rank'] as num?) ?? (++pos) * 65535,
    );
    final cid = card['id'] as String;
    final desc = StringBuffer();
    final d = (raw['description'] as String?)?.trim() ?? '';
    if (d.isNotEmpty) desc.writeln(d);
    final notebook = (raw['notebook'] as String?)?.trim() ?? '';
    if (notebook.isNotEmpty) {
      if (desc.isNotEmpty) desc.writeln();
      desc.writeln(notebook);
    }
    final due = (raw['due'] as num?)?.toInt();
    final patch = <String, dynamic>{
      if (desc.isNotEmpty) 'description': desc.toString().trim(),
      if (due != null && due > 0)
        'dueDate': DateTime.fromMillisecondsSinceEpoch(due).toUtc().toIso8601String(),
    };
    if (patch.isNotEmpty) store.updateCard(cid, patch);

    // Job-typed fields + card meta → Custom Fields (never folded into description).
    final jobVals = <String, String>{
      if ('${raw['company'] ?? ''}'.trim().isNotEmpty) 'Company': '${raw['company']}'.trim(),
      if ('${raw['positionTitle'] ?? ''}'.trim().isNotEmpty) 'Position': '${raw['positionTitle']}'.trim(),
      if ('${raw['jobStart'] ?? ''}'.trim().isNotEmpty) 'Start': '${raw['jobStart']}'.trim(),
      if ('${raw['jobEnd'] ?? ''}'.trim().isNotEmpty) 'End': '${raw['jobEnd']}'.trim(),
      if ('${raw['responsibilities'] ?? ''}'.trim().isNotEmpty)
        'Responsibilities': '${raw['responsibilities']}'.trim(),
      if ('${raw['achievements'] ?? ''}'.trim().isNotEmpty) 'Achievements': '${raw['achievements']}'.trim(),
      if ('${raw['assignee'] ?? ''}'.trim().isNotEmpty) 'Assignee': '${raw['assignee']}'.trim(),
      if ('${raw['status'] ?? ''}'.trim().isNotEmpty) 'Status': '${raw['status']}'.trim(),
      if (raw['priority'] != null && '${raw['priority']}' != '0') 'Priority': '${raw['priority']}',
      if (raw['urgent'] == true) 'Urgent': 'yes',
    };
    final custom = raw['custom'];
    if (custom is Map) {
      for (final e in custom.entries) {
        final s = '${e.value}'.trim();
        if (s.isNotEmpty) jobVals['${e.key}'] = s;
      }
    }
    if (jobVals.isNotEmpty) {
      _ensureJobCustomFields(store, bid);
      for (final e in jobVals.entries) {
        final cfId = _jobFieldIds[bid]![e.key];
        if (cfId == null) continue;
        store.setCardCustomFieldValue(cardId: cid, customFieldId: cfId, value: e.value);
      }
    }

    final color = (raw['color'] as num?)?.toInt() ?? 0;
    if (color != 0) store.setCardCoverColor(cid, color);

    final dx = (raw['dx'] as num?)?.toDouble();
    final dy = (raw['dy'] as num?)?.toDouble();
    if (dx != null && dy != null) store.setCardFreePos(cid, dx, dy);

    // Labels
    final labs = raw['labels'];
    if (labs is List) {
      for (final lid in labs) {
        final nid = labelIdMap['$lid'];
        if (nid != null) store.addCardLabel(cid, nid);
      }
    }

    // Checklists → tasks
    final checks = raw['checks'];
    if (checks is List) {
      var ti = 0;
      for (final ch in checks) {
        if (ch is! Map) continue;
        final tname = (ch['text'] as String?)?.trim() ?? (ch['title'] as String?)?.trim() ?? '';
        if (tname.isEmpty) continue;
        final t = store.addTask(cardId: cid, name: tname, position: (++ti) * 65535);
        if (ch['done'] == true || ch['completed'] == true) {
          store.updateTask(t['id'] as String, {'isCompleted': true});
        }
      }
    }

    // Activity → comments (history parity)
    final activity = raw['activity'];
    if (activity is List) {
      for (final a in activity) {
        if (a is! Map) continue;
        final text = (a['text'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;
        store.createComment(cid, text);
      }
    }

    // Cover / file metadata (data URLs kept as attachment url when present)
    final files = raw['files'];
    if (files is List) {
      for (final f in files) {
        if (f is! Map) continue;
        final fname = (f['name'] as String?)?.trim() ?? 'file';
        final dataUrl = (f['dataUrl'] as String?) ?? (f['url'] as String?);
        final att = store.createAttachment(
          cardId: cid,
          name: fname,
          url: dataUrl,
        );
        if (fname.toLowerCase().startsWith('cover.')) {
          store.updateCard(cid, {'coverAttachmentId': att['id']});
        }
      }
    }
  }

  return true; // board itself counts even if empty
}

bool _importKanbanStore(PlankaStore store, Map<String, dynamic> j) {
  final cards = j['cards'];
  if (cards is! List || cards.isEmpty) return false;

  final proj = store.createProject('Project');
  final board = store.createBoard(
    projectId: proj['id'] as String,
    name: 'Board',
    position: 65535,
  );
  final bid = board['id'] as String;
  final cols = ['To Do', 'Doing', 'Done'];
  final listIds = <String>[];
  for (final (i, t) in cols.indexed) {
    final l = store.createList(boardId: bid, name: t, position: (i + 1) * 65535);
    listIds.add(l['id'] as String);
  }

  // Palette used by KanbanStore color index (approximate ARGB).
  const palette = [0xFFEB5A46, 0xFF0079BF, 0xFF61BD4F, 0xFFF2D600];
  var pos = 0;
  for (final raw in cards) {
    if (raw is! Map) continue;
    final title = (raw['title'] as String?)?.trim() ?? '';
    final notes = (raw['notes'] as String?)?.trim() ?? '';
    if (title.isEmpty && notes.isEmpty) continue;
    final col = ((raw['col'] as num?)?.toInt() ?? 0).clamp(0, listIds.length - 1);
    final card = store.createCard(
      listId: listIds[col],
      boardId: bid,
      name: title.isEmpty ? 'Card' : title,
      position: (++pos) * 65535,
    );
    final cid = card['id'] as String;
    if (notes.isNotEmpty) store.updateCard(cid, {'description': notes});
    final colorIdx = (raw['color'] as num?)?.toInt() ?? 0;
    if (colorIdx >= 0 && colorIdx < palette.length) {
      store.setCardCoverColor(cid, palette[colorIdx]);
    }
  }
  return true;
}


/// boardId -> fieldName -> customFieldId
final Map<String, Map<String, String>> _jobFieldIds = {};

void _ensureJobCustomFields(PlankaStore store, String boardId) {
  if (_jobFieldIds.containsKey(boardId)) return;
  const names = [
    'Company',
    'Position',
    'Start',
    'End',
    'Responsibilities',
    'Achievements',
    'Assignee',
    'Status',
    'Priority',
    'Urgent',
  ];
  final grp = store.createCustomFieldGroup(boardId: boardId, name: 'Job', position: 1);
  final map = <String, String>{};
  var pos = 0;
  for (final n in names) {
    final f = store.createCustomField(
      boardId: boardId,
      customFieldGroupId: grp['id'] as String,
      name: n,
      type: 'text',
      position: ++pos,
    );
    map[n] = f['id'] as String;
  }
  _jobFieldIds[boardId] = map;
}

/// Map legacy ARGB to a stock planka label color name.
String _nearestLabelColor(int? argb) {
  if (argb == null || argb == 0) return 'lagune-blue';
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  // Rough buckets matching common Trello/planka hues.
  if (r > 180 && g < 100 && b < 100) return 'berry-red';
  if (r > 180 && g > 100 && b < 80) return 'orange-peel';
  if (r > 180 && g > 180 && b < 100) return 'sunny-grass'; // yellow-ish
  if (g > r && g > b) return 'bright-moss';
  if (b > r && b > g) return 'lagune-blue';
  if (r > 100 && b > 100) return 'pink-tulip';
  return 'lagune-blue';
}
