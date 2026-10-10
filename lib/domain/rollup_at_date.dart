import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import 'balance_chart_data.dart' show priceSeriesByAsset;
import 'balance_forecast.dart';
import 'calendar_date.dart';
import 'container_tree.dart';
import 'multi_asset_rollup.dart';

MultiAssetRollup computeRollupAt({
  required BalanceForecaster forecaster,
  required List<ldb.Container> containers,
  required List<ldb.PriceSnapshot> priceSnapshots,
  required String displayAssetId,
  required CalendarDate date,
  bool Function(String assetId)? includeAsset,
}) {
  forecaster.ensureHorizon(date);
  final prices = priceSeriesByAsset(priceSnapshots, displayAssetId);
  final containerIds = {for (final c in containers) c.id};
  final ownPositive = <String, Decimal>{};
  final ownDebt = <String, Decimal>{};
  final ownHoldings = <String, List<AssetHolding>>{};
  final unconvertible = <String>{};

  for (final pair in forecaster.pairs()) {
    if (!containerIds.contains(pair.containerId)) continue;
    if (includeAsset != null && !includeAsset(pair.assetId)) continue;
    final quantity = forecaster.quantityAt(
      pair.containerId,
      pair.assetId,
      date,
    );
    if (quantity == Decimal.zero) continue;

    final Decimal? price = pair.assetId == displayAssetId
        ? Decimal.one
        : prices[pair.assetId]?.valueAtOrNull(date);
    Decimal? converted;
    if (price == null) {
      unconvertible.addAll(ancestorIds(pair.containerId, containers));
    } else {
      converted = quantity * price;
      final into = quantity > Decimal.zero ? ownPositive : ownDebt;
      into[pair.containerId] =
          (into[pair.containerId] ?? Decimal.zero) + converted;
    }
    (ownHoldings[pair.containerId] ??= []).add(
      AssetHolding(
        assetId: pair.assetId,
        quantity: quantity,
        convertedValue: converted,
      ),
    );
  }
  for (final holdings in ownHoldings.values) {
    holdings.sort((a, b) => a.assetId.compareTo(b.assetId));
  }

  return MultiAssetRollup(
    ownPositive: ownPositive,
    ownDebt: ownDebt,
    ownHoldings: ownHoldings,
    containersWithUnconvertible: unconvertible,
  );
}

Map<String, Decimal> computeSingleAssetBalancesAt({
  required BalanceForecaster forecaster,
  required List<ldb.Container> containers,
  required String assetId,
  required CalendarDate date,
}) {
  forecaster.ensureHorizon(date);
  final result = <String, Decimal>{};
  for (final c in containers) {
    final q = forecaster.quantityAt(c.id, assetId, date);
    if (q != Decimal.zero) result[c.id] = q;
  }
  return result;
}
