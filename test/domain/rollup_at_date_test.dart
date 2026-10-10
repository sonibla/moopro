import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/balance_forecast.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/container_tree.dart';
import 'package:moopro/domain/multi_asset_rollup.dart' show MultiAssetRollup;
import 'package:moopro/domain/rollup_at_date.dart';

import 'balance_chart_rows.dart';

final today = CalendarDate(2026, 6, 15);

BalanceForecaster forecasterFor(List txs, [List templates = const []]) =>
    BalanceForecaster()..update(
      transactions: List.of(txs.cast()),
      templates: List.of(templates.cast()),
      today: today,
    );

Decimal d(String s) => Decimal.parse(s);

void main() {
  final containers = [
    containerRow('h1', 'Bank A'),
    containerRow('h2', 'Bank B'),
  ];

  group('computeRollupAt', () {
    test('values each container as of the given date, not today', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          amount: '100',
          holderAfter: '100',
        ),
        incomeRow(
          'b',
          CalendarDate(2026, 6, 1),
          amount: '50',
          holderAfter: '150',
        ),
      ]);
      final before = computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: const [],
        displayAssetId: 'eur',
        date: CalendarDate(2026, 5, 15),
      );
      final after = computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: const [],
        displayAssetId: 'eur',
        date: today,
      );
      expect(before.ownPositive['h1'], d('100'));
      expect(after.ownPositive['h1'], d('150'));
    });

    test('forecast date includes recurring occurrences', () {
      final f = forecasterFor(
        [
          incomeRow(
            'a',
            CalendarDate(2026, 5, 1),
            amount: '100',
            holderAfter: '100',
          ),
        ],
        [monthlyExpenseTemplate('t', CalendarDate(2026, 7, 1), amount: '10')],
      );
      final r = computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: const [],
        displayAssetId: 'eur',
        date: CalendarDate(2026, 8, 15),
      );
      expect(r.ownPositive['h1'], d('80'));
    });

    test('converts through the latest snapshot on or before the date', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          asset: 'btc',
          amount: '2',
          holderAfter: '2',
        ),
      ]);
      final prices = [
        priceRow('btc', CalendarDate(2026, 5, 1), '100'),
        priceRow('btc', CalendarDate(2026, 6, 1), '200'),
      ];
      MultiAssetRollup at(CalendarDate day) => computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: prices,
        displayAssetId: 'eur',
        date: day,
      );
      expect(at(CalendarDate(2026, 5, 20)).ownPositive['h1'], d('200'));
      expect(at(today).ownPositive['h1'], d('400'));
    });

    test('unpriced asset is listed and flagged, not summed', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          asset: 'btc',
          amount: '2',
          holderAfter: '2',
        ),
      ]);
      final r = computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: const [],
        displayAssetId: 'eur',
        date: today,
      );
      expect(r.ownPositive['h1'], isNull);
      expect(r.containersWithUnconvertible, contains('h1'));
      expect(r.ownHoldings['h1']!.single.convertedValue, isNull);
      expect(r.ownHoldings['h1']!.single.quantity, d('2'));
    });

    test('includeAsset restricts which assets count', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          asset: 'eur',
          amount: '10',
          holderAfter: '10',
        ),
        incomeRow(
          'b',
          CalendarDate(2026, 5, 2),
          asset: 'usd',
          amount: '5',
          holderAfter: '5',
        ),
      ]);
      final r = computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: const [],
        displayAssetId: 'eur',
        date: today,
        includeAsset: (id) => id == 'eur',
      );
      expect(r.ownHoldings['h1']!.map((h) => h.assetId), ['eur']);
    });

    test('negative holdings go to ownDebt, never netted', () {
      final f = forecasterFor([
        expenseRow(
          'a',
          CalendarDate(2026, 5, 1),
          amount: '30',
          holderAfter: '-30',
        ),
      ]);
      final r = computeRollupAt(
        forecaster: f,
        containers: containers,
        priceSnapshots: const [],
        displayAssetId: 'eur',
        date: today,
      );
      expect(r.ownDebt['h1'], d('-30'));
      expect(r.ownPositive['h1'], isNull);
    });
  });

  test('computeSingleAssetBalancesAt is raw and date-sensitive', () {
    final f = forecasterFor([
      incomeRow(
        'a',
        CalendarDate(2026, 5, 1),
        asset: 'btc',
        amount: '2',
        holderAfter: '2',
      ),
    ]);
    expect(
      computeSingleAssetBalancesAt(
        forecaster: f,
        containers: containers,
        assetId: 'btc',
        date: CalendarDate(2026, 4, 1),
      ),
      isEmpty,
    );
    expect(
      computeSingleAssetBalancesAt(
        forecaster: f,
        containers: containers,
        assetId: 'btc',
        date: today,
      ),
      {'h1': d('2')},
    );
  });

  group('containerColorIndex', () {
    final tree = [
      containerRow('z', 'Zoo', type: 'budget'),
      containerRow('a', 'Apple', type: 'budget'),
      containerRow('c', 'Child', type: 'budget', parentId: 'z'),
    ];
    test('is the name-sorted position among siblings', () {
      expect(containerColorIndex('a', tree), 0);
      expect(containerColorIndex('z', tree), 1);
      expect(containerColorIndex('c', tree), 0);
    });
    test('does not shift when other containers are filtered away', () {
      expect(containerColorIndex('z', tree), 1);
      expect(containerColorIndex('missing', tree), 0);
    });
  });
}
