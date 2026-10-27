import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as cache;
import 'models.dart';

MoneyContainer containerFromCacheRow(cache.Container c) => MoneyContainer(
  id: c.id,
  name: c.name,
  containerType: ContainerType.fromJson(c.containerType),
  parentId: c.parentId,
  icon: c.icon,
);

MoneyTransaction transactionFromCacheRow(cache.Transaction t) =>
    MoneyTransaction(
      id: t.id,
      postedAt: t.postedAt,
      effectiveDate: t.effectiveDate,
      note: t.note,
      kind: TransactionKind.fromJson(t.kind),
      legOut: TransactionLeg(
        containerId: t.legOutContainerId,
        assetId: t.legOutAssetId,
        quantity: Decimal.parse(t.legOutQuantity),
      ),
      legIn: TransactionLeg(
        containerId: t.legInContainerId,
        assetId: t.legInAssetId,
        quantity: Decimal.parse(t.legInQuantity),
      ),
      budgetLegOut: t.budgetLegOutContainerId == null
          ? null
          : TransactionLeg(
              containerId: t.budgetLegOutContainerId!,
              assetId: t.budgetLegOutAssetId!,
              quantity: Decimal.parse(t.budgetLegOutQuantity!),
            ),
      budgetLegIn: t.budgetLegInContainerId == null
          ? null
          : TransactionLeg(
              containerId: t.budgetLegInContainerId!,
              assetId: t.budgetLegInAssetId!,
              quantity: Decimal.parse(t.budgetLegInQuantity!),
            ),
      tags: decodeTagsColumn(t.tags),
      manualOrderRank: t.manualOrderRank,
    );

PriceSnapshot priceSnapshotFromCacheRow(cache.PriceSnapshot p) => PriceSnapshot(
  id: p.id,
  assetId: p.assetId,
  date: p.date,
  price: Decimal.parse(p.price),
  currencyAssetId: p.currencyAssetId,
  source: PriceSnapshotSource.fromJson(p.source),
);
