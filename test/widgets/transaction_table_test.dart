import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/date_time_format_prefs.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_list_grouping.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/amount_text.dart';
import 'package:moopro/widgets/transaction_table.dart';
import 'package:moopro/domain/calendar_date.dart';

const _eur = Asset(
  id: 'eur',
  kind: AssetKind.fiat,
  symbol: 'EUR',
  name: 'Euro',
  displaySymbol: '€',
);
const _btc = Asset(
  id: 'btc',
  kind: AssetKind.crypto,
  symbol: 'BTC',
  name: 'Bitcoin',
);

ldb.Transaction _tradeTx({required String id, String? budgetId}) =>
    ldb.Transaction(
      id: id,
      postedAt: DateTime.utc(2026, 1, 1),
      effectiveDate: CalendarDate(2026, 1, 1),
      kind: TransactionKind.trade.name,
      legOutContainerId: 'bank',
      legOutAssetId: 'eur',
      legOutQuantity: '500',
      legInContainerId: 'bank',
      legInAssetId: 'btc',
      legInQuantity: '0.0071',
      budgetLegOutContainerId: budgetId,
      budgetLegOutAssetId: budgetId == null ? null : 'eur',
      budgetLegOutQuantity: budgetId == null ? null : '500',
      budgetLegInContainerId: budgetId,
      budgetLegInAssetId: budgetId == null ? null : 'btc',
      budgetLegInQuantity: budgetId == null ? null : '0.0071',
      tags: '[]',
      manualOrderRank: 0,
      deleted: false,
    );

TransactionRowItem _tradeRow({String id = 'trade1', String? budgetId}) {
  final row = _tradeTx(id: id, budgetId: budgetId);
  return TransactionRowItem(
    row: row,
    id: id,
    effectiveDate: row.effectiveDate,
    postedAt: row.postedAt,
    title: 'Bought BTC',
    displayQuantity: Decimal.parse('500'),
    displayAsset: _eur,
    tradeQuantityIn: Decimal.parse('0.0071'),
    tradeAssetIn: _btc,
    sign: AmountSign.neutral,
    kind: TransactionKind.trade,
  );
}

ldb.Transaction _incomeTx({required String id}) => ldb.Transaction(
  id: id,
  postedAt: DateTime.utc(2026, 1, 1),
  effectiveDate: CalendarDate(2026, 1, 1),
  kind: TransactionKind.income.name,
  legOutContainerId: externalHolderContainerId,
  legOutAssetId: 'eur',
  legOutQuantity: '500',
  legInContainerId: 'bank',
  legInAssetId: 'eur',
  legInQuantity: '500',
  budgetLegOutContainerId: externalBudgetContainerId,
  budgetLegOutAssetId: 'eur',
  budgetLegOutQuantity: '500',
  budgetLegInContainerId: 'investments',
  budgetLegInAssetId: 'eur',
  budgetLegInQuantity: '500',
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

TransactionRowItem _incomeRow({String id = 'income1', int clusterSize = 1}) {
  final row = _incomeTx(id: id);
  return TransactionRowItem(
    row: row,
    id: id,
    effectiveDate: row.effectiveDate,
    postedAt: row.postedAt,
    title: 'Bank · Investments',
    displayQuantity: Decimal.parse('500'),
    displayAsset: _eur,
    sign: AmountSign.positive,
    kind: TransactionKind.income,
    reorderClusterId: clusterSize > 1 ? 'c' : null,
    reorderClusterSize: clusterSize,
  );
}

Widget _wrap(
  List<TransactionListItem> rows, {
  List<ldb.Container> containers = const [],
  DateTimeFormatPrefs prefs = DateTimeFormatPrefs.defaults,
  void Function(TransactionRowItem)? onReorder,
  void Function(TransactionRowItem)? onMakeRecurring,
  Set<String> selectedIds = const {},
  void Function(Iterable<String>, bool)? onSetSelected,
}) => ProviderScope(
  overrides: [
    recordSyncStatusesProvider.overrideWith((ref) => Stream.value(const {})),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: TransactionTable(
        items: rows,
        containers: containers,
        selectedIds: selectedIds,
        onTapRow: (_) {},
        onSelectedChanged: (_, _) {},
        onSetSelected: onSetSelected ?? (_, _) {},
        onDelete: (_) {},
        onResolveConflict: (_) {},
        dateTimeFormatPrefs: prefs,
        onReorderCluster: onReorder,
        onMakeRecurring: onMakeRecurring,
      ),
    ),
  ),
);

void main() {
  final containers = [
    const ldb.Container(
      id: 'bank',
      name: 'Bank',
      containerType: 'holder',
      deleted: false,
    ),
    const ldb.Container(
      id: 'investments',
      name: 'Investments',
      containerType: 'budget',
      deleted: false,
    ),
  ];

  group('container icons', () {
    ldb.Container c(String id, String type, String? icon) => ldb.Container(
      id: id,
      name: id,
      containerType: type,
      icon: icon,
      deleted: false,
    );

    TransactionRowItem transferRow(
      TransactionKind kind, {
      required String out,
      required String into,
    }) {
      final row = ldb.Transaction(
        id: 't1',
        postedAt: DateTime.utc(2026, 1, 1),
        effectiveDate: CalendarDate(2026, 1, 1),
        kind: kind.name,
        legOutContainerId: out,
        legOutAssetId: 'eur',
        legOutQuantity: '10',
        legInContainerId: into,
        legInAssetId: 'eur',
        legInQuantity: '10',
        tags: '[]',
        manualOrderRank: 0,
        deleted: false,
      );
      return TransactionRowItem(
        row: row,
        id: 't1',
        effectiveDate: row.effectiveDate,
        postedAt: row.postedAt,
        title: 'Transfer',
        displayQuantity: Decimal.parse('10'),
        displayAsset: _eur,
        sign: AmountSign.neutral,
        kind: kind,
      );
    }

    testWidgets('a holder transfer shows both holders\' icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          [transferRow(TransactionKind.holderTransfer, out: 'h1', into: 'h2')],
          containers: [
            c('h1', 'holder', 'fa:solidHouse'),
            c('h2', 'holder', 'fa:bitcoin'),
          ],
        ),
      );
      expect(find.byType(FaIcon), findsNWidgets(2));
      expect(find.textContaining('h1'), findsOneWidget);
      expect(find.textContaining('h2'), findsOneWidget);
    });

    testWidgets('a holder transfer with only one icon shows just that one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          [transferRow(TransactionKind.holderTransfer, out: 'h1', into: 'h2')],
          containers: [
            c('h1', 'holder', null),
            c('h2', 'holder', 'fa:bitcoin'),
          ],
        ),
      );
      expect(find.byType(FaIcon), findsOneWidget);
    });

    testWidgets('a budget transfer shows both budgets\' icons', (tester) async {
      await tester.pumpWidget(
        _wrap(
          [transferRow(TransactionKind.budgetTransfer, out: 'b1', into: 'b2')],
          containers: [
            c('b1', 'budget', 'fa:solidHouse'),
            c('b2', 'budget', 'fa:bitcoin'),
          ],
        ),
      );
      expect(find.byType(FaIcon), findsNWidgets(2));
    });

    testWidgets('an income row shows its budget and holder icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          [_incomeRow()],
          containers: [
            c('bank', 'holder', 'fa:solidHouse'),
            c('investments', 'budget', 'fa:bitcoin'),
          ],
        ),
      );
      expect(find.byType(FaIcon), findsNWidgets(2));
    });
  });

  testWidgets('renders day-section headers between rows', (tester) async {
    await tester.pumpWidget(
      _wrap([
        const DateHeaderItem('Today'),
        _tradeRow(id: 'a'),
        const DateHeaderItem('Yesterday'),
        _tradeRow(id: 'b'),
      ], containers: containers),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(5));
  });

  testWidgets('renders the Now marker between future and current days, '
      'without a checkbox', (tester) async {
    await tester.pumpWidget(
      _wrap([
        const DateHeaderItem('Tomorrow'),
        _tradeRow(id: 'a'),
        const NowMarkerItem(),
        const DateHeaderItem('Today'),
        _tradeRow(id: 'b'),
      ], containers: containers),
    );
    expect(find.byKey(const ValueKey('nowMarker')), findsOneWidget);
    expect(find.text('NOW'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(5));
    expect(
      tester.getSize(find.byKey(const ValueKey('nowMarker'))).height,
      NowMarkerItem.height,
    );
  });

  group('header checkboxes', () {
    List<TransactionListItem> items() => [
      const DateHeaderItem('Today', ['a']),
      _tradeRow(id: 'a'),
      const DateHeaderItem('Yesterday', ['b', 'c']),
      _tradeRow(id: 'b'),
      _tradeRow(id: 'c'),
    ];

    bool? value(WidgetTester tester, int i) =>
        tester.widget<Checkbox>(find.byType(Checkbox).at(i)).value;

    testWidgets('day headers are checked / indeterminate / unchecked from '
        'their rows\' selection', (tester) async {
      await tester.pumpWidget(_wrap(items(), selectedIds: {'a', 'b'}));
      expect(value(tester, 1), isTrue);
      expect(value(tester, 3), isNull);
      expect(value(tester, 0), isNull);
    });

    testWidgets('tapping a day header selects its rows; tapping a fully '
        'selected one deselects them', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _wrap(
          items(),
          selectedIds: {'a'},
          onSetSelected: (ids, v) => calls.add('${ids.join(',')}:$v'),
        ),
      );
      await tester.tap(find.byType(Checkbox).at(3));
      await tester.tap(find.byType(Checkbox).at(1));
      expect(calls, ['b,c:true', 'a:false']);
    });

    testWidgets('the column header selects every row, or none when all '
        'are selected', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _wrap(
          items(),
          onSetSelected: (ids, v) => calls.add('${ids.join(',')}:$v'),
        ),
      );
      await tester.tap(find.byType(Checkbox).at(0));
      expect(calls.single, 'a,b,c:true');

      calls.clear();
      await tester.pumpWidget(
        _wrap(
          items(),
          selectedIds: {'a', 'b', 'c'},
          onSetSelected: (ids, v) => calls.add('${ids.join(',')}:$v'),
        ),
      );
      await tester.tap(find.byType(Checkbox).at(0));
      expect(calls.single, 'a,b,c:false');
    });
  });

  group('trade rows', () {
    testWidgets('renders the give→get pair via TradeAmountText, not a '
        'single-sided AmountText', (tester) async {
      await tester.pumpWidget(
        _wrap([_tradeRow(budgetId: 'investments')], containers: containers),
      );
      await tester.pump();

      expect(find.byType(TradeAmountText), findsOneWidget);
      expect(find.byType(AmountText), findsNothing);
      expect(find.textContaining('500.00 € → 0.00710000 BTC'), findsOneWidget);
    });

    testWidgets('shows the trade\'s budget column instead of leaving it '
        'blank (regression: used to always be "—")', (tester) async {
      await tester.pumpWidget(
        _wrap([_tradeRow(budgetId: 'investments')], containers: containers),
      );
      await tester.pump();

      expect(find.text('Investments'), findsOneWidget);
    });

    testWidgets('a legacy trade with no budget leg still shows "—" '
        'rather than crashing', (tester) async {
      await tester.pumpWidget(
        _wrap([_tradeRow(budgetId: null)], containers: containers),
      );
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
      expect(find.byType(TradeAmountText), findsOneWidget);
    });
  });

  testWidgets(
    'budget transfer shows leaf names, each with its own full-path tooltip',
    (tester) async {
      final tree = [
        ...containers,
        const ldb.Container(
          id: 'spend',
          name: 'Spendings',
          containerType: 'budget',
          deleted: false,
        ),
        const ldb.Container(
          id: 'food',
          name: 'Food',
          containerType: 'budget',
          parentId: 'spend',
          deleted: false,
        ),
      ];
      final base = _incomeTx(id: 'bt1');
      final row = base.copyWith(
        kind: TransactionKind.budgetTransfer.name,
        legOutContainerId: 'food',
        legInContainerId: 'investments',
      );
      final item = TransactionRowItem(
        row: row,
        id: 'bt1',
        effectiveDate: row.effectiveDate,
        postedAt: row.postedAt,
        title: 'Food → Investments',
        displayQuantity: Decimal.parse('500'),
        displayAsset: _eur,
        sign: AmountSign.neutral,
        kind: TransactionKind.budgetTransfer,
      );
      await tester.pumpWidget(_wrap([item], containers: tree));
      await tester.pump();

      String tip(String name) => tester
          .widget<Tooltip>(
            find
                .ancestor(of: find.text(name), matching: find.byType(Tooltip))
                .first,
          )
          .message!;
      expect(tip('Food'), 'Spendings › Food');
      expect(tip('Investments'), 'Investments');
    },
  );

  testWidgets(
    'single-budget rows show the leaf name with the full path as tooltip',
    (tester) async {
      final tree = [
        ...containers.where((c) => c.id != 'investments'),
        const ldb.Container(
          id: 'wealth',
          name: 'Wealth',
          containerType: 'budget',
          deleted: false,
        ),
        const ldb.Container(
          id: 'investments',
          name: 'Investments',
          containerType: 'budget',
          parentId: 'wealth',
          deleted: false,
        ),
      ];
      await tester.pumpWidget(_wrap([_incomeRow()], containers: tree));
      await tester.pump();

      expect(find.text('Wealth › Investments'), findsNothing);
      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(
              of: find.text('Investments'),
              matching: find.byType(Tooltip),
            )
            .first,
      );
      expect(tooltip.message, 'Wealth › Investments');
    },
  );

  testWidgets(
    'a non-trade row still renders the plain single-sided AmountText',
    (tester) async {
      await tester.pumpWidget(_wrap([_incomeRow()], containers: containers));
      await tester.pump();

      expect(find.byType(AmountText), findsOneWidget);
      expect(find.byType(TradeAmountText), findsNothing);
    },
  );

  testWidgets('date column uses the date format from settings', (tester) async {
    for (final (option, text) in [
      (DateFormatOption.ymd, '2026-01-01'),
      (DateFormatOption.dmy, '01/01/2026'),
      (DateFormatOption.mdy, '01/01/2026'),
    ]) {
      await tester.pumpWidget(
        _wrap(
          [_incomeRow()],
          containers: containers,
          prefs: DateTimeFormatPrefs(dateFormat: option, use24HourTime: true),
        ),
      );
      await tester.pump();
      expect(find.text(text), findsOneWidget, reason: option.label);
    }
  });

  group('reorder button', () {
    testWidgets('shows for a same-day cluster and invokes the callback', (
      tester,
    ) async {
      TransactionRowItem? tapped;
      await tester.pumpWidget(
        _wrap(
          [_incomeRow(clusterSize: 3)],
          containers: containers,
          onReorder: (r) => tapped = r,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Reorder 3 same-day entries'));
      expect(tapped?.id, 'income1');
    });

    testWidgets('is hidden for a row that is alone in its cluster', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([_incomeRow()], containers: containers, onReorder: (_) {}),
      );
      await tester.pump();

      expect(find.byIcon(Icons.unfold_more), findsNothing);
    });
  });

  group('make recurring button', () {
    testWidgets('shows for an income row and invokes the callback', (
      tester,
    ) async {
      TransactionRowItem? tapped;
      await tester.pumpWidget(
        _wrap(
          [_incomeRow()],
          containers: containers,
          onMakeRecurring: (r) => tapped = r,
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Make recurring'));
      expect(tapped?.id, 'income1');
    });

    testWidgets('is hidden for a trade row', (tester) async {
      await tester.pumpWidget(
        _wrap([_tradeRow()], containers: containers, onMakeRecurring: (_) {}),
      );
      await tester.pump();

      expect(find.byTooltip('Make recurring'), findsNothing);
    });

    testWidgets('is hidden when the table has no callback', (tester) async {
      await tester.pumpWidget(_wrap([_incomeRow()], containers: containers));
      await tester.pump();

      expect(find.byTooltip('Make recurring'), findsNothing);
    });
  });
}
