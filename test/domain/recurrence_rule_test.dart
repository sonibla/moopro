import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/recurrence_rule.dart';
import 'package:moopro/domain/calendar_date.dart';

void main() {
  group('occurrenceDate', () {
    test('daily, interval 1', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.day,
        interval: 1,
      );
      expect(occurrenceDate(rule, 0), equals(CalendarDate(2026, 1, 1)));
      expect(occurrenceDate(rule, 1), equals(CalendarDate(2026, 1, 2)));
      expect(occurrenceDate(rule, 30), equals(CalendarDate(2026, 1, 31)));
    });

    test('weekly, interval 2 (biweekly)', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 5),
        unit: RecurrenceUnit.week,
        interval: 2,
      );
      expect(occurrenceDate(rule, 0), equals(CalendarDate(2026, 1, 5)));
      expect(occurrenceDate(rule, 1), equals(CalendarDate(2026, 1, 19)));
      expect(occurrenceDate(rule, 2), equals(CalendarDate(2026, 2, 2)));
    });

    test('monthly, interval 3 (quarterly)', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 15),
        unit: RecurrenceUnit.month,
        interval: 3,
      );
      expect(occurrenceDate(rule, 0), equals(CalendarDate(2026, 1, 15)));
      expect(occurrenceDate(rule, 1), equals(CalendarDate(2026, 4, 15)));
      expect(occurrenceDate(rule, 2), equals(CalendarDate(2026, 7, 15)));
    });

    test('yearly, interval 1', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 6, 1),
        unit: RecurrenceUnit.year,
        interval: 1,
      );
      expect(occurrenceDate(rule, 0), equals(CalendarDate(2026, 6, 1)));
      expect(occurrenceDate(rule, 3), equals(CalendarDate(2029, 6, 1)));
    });

    test(
      'monthly anchored on the 31st clamps to the shorter month, but the '
      'next occurrence is computed fresh from the real anchor — no drift',
      () {
        final rule = RecurrenceRule(
          startDate: CalendarDate(2026, 1, 31),
          unit: RecurrenceUnit.month,
          interval: 1,
        );
        expect(occurrenceDate(rule, 0), equals(CalendarDate(2026, 1, 31)));
        expect(occurrenceDate(rule, 1), equals(CalendarDate(2026, 2, 28)));
        expect(occurrenceDate(rule, 2), equals(CalendarDate(2026, 3, 31)));
        expect(occurrenceDate(rule, 3), equals(CalendarDate(2026, 4, 30)));
      },
    );

    test('yearly Feb 29 clamps to Feb 28 in a non-leap year', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2024, 2, 29),
        unit: RecurrenceUnit.year,
        interval: 1,
      );
      expect(occurrenceDate(rule, 0), equals(CalendarDate(2024, 2, 29)));
      expect(occurrenceDate(rule, 1), equals(CalendarDate(2025, 2, 28)));
      expect(occurrenceDate(rule, 4), equals(CalendarDate(2028, 2, 29)));
    });
  });

  group('occurrencesBetween', () {
    test('honors endDate as an inclusive cutoff', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
        endDate: CalendarDate(2026, 3, 1),
      );
      final occurrences = occurrencesBetween(
        rule,
        upTo: CalendarDate(2026, 12, 31),
      );
      expect(
        occurrences,
        equals([
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 2, 1),
          CalendarDate(2026, 3, 1),
        ]),
      );
    });

    test('honors maxOccurrences as a count cutoff', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
        maxOccurrences: 2,
      );
      final occurrences = occurrencesBetween(
        rule,
        upTo: CalendarDate(2026, 12, 31),
      );
      expect(
        occurrences,
        equals([CalendarDate(2026, 1, 1), CalendarDate(2026, 2, 1)]),
      );
    });

    test('after excludes everything on or before it, not just strictly '
        'before', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      );
      final occurrences = occurrencesBetween(
        rule,
        after: CalendarDate(2026, 2, 1),
        upTo: CalendarDate(2026, 4, 1),
      );
      expect(
        occurrences,
        equals([CalendarDate(2026, 3, 1), CalendarDate(2026, 4, 1)]),
      );
    });

    test('upTo excludes everything after it', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.day,
        interval: 1,
      );
      final occurrences = occurrencesBetween(
        rule,
        upTo: CalendarDate(2026, 1, 3),
      );
      expect(
        occurrences,
        equals([
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 1, 2),
          CalendarDate(2026, 1, 3),
        ]),
      );
    });

    test('no after and upTo before startDate returns nothing', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 6, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      );
      expect(occurrencesBetween(rule, upTo: CalendarDate(2026, 1, 1)), isEmpty);
    });
  });

  group('nextOccurrence', () {
    test('with no after, returns the very first occurrence', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      );
      expect(nextOccurrence(rule), equals(CalendarDate(2026, 1, 1)));
    });

    test('with after set, returns the first occurrence strictly after it', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      );
      expect(
        nextOccurrence(rule, after: CalendarDate(2026, 1, 1)),
        equals(CalendarDate(2026, 2, 1)),
      );
    });

    test('returns null once endDate/maxOccurrences are exhausted', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
        maxOccurrences: 2,
      );
      expect(nextOccurrence(rule, after: CalendarDate(2026, 2, 1)), isNull);
    });
  });
}
