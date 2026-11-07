import 'package:collider_flutter/features/smartgen/reminder_calendar.dart';
import 'package:collider_flutter/features/smartgen/sg_model.dart';
import 'package:enough_icalendar/enough_icalendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reminder cards become a valid iCalendar event with an alarm', () {
    final due = DateTime.utc(2026, 11, 9, 15, 30);
    final s = SgStore()..ensureStarter();
    final r = s.addCard(SgType.reminder)!
      ..title = 'Call the dentist'
      ..dueMs = due.millisecondsSinceEpoch;
    final t = s.addCard(SgType.task)!..dueMs = due.millisecondsSinceEpoch;
    final ics = remindersIcs([r, t]);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('SUMMARY:Call the dentist'));
    expect(ics, contains('BEGIN:VALARM'));
    final parsed = VComponent.parse(ics) as VCalendar;
    final events = parsed.children.whereType<VEvent>().toList();
    expect(events.length, 1);
    expect(events.single.start, due);
  });
}
