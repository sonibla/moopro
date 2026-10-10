import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class ConsistencyWarningIndicator extends ConsumerWidget {
  const ConsistencyWarningIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consistency = ref.watch(holderBudgetConsistencyProvider).value;
    if (consistency == null || consistency.isConsistent) {
      return const SizedBox.shrink();
    }

    final assetsById = {
      for (final a in ref.watch(assetsStreamProvider).value ?? const [])
        a.id: a,
    };
    String label(String assetId) => assetsById[assetId]?.symbol ?? assetId;

    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    final detail = consistency.mismatchesByAsset.keys
        .map((assetId) {
          final holderQty = consistency.holderBalances[assetId] ?? Decimal.zero;
          final budgetQty = consistency.budgetBalances[assetId] ?? Decimal.zero;
          return '${label(assetId)}: holders $holderQty vs budgets $budgetQty';
        })
        .join('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Tooltip(
        message:
            'Holders and budgets disagree on how much of some asset '
            'they hold — a trade may have converted an asset without '
            'updating a budget.\n$detail',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              'Out of sync',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
