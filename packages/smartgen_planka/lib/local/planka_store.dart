import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

typedef PlankaPersistSave = Future<void> Function(String json);
typedef PlankaPersistLoad = Future<String?> Function();

/// Local Planka document store for Collider Smart Gen (FileBlobs-backed).
/// Empty by default — no seed projects/boards/cards.
class PlankaStore extends ChangeNotifier {
  PlankaStore._();
  static final PlankaStore instance = PlankaStore._();

  static const int schemaVersion = 1;

  PlankaPersistSave? onSave;
  PlankaPersistLoad? onLoad;

  final List<Map<String, dynamic>> users = [];
  final List<Map<String, dynamic>> projects = [];
  final List<Map<String, dynamic>> boards = [];
  final List<Map<String, dynamic>> lists = [];
  final List<Map<String, dynamic>> cards = [];
  final List<Map<String, dynamic>> labels = [];
  final List<Map<String, dynamic>> cardLabels = [];
  final List<Map<String, dynamic>> tasks = [];
  final List<Map<String, dynamic>> comments = [];
  final List<Map<String, dynamic>> attachments = [];
  final List<Map<String, dynamic>> cardMemberships = [];
  final List<Map<String, dynamic>> boardMemberships = [];
  final List<Map<String, dynamic>> customFieldGroups = [];
  final List<Map<String, dynamic>> customFields = [];
  final List<Map<String, dynamic>> cardCustomFieldValues = [];

  /// Free place by default (Align off).
  bool snapAlign = false;

  /// listId -> color name from labelColors.json palette.
  final Map<String, String> listColors = {};

  /// cardId -> ARGB int for full-card cover tint.
  final Map<String, int> cardCoverColors = {};

  /// cardId -> free-drag {dx, dy} on the canvas (Align off).
  final Map<String, Map<String, double>> cardFreePos = {};

  /// Archived entity ids.
  final Set<String> archivedCardIds = {};
  final Set<String> archivedListIds = {};

  String? filterQuery;
  String? sortBy; // name | dueDate | position

  bool _loaded = false;
  bool get loaded => _loaded;

  final List<String> _undo = [];
  final List<String> _redo = [];
  String _lastCommitted = '';
  bool _amidRestore = false;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  String get localUserId {
    if (users.isEmpty) {
      users.add({
        'id': 'u_local',
        'email': 'you@local',
        'name': 'You',
        'username': 'you',
        'isAdmin': true,
      });
    }
    return users.first['id'] as String;
  }

  String _id([String prefix = 'id']) {
    final n = DateTime.now().microsecondsSinceEpoch;
    final r = Random().nextInt(1 << 20);
    return '${prefix}_${n}_$r';
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    localUserId; // ensure local user exists before restore
    final load = onLoad;
    if (load != null) {
      final raw = await load();
      if (raw != null && raw.isNotEmpty) {
        try {
          _fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('PlankaStore: ignored bad blob: $e');
        }
      }
    }
    _loaded = true;
    _lastCommitted = jsonEncode(toJson());
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }

  Future<void> persist() async {
    final save = onSave;
    if (save == null) return;
    await save(jsonEncode(toJson()));
  }

  /// Run [body] without recording undo (migrate / restore / seed).
  void runWithoutUndo(void Function() body) {
    final prev = _amidRestore;
    _amidRestore = true;
    try {
      body();
    } finally {
      _amidRestore = prev;
      _lastCommitted = jsonEncode(toJson());
    }
  }

  void _touch() {
    if (!_amidRestore) {
      if (_lastCommitted.isNotEmpty) {
        _undo.add(_lastCommitted);
        if (_undo.length > 40) _undo.removeAt(0);
        _redo.clear();
      }
    }
    notifyListeners();
    _lastCommitted = jsonEncode(toJson());
    // fire-and-forget persist
    persist();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(jsonEncode(toJson()));
    final raw = _undo.removeLast();
    _amidRestore = true;
    try {
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } finally {
      _amidRestore = false;
    }
    _lastCommitted = jsonEncode(toJson());
    notifyListeners();
    persist();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(jsonEncode(toJson()));
    final raw = _redo.removeLast();
    _amidRestore = true;
    try {
      _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } finally {
      _amidRestore = false;
    }
    _lastCommitted = jsonEncode(toJson());
    notifyListeners();
    persist();
  }

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'snapAlign': snapAlign,
        'users': users,
        'projects': projects,
        'boards': boards,
        'lists': lists,
        'cards': cards,
        'labels': labels,
        'cardLabels': cardLabels,
        'tasks': tasks,
        'comments': comments,
        'attachments': attachments,
        'cardMemberships': cardMemberships,
        'boardMemberships': boardMemberships,
        'customFieldGroups': customFieldGroups,
        'customFields': customFields,
        'cardCustomFieldValues': cardCustomFieldValues,
        'listColors': listColors,
        'cardCoverColors': cardCoverColors.map((k, v) => MapEntry(k, v)),
        'cardFreePos': {
          for (final e in cardFreePos.entries)
            e.key: {'dx': e.value['dx'] ?? 0, 'dy': e.value['dy'] ?? 0},
        },
        'archivedCardIds': archivedCardIds.toList(),
        'archivedListIds': archivedListIds.toList(),
      };

  void _fromJson(Map<String, dynamic> j) {
    void loadList(String key, List<Map<String, dynamic>> dest) {
      dest
        ..clear()
        ..addAll(((j[key] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)));
    }

    loadList('users', users);
    loadList('projects', projects);
    loadList('boards', boards);
    loadList('lists', lists);
    loadList('cards', cards);
    loadList('labels', labels);
    loadList('cardLabels', cardLabels);
    loadList('tasks', tasks);
    loadList('comments', comments);
    loadList('attachments', attachments);
    loadList('cardMemberships', cardMemberships);
    loadList('boardMemberships', boardMemberships);
    loadList('customFieldGroups', customFieldGroups);
    loadList('customFields', customFields);
    loadList('cardCustomFieldValues', cardCustomFieldValues);
    snapAlign = j['snapAlign'] == true;
    listColors
      ..clear()
      ..addAll(Map<String, String>.from(
          ((j['listColors'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v'))));
    cardCoverColors
      ..clear()
      ..addAll(Map<String, int>.from(((j['cardCoverColors'] as Map?) ?? const {})
          .map((k, v) => MapEntry('$k', (v as num).toInt()))));
    cardFreePos
      ..clear()
      ..addAll({
        for (final e in (((j['cardFreePos'] as Map?) ?? const {}).entries))
          '${e.key}': {
            'dx': ((e.value as Map)['dx'] as num?)?.toDouble() ?? 0,
            'dy': ((e.value as Map)['dy'] as num?)?.toDouble() ?? 0,
          },
      });
    archivedCardIds
      ..clear()
      ..addAll((((j['archivedCardIds'] as List?) ?? const []).map((e) => '$e')));
    archivedListIds
      ..clear()
      ..addAll((((j['archivedListIds'] as List?) ?? const []).map((e) => '$e')));
    localUserId;
  }

  // ——— Projects ———
  Map<String, dynamic> createProject(String name) {
    final p = {
      'id': _id('proj'),
      'name': name,
      'background': null,
      'backgroundImage': null,
    };
    projects.add(p);
    _touch();
    return p;
  }

  void deleteProject(String id) {
    final boardIds = boards.where((b) => b['projectId'] == id).map((b) => b['id'] as String).toList();
    for (final bid in boardIds) {
      deleteBoard(bid);
    }
    projects.removeWhere((p) => p['id'] == id);
    _touch();
  }

  void updateProjectName(String id, String name) {
    final i = projects.indexWhere((p) => p['id'] == id);
    if (i >= 0) {
      projects[i]['name'] = name;
      _touch();
    }
  }

  Map<String, dynamic> projectsIndexPayload() {
    final includedBoards = boards.toList();
    return {
      'items': projects.map((p) => Map<String, dynamic>.from(p)).toList(),
      'included': {
        'boards': includedBoards,
        'users': users,
      },
    };
  }

  // ——— Boards ———
  Map<String, dynamic> createBoard({
    required String projectId,
    required String name,
    required num position,
  }) {
    final b = {
      'id': _id('board'),
      'projectId': projectId,
      'name': name,
      'position': position,
    };
    boards.add(b);
    boardMemberships.add({
      'id': _id('bm'),
      'boardId': b['id'],
      'userId': localUserId,
      'role': 'editor',
      'canComment': true,
    });
    _touch();
    return b;
  }

  void deleteBoard(String id) {
    final listIds = lists.where((l) => l['boardId'] == id).map((l) => l['id'] as String).toList();
    for (final lid in listIds) {
      deleteList(lid);
    }
    labels.removeWhere((l) => l['boardId'] == id);
    boardMemberships.removeWhere((m) => m['boardId'] == id);
    customFieldGroups.removeWhere((g) => g['boardId'] == id);
    customFields.removeWhere((f) => f['boardId'] == id);
    boards.removeWhere((b) => b['id'] == id);
    _touch();
  }

  void updateBoardName(String id, String name) {
    final i = boards.indexWhere((b) => b['id'] == id);
    if (i >= 0) {
      boards[i]['name'] = name;
      _touch();
    }
  }

  Map<String, dynamic> projectDetailPayload(String projectId) {
    final item = projects.firstWhere((p) => p['id'] == projectId, orElse: () => {});
    final projectBoards = boards.where((b) => b['projectId'] == projectId).toList();
    return {
      'item': item,
      'included': {
        'boards': projectBoards,
        'users': users,
      },
    };
  }

  Map<String, dynamic> boardDetailPayload(String boardId) {
    final item = boards.firstWhere((b) => b['id'] == boardId, orElse: () => {});
    final boardLists = lists
        .where((l) => l['boardId'] == boardId && !archivedListIds.contains(l['id']))
        .toList()
      ..sort((a, b) => ((a['position'] as num?) ?? 0).compareTo((b['position'] as num?) ?? 0));
    final boardCards = cards
        .where((c) => c['boardId'] == boardId && !archivedCardIds.contains(c['id']))
        .toList();
    final boardLabels = labels.where((l) => l['boardId'] == boardId).toList();
    final boardTasks = tasks.where((t) => boardCards.any((c) => c['id'] == t['cardId'])).toList();
    final boardCardMemberships =
        cardMemberships.where((m) => boardCards.any((c) => c['id'] == m['cardId'])).toList();
    final boardAttachments =
        attachments.where((a) => boardCards.any((c) => c['id'] == a['cardId'])).toList();
    final boardMs = boardMemberships.where((m) => m['boardId'] == boardId).toList();
    return {
      'item': item,
      'included': {
        'lists': boardLists,
        'cards': boardCards,
        'labels': boardLabels,
        'tasks': boardTasks,
        'cardMemberships': boardCardMemberships,
        'attachments': boardAttachments,
        'users': users,
        'boardMemberships': boardMs,
        'cardLabels': cardLabels
            .where((cl) => boardCards.any((c) => c['id'] == cl['cardId']))
            .toList(),
      },
    };
  }

  // ——— Lists ———
  Map<String, dynamic> createList({
    required String boardId,
    required String name,
    required num position,
    String? color,
  }) {
    final l = {
      'id': _id('list'),
      'boardId': boardId,
      'name': name,
      'position': position,
      if (color != null) 'color': color,
    };
    lists.add(l);
    if (color != null) listColors[l['id'] as String] = color;
    _touch();
    return l;
  }

  void deleteList(String id) {
    final cardIds = cards.where((c) => c['listId'] == id).map((c) => c['id'] as String).toList();
    for (final cid in cardIds) {
      deleteCard(cid);
    }
    lists.removeWhere((l) => l['id'] == id);
    listColors.remove(id);
    archivedListIds.remove(id);
    _touch();
  }

  void updateListName(String id, String name) {
    final i = lists.indexWhere((l) => l['id'] == id);
    if (i >= 0) {
      lists[i]['name'] = name;
      _touch();
    }
  }

  void updateListPosition(String id, num position) {
    final i = lists.indexWhere((l) => l['id'] == id);
    if (i >= 0) {
      lists[i]['position'] = position;
      _touch();
    }
  }

  void setListColor(String id, String? color) {
    final i = lists.indexWhere((l) => l['id'] == id);
    if (i < 0) return;
    if (color == null || color.isEmpty) {
      lists[i].remove('color');
      listColors.remove(id);
    } else {
      lists[i]['color'] = color;
      listColors[id] = color;
    }
    _touch();
  }

  void archiveList(String id) {
    archivedListIds.add(id);
    _touch();
  }

  void archiveCardsInList(String listId) {
    for (final c in cards.where((c) => c['listId'] == listId)) {
      archivedCardIds.add(c['id'] as String);
    }
    _touch();
  }

  // ——— Cards ———
  Map<String, dynamic> createCard({
    required String listId,
    required String boardId,
    required String name,
    required num position,
  }) {
    final c = {
      'id': _id('card'),
      'listId': listId,
      'boardId': boardId,
      'name': name,
      'position': position,
      'description': null,
      'dueDate': null,
      'isSubscribed': false,
      'coverAttachmentId': null,
      'creatorUserId': localUserId,
      'stopwatch': null,
      'type': 'project',
    };
    cards.add(c);
    _touch();
    return c;
  }

  void deleteCard(String id) {
    tasks.removeWhere((t) => t['cardId'] == id);
    comments.removeWhere((c) => c['cardId'] == id);
    attachments.removeWhere((a) => a['cardId'] == id);
    cardMemberships.removeWhere((m) => m['cardId'] == id);
    cardLabels.removeWhere((cl) => cl['cardId'] == id);
    cardCustomFieldValues.removeWhere((v) => v['cardId'] == id);
    cardCoverColors.remove(id);
    archivedCardIds.remove(id);
    cards.removeWhere((c) => c['id'] == id);
    _touch();
  }

  void archiveCard(String id) {
    archivedCardIds.add(id);
    _touch();
  }

  void updateCard(String id, Map<String, dynamic> patch) {
    final i = cards.indexWhere((c) => c['id'] == id);
    if (i < 0) return;
    cards[i].addAll(patch);
    _touch();
  }

  void setCardCoverColor(String id, int? color) {
    if (color == null || color == 0) {
      cardCoverColors.remove(id);
    } else {
      cardCoverColors[id] = color;
    }
    _touch();
  }

  Map<String, dynamic> cardDetailPayload(String cardId) {
    final item = Map<String, dynamic>.from(
        cards.firstWhere((c) => c['id'] == cardId, orElse: () => {'id': cardId, 'name': '', 'listId': ''}));
    final cls = cardLabels.where((cl) => cl['cardId'] == cardId).toList();
    return {
      'item': item,
      'included': {
        'cardMemberships': cardMemberships.where((m) => m['cardId'] == cardId).toList(),
        'cardLabels': cls,
        'attachments': attachments.where((a) => a['cardId'] == cardId).toList(),
        'tasks': tasks.where((t) => t['cardId'] == cardId).toList(),
        'labels': labels
            .where((l) => cls.any((cl) => cl['labelId'] == l['id']))
            .toList(),
        'users': users,
        'customFieldGroups': customFieldGroups
            .where((g) => g['boardId'] == item['boardId'])
            .toList(),
        'customFields': customFields
            .where((f) => f['boardId'] == item['boardId'])
            .toList(),
        'cardCustomFieldValues':
            cardCustomFieldValues.where((v) => v['cardId'] == cardId).toList(),
      },
    };
  }

  // ——— Labels ———
  Map<String, dynamic> createLabel({
    required String boardId,
    required String name,
    required String color,
    num position = 0,
  }) {
    final l = {
      'id': _id('label'),
      'boardId': boardId,
      'name': name,
      'color': color,
      'position': position,
    };
    labels.add(l);
    _touch();
    return l;
  }

  void updateLabel(String id, {String? name, String? color}) {
    final i = labels.indexWhere((l) => l['id'] == id);
    if (i < 0) return;
    if (name != null) labels[i]['name'] = name;
    if (color != null) labels[i]['color'] = color;
    _touch();
  }

  void deleteLabel(String id) {
    cardLabels.removeWhere((cl) => cl['labelId'] == id);
    labels.removeWhere((l) => l['id'] == id);
    _touch();
  }

  void addCardLabel(String cardId, String labelId) {
    if (cardLabels.any((cl) => cl['cardId'] == cardId && cl['labelId'] == labelId)) return;
    cardLabels.add({'id': _id('cl'), 'cardId': cardId, 'labelId': labelId});
    _touch();
  }

  void removeCardLabel(String cardId, String labelId) {
    cardLabels.removeWhere((cl) => cl['cardId'] == cardId && cl['labelId'] == labelId);
    _touch();
  }

  // ——— Tasks ———
  Map<String, dynamic> addTask({
    required String cardId,
    required String name,
    required num position,
  }) {
    final t = {
      'id': _id('task'),
      'cardId': cardId,
      'name': name,
      'position': position,
      'isCompleted': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    tasks.add(t);
    _touch();
    return t;
  }

  void removeTask(String id) {
    tasks.removeWhere((t) => t['id'] == id);
    _touch();
  }

  void updateTask(String id, Map<String, dynamic> patch) {
    final i = tasks.indexWhere((t) => t['id'] == id);
    if (i < 0) return;
    tasks[i].addAll(patch);
    _touch();
  }

  // ——— Comments ———
  Map<String, dynamic> createComment(String cardId, String body) {
    final c = {
      'id': _id('cmt'),
      'cardId': cardId,
      'userId': localUserId,
      'text': body,
      'data': {'text': body},
      'type': 'commentCard',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    comments.add(c);
    _touch();
    return c;
  }

  void updateComment(String id, String body) {
    final i = comments.indexWhere((c) => c['id'] == id);
    if (i < 0) return;
    comments[i]['text'] = body;
    comments[i]['data'] = {'text': body};
    _touch();
  }

  void deleteComment(String id) {
    comments.removeWhere((c) => c['id'] == id);
    _touch();
  }

  List<Map<String, dynamic>> commentsFor(String cardId) =>
      comments.where((c) => c['cardId'] == cardId).toList();

  // ——— Memberships ———
  void addBoardMember(String boardId, String userId) {
    if (boardMemberships.any((m) => m['boardId'] == boardId && m['userId'] == userId)) return;
    boardMemberships.add({
      'id': _id('bm'),
      'boardId': boardId,
      'userId': userId,
      'role': 'editor',
      'canComment': true,
    });
    _touch();
  }

  void removeBoardMember(String membershipId) {
    boardMemberships.removeWhere((m) => m['id'] == membershipId);
    _touch();
  }

  void addCardMember(String cardId, String userId) {
    if (cardMemberships.any((m) => m['cardId'] == cardId && m['userId'] == userId)) return;
    cardMemberships.add({'id': _id('cm'), 'cardId': cardId, 'userId': userId});
    _touch();
  }

  void removeCardMember(String cardId, String userId) {
    cardMemberships.removeWhere((m) => m['cardId'] == cardId && m['userId'] == userId);
    _touch();
  }

  // ——— Attachments (metadata only; bytes via FileBlobs id) ———
  Map<String, dynamic> createAttachment({
    required String cardId,
    required String name,
    String? url,
    String? blobId,
  }) {
    final a = {
      'id': _id('att'),
      'cardId': cardId,
      'name': name,
      'url': url,
      'blobId': blobId,
      'creatorUserId': localUserId,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    attachments.add(a);
    _touch();
    return a;
  }

  void deleteAttachment(String id) {
    attachments.removeWhere((a) => a['id'] == id);
    _touch();
  }

  void renameAttachment(String id, String name) {
    final i = attachments.indexWhere((a) => a['id'] == id);
    if (i < 0) return;
    attachments[i]['name'] = name;
    _touch();
  }

  // ——— Custom fields (PLANKA v2 shape) ———
  Map<String, dynamic> createCustomFieldGroup({
    required String boardId,
    required String name,
    num position = 0,
  }) {
    final g = {
      'id': _id('cfg'),
      'boardId': boardId,
      'name': name,
      'position': position,
    };
    customFieldGroups.add(g);
    _touch();
    return g;
  }

  void deleteCustomFieldGroup(String id) {
    final fieldIds =
        customFields.where((f) => f['customFieldGroupId'] == id).map((f) => f['id'] as String).toList();
    for (final fid in fieldIds) {
      deleteCustomField(fid);
    }
    customFieldGroups.removeWhere((g) => g['id'] == id);
    _touch();
  }

  Map<String, dynamic> createCustomField({
    required String boardId,
    required String customFieldGroupId,
    required String name,
    required String type, // text | number | date | checkbox | dropdown
    num position = 0,
    List<String>? options,
  }) {
    final f = {
      'id': _id('cf'),
      'boardId': boardId,
      'customFieldGroupId': customFieldGroupId,
      'name': name,
      'type': type,
      'position': position,
      if (options != null) 'options': options,
    };
    customFields.add(f);
    _touch();
    return f;
  }

  void deleteCustomField(String id) {
    cardCustomFieldValues.removeWhere((v) => v['customFieldId'] == id);
    customFields.removeWhere((f) => f['id'] == id);
    _touch();
  }

  void setCardCustomFieldValue({
    required String cardId,
    required String customFieldId,
    dynamic value,
  }) {
    final i = cardCustomFieldValues
        .indexWhere((v) => v['cardId'] == cardId && v['customFieldId'] == customFieldId);
    if (value == null || (value is String && value.isEmpty)) {
      if (i >= 0) cardCustomFieldValues.removeAt(i);
    } else if (i >= 0) {
      cardCustomFieldValues[i]['value'] = value;
    } else {
      cardCustomFieldValues.add({
        'id': _id('cfv'),
        'cardId': cardId,
        'customFieldId': customFieldId,
        'value': value,
      });
    }
    _touch();
  }


  void setCardFreePos(String cardId, double dx, double dy) {
    cardFreePos[cardId] = {'dx': dx, 'dy': dy};
    _touch();
  }

  void clearCardFreePos() {
    cardFreePos.clear();
    _touch();
  }

  /// Neutral preview data for capture/screenshots only — never used as Collider default.
  /// Returns stable ids used by the standalone ?screen= bootstrap.
  Map<String, String> seedCapturePreview() {
    projects.clear();
    boards.clear();
    lists.clear();
    cards.clear();
    labels.clear();
    cardLabels.clear();
    tasks.clear();
    comments.clear();
    attachments.clear();
    cardMemberships.clear();
    boardMemberships.clear();
    customFieldGroups.clear();
    customFields.clear();
    cardCustomFieldValues.clear();
    listColors.clear();
    cardCoverColors.clear();
    archivedCardIds.clear();
    archivedListIds.clear();
    filterQuery = null;
    sortBy = null;
    snapAlign = true;
    cardFreePos.clear();
    localUserId;

    final proj = createProject('Project 1');
    final board = createBoard(projectId: proj['id'] as String, name: 'Board 1', position: 65535);
    final bid = board['id'] as String;
    final todo = createList(boardId: bid, name: 'To Do', position: 65535, color: 'lagoon-blue');
    final doing = createList(boardId: bid, name: 'Doing', position: 131070, color: 'pumpkin-orange');
    final done = createList(boardId: bid, name: 'Done', position: 196605, color: 'bright-moss');

    final c1 = createCard(listId: todo['id'] as String, boardId: bid, name: 'Draft brief', position: 65535);
    final c2 = createCard(listId: todo['id'] as String, boardId: bid, name: 'Gather refs', position: 131070);
    final c3 = createCard(listId: doing['id'] as String, boardId: bid, name: 'Design pass', position: 65535);
    final c4 = createCard(listId: done['id'] as String, boardId: bid, name: 'Kickoff notes', position: 65535);

    void setCard(String id, {String? description, String? dueDate}) {
      final i = cards.indexWhere((c) => c['id'] == id);
      if (i < 0) return;
      if (description != null) cards[i]['description'] = description;
      if (dueDate != null) cards[i]['dueDate'] = dueDate;
    }

    setCard(c1['id'] as String, description: 'Outline the first pass.', dueDate: '2026-11-05');
    setCard(c2['id'] as String, dueDate: '2026-11-08');
    setCard(c3['id'] as String, description: 'In progress.', dueDate: '2026-11-03');
    setCard(c4['id'] as String, dueDate: '2026-10-28');

    final labDesign = createLabel(boardId: bid, name: 'Design', color: 'berry-red', position: 1);
    final labRush = createLabel(boardId: bid, name: 'Rush', color: 'orange-peel', position: 2);
    final labShip = createLabel(boardId: bid, name: 'Ship', color: 'lagune-blue', position: 3);
    addCardLabel(c1['id'] as String, labDesign['id'] as String);
    addCardLabel(c3['id'] as String, labRush['id'] as String);
    addCardLabel(c3['id'] as String, labShip['id'] as String);

    setCardCoverColor(c3['id'] as String, 0xFF72B3C6);

    final grp = createCustomFieldGroup(boardId: bid, name: 'Details');
    final fStatus = createCustomField(
      boardId: bid,
      customFieldGroupId: grp['id'] as String,
      name: 'Status',
      type: 'dropdown',
      position: 1,
      options: const ['Open', 'Blocked', 'Done'],
    );
    final fPts = createCustomField(
      boardId: bid,
      customFieldGroupId: grp['id'] as String,
      name: 'Points',
      type: 'number',
      position: 2,
    );
    setCardCustomFieldValue(cardId: c1['id'] as String, customFieldId: fStatus['id'] as String, value: 'Open');
    setCardCustomFieldValue(cardId: c1['id'] as String, customFieldId: fPts['id'] as String, value: 3);
    setCardCustomFieldValue(cardId: c3['id'] as String, customFieldId: fStatus['id'] as String, value: 'Blocked');

    notifyListeners();
    return {
      'projectId': proj['id'] as String,
      'boardId': bid,
      'cardId': c1['id'] as String,
      'cardTintId': c3['id'] as String,
      'listTodoId': todo['id'] as String,
      'listDoingId': doing['id'] as String,
      'listDoneId': done['id'] as String,
    };
  }

  // ——— Search ———
  List<Map<String, dynamic>> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <Map<String, dynamic>>[];
    for (final b in boards) {
      if ('${b['name']}'.toLowerCase().contains(q)) {
        hits.add({'kind': 'board', ...b});
      }
    }
    for (final c in cards) {
      if (archivedCardIds.contains(c['id'])) continue;
      final hay = '${c['name']} ${c['description'] ?? ''}'.toLowerCase();
      if (hay.contains(q)) hits.add({'kind': 'card', ...c});
    }
    for (final v in cardCustomFieldValues) {
      if ('${v['value']}'.toLowerCase().contains(q)) {
        final card = cards.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c?['id'] == v['cardId'],
              orElse: () => null,
            );
        if (card != null) hits.add({'kind': 'field', ...card, 'fieldValue': v['value']});
      }
    }
    return hits;
  }
}
