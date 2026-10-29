import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/files/file_blobs.dart';

/// Smart Gen data, ported from the trello-clone schema (Board, List, Card,
/// Label, guests, stars, background) plus the binding ledger (card types,
/// typed fields, canvases, triggers, embeds). One card set, many surfaces.

enum SgType { artifact, task, reminder, project, journal, note, listItem, feature, job, poster, segment, memory }

enum SgSurface {
  kanban,
  calendar,
  notebook,
  album,
  storyboard,
  vision,
  swimlane,
  portfolio,
  usMap,
  worldMap,
  files,
  corkboard,
  clipboard,
  ledger,
  desk,
  binder,
  slate,
  whiteboard,
  canvas,
}

/// David's clone `FieldTypeEnum` / `FIELD_TYPES`.
enum SgFieldKind { text, textarea, richtext, number, date, datetime, checkbox, select, multi, person, url, file }

/// David's clone `BoardKindEnum`.
enum SgBoardKind { notebook, portfolio, corkboard, clipboard, ledger, desk, binder, slate }

/// David's clone `HoldKindEnum`.
enum SgHoldKind { tray, shelf, table, wall, spread, rack }

SgFieldKind sgFieldKind(Object? raw) {
  return switch (raw) {
    'string' || 'text' => SgFieldKind.text,
    'boolean' => SgFieldKind.checkbox,
    'time' => SgFieldKind.datetime,
    final String name => SgFieldKind.values.asNameMap()[name] ?? SgFieldKind.text,
    _ => SgFieldKind.text,
  };
}

enum SgStatusKind { dropdown, toggle, input, color }

enum SgComponentKind { card, canvas, board }

extension SgTypeX on SgType {
  String get label => switch (this) {
        SgType.artifact => 'Artifact',
        SgType.task => 'Task',
        SgType.reminder => 'Reminder',
        SgType.project => 'Project',
        SgType.journal => 'Journal entry',
        SgType.note => 'Note',
        SgType.listItem => 'List',
        SgType.feature => 'Feature',
        SgType.job => 'Job',
        SgType.poster => 'Poster',
        SgType.segment => 'Segment',
        SgType.memory => 'Memory',
      };

  int get argb => switch (this) {
        SgType.artifact => 0xFF7C6A9A,
        SgType.task => 0xFF3D7A6A,
        SgType.reminder => 0xFFB86B4A,
        SgType.project => 0xFF3E6EA8,
        SgType.journal => 0xFF8A6A4A,
        SgType.note => 0xFFC4A15A,
        SgType.listItem => 0xFF5C7A4A,
        SgType.feature => 0xFF4A7A8A,
        SgType.job => 0xFF6A4A3A,
        SgType.poster => 0xFF8A4A6A,
        SgType.segment => 0xFF4A5A8A,
        SgType.memory => 0xFF6A5A8A,
      };
}

extension SgSurfaceX on SgSurface {
  String get label => switch (this) {
        SgSurface.kanban => 'Kanban',
        SgSurface.calendar => 'Calendar',
        SgSurface.notebook => 'Notebook',
        SgSurface.album => 'Photo album',
        SgSurface.storyboard => 'Storyboard',
        SgSurface.vision => 'Vision board',
        SgSurface.swimlane => 'Swimlane',
        SgSurface.portfolio => 'Portfolio desk',
        SgSurface.usMap => 'US map',
        SgSurface.worldMap => 'World map',
        SgSurface.files => 'Files',
        SgSurface.corkboard => 'Corkboard',
        SgSurface.clipboard => 'Clipboard',
        SgSurface.ledger => 'Ledger',
        SgSurface.desk => 'Desk',
        SgSurface.binder => 'Binder',
        SgSurface.slate => 'Slate',
        SgSurface.whiteboard => 'Whiteboard',
        SgSurface.canvas => 'Canvas',
      };
}

extension SgFieldKindX on SgFieldKind {
  String get label => name;
}

const List<(String, String)> kUsStates = [
  ('Alabama', 'Montgomery'),
  ('Alaska', 'Juneau'),
  ('Arizona', 'Phoenix'),
  ('Arkansas', 'Little Rock'),
  ('California', 'Sacramento'),
  ('Colorado', 'Denver'),
  ('Connecticut', 'Hartford'),
  ('Delaware', 'Dover'),
  ('Florida', 'Tallahassee'),
  ('Georgia', 'Atlanta'),
  ('Hawaii', 'Honolulu'),
  ('Idaho', 'Boise'),
  ('Illinois', 'Springfield'),
  ('Indiana', 'Indianapolis'),
  ('Iowa', 'Des Moines'),
  ('Kansas', 'Topeka'),
  ('Kentucky', 'Frankfort'),
  ('Louisiana', 'Baton Rouge'),
  ('Maine', 'Augusta'),
  ('Maryland', 'Annapolis'),
  ('Massachusetts', 'Boston'),
  ('Michigan', 'Lansing'),
  ('Minnesota', 'Saint Paul'),
  ('Mississippi', 'Jackson'),
  ('Missouri', 'Jefferson City'),
  ('Montana', 'Helena'),
  ('Nebraska', 'Lincoln'),
  ('Nevada', 'Carson City'),
  ('New Hampshire', 'Concord'),
  ('New Jersey', 'Trenton'),
  ('New Mexico', 'Santa Fe'),
  ('New York', 'Albany'),
  ('North Carolina', 'Raleigh'),
  ('North Dakota', 'Bismarck'),
  ('Ohio', 'Columbus'),
  ('Oklahoma', 'Oklahoma City'),
  ('Oregon', 'Salem'),
  ('Pennsylvania', 'Harrisburg'),
  ('Rhode Island', 'Providence'),
  ('South Carolina', 'Columbia'),
  ('South Dakota', 'Pierre'),
  ('Tennessee', 'Nashville'),
  ('Texas', 'Austin'),
  ('Utah', 'Salt Lake City'),
  ('Vermont', 'Montpelier'),
  ('Virginia', 'Richmond'),
  ('Washington', 'Olympia'),
  ('West Virginia', 'Charleston'),
  ('Wisconsin', 'Madison'),
  ('Wyoming', 'Cheyenne'),
];

const List<String> kWorldCountries = [
  'United States',
  'Canada',
  'Mexico',
  'Brazil',
  'United Kingdom',
  'France',
  'Germany',
  'Italy',
  'Spain',
  'Sweden',
  'Egypt',
  'Nigeria',
  'South Africa',
  'India',
  'China',
  'Japan',
  'South Korea',
  'Australia',
  'New Zealand',
  'Argentina',
];

/// A 10×10 red PNG so album and vision cards have a real cover without a network.
const String kSeedPng = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6oAAAAAElFTkSuQmCC';

class SgLabel {
  SgLabel({required this.id, required this.title, required this.color});
  final String id;
  String title;
  int color;
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'color': color};
  static SgLabel fromJson(Map<String, Object?> j) => SgLabel(id: j['id']! as String, title: j['title'] as String? ?? '', color: (j['color'] as num?)?.toInt() ?? 0xFF3D7A6A);
}

class SgList {
  SgList({required this.id, required this.title, required this.position});
  final String id;
  String title;
  int position;
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'position': position};
  static SgList fromJson(Map<String, Object?> j) => SgList(id: j['id']! as String, title: j['title'] as String? ?? '', position: (j['position'] as num?)?.toInt() ?? 0);
}

class SgFieldDef {
  SgFieldDef({required this.id, required this.name, required this.kind});
  final String id;
  String name;
  SgFieldKind kind;
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'kind': kind.name};
  static SgFieldDef fromJson(Map<String, Object?> j) => SgFieldDef(
        id: j['id']! as String,
        name: j['name'] as String? ?? '',
        kind: sgFieldKind(j['kind']),
      );
}

class SgCheck {
  SgCheck({required this.id, required this.text, this.done = false});
  final String id;
  String text;
  bool done;
  Map<String, Object?> toJson() => {'id': id, 'text': text, 'done': done};
  static SgCheck fromJson(Map<String, Object?> j) => SgCheck(id: j['id']! as String, text: j['text'] as String? ?? '', done: j['done'] == true);
}

class SgFile {
  SgFile({required this.id, required this.name, required this.dataUrl, this.cardId = ''});
  final String id;
  String name;
  String dataUrl;
  String cardId;
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'data': dataUrl, 'card': cardId};
  static SgFile fromJson(Map<String, Object?> j) => SgFile(id: j['id']! as String, name: j['name'] as String? ?? 'file', dataUrl: j['data'] as String? ?? '', cardId: j['card'] as String? ?? '');
}

class SgActivity {
  SgActivity({required this.at, required this.text});
  final int at;
  final String text;
  Map<String, Object?> toJson() => {'at': at, 'text': text};
  static SgActivity fromJson(Map<String, Object?> j) => SgActivity(at: (j['at'] as num?)?.toInt() ?? 0, text: j['text'] as String? ?? '');
}

class SgCard {
  SgCard({
    required this.id,
    required this.title,
    this.description = '',
    this.type = SgType.task,
    this.color = 0xFF3D7A6A,
    required this.listId,
    this.status = 'To Do',
    this.assignee = '',
    this.dueMs,
    this.priority = 0,
    this.urgent = false,
    List<String>? tags,
    this.hiddenNotes = '',
    Set<String>? hiddenKeys,
    List<String>? labelIds,
    List<SgFile>? files,
    Map<String, String>? custom,
    List<String>? embeds,
    this.notebook = '',
    this.triggers = '',
    this.company = '',
    this.positionTitle = '',
    this.jobStart = '',
    this.jobEnd = '',
    this.responsibilities = '',
    this.achievements = '',
    List<SgCheck>? checks,
    List<String>? members,
    List<SgActivity>? activity,
    this.inherit = true,
    this.rank = 0,
    this.canvasId = '',
    this.dx = 12,
    this.dy = 12,
  })  : tags = tags ?? [],
        hiddenKeys = hiddenKeys ?? {},
        labelIds = labelIds ?? [],
        files = files ?? [],
        custom = custom ?? {},
        embeds = embeds ?? [],
        checks = checks ?? [],
        members = members ?? [],
        activity = activity ?? [];

  final String id;
  String title;
  String description;
  SgType type;
  int color;
  String listId;
  String status;
  String assignee;
  int? dueMs;
  int priority;
  bool urgent;
  final List<String> tags;
  String hiddenNotes;
  final Set<String> hiddenKeys;
  final List<String> labelIds;
  final List<SgFile> files;
  final Map<String, String> custom;
  final List<String> embeds;
  String notebook;
  String triggers;
  String company;
  String positionTitle;
  String jobStart;
  String jobEnd;
  String responsibilities;
  String achievements;
  final List<SgCheck> checks;
  final List<String> members;
  final List<SgActivity> activity;
  bool inherit;
  double rank;
  String canvasId;
  double dx;
  double dy;

  bool get hasHidden => hiddenNotes.isNotEmpty || hiddenKeys.isNotEmpty;
  List<String> get pages => notebook.split('---').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  bool matchesPlace(String name) {
    final h = '${title.toLowerCase()} ${tags.join(' ').toLowerCase()} ${description.toLowerCase()}';
    return h.contains(name.toLowerCase());
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'color': color,
        'listId': listId,
        'status': status,
        'assignee': assignee,
        'due': dueMs,
        'priority': priority,
        'urgent': urgent,
        'tags': tags,
        'hidden': hiddenNotes,
        'hiddenKeys': hiddenKeys.toList(),
        'labels': labelIds,
        'files': [for (final f in files) f.toJson()],
        'custom': custom,
        'embeds': embeds,
        'notebook': notebook,
        'triggers': triggers,
        'company': company,
        'positionTitle': positionTitle,
        'jobStart': jobStart,
        'jobEnd': jobEnd,
        'responsibilities': responsibilities,
        'achievements': achievements,
        'checks': [for (final c in checks) c.toJson()],
        'members': members,
        'activity': [for (final a in activity) a.toJson()],
        'inherit': inherit,
        'rank': rank,
        'canvasId': canvasId,
        'dx': dx,
        'dy': dy,
      };

  static SgCard fromJson(Map<String, Object?> j) => SgCard(
        id: j['id']! as String,
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        type: SgType.values.asNameMap()[j['type']] ?? SgType.task,
        color: (j['color'] as num?)?.toInt() ?? 0xFF3D7A6A,
        listId: j['listId'] as String? ?? '',
        status: j['status'] as String? ?? '',
        assignee: j['assignee'] as String? ?? '',
        dueMs: (j['due'] as num?)?.toInt(),
        priority: (j['priority'] as num?)?.toInt() ?? 0,
        urgent: j['urgent'] == true,
        tags: [for (final t in (j['tags'] as List?) ?? const []) t.toString()],
        hiddenNotes: j['hidden'] as String? ?? '',
        hiddenKeys: {for (final t in (j['hiddenKeys'] as List?) ?? const []) t.toString()},
        labelIds: [for (final t in (j['labels'] as List?) ?? const []) t.toString()],
        files: [for (final f in (j['files'] as List?) ?? const []) if (f is Map) SgFile.fromJson(f.cast<String, Object?>())],
        custom: {for (final e in ((j['custom'] as Map?) ?? const {}).entries) e.key.toString(): e.value.toString()},
        embeds: [for (final t in (j['embeds'] as List?) ?? const []) t.toString()],
        notebook: j['notebook'] as String? ?? '',
        triggers: j['triggers'] as String? ?? '',
        company: j['company'] as String? ?? '',
        positionTitle: j['positionTitle'] as String? ?? '',
        jobStart: j['jobStart'] as String? ?? '',
        jobEnd: j['jobEnd'] as String? ?? '',
        responsibilities: j['responsibilities'] as String? ?? '',
        achievements: j['achievements'] as String? ?? '',
        checks: [for (final c in (j['checks'] as List?) ?? const []) if (c is Map) SgCheck.fromJson(c.cast<String, Object?>())],
        members: [for (final t in (j['members'] as List?) ?? const []) t.toString()],
        activity: [for (final a in (j['activity'] as List?) ?? const []) if (a is Map) SgActivity.fromJson(a.cast<String, Object?>())],
        inherit: j['inherit'] != false,
        rank: (j['rank'] as num?)?.toDouble() ?? 0,
        canvasId: j['canvasId'] as String? ?? '',
        dx: (j['dx'] as num?)?.toDouble() ?? 12,
        dy: (j['dy'] as num?)?.toDouble() ?? 12,
      );
}

class SgCanvas {
  SgCanvas({required this.id, required this.name, this.kind = 'Glass', this.color = 0xFF2F6FED, this.hold = SgHoldKind.tray});
  final String id;
  String name;
  String kind;
  int color;
  SgHoldKind hold;
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'kind': kind, 'color': color, 'hold': hold.name};
  static SgCanvas fromJson(Map<String, Object?> j) => SgCanvas(
        id: j['id']! as String,
        name: j['name'] as String? ?? 'Canvas',
        kind: j['kind'] as String? ?? 'Glass',
        color: (j['color'] as num?)?.toInt() ?? 0xFF2F6FED,
        hold: SgHoldKind.values.asNameMap()[j['hold']] ?? SgHoldKind.tray,
      );
}

class SgBoard {
  SgBoard({
    required this.id,
    required this.name,
    this.starred = false,
    this.background = 0x66302824,
    this.surface = SgSurface.kanban,
    this.statusKind = SgStatusKind.dropdown,
    this.autoArrange = false,
    this.autoSort = false,
    this.autoFilterComplete = false,
    this.inheritColumnStatus = true,
    this.urgentAutoCalendar = true,
    this.kind = SgBoardKind.notebook,
    List<String>? guests,
    List<SgList>? lists,
    List<SgLabel>? labels,
    List<SgCard>? cards,
    List<SgCanvas>? canvases,
    List<SgFieldDef>? fields,
    List<String>? statuses,
    List<String>? typeNames,
    this.canvasIndex = 0,
  })  : guests = guests ?? [],
        lists = lists ?? [],
        labels = labels ?? [],
        cards = cards ?? [],
        canvases = canvases ?? [],
        fields = fields ?? [],
        statuses = statuses ?? [],
        typeNames = typeNames ?? [for (final t in SgType.values) t.label];

  final String id;
  String name;
  bool starred;
  int background;
  SgSurface surface;
  SgStatusKind statusKind;
  bool autoArrange;
  bool autoSort;
  bool autoFilterComplete;
  bool inheritColumnStatus;
  bool urgentAutoCalendar;
  SgBoardKind kind;
  final List<String> guests;
  final List<SgList> lists;
  final List<SgLabel> labels;
  final List<SgCard> cards;
  final List<SgCanvas> canvases;
  final List<SgFieldDef> fields;
  final List<String> statuses;
  final List<String> typeNames;
  int canvasIndex;

  List<SgList> get orderedLists {
    final copy = [...lists]..sort((a, b) => a.position.compareTo(b.position));
    return copy;
  }

  List<SgCard> cardsIn(String listId) {
    final copy = cards.where((c) => c.listId == listId).toList()..sort((a, b) => a.rank.compareTo(b.rank));
    if (autoFilterComplete) {
      final last = orderedLists.isEmpty ? '' : orderedLists.last.title;
      copy.removeWhere((c) => c.status == last && last.isNotEmpty);
    }
    if (autoSort) {
      copy.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return copy;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'starred': starred,
        'background': background,
        'surface': surface.name,
        'statusKind': statusKind.name,
        'autoArrange': autoArrange,
        'autoSort': autoSort,
        'autoFilterComplete': autoFilterComplete,
        'inheritColumnStatus': inheritColumnStatus,
        'urgentAutoCalendar': urgentAutoCalendar,
        'kind': kind.name,
        'guests': guests,
        'lists': [for (final l in lists) l.toJson()],
        'labels': [for (final l in labels) l.toJson()],
        'cards': [for (final c in cards) c.toJson()],
        'canvases': [for (final c in canvases) c.toJson()],
        'fields': [for (final f in fields) f.toJson()],
        'statuses': statuses,
        'typeNames': typeNames,
        'canvasIndex': canvasIndex,
      };

  static SgBoard fromJson(Map<String, Object?> j) => SgBoard(
        id: j['id']! as String,
        name: j['name'] as String? ?? 'Board',
        starred: j['starred'] == true,
        background: (j['background'] as num?)?.toInt() ?? 0x66302824,
        surface: SgSurface.values.asNameMap()[j['surface']] ?? SgSurface.kanban,
        statusKind: SgStatusKind.values.asNameMap()[j['statusKind']] ?? SgStatusKind.dropdown,
        autoArrange: j['autoArrange'] == true,
        autoSort: j['autoSort'] == true,
        autoFilterComplete: j['autoFilterComplete'] == true,
        inheritColumnStatus: j['inheritColumnStatus'] != false,
        urgentAutoCalendar: j['urgentAutoCalendar'] != false,
        kind: SgBoardKind.values.asNameMap()[j['kind']] ?? SgBoardKind.notebook,
        guests: [for (final g in (j['guests'] as List?) ?? const []) g.toString()],
        lists: [for (final l in (j['lists'] as List?) ?? const []) if (l is Map) SgList.fromJson(l.cast<String, Object?>())],
        labels: [for (final l in (j['labels'] as List?) ?? const []) if (l is Map) SgLabel.fromJson(l.cast<String, Object?>())],
        cards: [for (final c in (j['cards'] as List?) ?? const []) if (c is Map) SgCard.fromJson(c.cast<String, Object?>())],
        canvases: [for (final c in (j['canvases'] as List?) ?? const []) if (c is Map) SgCanvas.fromJson(c.cast<String, Object?>())],
        fields: [for (final f in (j['fields'] as List?) ?? const []) if (f is Map) SgFieldDef.fromJson(f.cast<String, Object?>())],
        statuses: [for (final s in (j['statuses'] as List?) ?? const []) s.toString()],
        typeNames: [for (final s in (j['typeNames'] as List?) ?? const []) s.toString()],
        canvasIndex: (j['canvasIndex'] as num?)?.toInt() ?? 0,
      );
}

class SgMessage {
  SgMessage({required this.role, required this.text, this.attachment = ''});
  final String role;
  final String text;
  final String attachment;
  Map<String, Object?> toJson() => {'role': role, 'text': text, 'attachment': attachment};
  static SgMessage fromJson(Map<String, Object?> j) => SgMessage(role: j['role'] as String? ?? 'genie', text: j['text'] as String? ?? '', attachment: j['attachment'] as String? ?? '');
}

/// Local engine behind [callAiApi]. No provider credentials are configured,
/// so this never pretends a model answered.
String callAiApi(String prompt, {required int cards, required int columns}) {
  return 'callAiApi is wired and was not called. No provider credentials are configured. Local reading of $cards cards across $columns lists: $prompt';
}

class SgStore extends ChangeNotifier {
  SgStore();
  static final SgStore instance = SgStore();
  static const int maxCards = 999;
  static const int maxCanvases = 10;
  static const String _blobId = 'smartgen/boards.json';

  /// All boards. Smart Gen opens empty — no seed boards or cards.
  final List<SgBoard> boards = [];
  String? activeBoardId;
  final List<SgMessage> genie = [];
  final List<String> _undo = [];
  final List<String> _redo = [];
  String notice = '';
  bool loaded = false;
  bool atHome = true;
  int _seq = 0;

  SgBoard? get board {
    final id = activeBoardId;
    if (id == null) return null;
    for (final b in boards) {
      if (b.id == id) return b;
    }
    return null;
  }

  set board(SgBoard? value) {
    if (value == null) {
      activeBoardId = null;
      return;
    }
    final i = boards.indexWhere((b) => b.id == value.id);
    if (i >= 0) {
      boards[i] = value;
    } else {
      boards.add(value);
    }
    activeBoardId = value.id;
  }

  int get cardCount => board?.cards.length ?? 0;

  String _id(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}${_seq++}';

  void debugReset() {
    boards.clear();
    activeBoardId = null;
    genie.clear();
    _undo.clear();
    _redo.clear();
    notice = '';
    loaded = false;
    atHome = true;
    // Wipe persisted blob so a fresh capture/session cannot revive seed or prior boards.
    FileBlobs.put(_blobId, Uint8List(0));
  }

  Future<void> init() async {
    if (loaded) return;
    try {
      final raw = await FileBlobs.get(_blobId);
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(utf8.decode(raw));
        if (j is Map) {
          final list = j['boards'];
          if (list is List) {
            boards
              ..clear()
              ..addAll([
                for (final b in list)
                  if (b is Map) SgBoard.fromJson(b.cast<String, Object?>())
              ]);
          } else if (j['board'] is Map) {
            // Migrate single-board blob from v9.1.8.
            boards
              ..clear()
              ..add(SgBoard.fromJson((j['board'] as Map).cast<String, Object?>()));
          }
          activeBoardId = j['activeBoardId'] as String?;
          if (activeBoardId != null && board == null && boards.isNotEmpty) {
            activeBoardId = boards.first.id;
          }
          atHome = j['atHome'] == true || activeBoardId == null;
          final g = j['genie'];
          if (g is List) {
            genie
              ..clear()
              ..addAll([for (final m in g) if (m is Map) SgMessage.fromJson(m.cast<String, Object?>())]);
          }
        }
      }
    } catch (e) {
      debugPrint('SgStore: ignored unreadable board: $e');
    }
    // Never invent seed content. Empty is correct.
    loaded = true;
    notifyListeners();
  }

  /// Test helper: open one empty board with the three default lists.
  void ensureStarter() {
    if (boards.isEmpty) {
      createBoard('Board', goHome: false);
    } else {
      activeBoardId ??= boards.first.id;
      atHome = false;
    }
    loaded = true;
  }

  /// A new board always starts with To Do / Doing / Done and no cards.
  SgBoard createBoard(String name, {bool goHome = false}) {
    final todo = SgList(id: _id('l'), title: 'To Do', position: 0);
    final doing = SgList(id: _id('l'), title: 'Doing', position: 1);
    final done = SgList(id: _id('l'), title: 'Done', position: 2);
    final b = SgBoard(
      id: _id('b'),
      name: name.trim().isEmpty ? 'Board' : name.trim(),
      lists: [todo, doing, done],
      statuses: const ['To Do', 'Doing', 'Done'],
    );
    boards.add(b);
    activeBoardId = b.id;
    atHome = goHome;
    loaded = true;
    _commit();
    return b;
  }

  void openBoard(String id) {
    if (boards.any((b) => b.id == id)) {
      activeBoardId = id;
      atHome = false;
      notifyListeners();
      _commit();
    }
  }

  void goHome() {
    atHome = true;
    notifyListeners();
    _commit();
  }

  void deleteBoard(String id) {
    _checkpoint();
    boards.removeWhere((b) => b.id == id);
    if (activeBoardId == id) {
      activeBoardId = boards.isEmpty ? null : boards.first.id;
      atHome = true;
    }
    _commit();
  }

  String _snap() => jsonEncode({
        'boards': [for (final b in boards) b.toJson()],
        'activeBoardId': activeBoardId,
        'atHome': atHome,
        'genie': [for (final m in genie) m.toJson()],
      });

  void _checkpoint() {
    _undo.add(_snap());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> _commit() async {
    notifyListeners();
    try {
      final doc = utf8.encode(_snap());
      await FileBlobs.put(_blobId, Uint8List.fromList(doc));
    } catch (_) {
      // Tests and platforms without a path_provider channel still keep state in memory.
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snap());
    _restore(jsonDecode(_undo.removeLast()));
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snap());
    _restore(jsonDecode(_redo.removeLast()));
    notifyListeners();
  }

  void _restore(Object? raw) {
    if (raw is! Map) return;
    final j = raw.cast<String, Object?>();
    boards.clear();
    final list = j['boards'];
    if (list is List) {
      boards.addAll([for (final b in list) if (b is Map) SgBoard.fromJson(b.cast<String, Object?>())]);
    } else if (j['board'] is Map) {
      boards.add(SgBoard.fromJson((j['board'] as Map).cast<String, Object?>()));
    }
    activeBoardId = j['activeBoardId'] as String?;
    atHome = j['atHome'] == true || activeBoardId == null;
    genie
      ..clear()
      ..addAll([for (final m in (j['genie'] as List?) ?? const []) if (m is Map) SgMessage.fromJson(m.cast<String, Object?>())]);
  }

  void setNotice(String text) {
    notice = text;
    notifyListeners();
  }

  SgCard? byId(String? id) {
    if (id == null || board == null) return null;
    for (final c in board!.cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  SgCard? addCard(SgType type) {
    final b = board;
    if (b == null || b.lists.isEmpty) return null;
    if (b.cards.length >= maxCards) {
      notice = '999 cards is the limit.';
      notifyListeners();
      return null;
    }
    _checkpoint();
    final list = b.orderedLists.first;
    final ranks = b.cardsIn(list.id).map((c) => c.rank);
    final top = ranks.isEmpty ? 0.0 : ranks.reduce((a, r) => a < r ? a : r) - 1;
    final c = SgCard(
      id: _id('c'),
      title: type.label,
      type: type,
      color: type.argb,
      listId: list.id,
      status: list.title,
      rank: top,
    );
    c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: 'Card added'));
    b.cards.insert(0, c);
    notice = '';
    _commit();
    return c;
  }

  void moveCard(String id, String listId, {int? beforeIndex}) {
    final b = board;
    final c = byId(id);
    if (b == null || c == null) return;
    _checkpoint();
    final dest = b.lists.where((l) => l.id == listId).firstOrNull;
    c.listId = listId;
    if (b.inheritColumnStatus && c.inherit && dest != null) c.status = dest.title;
    final mates = b.cardsIn(listId).where((x) => x.id != id).toList();
    final index = beforeIndex == null ? mates.length : beforeIndex.clamp(0, mates.length);
    mates.insert(index, c);
    for (var i = 0; i < mates.length; i++) {
      mates[i].rank = i.toDouble();
    }
    c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: 'Moved to ${dest?.title ?? listId}'));
    _commit();
  }

  void edit(SgCard c) {
    c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: 'Edited'));
    _commit();
  }

  void touch(void Function() change) {
    _checkpoint();
    change();
    _commit();
  }

  void removeCards(Iterable<String> ids) {
    final b = board;
    if (b == null) return;
    _checkpoint();
    final set = ids.toSet();
    b.cards.removeWhere((c) => set.contains(c.id));
    for (final c in b.cards) {
      c.embeds.removeWhere(set.contains);
    }
    _commit();
  }

  bool addCanvas(String name, String kind) {
    final b = board;
    if (b == null) return false;
    if (b.canvases.length >= maxCanvases) {
      notice = '10 canvases is the limit on this board.';
      notifyListeners();
      return false;
    }
    _checkpoint();
    b.canvases.add(SgCanvas(id: _id('v'), name: name, kind: kind));
    b.canvasIndex = b.canvases.length - 1;
    notice = '';
    _commit();
    return true;
  }

  void addList(String title) {
    final b = board;
    if (b == null) return;
    _checkpoint();
    final name = title.trim().isEmpty ? 'List' : title.trim();
    b.lists.add(SgList(id: _id('l'), title: name, position: b.lists.length));
    if (!b.statuses.contains(name)) b.statuses.add(name);
    _commit();
  }

  void addStatus(String name) {
    final b = board;
    if (b == null) return;
    final t = name.trim();
    if (t.isEmpty || b.statuses.contains(t)) return;
    _checkpoint();
    b.statuses.add(t);
    addList(t);
  }

  void addField(String name, SgFieldKind kind) {
    final b = board;
    if (b == null) return;
    _checkpoint();
    b.fields.add(SgFieldDef(id: _id('fd'), name: name.trim().isEmpty ? 'Field' : name.trim(), kind: kind));
    _commit();
  }

  /// Hourly trigger: a card flagged `hourly` walks to the next status.
  int applyHourly() {
    final b = board;
    if (b == null) return 0;
    var n = 0;
    for (final c in b.cards) {
      if (!c.triggers.split(',').map((s) => s.trim()).contains('hourly')) continue;
      final i = b.statuses.indexOf(c.status);
      if (i < 0 || i >= b.statuses.length - 1) continue;
      c.status = b.statuses[i + 1];
      final lists = b.orderedLists;
      if (i + 1 < lists.length) c.listId = lists[i + 1].id;
      c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: 'Moved to ${c.status}'));
      n++;
    }
    if (n > 0) _commit();
    return n;
  }

  /// Mark-done trigger: status becomes the final column.
  void markDone(SgCard c) {
    final b = board;
    if (b == null) return;
    _checkpoint();
    if (c.triggers.split(',').map((s) => s.trim()).contains('done-final') && b.statuses.isNotEmpty) {
      c.status = b.statuses.last;
      final lists = b.orderedLists;
      if (lists.isNotEmpty) c.listId = lists.last.id;
    } else if (b.statuses.isNotEmpty) {
      c.status = b.statuses.last;
    }
    c.activity.add(SgActivity(at: DateTime.now().millisecondsSinceEpoch, text: 'Marked done'));
    _commit();
  }

  /// Local Genie. Mass edits and type refactors run here. [callAiApi] is not
  /// invoked, because no provider key is configured.
  String askGenie(String prompt, {String attachment = ''}) {
    final b = board;
    genie.add(SgMessage(role: 'you', text: prompt, attachment: attachment));
    final text = prompt.trim();
    final lower = text.toLowerCase();
    String reply;
    final setAll = RegExp(r'^set all (\w+) to (.+)$', caseSensitive: false).firstMatch(text);
    final refactor = RegExp(r'^refactor (\w+) as (\w+)$', caseSensitive: false).firstMatch(text);
    if (b == null) {
      reply = 'No board is open.';
    } else if (setAll != null) {
      final field = setAll.group(1)!.toLowerCase();
      final value = setAll.group(2)!.trim();
      _checkpoint();
      for (final c in b.cards) {
        switch (field) {
          case 'priority':
            c.priority = int.tryParse(value) ?? (value.toLowerCase() == 'high' ? 3 : 1);
          case 'urgent':
            c.urgent = value.toLowerCase() == 'true' || value == '1';
          case 'status':
            c.status = value;
          case 'assignee':
            c.assignee = value;
          default:
            c.custom[field] = value;
        }
      }
      reply = 'Set $field to $value on ${b.cards.length} cards.';
      _commit();
    } else if (refactor != null) {
      final from = SgType.values.asNameMap()[refactor.group(1)!.toLowerCase()];
      final to = SgType.values.asNameMap()[refactor.group(2)!.toLowerCase()];
      if (from == null || to == null) {
        reply = 'Name two card types, for example: refactor task as note.';
      } else {
        _checkpoint();
        var n = 0;
        for (final c in b.cards.where((c) => c.type == from)) {
          if (c.color == from.argb) c.color = to.argb;
          c.type = to;
          n++;
        }
        reply = 'Refactored $n ${from.label} cards as ${to.label}.';
        _commit();
      }
    } else if (lower == 'new conversation') {
      genie.clear();
      reply = 'Started a new conversation.';
      genie.add(SgMessage(role: 'genie', text: reply));
      _commit();
      return reply;
    } else {
      reply = callAiApi(text, cards: b.cards.length, columns: b.lists.length);
    }
    genie.add(SgMessage(role: 'genie', text: reply, attachment: attachment));
    _commit();
    return reply;
  }

  void newConversation() {
    genie.clear();
    _commit();
  }

  List<SgCard> search(String q) {
    final b = board;
    if (b == null) return const [];
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return const [];
    return [
      for (final c in b.cards)
        if ('${c.title} ${c.description} ${c.tags.join(' ')} ${c.assignee} ${c.company}'.toLowerCase().contains(s)) c,
    ];
  }
}

/// David's clone `HOOK_TRIGGERS` / `HOOK_ACTIONS` and `runHooks`.
enum SgHookTrigger { fieldChange, listEnter, listLeave, cardCreate, typeReparent }

enum SgHookAction { setField, moveToList, addLabel, createCard }

class SgHook {
  SgHook({required this.id, required this.name, this.enabled = true, required this.trigger, this.fieldKey, this.equals, this.listId, this.typeId, required this.action, this.thenField, this.thenValue, this.thenList, this.thenLabel, this.thenTitle});
  final String id;
  final String name;
  final bool enabled;
  final SgHookTrigger trigger;
  final String? fieldKey;
  final String? equals;
  final String? listId;
  final String? typeId;
  final SgHookAction action;
  final String? thenField;
  final String? thenValue;
  final String? thenList;
  final String? thenLabel;
  final String? thenTitle;
}

class SgHookEvent {
  SgHookEvent({required this.trigger, required this.cardId, this.fieldKey, this.value, this.listId, this.typeId});
  final SgHookTrigger trigger;
  final String cardId;
  final String? fieldKey;
  final Object? value;
  final String? listId;
  final String? typeId;
}

class SgHookMutations {
  SgHookMutations({required this.setField, required this.moveToList, required this.addLabel, required this.createCard});
  final void Function(String cardId, String fieldKey, String value) setField;
  final void Function(String cardId, String listId) moveToList;
  final void Function(String cardId, String labelId) addLabel;
  final void Function(String listId, String title) createCard;
}

const List<String> kFieldTypes = ['text', 'textarea', 'richtext', 'number', 'date', 'datetime', 'checkbox', 'select', 'multi', 'person', 'url', 'file'];

final List<SgHook> kDefaultHooks = [
  SgHook(id: 'h-done', name: 'Done', trigger: SgHookTrigger.fieldChange, fieldKey: 'done', equals: 'true', action: SgHookAction.setField, thenField: 'status', thenValue: 'done'),
];

void runHooks(List<SgHook> hooks, SgHookEvent event, SgHookMutations mut) {
  for (final hook in hooks) {
    if (!hook.enabled) continue;
    if (hook.trigger != event.trigger) continue;
    if (hook.fieldKey != null && hook.fieldKey != event.fieldKey) continue;
    if (hook.listId != null && hook.listId != event.listId) continue;
    if (hook.typeId != null && hook.typeId != event.typeId) continue;
    if (hook.equals != null && '${event.value ?? ''}' != hook.equals) continue;
    switch (hook.action) {
      case SgHookAction.setField:
        if (hook.thenField != null) mut.setField(event.cardId, hook.thenField!, hook.thenValue ?? '');
      case SgHookAction.moveToList:
        if (hook.thenList != null) mut.moveToList(event.cardId, hook.thenList!);
      case SgHookAction.addLabel:
        if (hook.thenLabel != null) mut.addLabel(event.cardId, hook.thenLabel!);
      case SgHookAction.createCard:
        if (hook.thenList != null) mut.createCard(hook.thenList!, hook.thenTitle ?? '');
    }
  }
}
