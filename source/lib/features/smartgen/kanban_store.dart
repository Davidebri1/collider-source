import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/files/file_blobs.dart';

/// One Smart Gen card.
class KanbanCard {
  final String id;
  String title;
  String notes;
  int column; // index into KanbanStore.columns
  int color; // index into the card palette
  final int createdMs;
  int updatedMs;

  KanbanCard({
    required this.id,
    this.title = '',
    this.notes = '',
    this.column = 0,
    this.color = 0,
    required this.createdMs,
    required this.updatedMs,
  });

  Map<String, Object?> toJson() =>
      {'id': id, 'title': title, 'notes': notes, 'col': column, 'color': color, 'at': createdMs, 'up': updatedMs};

  static KanbanCard? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! String) return null;
    return KanbanCard(
      id: id,
      title: (j['title'] as String?) ?? '',
      notes: (j['notes'] as String?) ?? '',
      column: ((j['col'] as num?)?.toInt() ?? 0).clamp(0, KanbanStore.columns.length - 1),
      color: (j['color'] as num?)?.toInt() ?? 0,
      createdMs: (j['at'] as num?)?.toInt() ?? 0,
      updatedMs: (j['up'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The user's local Kanban board (map rows 23-25, D54). Only cards the user
/// made: no samples. Saved as one JSON document through [FileBlobs]
/// (IndexedDB on web, a file in the app's documents on iOS / Android), so it
/// is there after a reload or a restart.
class KanbanStore extends ChangeNotifier {
  KanbanStore._();
  static final KanbanStore instance = KanbanStore._();

  static const List<String> columns = ['To Do', 'Doing', 'Done'];
  static const String _blobId = 'smartgen/kanban.json';

  final List<KanbanCard> _cards = [];
  bool _loaded = false;
  Future<void>? _loading;

  bool get loaded => _loaded;

  /// Cards in [column], newest first.
  List<KanbanCard> inColumn(int column) {
    final l = _cards.where((c) => c.column == column).toList()..sort((a, b) => b.createdMs.compareTo(a.createdMs));
    return l;
  }

  int count(int column) => _cards.where((c) => c.column == column).length;

  Future<void> init() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final b = await FileBlobs.get(_blobId);
      if (b != null && b.isNotEmpty) {
        final j = jsonDecode(utf8.decode(b));
        final list = j is Map ? j['cards'] : null;
        if (list is List) {
          _cards
            ..clear()
            ..addAll(list.map(KanbanCard.fromJson).whereType<KanbanCard>());
        }
      }
    } catch (e) {
      debugPrint('KanbanStore: ignored unreadable board: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final doc = jsonEncode({'v': 1, 'cards': [for (final c in _cards) c.toJson()]});
    await FileBlobs.put(_blobId, Uint8List.fromList(utf8.encode(doc)));
  }

  KanbanCard add(int column) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = KanbanCard(id: 'k$now', column: column, color: _cards.length % 4, createdMs: now, updatedMs: now);
    _cards.add(c);
    notifyListeners();
    // Saved once it has a title (an untitled card is dropped, see [edit]).
    return c;
  }

  Future<void> edit(KanbanCard c, {String? title, String? notes}) async {
    if (title != null) c.title = title.trim();
    if (notes != null) c.notes = notes.trim();
    if (c.title.isEmpty && c.notes.isEmpty) {
      await remove(c);
      return;
    }
    c.updatedMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _save();
  }

  Future<void> move(KanbanCard c, int column) async {
    if (c.column == column) return;
    c.column = column;
    c.updatedMs = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    await _save();
  }

  Future<void> recolor(KanbanCard c, int color) async {
    c.color = color;
    notifyListeners();
    await _save();
  }

  Future<void> remove(KanbanCard c) async {
    _cards.removeWhere((x) => x.id == c.id);
    notifyListeners();
    await _save();
  }
}
