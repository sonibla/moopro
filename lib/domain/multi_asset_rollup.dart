import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import 'balance_engine.dart';
import 'container_tree.dart';
import 'models.dart';
import 'price_engine.dart';

class AssetHolding {
  final String assetId;
  final Decimal quantity;
  final Decimal? convertedValue;

  const AssetHolding({
    required this.assetId,
    required this.quantity,
    required this.convertedValue,
  });
}

class MultiAssetRollup {
  final Map<String, Decimal> ownPositive;

  final Map<String, Decimal> ownDebt;

  final Map<String, List<AssetHolding>> ownHoldings;

  final Set<String> containersWithUnconvertible;

  const MultiAssetRollup({
    required this.ownPositive,
    required this.ownDebt,
    required this.ownHoldings,
    required this.containersWithUnconvertible,
  });
}

Future<MultiAssetRollup> computeMultiAssetRollup({
  required BalanceEngine balanceEngine,
  required PriceEngine priceEngine,
  required List<ldb.Container> containers,
  required String displayAssetId,
  DateTime? asOf,
}) {
  return _computeRollup(
    balanceEngine: balanceEngine,
    priceEngine: priceEngine,
    containers: containers,
    displayAssetId: displayAssetId,
    asOf: asOf,
    includeAsset: (_) => true,
  );
}

Future<MultiAssetRollup> computeAssetKindRollup({
  required BalanceEngine balanceEngine,
  required PriceEngine priceEngine,
  required List<ldb.Container> containers,
  required String displayAssetId,
  required AssetKind kind,
  required Map<String, ldb.Asset> assetsById,
  DateTime? asOf,
}) {
  return _computeRollup(
    balanceEngine: balanceEngine,
    priceEngine: priceEngine,
    containers: containers,
    displayAssetId: displayAssetId,
    asOf: asOf,
    includeAsset: (assetId) => assetsById[assetId]?.kind == kind.name,
  );
}

Future<MultiAssetRollup> _computeRollup({
  required BalanceEngine balanceEngine,
  required PriceEngine priceEngine,
  required List<ldb.Container> containers,
  required String displayAssetId,
  required bool Function(String assetId) includeAsset,
  DateTime? asOf,
}) async {
  final effectiveAsOf = asOf ?? DateTime.now();
  final ownPositive = <String, Decimal>{};
  final ownDebt = <String, Decimal>{};
  final ownHoldings = <String, List<AssetHolding>>{};
  final containersWithUnconvertible = <String>{};

  for (final container in containers) {
    final balances = await balanceEngine.assetBalances(container.id);
    final holdings = <AssetHolding>[];
    for (final entry in balances.entries) {
      final assetId = entry.key;
      if (!includeAsset(assetId)) continue;
      final quantity = entry.value;
      final price = await priceEngine.latestPrice(
        assetId,
        displayAssetId,
        effectiveAsOf,
      );
      Decimal? convertedValue;
      if (price != null) {
        convertedValue = quantity * price;
        if (quantity > Decimal.zero) {
          ownPositive[container.id] =
              (ownPositive[container.id] ?? Decimal.zero) + convertedValue;
        } else if (quantity < Decimal.zero) {
          ownDebt[container.id] =
              (ownDebt[container.id] ?? Decimal.zero) + convertedValue;
        }
      } else {
        containersWithUnconvertible.addAll(
          ancestorIds(container.id, containers),
        );
      }
      holdings.add(
        AssetHolding(
          assetId: assetId,
          quantity: quantity,
          convertedValue: convertedValue,
        ),
      );
    }
    if (holdings.isNotEmpty) ownHoldings[container.id] = holdings;
  }

  return MultiAssetRollup(
    ownPositive: ownPositive,
    ownDebt: ownDebt,
    ownHoldings: ownHoldings,
    containersWithUnconvertible: containersWithUnconvertible,
  );
}

Future<Map<String, Decimal>> computeSingleAssetBalances({
  required BalanceEngine balanceEngine,
  required List<ldb.Container> containers,
  required String assetId,
}) async {
  final result = <String, Decimal>{};
  for (final container in containers) {
    final balances = await balanceEngine.assetBalances(container.id);
    final quantity = balances[assetId];
    if (quantity != null) result[container.id] = quantity;
  }
  return result;
}

Set<String> containersInFilteredSubtree(
  Iterable<String> directlyHoldingIds,
  List<ldb.Container> containers,
) {
  final result = <String>{};
  for (final id in directlyHoldingIds) {
    result.addAll(ancestorIds(id, containers));
  }
  return result;
}

List<AssetHolding> mergeHoldingsByAsset(
  Iterable<List<AssetHolding>> perContainer,
) {
  final byAsset = <String, AssetHolding>{};
  for (final holdings in perContainer) {
    for (final holding in holdings) {
      final existing = byAsset[holding.assetId];
      byAsset[holding.assetId] = existing == null
          ? holding
          : AssetHolding(
              assetId: holding.assetId,
              quantity: existing.quantity + holding.quantity,
              convertedValue:
                  (existing.convertedValue != null &&
                      holding.convertedValue != null)
                  ? existing.convertedValue! + holding.convertedValue!
                  : null,
            );
    }
  }
  final result = byAsset.values.toList()
    ..sort((a, b) => a.assetId.compareTo(b.assetId));
  return result;
}

Future<Map<String, Map<String, Decimal>>> computeHoldingsByAssetAndContainer({
  required BalanceEngine balanceEngine,
  required List<ldb.Container> containers,
}) async {
  final result = <String, Map<String, Decimal>>{};
  for (final container in containers) {
    final balances = await balanceEngine.assetBalances(container.id);
    for (final entry in balances.entries) {
      (result[entry.key] ??= {})[container.id] = entry.value;
    }
  }
  return result;
}
