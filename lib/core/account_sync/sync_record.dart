/// One versioned JSON document in a named collection.
class SyncRecord {
  final String collection;
  final String id;
  final Map<String, Object?> data;
  final int updatedAtMs;
  final bool deleted;

  const SyncRecord({
    required this.collection,
    required this.id,
    required this.data,
    required this.updatedAtMs,
    this.deleted = false,
  });

  Map<String, Object?> toJson() => {
        'collection': collection,
        'id': id,
        'data': data,
        'updatedAtMs': updatedAtMs,
        'deleted': deleted,
      };

  static SyncRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final c = j['collection'];
    final id = j['id'];
    if (c is! String || id is! String) return null;
    final data = j['data'];
    return SyncRecord(
      collection: c,
      id: id,
      data: data is Map ? Map<String, Object?>.from(data) : <String, Object?>{},
      updatedAtMs: (j['updatedAtMs'] as num?)?.toInt() ?? 0,
      deleted: j['deleted'] == true,
    );
  }
}
