import 'package:dio/dio.dart';

import 'sg_model.dart';

/// A reminder as Collider stores it, for calendar sync.
class LocalReminder {
  const LocalReminder({
    required this.id,
    required this.title,
    required this.description,
    required this.start,
    required this.updated,
    this.repeat,
    this.remoteId,
  });
  final String id;
  final String title;
  final String description;
  final DateTime start;
  final DateTime updated;
  final String? repeat;
  final String? remoteId;
}

class RemoteCalEvent {
  const RemoteCalEvent({
    required this.id,
    required this.colliderId,
    required this.summary,
    required this.start,
    required this.updated,
    this.description = '',
    this.rrule,
  });
  final String id;
  final String colliderId;
  final String summary;
  final String description;
  final DateTime start;
  final DateTime updated;
  final String? rrule;
}

enum CalAction { create, update, delete, takeRemote }

class CalPlan {
  const CalPlan(this.action, {this.local, this.remote});
  final CalAction action;
  final LocalReminder? local;
  final RemoteCalEvent? remote;
}

/// Two-way plan. The newer stamp wins. A remote event whose card is gone is deleted.
/// A card with no remote event is created. This does not call a network.
List<CalPlan> planReminderSync(List<LocalReminder> local, List<RemoteCalEvent> remote) {
  final byCard = {for (final r in remote) r.colliderId: r};
  final plans = <CalPlan>[];
  final seen = <String>{};
  for (final card in local) {
    seen.add(card.id);
    final ev = byCard[card.id];
    if (ev == null) {
      plans.add(CalPlan(CalAction.create, local: card));
      continue;
    }
    if (!ev.updated.isBefore(card.updated)) {
      plans.add(CalPlan(CalAction.takeRemote, local: card, remote: ev));
    } else {
      plans.add(CalPlan(CalAction.update, local: card, remote: ev));
    }
  }
  for (final ev in remote) {
    if (!seen.contains(ev.colliderId)) {
      plans.add(CalPlan(CalAction.delete, remote: ev));
    }
  }
  return plans;
}

String? rruleFor(String? repeat) => switch (repeat) {
      'daily' => 'RRULE:FREQ=DAILY',
      'weekly' => 'RRULE:FREQ=WEEKLY',
      'monthly' => 'RRULE:FREQ=MONTHLY',
      _ => null,
    };

Map<String, Object?> eventBody(LocalReminder card) {
  final start = card.start.toUtc();
  final end = start.add(const Duration(minutes: 15));
  final rule = rruleFor(card.repeat);
  return {
    'summary': card.title.isEmpty ? 'Reminder' : card.title,
    if (card.description.isNotEmpty) 'description': card.description,
    'start': {'dateTime': start.toIso8601String()},
    'end': {'dateTime': end.toIso8601String()},
    if (rule != null) 'recurrence': [rule],
    'reminders': {
      'useDefault': false,
      'overrides': [
        {'method': 'popup', 'minutes': 0},
      ],
    },
    'extendedProperties': {
      'private': {'collider': '1', 'colliderId': card.id},
    },
  };
}

LocalReminder reminderFromCard(SgCard c) {
  final updatedMs = c.activity.isEmpty ? (c.dueMs ?? 0) : c.activity.last.at;
  return LocalReminder(
    id: c.id,
    title: c.title,
    description: c.description,
    start: DateTime.fromMillisecondsSinceEpoch(c.dueMs ?? 0),
    updated: DateTime.fromMillisecondsSinceEpoch(updatedMs),
    repeat: c.custom['repeat'],
    remoteId: c.custom['gcalId'],
  );
}

/// Google Calendar API. Requires an OAuth access token with calendar.events.
/// The token is only the Authorization header for these calls. It is not
/// written onto the card, into AccountSync, or into the app build.
class GoogleCalendarGateway {
  GoogleCalendarGateway({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://www.googleapis.com/calendar/v3',
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (_) => true,
            ));

  final Dio _dio;

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});

  Future<List<RemoteCalEvent>> listOurs(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/calendars/primary/events',
      queryParameters: {'privateExtendedProperty': 'collider=1', 'maxResults': 250},
      options: _auth(token),
    );
    if (res.statusCode != 200 || res.data == null) {
      throw CalendarSyncException(res.statusCode ?? 0);
    }
    final items = res.data!['items'];
    if (items is! List) return const [];
    return [
      for (final raw in items)
        if (raw is Map) _event(Map<String, dynamic>.from(raw)),
    ].whereType<RemoteCalEvent>().toList();
  }

  Future<String> create(String token, LocalReminder card) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/calendars/primary/events',
      data: eventBody(card),
      options: _auth(token),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw CalendarSyncException(res.statusCode ?? 0);
    }
    return res.data?['id'] as String? ?? '';
  }

  Future<void> update(String token, String eventId, LocalReminder card) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/calendars/primary/events/${Uri.encodeComponent(eventId)}',
      data: eventBody(card),
      options: _auth(token),
    );
    if (res.statusCode != 200) throw CalendarSyncException(res.statusCode ?? 0);
  }

  Future<void> delete(String token, String eventId) async {
    final res = await _dio.delete(
      '/calendars/primary/events/${Uri.encodeComponent(eventId)}',
      options: _auth(token),
    );
    if (res.statusCode != 204 && res.statusCode != 200 && res.statusCode != 410) {
      throw CalendarSyncException(res.statusCode ?? 0);
    }
  }

  RemoteCalEvent? _event(Map<String, dynamic> j) {
    final ext = j['extendedProperties'];
    final priv = ext is Map ? ext['private'] : null;
    final colliderId = priv is Map ? priv['colliderId']?.toString() ?? '' : '';
    if (colliderId.isEmpty) return null;
    final startRaw = j['start'];
    final startStr = startRaw is Map ? (startRaw['dateTime'] ?? startRaw['date'])?.toString() : null;
    final start = DateTime.tryParse(startStr ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final updated = DateTime.tryParse(j['updated']?.toString() ?? '') ?? start;
    final rec = j['recurrence'];
    return RemoteCalEvent(
      id: j['id']?.toString() ?? '',
      colliderId: colliderId,
      summary: j['summary']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      start: start,
      updated: updated.toUtc(),
      rrule: rec is List && rec.isNotEmpty ? rec.first.toString() : null,
    );
  }
}

class CalendarSyncException implements Exception {
  CalendarSyncException(this.status);
  final int status;
  @override
  String toString() => 'CalendarSyncException($status)';
}

/// Applies [plan] through [gateway]. Returns remote ids written onto cards.
Future<Map<String, String>> runReminderSync({
  required String accessToken,
  required List<LocalReminder> local,
  required GoogleCalendarGateway gateway,
}) async {
  final remote = await gateway.listOurs(accessToken);
  final ids = <String, String>{};
  for (final step in planReminderSync(local, remote)) {
    switch (step.action) {
      case CalAction.create:
        final id = await gateway.create(accessToken, step.local!);
        if (id.isNotEmpty) ids[step.local!.id] = id;
      case CalAction.update:
        final id = step.remote!.id;
        await gateway.update(accessToken, id, step.local!);
        ids[step.local!.id] = id;
      case CalAction.delete:
        await gateway.delete(accessToken, step.remote!.id);
      case CalAction.takeRemote:
        if (step.local != null && step.remote != null) ids[step.local!.id] = step.remote!.id;
    }
  }
  return ids;
}
