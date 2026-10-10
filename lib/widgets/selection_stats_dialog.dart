import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/selection_stats.dart';
import '../domain/transaction_kind_style.dart';
import 'amount_text.dart';

Future<void> showSelectionStatsDialog(
  BuildContext context,
  SelectionStats stats,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SelectionStatsDialog(stats: stats),
  );
}

class _SelectionStatsDialog extends StatelessWidget {
  final SelectionStats stats;
  const _SelectionStatsDialog({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = stats.firstDate, last = stats.lastDate;
    return AlertDialog(
      title: Text('${stats.count} transaction${stats.count == 1 ? '' : 's'}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (first != null && last != null)
                Text(
                  first == last ? '$first' : '$first → $last',
                  style: theme.textTheme.bodySmall,
                ),
              for (final k in stats.byKind) ...[
                const SizedBox(height: 16),
                _KindSection(stats: k),
              ],
              if (stats.net.isNotEmpty) ...[
                const Divider(height: 32),
                Text(
                  'Net (income − expense)',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                for (final t in stats.net) _signedAmount(t),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

Widget _signedAmount(AssetTotal t) => Align(
  alignment: Alignment.centerRight,
  child: AmountText(
    quantity: t.total,
    asset: t.asset,
    sign: t.total > Decimal.zero
        ? AmountSign.positive
        : t.total < Decimal.zero
        ? AmountSign.negative
        : AmountSign.neutral,
  ),
);

class _KindSection extends StatelessWidget {
  final KindStats stats;
  const _KindSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = stats.kind;
    final color = TransactionKindStyle.colorOf(kind, theme.brightness);
    final isTrade = kind == TransactionKind.trade;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(TransactionKindStyle.iconOf(kind), color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                TransactionKindStyle.labels[kind]!,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text('×${stats.count}', style: theme.textTheme.titleSmall),
          ],
        ),
        if (isTrade) Text('paid', style: theme.textTheme.bodySmall),
        for (final t in stats.totals)
          Align(
            alignment: Alignment.centerRight,
            child: AmountText(
              quantity: t.total,
              asset: t.asset,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        if (isTrade && stats.totalsIn.isNotEmpty) ...[
          Text('received', style: theme.textTheme.bodySmall),
          for (final t in stats.totalsIn)
            Align(
              alignment: Alignment.centerRight,
              child: AmountText(
                quantity: t.total,
                asset: t.asset,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
        ],
      ],
    );
  }
}
