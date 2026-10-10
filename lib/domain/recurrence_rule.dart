import 'calendar_date.dart';
import 'models.dart';

CalendarDate occurrenceDate(RecurrenceRule rule, int index) {
  assert(index >= 0);
  final steps = rule.interval * index;
  final start = rule.startDate;
  switch (rule.unit) {
    case RecurrenceUnit.day:
      return start.addDays(steps);
    case RecurrenceUnit.week:
      return start.addDays(steps * 7);
    case RecurrenceUnit.month:
      return start.addMonthsClamped(steps);
    case RecurrenceUnit.year:
      return start.addMonthsClamped(steps * 12);
  }
}

CalendarDate? nextOccurrence(RecurrenceRule rule, {CalendarDate? after}) {
  for (var index = 0; ; index++) {
    final date = occurrenceDate(rule, index);
    if (!_occurrenceAllowed(rule, index, date)) return null;
    if (after == null || date.isAfter(after)) return date;
  }
}

bool _occurrenceAllowed(RecurrenceRule rule, int index, CalendarDate date) {
  if (rule.endDate != null && date.isAfter(rule.endDate!)) return false;
  if (rule.maxOccurrences != null && index >= rule.maxOccurrences!) {
    return false;
  }
  return true;
}

List<CalendarDate> occurrencesBetween(
  RecurrenceRule rule, {
  CalendarDate? after,
  required CalendarDate upTo,
}) {
  final result = <CalendarDate>[];
  for (var index = 0; ; index++) {
    final date = occurrenceDate(rule, index);
    if (!_occurrenceAllowed(rule, index, date)) break;
    if (date.isAfter(upTo)) break;
    if (after == null || date.isAfter(after)) {
      result.add(date);
    }
  }
  return result;
}
