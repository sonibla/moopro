import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import 'balance_engine.dart';
import 'models.dart';

class HolderBudgetConsistency {
  final Map<String, Decimal> holderBalances;

  final Map<String, Decimal> budgetBalances;

  final Map<String, Decimal> mismatchesByAsset;

  const HolderBudgetConsistency({
    required this.holderBalances,
    required this.budgetBalances,
    required this.mismatchesByAsset,
  });

  bool get isConsistent => mismatchesByAsset.isEmpty;
}

Map<String, Decimal> _sumBalances(
  Map<String, Map<String, Decimal>> perContainer,
) {
  final result = <String, Decimal>{};
  for (final balances in perContainer.values) {
    for (final entry in balances.entries) {
      result[entry.key] = (result[entry.key] ?? Decimal.zero) + entry.value;
    }
  }
  return result;
}

Future<HolderBudgetConsistency> computeHolderBudgetConsistency({
  required BalanceEngine balanceEngine,
  required List<ldb.Container> containers,
}) async {
  bool isTracked(ldb.Container c) =>
      c.id != externalHolderContainerId && c.id != externalBudgetContainerId;

  final holders = containers
      .where(
        (c) => c.containerType == ContainerType.holder.name && isTracked(c),
      )
      .toList();
  final budgets = containers
      .where(
        (c) => c.containerType == ContainerType.budget.name && isTracked(c),
      )
      .toList();

  final holderPerContainer = <String, Map<String, Decimal>>{};
  for (final h in holders) {
    holderPerContainer[h.id] = await balanceEngine.assetBalances(h.id);
  }
  final budgetPerContainer = <String, Map<String, Decimal>>{};
  for (final b in budgets) {
    budgetPerContainer[b.id] = await balanceEngine.assetBalances(b.id);
  }

  final holderBalances = _sumBalances(holderPerContainer);
  final budgetBalances = _sumBalances(budgetPerContainer);

  final mismatchesByAsset = <String, Decimal>{};
  for (final assetId in {...holderBalances.keys, ...budgetBalances.keys}) {
    final diff =
        (holderBalances[assetId] ?? Decimal.zero) -
        (budgetBalances[assetId] ?? Decimal.zero);
    if (diff != Decimal.zero) mismatchesByAsset[assetId] = diff;
  }

  return HolderBudgetConsistency(
    holderBalances: holderBalances,
    budgetBalances: budgetBalances,
    mismatchesByAsset: mismatchesByAsset,
  );
}
