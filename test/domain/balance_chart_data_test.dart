import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/balance_chart_data.dart';
import 'package:moopro/domain/balance_forecast.dart';

import 'balance_chart_rows.dart';

final today = CalendarDate(2026, 6, 15);

BalanceForecaster forecasterFor(List txs, [List templates = const []]) =>
    BalanceForecaster()..update(
      transactions: List.of(txs.cast()),
      templates: List.of(templates.cast()),
      today: today,
    );

void main() {
  group('sampleDates', () {
    test('daily when the range is short, always ending on the end date', () {
      final dates = sampleDates(
        CalendarDate(2026, 6, 1),
        CalendarDate(2026, 6, 5),
        today,
      );
      expect(dates.length, 5);
      expect(dates.last, CalendarDate(2026, 6, 5));
    });

    test('never exceeds maxPoints (+ the today marker) over long ranges', () {
      final dates = sampleDates(
        CalendarDate(2016, 1, 1),
        CalendarDate(2028, 1, 1),
        today,
        maxPoints: 100,
      );
      expect(dates.length, lessThanOrEqualTo(101));
      expect(dates.last, CalendarDate(2028, 1, 1));
      expect(dates, contains(CalendarDate(2026, 6, 15)));
      expect(dates, orderedEquals([...dates]..sort()));
    });
  });

  group('buildBalanceChartData', () {
    final containers = [
      containerRow('h1', 'Bank A'),
      containerRow('h2', 'Bank B'),
    ];

    BalanceChartData build(
      BalanceForecaster f, {
      bool Function(String)? include,
      String? raw,
      String display = 'eur',
      List prices = const [],
      CalendarDate? end,
    }) {
      f.ensureHorizon(end ?? CalendarDate(2026, 7, 15));
      return buildBalanceChartData(
        forecaster: f,
        containers: containers,
        priceSnapshots: List.of(prices.cast()),
        displayAssetId: display,
        includeAsset: include ?? (_) => true,
        rawUnitAssetId: raw,
        start: CalendarDate(2026, 6, 1),
        end: end ?? CalendarDate(2026, 7, 15),
      );
    }

    test('one band per container, with a net line and the today boundary', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          amount: '100',
          holderAfter: '100',
        ),
        incomeRow(
          'b',
          CalendarDate(2026, 5, 1),
          holder: 'h2',
          amount: '50',
          holderAfter: '50',
        ),
      ]);
      final data = build(f);

      expect(data.series.map((s) => s.containerId), ['h1', 'h2']);
      expect(data.net.first, 150);
      expect(data.dates[data.todayIndex], today);
      expect(data.hasForecast, isTrue);
    });

    test('debts stay apart from positives within one band', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          asset: 'eur',
          amount: '100',
          holderAfter: '100',
        ),
        expenseRow(
          'b',
          CalendarDate(2026, 5, 2),
          holder: 'h1',
          asset: 'usd',
          amount: '30',
          holderAfter: '-30',
        ),
      ]);
      final data = build(
        f,
        prices: [
          priceRow('usd', CalendarDate(2026, 1, 1), '1', currency: 'eur'),
        ],
      );

      final band = data.series.single;
      expect(band.positive.first, 100);
      expect(band.debt.first, -30);
      expect(data.net.first, 70);
    });

    test('converts through the latest price on or before each date', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          asset: 'share',
          amount: '10',
          holderAfter: '10',
        ),
      ]);
      final data = build(
        f,
        prices: [
          priceRow('share', CalendarDate(2026, 1, 1), '5'),
          priceRow('share', CalendarDate(2026, 6, 10), '8'),
        ],
      );

      final i9 = data.dates.indexOf(CalendarDate(2026, 6, 9));
      final i10 = data.dates.indexOf(CalendarDate(2026, 6, 10));
      expect(data.series.single.positive[i9], 50);
      expect(data.series.single.positive[i10], 80);
      expect(data.series.single.positive.last, 80);
    });

    test('an unpriced asset is left out and reported, never guessed', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          asset: 'eur',
          amount: '100',
          holderAfter: '100',
        ),
        incomeRow(
          'b',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          asset: 'coin',
          amount: '1',
          holderAfter: '1',
        ),
      ]);
      final data = build(f);

      expect(data.series.single.positive.first, 100);
      expect(data.unpricedAssetIds, {'coin'});
    });

    test(
      'a price dated after the holding leaves the earlier dates unpriced',
      () {
        final f = forecasterFor([
          incomeRow(
            'a',
            CalendarDate(2026, 5, 1),
            holder: 'h1',
            asset: 'share',
            amount: '10',
            holderAfter: '10',
          ),
        ]);
        final data = build(
          f,
          prices: [priceRow('share', CalendarDate(2026, 6, 10), '8')],
        );
        expect(data.series.single.positive.first, 0);
        expect(data.unpricedAssetIds, {'share'});
      },
    );

    test('asset filter restricts what counts', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          asset: 'eur',
          amount: '100',
          holderAfter: '100',
        ),
        incomeRow(
          'b',
          CalendarDate(2026, 5, 1),
          holder: 'h2',
          asset: 'share',
          amount: '10',
          holderAfter: '10',
        ),
      ]);
      final data = build(
        f,
        include: (id) => id == 'share',
        prices: [priceRow('share', CalendarDate(2026, 1, 1), '2')],
      );
      expect(data.series.map((s) => s.containerId), ['h2']);
      expect(data.net.first, 20);
    });

    test('single-asset filter keeps raw units, no conversion', () {
      final f = forecasterFor([
        incomeRow(
          'a',
          CalendarDate(2026, 5, 1),
          holder: 'h1',
          asset: 'btc',
          amount: '2',
          holderAfter: '2',
        ),
      ]);
      final data = build(
        f,
        include: (id) => id == 'btc',
        raw: 'btc',
        display: 'eur',
      );
      expect(data.unitAssetId, 'btc');
      expect(data.net.first, 2);
      expect(data.unpricedAssetIds, isEmpty);
    });

    test('forecast values come from recurring templates after today', () {
      final f = forecasterFor(
        [
          incomeRow(
            'a',
            CalendarDate(2026, 1, 1),
            holder: 'h1',
            amount: '1000',
            holderAfter: '1000',
          ),
        ],
        [
          monthlyExpenseTemplate(
            'rent',
            CalendarDate(2026, 1, 1),
            holder: 'h1',
            amount: '100',
          ),
        ],
      );
      final data = build(f);
      expect(data.net[data.todayIndex], 1000);
      expect(data.net.last, 900);
    });

    test('empty vault gives no bands', () {
      final data = build(forecasterFor([]));
      expect(data.isEmpty, isTrue);
    });

    test(
      'drilling into a container splits it into children + own holdings',
      () {
        final tree = [
          containerRow('parent', 'Parent', type: 'budget'),
          containerRow('kid1', 'Kid 1', type: 'budget', parentId: 'parent'),
          containerRow('kid2', 'Kid 2', type: 'budget', parentId: 'parent'),
        ];
        final f = forecasterFor([
          incomeRow(
            'a',
            CalendarDate(2026, 5, 1),
            budget: 'kid1',
            amount: '10',
            holderAfter: '10',
          ),
          incomeRow(
            'b',
            CalendarDate(2026, 5, 1),
            budget: 'kid2',
            amount: '20',
            holderAfter: '20',
          ),
          incomeRow(
            'c',
            CalendarDate(2026, 5, 1),
            budget: 'parent',
            amount: '5',
            holderAfter: '5',
          ),
        ])..ensureHorizon(CalendarDate(2026, 7, 1));

        List<String> ids(String? focus) => buildBalanceChartData(
          forecaster: f,
          containers: tree,
          priceSnapshots: const [],
          displayAssetId: 'eur',
          includeAsset: (_) => true,
          start: CalendarDate(2026, 6, 1),
          end: CalendarDate(2026, 7, 1),
          focusId: focus,
        ).series.map((s) => s.containerId).toList();

        expect(ids(null), ['parent'], reason: 'subtree rolled into one band');
        expect(ids('parent'), ['parent', 'kid1', 'kid2']);
      },
    );
  });

  group('bandAt', () {
    final data = BalanceChartData(
      dates: [CalendarDate(2026, 1, 1)],
      todayIndex: 0,
      series: const [
        BalanceChartSeries(
          containerId: 'a',
          label: 'A',
          icon: null,
          colorIndex: 0,
          isOwn: false,
          positive: [10],
          debt: [-4],
        ),
        BalanceChartSeries(
          containerId: 'b',
          label: 'B',
          icon: null,
          colorIndex: 1,
          isOwn: false,
          positive: [5],
          debt: [-6],
        ),
      ],
      net: const [5],
      unitAssetId: 'eur',
      unpricedAssetIds: const {},
    );

    test('positive bands stack upward in series order', () {
      expect(bandAt(data, 0, 3), 'a');
      expect(bandAt(data, 0, 12), 'b');
      expect(bandAt(data, 0, 16), isNull);
    });

    test('debt bands stack downward', () {
      expect(bandAt(data, 0, -2), 'a');
      expect(bandAt(data, 0, -7), 'b');
      expect(bandAt(data, 0, -11), isNull);
    });

    test('out-of-range index is a miss', () {
      expect(bandAt(data, 5, 1), isNull);
    });
  });
}
