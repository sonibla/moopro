import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/chart_ticks.dart';

List<String> labels(CalendarDate a, CalendarDate b, int max) => [
  for (final t in dateTicks(a, b, maxTicks: max)) t.label,
];

void main() {
  test('a one-year span gets bimonthly or quarterly ticks on month starts', () {
    final ticks = dateTicks(
      CalendarDate(2025, 10, 7),
      CalendarDate(2026, 10, 7),
      maxTicks: 6,
    );
    expect(ticks.length, lessThanOrEqualTo(6));
    expect(ticks.every((t) => t.date.day == 1), isTrue);
    final steps = {
      for (var i = 1; i < ticks.length; i++)
        (ticks[i].date.year * 12 + ticks[i].date.month) -
            (ticks[i - 1].date.year * 12 + ticks[i - 1].date.month),
    };
    expect(steps.length, 1);
  });

  test('quarterly ticks are anchored on January', () {
    expect(labels(CalendarDate(2025, 10, 7), CalendarDate(2026, 10, 7), 5), [
      'Jan 2026',
      'Apr',
      'Jul',
      'Oct',
    ]);
  });

  test('the year shows on the first tick and on every January', () {
    expect(labels(CalendarDate(2025, 11, 1), CalendarDate(2026, 3, 1), 8), [
      'Nov 2025',
      'Dec',
      'Jan 2026',
      'Feb',
      'Mar',
    ]);
  });

  test('short spans use Mondays', () {
    final ticks = dateTicks(
      CalendarDate(2026, 9, 7),
      CalendarDate(2026, 10, 7),
      maxTicks: 8,
    );
    expect(ticks.map((t) => t.label), [
      '7 Sep',
      '14 Sep',
      '21 Sep',
      '28 Sep',
      '5 Oct',
    ]);
    expect(ticks.every((t) => t.date.weekday == 1), isTrue);
  });

  test('multi-year spans step by whole years, anchored on even years', () {
    expect(labels(CalendarDate(2020, 5, 3), CalendarDate(2026, 10, 7), 4), [
      'Jan 2022',
      'Jan 2024',
      'Jan 2026',
    ]);
    expect(labels(CalendarDate(2020, 5, 3), CalendarDate(2026, 10, 7), 6), [
      'Jan 2021',
      'Jan 2022',
      'Jan 2023',
      'Jan 2024',
      'Jan 2025',
      'Jan 2026',
    ]);
  });

  test('only ticks inside the span are produced', () {
    expect(
      dateTicks(
        CalendarDate(2026, 1, 6),
        CalendarDate(2026, 1, 9),
        maxTicks: 5,
      ),
      isEmpty,
    );
    expect(
      dateTicks(
        CalendarDate(2026, 1, 9),
        CalendarDate(2026, 1, 6),
        maxTicks: 5,
      ),
      isEmpty,
    );
  });
}
