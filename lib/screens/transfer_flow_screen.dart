import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/container_tree.dart';
import '../domain/transaction_list_grouping.dart';
import '../domain/transfer_flow.dart';
import '../providers/app_providers.dart';
import '../widgets/amount_text.dart';
import '../widgets/pie_chart_card.dart' show categoricalColor;
import '../widgets/transfer_flow_chart.dart';

Future<void> showTransferFlow(
  BuildContext context,
  TransactionGroupItem group,
) {
  final screen = TransferFlowScreen(group: group);
  if (MediaQuery.sizeOf(context).width > 900) {
    return showDialog<void>(context: context, builder: (_) => screen);
  }
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class TransferFlowScreen extends ConsumerWidget {
  final TransactionGroupItem group;

  const TransferFlowScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final containers = ref.watch(containersStreamProvider).value ?? const [];
    final names = {for (final c in containers) c.id: c.name};
    final flow = TransferFlow.fromGroup(group, (id) => names[id] ?? id);
    final wide = MediaQuery.sizeOf(context).width > 900;
    final title = '${group.sourceName} · ${group.leafIds.length} transfers';

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total moved ${formatAssetQuantity(group.total, group.asset, hidden: ref.watch(hideAmountsProvider))}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TransferFlowChart(
            flow: flow,
            colorOf: (id) =>
                categoricalColor(containerColorIndex(id, containers)),
          ),
        ],
      ),
    );

    if (wide) {
      final screen = MediaQuery.sizeOf(context);
      final width = (TransferFlowChart.widthFor(flow) + 32).clamp(
        360.0,
        screen.width - 80,
      );
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(
            width: width,
          ).copyWith(maxHeight: screen.height - 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Flexible(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
