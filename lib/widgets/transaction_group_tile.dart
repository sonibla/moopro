import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transaction_kind_style.dart';
import '../domain/transaction_list_grouping.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'sync_status_icon.dart';

class TransactionGroupTile extends ConsumerWidget {
  final TransactionGroupItem group;
  final bool expanded;
  final VoidCallback? onToggle;

  final VoidCallback? onShowFlow;

  final bool selectionMode;
  final bool? selectionState;
  final ValueChanged<bool>? onSelectedChanged;

  const TransactionGroupTile({
    super.key,
    required this.group,
    required this.expanded,
    this.onToggle,
    this.onShowFlow,
    this.selectionMode = false,
    this.selectionState = false,
    this.onSelectedChanged,
  });

  static const double _minHeight = 72;
  static const double _destLineHeight = 16;

  static double headerHeight(TransactionGroupItem g) {
    final h = 40 + _destLineHeight * g.destinations.length;
    return h > _minHeight ? h : _minHeight;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final kindColor = TransactionKindStyle.colorOf(
      group.kind,
      theme.brightness,
    );
    final count = group.leafIds.length;
    return SizedBox(
      height: headerHeight(group),
      child: Padding(
        padding: EdgeInsets.only(left: 16.0 * group.depth),
        child: _tile(context, theme, kindColor, count, hidden),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    ThemeData theme,
    Color kindColor,
    int count,
    bool hidden,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.line(theme.brightness)),
        ),
      ),
      child: ListTile(
        tileColor: selectionState == true
            ? AppTheme.accentSoft(theme.brightness)
            : null,
        onTap: selectionMode
            ? () => onSelectedChanged?.call(selectionState != true)
            : onToggle,
        leading: selectionMode
            ? Checkbox(
                tristate: true,
                value: selectionState,
                onChanged: (_) =>
                    onSelectedChanged?.call(selectionState != true),
              )
            : Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kindColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    AppTheme.avatarTileRadius,
                  ),
                ),
                child: Icon(
                  TransactionKindStyle.iconOf(group.kind),
                  color: kindColor,
                  size: 20,
                ),
              ),
        title: Text(
          '${group.sourceName} · $count transfers',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in group.destinations)
              Text(
                '→ ${formatAssetQuantity(d.total, group.asset, hidden: hidden)}  ${d.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onShowFlow != null && !selectionMode)
              IconButton(
                icon: const Icon(Icons.stacked_line_chart, size: 20),
                tooltip: 'Show flow',
                onPressed: onShowFlow,
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  quantity: group.total,
                  asset: group.asset,
                  style: theme.textTheme.bodyMedium,
                ),
                GroupSyncStatusIcon(recordIds: group.leafIds),
              ],
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_more),
            ),
          ],
        ),
      ),
    );
  }
}
