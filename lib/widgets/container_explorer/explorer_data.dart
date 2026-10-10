import 'package:decimal/decimal.dart';

import '../../db/domain_cache_database.dart' as ldb;
import '../../domain/balance_forecast.dart';
import '../../domain/calendar_date.dart';
import '../../domain/container_tree.dart';
import '../../domain/models.dart';
import '../../domain/multi_asset_rollup.dart';
import '../../domain/rollup_at_date.dart';
import '../amount_text.dart' show kHiddenAmount;
import '../asset_view_controls.dart';

class ExplorerData {
  final ldb.Asset displayAsset;

  final ldb.Asset chartAsset;

  final MultiAssetRollup fullRollup;

  final Map<String, Decimal> mergedOwnBalances;

  final List<PieTreeNode> chartTree;
  final bool showAmountsInLegend;
  final Map<String, List<AssetHolding>>? holdingsByContainerId;
  final List<AssetHolding>? rootHoldings;

  const ExplorerData({
    required this.displayAsset,
    required this.chartAsset,
    required this.fullRollup,
    required this.mergedOwnBalances,
    required this.chartTree,
    required this.showAmountsInLegend,
    required this.holdingsByContainerId,
    required this.rootHoldings,
  });
}

PieTreeNode _flatNode(
  ldb.Container c,
  List<ldb.Container> all,
  Decimal positive,
  Decimal debt,
) => PieTreeNode(
  id: c.id,
  label: c.name,
  icon: c.icon,
  colorIndex: containerColorIndex(c.id, all),
  value: positive.toDouble(),
  debtValue: debt.toDouble(),
);

ExplorerData computeExplorerData({
  required BalanceForecaster forecaster,
  required List<ldb.Container> containers,
  required List<ldb.PriceSnapshot> priceSnapshots,
  required Map<String, ldb.Asset> assetsById,
  required String displayAssetId,
  required AssetFilter? filter,
  required CalendarDate asOf,
  required bool nested,
  String? focusId,
}) {
  final displayAsset = assetsById[displayAssetId]!;
  final fullRollup = computeRollupAt(
    forecaster: forecaster,
    containers: containers,
    priceSnapshots: priceSnapshots,
    displayAssetId: displayAssetId,
    date: asOf,
  );
  final merged = {
    for (final id in {
      ...fullRollup.ownPositive.keys,
      ...fullRollup.ownDebt.keys,
    })
      id:
          (fullRollup.ownPositive[id] ?? Decimal.zero) +
          (fullRollup.ownDebt[id] ?? Decimal.zero),
  };

  List<PieTreeNode> tree(
    Map<String, Decimal> positive, {
    Map<String, Decimal>? debt,
    Set<String>? unconvertible,
    Iterable<String>? holdingIds,
  }) {
    if (nested) {
      final visible = holdingIds == null
          ? containers
          : () {
              final ids = containersInFilteredSubtree({
                ...holdingIds,
                ?focusId,
              }, containers);
              return containers.where((c) => ids.contains(c.id)).toList();
            }();
      return buildPieTree(
        visible,
        positive,
        null,
        ownDebtBalances: debt,
        containersWithUnconvertible: unconvertible,
        colorSource: containers,
      );
    }
    return [
      for (final c in containers)
        if (holdingIds == null || holdingIds.contains(c.id) || c.id == focusId)
          _flatNode(
            c,
            containers,
            positive[c.id] ?? Decimal.zero,
            debt?[c.id] ?? Decimal.zero,
          ),
    ];
  }

  switch (filter) {
    case null:
      return ExplorerData(
        displayAsset: displayAsset,
        chartAsset: displayAsset,
        fullRollup: fullRollup,
        mergedOwnBalances: merged,
        chartTree: tree(
          fullRollup.ownPositive,
          debt: fullRollup.ownDebt,
          unconvertible: fullRollup.containersWithUnconvertible,
        ),
        showAmountsInLegend: true,
        holdingsByContainerId: fullRollup.ownHoldings,
        rootHoldings: mergeHoldingsByAsset(fullRollup.ownHoldings.values),
      );

    case SingleAssetFilter(:final assetId):
      final balances = computeSingleAssetBalancesAt(
        forecaster: forecaster,
        containers: containers,
        assetId: assetId,
        date: asOf,
      );
      final positive = {
        for (final e in balances.entries)
          if (e.value > Decimal.zero) e.key: e.value,
      };
      final debt = {
        for (final e in balances.entries)
          if (e.value < Decimal.zero) e.key: e.value,
      };
      return ExplorerData(
        displayAsset: displayAsset,
        chartAsset: assetsById[assetId]!,
        fullRollup: fullRollup,
        mergedOwnBalances: merged,
        chartTree: nested
            ? tree(balances, holdingIds: balances.keys)
            : tree(positive, debt: debt, holdingIds: balances.keys),
        showAmountsInLegend: false,
        holdingsByContainerId: null,
        rootHoldings: null,
      );

    case AssetKindFilterSelection(:final kind):
      final kindRollup = computeRollupAt(
        forecaster: forecaster,
        containers: containers,
        priceSnapshots: priceSnapshots,
        displayAssetId: displayAssetId,
        date: asOf,
        includeAsset: (id) => assetsById[id]?.kind == kind.name,
      );
      return ExplorerData(
        displayAsset: displayAsset,
        chartAsset: displayAsset,
        fullRollup: fullRollup,
        mergedOwnBalances: merged,
        chartTree: tree(
          kindRollup.ownPositive,
          debt: kindRollup.ownDebt,
          holdingIds: {
            ...kindRollup.ownPositive.keys,
            ...kindRollup.ownDebt.keys,
          },
        ),
        showAmountsInLegend: true,
        holdingsByContainerId: null,
        rootHoldings: null,
      );
  }
}

String explorerAmountLabel(
  double value,
  ldb.Asset asset, {
  bool hidden = false,
}) {
  if (hidden) return '$kHiddenAmount ${asset.symbol}';
  final decimals = asset.kind == AssetKind.crypto.name ? 8 : 2;
  return '${value.toStringAsFixed(decimals)} ${asset.symbol}';
}
