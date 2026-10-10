import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/balance_forecast.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/date_time_format_prefs.dart';
import 'package:moopro/domain/models.dart' show AssetKind;
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/asset_view_controls.dart';
import 'package:moopro/widgets/balance_chart_section.dart';

import '../domain/balance_chart_rows.dart';

final _today = CalendarDate.today();
CalendarDate _daysAgo(int n) => _today.addDays(-n);

final _eur = ldb.Asset(
  id: 'eur',
  kind: 'fiat',
  symbol: 'EUR',
  name: 'Euro',
  deleted: false,
);
final _coin = ldb.Asset(
  id: 'coin',
  kind: 'crypto',
  symbol: 'COIN',
  name: 'Coin',
  deleted: false,
);
final _share = ldb.Asset(
  id: 'share',
  kind: 'stock',
  symbol: 'SHR',
  name: 'Share',
  deleted: false,
);

Future<void> _pump(
  WidgetTester tester, {
  Stream<List<ldb.Transaction>>? txs,
  Stream<List<ldb.RecurringTransactionTemplate>>? templates,
  Stream<List<ldb.PriceSnapshot>>? prices,
  List<ldb.Container>? containers,
  AssetFilter? filter,
  String? focusId,
  ValueChanged<String?>? onFocusChanged,
  CalendarDate? asOf,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionsStreamProvider.overrideWith(
          (ref) => txs ?? Stream.value(const <ldb.Transaction>[]),
        ),
        recurringTemplatesStreamProvider.overrideWith(
          (ref) =>
              templates ??
              Stream.value(const <ldb.RecurringTransactionTemplate>[]),
        ),
        priceSnapshotsStreamProvider.overrideWith(
          (ref) => prices ?? Stream.value(const <ldb.PriceSnapshot>[]),
        ),
        dateTimeFormatPrefsProvider.overrideWithValue(
          DateTimeFormatPrefs.defaults,
        ),
        balanceForecasterProvider.overrideWithValue(BalanceForecaster()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BalanceChartSection(
              title: 'Balance over time',
              containers:
                  containers ??
                  [containerRow('h1', 'Bank A'), containerRow('h2', 'Bank B')],
              assets: [_eur, _coin, _share],
              displayAssetId: 'eur',
              assetFilter: filter,
              focusId: focusId,
              onFocusChanged: onFocusChanged ?? (_) {},
              asOf: asOf ?? _today,
              onAsOfChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

List<ldb.Transaction> _seedTxs() => [
  incomeRow('a', _daysAgo(60), holder: 'h1', amount: '100', holderAfter: '100'),
  incomeRow('b', _daysAgo(60), holder: 'h2', amount: '40', holderAfter: '40'),
];

List<LineChartBarData> _bars(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;

void main() {
  testWidgets('shows a spinner while the streams have not emitted', (
    tester,
  ) async {
    await _pump(
      tester,
      txs: Stream<List<ldb.Transaction>>.fromFuture(
        Completer<List<ldb.Transaction>>().future,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('a stream error shows the failure state', (tester) async {
    await _pump(
      tester,
      txs: Stream<List<ldb.Transaction>>.error('db exploded'),
    );
    expect(find.textContaining('Failed to load chart'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('an empty vault shows the empty state', (tester) async {
    await _pump(tester);
    expect(find.text('No balance history yet'), findsOneWidget);
  });

  testWidgets('draws a band per container with the history as solid lines', (
    tester,
  ) async {
    await _pump(tester, txs: Stream.value(_seedTxs()));
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Bank A'), findsOneWidget);
    expect(find.text('Bank B'), findsOneWidget);
  });

  testWidgets('a recurring template adds a dashed forecast; "No forecast" '
      'removes it', (tester) async {
    await _pump(
      tester,
      txs: Stream.value(_seedTxs()),
      templates: Stream.value([
        monthlyExpenseTemplate(
          'rent',
          _daysAgo(100),
          holder: 'h1',
          amount: '10',
        ),
      ]),
    );
    expect(_bars(tester).any((b) => b.dashArray != null), isTrue);

    await tester.tap(find.text('No forecast'));
    await tester.pump();
    expect(_bars(tester).every((b) => b.dashArray == null), isTrue);
  });

  testWidgets('a balance with no price in the display asset is flagged, not '
      'guessed', (tester) async {
    await _pump(
      tester,
      txs: Stream.value([
        incomeRow(
          'a',
          _daysAgo(60),
          holder: 'h1',
          amount: '100',
          holderAfter: '100',
        ),
        incomeRow(
          'c',
          _daysAgo(60),
          holder: 'h1',
          asset: 'coin',
          amount: '1',
          holderAfter: '1',
        ),
      ]),
    );
    expect(find.textContaining('left out: COIN'), findsOneWidget);
  });

  testWidgets('the asset-kind filter restricts the bands', (tester) async {
    await _pump(
      tester,
      txs: Stream.value([
        incomeRow(
          'a',
          _daysAgo(60),
          holder: 'h1',
          amount: '100',
          holderAfter: '100',
        ),
        incomeRow(
          's',
          _daysAgo(60),
          holder: 'h2',
          asset: 'share',
          amount: '3',
          holderAfter: '3',
        ),
      ]),
      prices: Stream.value([priceRow('share', _daysAgo(90), '10')]),
      filter: const AssetKindFilterSelection(AssetKind.stock),
    );
    expect(find.text('Bank B'), findsOneWidget);
    expect(find.text('Bank A'), findsNothing);
  });

  final tree = [
    containerRow('parent', 'Parent', type: 'budget'),
    containerRow('kid1', 'Kid 1', type: 'budget', parentId: 'parent'),
    containerRow('kid2', 'Kid 2', type: 'budget', parentId: 'parent'),
  ];
  Stream<List<ldb.Transaction>> kidTxs() => Stream.value([
    incomeRow(
      'a',
      _daysAgo(60),
      budget: 'kid1',
      amount: '10',
      holderAfter: '10',
    ),
    incomeRow(
      'b',
      _daysAgo(60),
      budget: 'kid2',
      amount: '20',
      holderAfter: '20',
    ),
  ]);

  testWidgets('without a focus the top level is one rolled-up band; tapping '
      'its chip reports the container', (tester) async {
    String? reported;
    await _pump(
      tester,
      containers: tree,
      txs: kidTxs(),
      onFocusChanged: (id) => reported = id,
    );
    expect(find.text('Parent'), findsOneWidget, reason: 'one rolled-up band');
    expect(find.text('Kid 1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('balance-legend-parent')));
    expect(reported, 'parent');
  });

  testWidgets('a focused container shows its children as bands; back reports '
      'its parent', (tester) async {
    String? reported = 'unset';
    await _pump(
      tester,
      containers: tree,
      txs: kidTxs(),
      focusId: 'parent',
      onFocusChanged: (id) => reported = id,
    );
    expect(find.text('Balance over time · Parent'), findsOneWidget);
    expect(find.text('Kid 1'), findsOneWidget);
    expect(find.text('Kid 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    expect(reported, isNull);
  });

  testWidgets('a focus on a container that no longer exists falls back to the '
      'top level', (tester) async {
    await _pump(tester, containers: tree, txs: kidTxs(), focusId: 'gone');
    expect(find.text('Balance over time'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });
}
