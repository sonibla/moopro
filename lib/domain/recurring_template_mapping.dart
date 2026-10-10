import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as cache;
import '../widgets/amount_text.dart' show AmountSign;
import 'models.dart';

RecurringTransactionTemplate recurringTemplateFromRow(
  cache.RecurringTransactionTemplate row,
) => RecurringTransactionTemplate(
  id: row.id,
  kind: TransactionKind.fromJson(row.kind),
  legOut: RecurringLeg(
    containerId: row.legOutContainerId,
    assetId: row.legOutAssetId,
    quantity: Decimal.parse(row.legOutQuantity),
  ),
  legIn: RecurringLeg(
    containerId: row.legInContainerId,
    assetId: row.legInAssetId,
    quantity: Decimal.parse(row.legInQuantity),
  ),
  budgetLegOut: row.budgetLegOutContainerId == null
      ? null
      : RecurringLeg(
          containerId: row.budgetLegOutContainerId!,
          assetId: row.budgetLegOutAssetId!,
          quantity: Decimal.parse(row.budgetLegOutQuantity!),
        ),
  budgetLegIn: row.budgetLegInContainerId == null
      ? null
      : RecurringLeg(
          containerId: row.budgetLegInContainerId!,
          assetId: row.budgetLegInAssetId!,
          quantity: Decimal.parse(row.budgetLegInQuantity!),
        ),
  note: row.note,
  tags: decodeTagsColumn(row.tags),
  rule: RecurrenceRule(
    startDate: row.ruleStartDate,
    unit: RecurrenceUnit.fromJson(row.ruleUnit),
    interval: row.ruleInterval,
    endDate: row.ruleEndDate,
    maxOccurrences: row.ruleMaxOccurrences,
  ),
  lastGeneratedOccurrenceDate: row.lastGeneratedOccurrenceDate,
  active: row.active,
);

Asset assetFromCacheRow(cache.Asset a) => Asset(
  id: a.id,
  kind: AssetKind.fromJson(a.kind),
  symbol: a.symbol,
  name: a.name,
  alphaVantageSymbol: a.alphaVantageSymbol,
  displaySymbol: a.displaySymbol,
);

AmountSign amountSignOfKind(TransactionKind kind) => switch (kind) {
  TransactionKind.income => AmountSign.positive,
  TransactionKind.expense => AmountSign.negative,
  _ => AmountSign.neutral,
};
