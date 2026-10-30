import 'model_def.dart';

class TickerMessage {
  final String id;
  final String sender; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  final List<String>? fileAttachments;

  const TickerMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.fileAttachments,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (fileAttachments != null) 'fileAttachments': fileAttachments,
      };

  static TickerMessage fromJson(Map<String, dynamic> j) => TickerMessage(
        id: j['id'] as String? ?? '',
        sender: j['sender'] as String? ?? 'user',
        text: j['text'] as String? ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        fileAttachments: (j['fileAttachments'] as List?)?.cast<String>(),
      );
}

class TickerItem {
  final ModelDef modelDef;
  final String relativeTime;
  final String summary;
  final List<TickerMessage> conversation;
  final bool isIsolated;
  final List<String>? mediaUrls;
  final bool isStreaming;

  const TickerItem({
    required this.modelDef,
    required this.relativeTime,
    required this.summary,
    required this.conversation,
    this.isIsolated = false,
    this.mediaUrls,
    this.isStreaming = false,
  });

  TickerItem copyWith({
    ModelDef? modelDef,
    String? relativeTime,
    String? summary,
    List<TickerMessage>? conversation,
    bool? isIsolated,
    List<String>? mediaUrls,
    bool? isStreaming,
  }) {
    return TickerItem(
      modelDef: modelDef ?? this.modelDef,
      relativeTime: relativeTime ?? this.relativeTime,
      summary: summary ?? this.summary,
      conversation: conversation ?? this.conversation,
      isIsolated: isIsolated ?? this.isIsolated,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ConversationHistorySession {
  final String id;
  final String title;
  final String? targetModelId; // If specific to a single model
  final String relativeTime;
  final DateTime timestamp;
  final String summary;
  final List<String> modelIds;
  final List<TickerMessage> messages;

  const ConversationHistorySession({
    required this.id,
    required this.title,
    this.targetModelId,
    required this.relativeTime,
    required this.timestamp,
    required this.summary,
    this.modelIds = const [],
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (targetModelId != null) 'targetModelId': targetModelId,
        'relativeTime': relativeTime,
        'timestamp': timestamp.toIso8601String(),
        'summary': summary,
        'modelIds': modelIds,
        'messages': [for (final m in messages) m.toJson()],
      };

  static ConversationHistorySession fromJson(Map<String, dynamic> j) => ConversationHistorySession(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        targetModelId: j['targetModelId'] as String?,
        relativeTime: j['relativeTime'] as String? ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        summary: j['summary'] as String? ?? '',
        modelIds: (j['modelIds'] as List?)?.cast<String>() ?? const [],
        messages: [
          for (final m in (j['messages'] as List?) ?? const [])
            if (m is Map) TickerMessage.fromJson(Map<String, dynamic>.from(m)),
        ],
      );
}

