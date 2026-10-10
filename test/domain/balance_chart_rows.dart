import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/models.dart';

ldb.Transaction incomeRow(
  String id,
  CalendarDate day, {
  String holder = 'h1',
  String budget = 'b1',
  String asset = 'eur',
  required String amount,
  required String holderAfter,
  String? budgetAfter,
  DateTime? postedAt,
  int manualOrderRank = 0,
}) => ldb.Transaction(
  id: id,
  postedAt: postedAt ?? day.toDateTime(),
  effectiveDate: day,
  kind: TransactionKind.income.name,
  legOutContainerId: externalHolderContainerId,
  legOutAssetId: asset,
  legOutQuantity: amount,
  legInContainerId: holder,
  legInAssetId: asset,
  legInQuantity: amount,
  legInBalanceAfter: holderAfter,
  budgetLegOutContainerId: externalBudgetContainerId,
  budgetLegOutAssetId: asset,
  budgetLegOutQuantity: amount,
  budgetLegInContainerId: budget,
  budgetLegInAssetId: asset,
  budgetLegInQuantity: amount,
  budgetLegInBalanceAfter: budgetAfter ?? holderAfter,
  tags: '[]',
  manualOrderRank: manualOrderRank,
  deleted: false,
);

ldb.Transaction expenseRow(
  String id,
  CalendarDate day, {
  String holder = 'h1',
  String budget = 'b1',
  String asset = 'eur',
  required String amount,
  required String holderAfter,
  String? budgetAfter,
  DateTime? postedAt,
}) => ldb.Transaction(
  id: id,
  postedAt: postedAt ?? day.toDateTime(),
  effectiveDate: day,
  kind: TransactionKind.expense.name,
  legOutContainerId: holder,
  legOutAssetId: asset,
  legOutQuantity: amount,
  legOutBalanceAfter: holderAfter,
  legInContainerId: externalHolderContainerId,
  legInAssetId: asset,
  legInQuantity: amount,
  budgetLegOutContainerId: budget,
  budgetLegOutAssetId: asset,
  budgetLegOutQuantity: amount,
  budgetLegOutBalanceAfter: budgetAfter ?? holderAfter,
  budgetLegInContainerId: externalBudgetContainerId,
  budgetLegInAssetId: asset,
  budgetLegInQuantity: amount,
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

ldb.RecurringTransactionTemplate monthlyExpenseTemplate(
  String id,
  CalendarDate start, {
  String holder = 'h1',
  String budget = 'b1',
  String asset = 'eur',
  required String amount,
  bool active = true,
  CalendarDate? endDate,
}) => ldb.RecurringTransactionTemplate(
  id: id,
  kind: TransactionKind.expense.name,
  legOutContainerId: holder,
  legOutAssetId: asset,
  legOutQuantity: amount,
  legInContainerId: externalHolderContainerId,
  legInAssetId: asset,
  legInQuantity: amount,
  budgetLegOutContainerId: budget,
  budgetLegOutAssetId: asset,
  budgetLegOutQuantity: amount,
  budgetLegInContainerId: externalBudgetContainerId,
  budgetLegInAssetId: asset,
  budgetLegInQuantity: amount,
  tags: '[]',
  ruleUnit: RecurrenceUnit.month.name,
  ruleInterval: 1,
  ruleStartDate: start,
  ruleEndDate: endDate,
  active: active,
  deleted: false,
);

ldb.Container containerRow(
  String id,
  String name, {
  String type = 'holder',
  String? parentId,
}) => ldb.Container(
  id: id,
  name: name,
  containerType: type,
  parentId: parentId,
  deleted: false,
);

ldb.PriceSnapshot priceRow(
  String assetId,
  CalendarDate day,
  String price, {
  String currency = 'eur',
}) => ldb.PriceSnapshot(
  id: '$assetId-${day.toIso()}',
  assetId: assetId,
  date: day.toDateTime(),
  price: price,
  currencyAssetId: currency,
  source: 'manual',
  deleted: false,
);
