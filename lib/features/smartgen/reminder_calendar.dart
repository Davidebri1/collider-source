// Reminder cards → the user's own calendar, as a standard iCalendar (.ics, RFC 5545) file.
// There is no Collider backend to host a subscribe feed or hold Google OAuth tokens, so the
// established no-server route is an .ics hand-off: Google Calendar, Apple Calendar and Outlook
// all import it, and on phones opening it offers "Add to calendar". Built with enough_icalendar.
import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_icalendar/enough_icalendar.dart';

import '../../core/files/file_blobs.dart';
import 'sg_model.dart';

/// One VEVENT (with a display alarm at the due time) per reminder card that has a due time.
String remindersIcs(Iterable<SgCard> cards) {
  final cal = VCalendar()
    ..productId = '-//Collider//Smart Gen Reminders//EN'
    ..version = '2.0'
    ..method = Method.publish;
  for (final c in cards) {
    if (c.type != SgType.reminder || c.dueMs == null) continue;
    final start = DateTime.fromMillisecondsSinceEpoch(c.dueMs!).toUtc();
    final ev = VEvent(parent: cal)
      ..uid = 'collider-reminder-${c.id}'
      ..timeStamp = DateTime.now().toUtc()
      ..start = start
      ..end = start.add(const Duration(minutes: 15))
      ..summary = c.title.isEmpty ? 'Reminder' : c.title
      ..description = c.description.isEmpty ? null : c.description;
    ev.children.add(VAlarm(parent: ev)
      ..action = AlarmAction.display
      ..triggerRelativeDuration = IsoDuration()
      ..description = ev.summary);
    cal.children.add(ev);
  }
  return cal.toString();
}

/// Hands the .ics to the browser / OS calendar. Returns false when there was nothing to add.
Future<bool> exportReminders(Iterable<SgCard> cards, {String name = 'reminders.ics'}) async {
  final list = cards.where((c) => c.type == SgType.reminder && c.dueMs != null).toList();
  if (list.isEmpty) return false;
  return FileBlobs.openExternal(name, Uint8List.fromList(utf8.encode(remindersIcs(list))), 'text/calendar');
}
