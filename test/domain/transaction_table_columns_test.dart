import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_table_columns.dart';
import 'package:moopro/domain/calendar_date.dart';

ldb.Container _container(
  String id, {
  String? parentId,
  String type = 'budget',
  String? icon,
}) => ldb.Container(
  id: id,
  name: id,
  containerType: type,
  parentId: parentId,
  icon: icon,
  deleted: false,
);

ldb.Transaction _tx({
  required TransactionKind kind,
  required String legOut,
  required String legIn,
  String? budgetLegOut,
  String? budgetLegIn,
}) => ldb.Transaction(
  id: 'tx1',
  postedAt: DateTime.utc(2026, 1, 1),
  effectiveDate: CalendarDate(2026, 1, 1),
  kind: kind.name,
  legOutContainerId: legOut,
  legOutAssetId: 'eur',
  legOutQuantity: '10',
  legInContainerId: legIn,
  legInAssetId: 'eur',
  legInQuantity: '10',
  budgetLegOutContainerId: budgetLegOut,
  budgetLegOutAssetId: budgetLegOut == null ? null : 'eur',
  budgetLegOutQuantity: budgetLegOut == null ? null : '10',
  budgetLegInContainerId: budgetLegIn,
  budgetLegInAssetId: budgetLegIn == null ? null : 'eur',
  budgetLegInQuantity: budgetLegIn == null ? null : '10',
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

void main() {
  final containers = [
    _container('spendings', type: 'budget'),
    _container('restaurants', parentId: 'spendings', type: 'budget'),
    _container('savings', type: 'budget'),
    _container('bank', type: 'holder'),
    _container('revolut', type: 'holder'),
  ];

  test(
    'income: budget path is the budget-leg breadcrumb, holder path is the holder leg',
    () {
      final row = _tx(
        kind: TransactionKind.income,
        legOut: externalHolderContainerId,
        legIn: 'bank',
        budgetLegOut: externalBudgetContainerId,
        budgetLegIn: 'savings',
      );
      final cols = transactionTableColumns(row, containers);
      expect(cols.budget, (name: 'savings', path: 'savings', icon: null));
      expect(cols.holderPath, 'bank');
    },
  );

  test(
    'expense: budget path uses the nested breadcrumb, holder path is the holder leg',
    () {
      final row = _tx(
        kind: TransactionKind.expense,
        legOut: 'bank',
        legIn: externalHolderContainerId,
        budgetLegOut: 'restaurants',
        budgetLegIn: externalBudgetContainerId,
      );
      final cols = transactionTableColumns(row, containers);
      expect(cols.budget, (
        name: 'restaurants',
        path: 'spendings › restaurants',
        icon: null,
      ));
      expect(cols.holderPath, 'bank');
    },
  );

  test('holderTransfer: holder path is "from → to", budget path is null', () {
    final row = _tx(
      kind: TransactionKind.holderTransfer,
      legOut: 'bank',
      legIn: 'revolut',
    );
    final cols = transactionTableColumns(row, containers);
    expect(cols.holderPath, 'bank → revolut');
    expect(cols.budget, isNull);
  });

  test('budgetTransfer: budget path is "from → to", holder path is null', () {
    final row = _tx(
      kind: TransactionKind.budgetTransfer,
      legOut: 'restaurants',
      legIn: 'savings',
    );
    final cols = transactionTableColumns(row, containers);
    expect(cols.budgetFrom, (
      name: 'restaurants',
      path: 'spendings › restaurants',
      icon: null,
    ));
    expect(cols.budgetTo, (name: 'savings', path: 'savings', icon: null));
    expect(cols.holderPath, isNull);
  });

  test('trade: holder path is the single shared holder, budget path is the '
      "trade's shared budget leg (recordTrade always sets one)", () {
    final row = _tx(
      kind: TransactionKind.trade,
      legOut: 'bank',
      legIn: 'bank',
      budgetLegOut: 'restaurants',
      budgetLegIn: 'restaurants',
    );
    final cols = transactionTableColumns(row, containers);
    expect(cols.holderPath, 'bank');
    expect(cols.budget, (
      name: 'restaurants',
      path: 'spendings › restaurants',
      icon: null,
    ));
  });

  test('trade: budget path is null for a trade recorded before trades '
      'required a budget leg (pre-existing data)', () {
    final row = _tx(kind: TransactionKind.trade, legOut: 'bank', legIn: 'bank');
    final cols = transactionTableColumns(row, containers);
    expect(cols.holderPath, 'bank');
    expect(cols.budget, isNull);
  });

  test('carries budget and holder icon keys through to the columns', () {
    final withIcons = [
      _container('savings', icon: 'fa:piggyBank'),
      _container('bank', type: 'holder', icon: 'bank:ing'),
      _container('revolut', type: 'holder'),
    ];
    final income = transactionTableColumns(
      _tx(
        kind: TransactionKind.income,
        legOut: externalHolderContainerId,
        legIn: 'bank',
        budgetLegOut: externalBudgetContainerId,
        budgetLegIn: 'savings',
      ),
      withIcons,
    );
    expect(income.budget!.icon, 'fa:piggyBank');
    expect(income.holderIcon, 'bank:ing');

    final transfer = transactionTableColumns(
      _tx(
        kind: TransactionKind.holderTransfer,
        legOut: 'bank',
        legIn: 'revolut',
      ),
      withIcons,
    );
    expect(transfer.holderIcon, isNull);
  });
}
