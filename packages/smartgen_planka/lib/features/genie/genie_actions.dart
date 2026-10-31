import 'dart:convert';

import '../../local/planka_store.dart';

const kPlankaGenieSystemPrompt = """
You are Collider Smart Gen Genie. You edit the open board.
Always reply with ONE JSON object only (no markdown fences), shape:
{"reply":"short human summary","actions":[ ... ]}
Allowed actions (omit unknown fields):
{"op":"add_card","title":"...","list":"To Do","color":"EB5A46"}
{"op":"recolor","title":"...","color":"0079BF"}
{"op":"rename","from":"...","to":"..."}
{"op":"set_field","title":"...","field":"description|dueDate","value":"..."}
{"op":"move","title":"...","list":"Doing"}
Use hex colors without #. Prefer few precise actions. If nothing to change, actions may be [].
""";

/// Build a compact board JSON for the Genie system turn.
String plankaBoardContextForGenie({String? boardId}) {
  final store = PlankaStore.instance;
  final boards = store.boards;
  if (boards.isEmpty) return jsonEncode({'board': null, 'lists': [], 'cards': []});
  final b = boardId == null
      ? boards.first
      : boards.firstWhere((x) => x['id'] == boardId, orElse: () => boards.first);
  final bid = b['id'] as String;
  final lists = [
    for (final l in store.lists.where((l) => l['boardId'] == bid && !store.archivedListIds.contains(l['id'])))
      {'id': l['id'], 'title': l['name']},
  ];
  final cards = [
    for (final c in store.cards.where((c) => c['boardId'] == bid && !store.archivedCardIds.contains(c['id'])))
      {
        'id': c['id'],
        'title': c['name'],
        'list': c['listId'],
        'description': c['description'],
        'color': store.cardCoverColors[c['id']]?.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase(),
      },
  ];
  return jsonEncode({
    'board': b['name'],
    'boardId': bid,
    'lists': lists,
    'cards': cards,
    'cardCount': cards.length,
    'listCount': lists.length,
  });
}

Map<String, Object?>? extractGenieJson(String raw) {
  var s = raw.trim();
  if (s.startsWith('```')) {
    final lines = s.split('\n');
    s = lines.skip(1).takeWhile((l) => !l.trim().startsWith('```')).join('\n').trim();
  }
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final j = jsonDecode(s.substring(start, end + 1));
    if (j is Map) return j.cast<String, Object?>();
  } catch (_) {}
  return null;
}

int? parseHexColor(String raw) {
  var s = raw.trim().replaceAll('#', '');
  if (s.isEmpty) return null;
  if (s.length == 6) s = 'FF$s';
  return int.tryParse(s, radix: 16);
}

/// Apply Genie model reply actions onto [PlankaStore]. Returns human reply text.
String applyPlankaGenieReply(String raw, {String? boardId}) {
  final store = PlankaStore.instance;
  final parsed = extractGenieJson(raw);
  if (parsed == null) {
    return raw.trim().isEmpty ? 'The model returned an empty reply.' : raw.trim();
  }
  final reply = (parsed['reply'] as String?)?.trim();
  final actions = parsed['actions'];
  var n = 0;
  if (actions is List) {
    final boards = store.boards;
    if (boards.isEmpty) {
      return reply?.isNotEmpty == true ? reply! : 'No board is open.';
    }
    final b = boardId == null
        ? boards.first
        : boards.firstWhere((x) => x['id'] == boardId, orElse: () => boards.first);
    final bid = b['id'] as String;
    final boardLists = store.lists
        .where((l) => l['boardId'] == bid && !store.archivedListIds.contains(l['id']))
        .toList();

    String? listIdByName(String name) {
      final lower = name.toLowerCase();
      for (final l in boardLists) {
        if ('${l['name']}'.toLowerCase() == lower) return l['id'] as String;
      }
      return null;
    }

    for (final a in actions) {
      if (a is! Map) continue;
      final op = '${a['op'] ?? ''}'.toLowerCase();
      switch (op) {
        case 'add_card':
          final title = '${a['title'] ?? 'Card'}'.trim();
          final listName = '${a['list'] ?? ''}'.trim();
          final lid = listName.isEmpty
              ? (boardLists.isEmpty ? null : boardLists.first['id'] as String)
              : listIdByName(listName) ?? (boardLists.isEmpty ? null : boardLists.first['id'] as String);
          if (lid == null) break;
          final card = store.createCard(
            listId: lid,
            boardId: bid,
            name: title.isEmpty ? 'Card' : title,
            position: (store.cards.where((c) => c['listId'] == lid).length + 1) * 65535,
          );
          final color = parseHexColor('${a['color'] ?? ''}');
          if (color != null) store.setCardCoverColor(card['id'] as String, color);
          n++;
        case 'recolor':
          final title = '${a['title'] ?? ''}'.toLowerCase();
          final color = parseHexColor('${a['color'] ?? ''}');
          if (color == null) break;
          for (final c in store.cards.where((c) => c['boardId'] == bid)) {
            if (title.isEmpty || '${c['name']}'.toLowerCase().contains(title)) {
              store.setCardCoverColor(c['id'] as String, color);
              n++;
              if (title.isNotEmpty) break;
            }
          }
        case 'rename':
          final from = '${a['from'] ?? ''}';
          final to = '${a['to'] ?? ''}'.trim();
          if (from.isEmpty || to.isEmpty) break;
          for (final c in store.cards.where((c) => c['boardId'] == bid)) {
            final name = '${c['name']}';
            if (name == from || name.toLowerCase() == from.toLowerCase()) {
              store.updateCard(c['id'] as String, {'name': to});
              n++;
              break;
            }
          }
        case 'set_field':
          final title = '${a['title'] ?? ''}'.toLowerCase();
          final field = '${a['field'] ?? ''}'.toLowerCase();
          final value = '${a['value'] ?? ''}'.trim();
          for (final c in store.cards.where((c) => c['boardId'] == bid)) {
            if (title.isNotEmpty && !'${c['name']}'.toLowerCase().contains(title)) continue;
            if (field == 'description') {
              store.updateCard(c['id'] as String, {'description': value});
              n++;
            } else if (field == 'duedate' || field == 'due') {
              store.updateCard(c['id'] as String, {'dueDate': value});
              n++;
            }
            break;
          }
        case 'move':
          final title = '${a['title'] ?? ''}'.toLowerCase();
          final listName = '${a['list'] ?? ''}'.trim();
          final lid = listIdByName(listName);
          if (lid == null || title.isEmpty) break;
          for (final c in store.cards.where((c) => c['boardId'] == bid)) {
            if (!'${c['name']}'.toLowerCase().contains(title)) continue;
            store.updateCard(c['id'] as String, {'listId': lid});
            n++;
            break;
          }
      }
    }
  }
  if (reply != null && reply.isNotEmpty) {
    return n > 0 ? '$reply ($n changes)' : reply;
  }
  return n > 0 ? 'Applied $n board changes.' : (raw.trim().isEmpty ? 'No changes.' : raw.trim());
}
