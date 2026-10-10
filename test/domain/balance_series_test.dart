import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/balance_series.dart';

import 'balance_chart_rows.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('StepSeries', () {
    final series = StepSeries(
      [CalendarDate(2026, 1, 10), CalendarDate(2026, 1, 20)],
      [d('100'), d('40')],
    );

    test('is null/zero before the first point', () {
      expect(series.valueAtOrNull(CalendarDate(2026, 1, 9)), isNull);
      expect(series.valueAt(CalendarDate(2026, 1, 9)), d('0'));
    });

    test('holds a value from its day until the next point', () {
      expect(series.valueAt(CalendarDate(2026, 1, 10)), d('100'));
      expect(series.valueAt(CalendarDate(2026, 1, 19)), d('100'));
      expect(series.valueAt(CalendarDate(2026, 1, 20)), d('40'));
      expect(series.valueAt(CalendarDate(2030, 1, 1)), d('40'));
    });

    test('a CalendarDate built from a DateTime ignores its time of day', () {
      final lateEvening = DateTime(2026, 1, 10, 23, 59);
      expect(series.valueAt(CalendarDate.fromDateTime(lateEvening)), d('100'));
    });

    test('empty series reads as zero', () {
      expect(StepSeries.empty.valueAt(CalendarDate(2026, 1, 1)), d('0'));
      expect(StepSeries.empty.isEmpty, isTrue);
    });
  });

  group('buildBalanceSeries', () {
    test('reads balanceAfter per pair, holder and budget side separately', () {
      final series = buildBalanceSeries([
        incomeRow(
          'a',
          CalendarDate(2026, 1, 1),
          amount: '100',
          holderAfter: '100',
        ),
        expenseRow(
          'b',
          CalendarDate(2026, 1, 5),
          amount: '30',
          holderAfter: '70',
        ),
      ]);

      expect(series['h1|eur']!.valueAt(CalendarDate(2026, 1, 3)), d('100'));
      expect(series['h1|eur']!.valueAt(CalendarDate(2026, 1, 5)), d('70'));
      expect(series['b1|eur']!.valueAt(CalendarDate(2026, 1, 5)), d('70'));
    });

    test(
      'takes the last transaction of a day in the engine\'s same-day order',
      () {
        final day = CalendarDate(2026, 2, 1);
        final series = buildBalanceSeries([
          expenseRow('exp', day, amount: '30', holderAfter: '70'),
          incomeRow('inc', day, amount: '100', holderAfter: '100'),
        ]);

        expect(series['h1|eur']!.days, [day]);
        expect(series['h1|eur']!.valueAt(day), d('70'));
      },
    );

    test('falls back to the running sum when balanceAfter is missing', () {
      final noCache = incomeRow(
        'a',
        CalendarDate(2026, 1, 1),
        amount: '100',
        holderAfter: '100',
      );
      final series = buildBalanceSeries([
        noCache.copyWith(legInBalanceAfter: const Value.absent()),
        expenseRow(
          'b',
          CalendarDate(2026, 1, 5),
          amount: '30',
          holderAfter: '70',
        ),
      ]);
      expect(series['h1|eur']!.valueAt(CalendarDate(2026, 1, 2)), d('100'));
      expect(series['h1|eur']!.valueAt(CalendarDate(2026, 1, 5)), d('70'));
    });

    test('future-dated transactions are ordinary points', () {
      final series = buildBalanceSeries([
        incomeRow(
          'a',
          CalendarDate(2099, 1, 1),
          amount: '500',
          holderAfter: '500',
        ),
      ]);
      expect(series['h1|eur']!.valueAt(CalendarDate(2099, 6, 1)), d('500'));
    });

    test('skips deleted rows', () {
      final row = incomeRow(
        'a',
        CalendarDate(2026, 1, 1),
        amount: '100',
        holderAfter: '100',
      );
      expect(buildBalanceSeries([row.copyWith(deleted: true)]), isEmpty);
    });
  });
}
