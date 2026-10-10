import 'package:flutter/material.dart';

import '../../domain/container_tree.dart';
import 'package:decimal/decimal.dart';

import '../../domain/multi_asset_rollup.dart';
import '../pie_chart_card.dart';

class ContainerBreakdownCard extends StatefulWidget {
  final List<PieTreeNode> nodes;

  final String? focusId;
  final ValueChanged<String?> onFocusChanged;

  final bool drillDown;
  final String Function(double value)? amountLabel;
  final bool showAmounts;

  final List<AssetHolding>? holdings;
  final String Function(String assetId, Decimal quantity)? holdingQuantityLabel;

  final String? filterNote;
  final Widget? Function(String containerId)? rowTrailing;

  const ContainerBreakdownCard({
    super.key,
    required this.nodes,
    required this.focusId,
    required this.onFocusChanged,
    required this.drillDown,
    required this.amountLabel,
    required this.showAmounts,
    required this.holdings,
    required this.holdingQuantityLabel,
    this.filterNote,
    this.rowTrailing,
  });

  @override
  State<ContainerBreakdownCard> createState() => _ContainerBreakdownCardState();
}

class _ContainerBreakdownCardState extends State<ContainerBreakdownCard> {
  bool _showLiabilities = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusId = widget.focusId;
    final focusNode = widget.drillDown && focusId != null
        ? pieAncestorPath(widget.nodes, focusId)?.last
        : null;
    final hasAnyDebt = widget.nodes.any((n) => n.hasDebt);
    final holdings = widget.holdings;
    final hasHoldings = holdings != null && holdings.isNotEmpty;

    final legend = PieLegendPanel(
      nodes: widget.nodes,
      focusNode: focusNode,
      selectedId: widget.drillDown ? null : focusId,
      onFocus: widget.onFocusChanged,
      amountLabel: widget.amountLabel,
      showAmounts: widget.showAmounts,
      showLiabilities: _showLiabilities,
      rowTrailing: widget.rowTrailing,
    );
    final held = hasHoldings
        ? ActualAssetsHeldPanel(
            holdings: holdings,
            quantityLabel: widget.holdingQuantityLabel,
            amountLabel: widget.amountLabel,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Breakdown', style: theme.textTheme.titleMedium),
                if (widget.filterNote != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.filterNote!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (hasAnyDebt)
                  LiabilitiesToggle(
                    value: _showLiabilities,
                    onChanged: (v) => setState(() => _showLiabilities = v),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                if (held == null) return legend;
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [legend, const SizedBox(height: 16), held],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: legend),
                    const SizedBox(width: 32),
                    Expanded(child: held),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
