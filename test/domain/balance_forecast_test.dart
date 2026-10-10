import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/balance_forecast.dart';

import 'balance_chart_rows.dart';

Decimal d(String s) => Decimal.parse(s);

final today = CalendarDate(2026, 6, 15);

BalanceForecaster forecaster({
  List<ldb.Transaction>? txs,
  List<ldb.RecurringTransactionTemplate>? templates,
}) => BalanceForecaster()
  ..update(transactions: txs ?? [], templates: templates ?? [], today: today);

Decimal at(BalanceForecaster f, CalendarDate day) =>
    f.quantityAt('h1', 'eur', day);

void main() {
  final seed = incomeRow(
    'seed',
    CalendarDate(2026, 1, 1),
    amount: '1000',
    holderAfter: '1000',
  );

  test('does no work until something asks for it', () {
    final f = forecaster(txs: [seed]);
    expect(f.stepBuildCount, 0);
    expect(f.expandedOccurrenceCount, 0);

    at(f, today);
    expect(f.stepBuildCount, 1);
    expect(f.expandedOccurrenceCount, 0, reason: 'no horizon requested');
  });

  test('past quantities come from the recorded balance', () {
    final f = forecaster(
      txs: [
        seed,
        expenseRow(
          'e',
          CalendarDate(2026, 3, 1),
          amount: '200',
          holderAfter: '800',
        ),
      ],
    );
    expect(at(f, CalendarDate(2026, 2, 1)), d('1000'));
    expect(at(f, CalendarDate(2026, 3, 1)), d('800'));
  });

  test('recurring occurrences after today are added on top of the balance', () {
    final f = forecaster(
      txs: [seed],
      templates: [
        monthlyExpenseTemplate('rent', CalendarDate(2026, 1, 1), amount: '100'),
      ],
    )..ensureHorizon(CalendarDate(2026, 9, 30));

    expect(at(f, today), d('1000'), reason: 'nothing projected up to today');
    expect(at(f, CalendarDate(2026, 7, 1)), d('900'));
    expect(at(f, CalendarDate(2026, 8, 31)), d('800'));
    expect(at(f, CalendarDate(2026, 9, 30)), d('700'));
  });

  test('past-due unposted occurrences are not projected', () {
    final f = forecaster(
      txs: [seed],
      templates: [
        monthlyExpenseTemplate('rent', CalendarDate(2026, 1, 1), amount: '100'),
      ],
    )..ensureHorizon(CalendarDate(2026, 7, 1));
    expect(at(f, CalendarDate(2026, 6, 15)), d('1000'));
    expect(f.expandedOccurrenceCount, 1, reason: 'Jul 1 only');
  });

  test('real future transactions and recurring occurrences interleave', () {
    final f = forecaster(
      txs: [
        seed,
        expenseRow(
          'future',
          CalendarDate(2026, 7, 10),
          amount: '50',
          holderAfter: '950',
        ),
      ],
      templates: [
        monthlyExpenseTemplate('rent', CalendarDate(2026, 1, 1), amount: '100'),
      ],
    )..ensureHorizon(CalendarDate(2026, 8, 31));

    expect(at(f, CalendarDate(2026, 7, 1)), d('900'), reason: 'rent only');
    expect(at(f, CalendarDate(2026, 7, 10)), d('850'), reason: 'rent + future');
    expect(at(f, CalendarDate(2026, 8, 1)), d('750'));
  });

  test('paused and ended templates project nothing', () {
    final f = forecaster(
      txs: [seed],
      templates: [
        monthlyExpenseTemplate(
          'paused',
          CalendarDate(2026, 1, 1),
          amount: '100',
          active: false,
        ),
        monthlyExpenseTemplate(
          'ended',
          CalendarDate(2026, 1, 1),
          amount: '100',
          endDate: CalendarDate(2026, 6, 30),
        ),
      ],
    )..ensureHorizon(CalendarDate(2026, 12, 31));
    expect(at(f, CalendarDate(2026, 12, 31)), d('1000'));
  });

  test('a pair that only recurring touches still gets a quantity', () {
    final f = forecaster(
      templates: [
        monthlyExpenseTemplate('rent', CalendarDate(2026, 1, 1), amount: '100'),
      ],
    )..ensureHorizon(CalendarDate(2026, 7, 31));
    expect(at(f, CalendarDate(2026, 7, 31)), d('-100'));
    expect(f.pairs().map((p) => p.containerId), contains('h1'));
  });

  group('caching', () {
    test('asking again for the same horizon reuses everything', () {
      final f = forecaster(
        txs: [seed],
        templates: [
          monthlyExpenseTemplate(
            'rent',
            CalendarDate(2026, 1, 1),
            amount: '100',
          ),
        ],
      )..ensureHorizon(CalendarDate(2026, 12, 31));
      at(f, today);
      final expanded = f.expandedOccurrenceCount;
      final builds = f.stepBuildCount;

      f.ensureHorizon(CalendarDate(2026, 12, 31));
      f.ensureHorizon(CalendarDate(2026, 9, 1));
      at(f, CalendarDate(2026, 9, 1));

      expect(f.expandedOccurrenceCount, expanded);
      expect(f.stepBuildCount, builds);
    });

    test('extending the horizon expands only the new range', () {
      final f = forecaster(
        txs: [seed],
        templates: [
          monthlyExpenseTemplate(
            'rent',
            CalendarDate(2026, 1, 1),
            amount: '100',
          ),
        ],
      )..ensureHorizon(CalendarDate(2026, 8, 31));
      final first = f.expandedOccurrenceCount;

      f.ensureHorizon(CalendarDate(2026, 10, 31));
      expect(first, 2);
      expect(f.expandedOccurrenceCount - first, 2, reason: 'Sep and Oct only');
      expect(at(f, CalendarDate(2026, 10, 31)), d('600'));
    });

    test('same inputs by identity do not invalidate; new transactions do', () {
      final txs = [seed];
      final templates = <ldb.RecurringTransactionTemplate>[];
      final f = BalanceForecaster()
        ..update(transactions: txs, templates: templates, today: today);
      at(f, today);
      f.update(transactions: txs, templates: templates, today: today);
      at(f, today);
      expect(f.stepBuildCount, 1);

      f.update(transactions: [seed], templates: templates, today: today);
      at(f, today);
      expect(f.stepBuildCount, 2);
    });

    test('a template change re-expands but keeps the step series', () {
      final txs = [seed];
      final f = BalanceForecaster()
        ..update(transactions: txs, templates: [], today: today)
        ..ensureHorizon(CalendarDate(2026, 9, 1));
      at(f, today);

      f.update(
        transactions: txs,
        today: today,
        templates: [
          monthlyExpenseTemplate(
            'rent',
            CalendarDate(2026, 1, 1),
            amount: '100',
          ),
        ],
      );
      f.ensureHorizon(CalendarDate(2026, 9, 1));

      expect(f.stepBuildCount, 1);
      expect(at(f, CalendarDate(2026, 9, 1)), d('700'));
    });

    test('a new day drops the forecast but keeps the step series', () {
      final txs = [seed];
      final templates = [
        monthlyExpenseTemplate('rent', CalendarDate(2026, 1, 1), amount: '100'),
      ];
      final f = BalanceForecaster()
        ..update(transactions: txs, templates: templates, today: today)
        ..ensureHorizon(CalendarDate(2026, 9, 1));
      at(f, today);

      f.update(
        transactions: txs,
        templates: templates,
        today: CalendarDate(2026, 7, 1),
      );
      f.ensureHorizon(CalendarDate(2026, 9, 1));

      expect(f.stepBuildCount, 1);
      expect(at(f, CalendarDate(2026, 7, 1)), d('1000'));
      expect(at(f, CalendarDate(2026, 9, 1)), d('800'));
    });
  });
}
