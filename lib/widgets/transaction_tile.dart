import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../domain/date_time_format_prefs.dart';
import '../domain/models.dart';
import '../domain/transaction_kind_style.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'sync_status_icon.dart';
import 'tag_pill_row.dart';
import '../domain/calendar_date.dart';

class TransactionTile extends StatelessWidget {
  final CalendarDate date;
  final String? note;
  final String title;
  final Decimal displayQuantity;
  final Asset displayAsset;
  final AmountSign sign;
  final TransactionKind kind;
  final String recordId;

  final Decimal? tradeQuantityIn;
  final Asset? tradeAssetIn;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDateInline;

  final DateTimeFormatPrefs dateTimeFormatPrefs;

  final DateTime? postedAtIfDifferentDay;

  final VoidCallback? onResolveConflict;

  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectedChanged;

  final int? reorderClusterSize;
  final VoidCallback? onReorderCluster;

  final VoidCallback? onMakeRecurring;

  final List<String> tags;

  static const double height = 58;
  static const double _tagsRowHeight = 24;

  static const double _tradeAmountExtraHeight = 18;

  static double heightFor(List<String> tags, {bool isTwoAssetTrade = false}) {
    var h = tags.isEmpty ? height : height + _tagsRowHeight - 4;
    if (isTwoAssetTrade) h += _tradeAmountExtraHeight;
    return h;
  }

  const TransactionTile({
    super.key,
    required this.date,
    this.note,
    required this.title,
    required this.displayQuantity,
    required this.displayAsset,
    required this.sign,
    required this.kind,
    required this.recordId,
    this.tradeQuantityIn,
    this.tradeAssetIn,
    this.onTap,
    this.onLongPress,
    this.showDateInline = true,
    this.dateTimeFormatPrefs = DateTimeFormatPrefs.defaults,
    this.postedAtIfDifferentDay,
    this.onResolveConflict,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectedChanged,
    this.reorderClusterSize,
    this.onReorderCluster,
    this.onMakeRecurring,
    this.tags = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = TransactionKindStyle.iconOf(kind);
    final kindColor = TransactionKindStyle.colorOf(kind, theme.brightness);

    final subtitleParts = [
      if (showDateInline) dateTimeFormatPrefs.formatCalendarDate(date),
      if (note != null && note!.isNotEmpty) note!,
      if (postedAtIfDifferentDay != null)
        'posted ${dateTimeFormatPrefs.formatDate(postedAtIfDifferentDay!)}',
    ];

    final isTwoAssetTrade =
        kind == TransactionKind.trade &&
        tradeQuantityIn != null &&
        tradeAssetIn != null;

    return SizedBox(
      height: heightFor(tags, isTwoAssetTrade: isTwoAssetTrade),
      child: _tile(context, subtitleParts, kindColor, icon),
    );
  }

  Widget _tile(
    BuildContext context,
    List<String> subtitleParts,
    Color kindColor,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: tags.isEmpty
          ? null
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: selectionMode ? () => onSelectedChanged?.call(!selected) : onTap,
      onLongPress: onLongPress,
      leading: selectionMode
          ? Checkbox(
              value: selected,
              onChanged: (v) => onSelectedChanged?.call(v ?? false),
            )
          : Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kindColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.avatarTileRadius),
              ),
              child: Icon(icon, color: kindColor, size: 20),
            ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: subtitleParts.isEmpty && tags.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                if (tags.isNotEmpty)
                  TagPillRow(tags: tags, height: _tagsRowHeight),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reorderClusterSize != null && reorderClusterSize! > 1)
            IconButton(
              icon: const Icon(Icons.unfold_more, size: 20),
              tooltip: 'Reorder $reorderClusterSize same-day entries',
              onPressed: onReorderCluster,
            ),
          if (onMakeRecurring != null)
            IconButton(
              icon: const Icon(Icons.event_repeat, size: 20),
              tooltip: 'Make recurring',
              onPressed: onMakeRecurring,
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (kind == TransactionKind.trade &&
                  tradeQuantityIn != null &&
                  tradeAssetIn != null)
                TradeAmountText(
                  quantityOut: displayQuantity,
                  assetOut: displayAsset,
                  quantityIn: tradeQuantityIn!,
                  assetIn: tradeAssetIn!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.end,
                )
              else
                AmountText(
                  quantity: displayQuantity,
                  asset: displayAsset,
                  sign: sign,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 2),
              SyncStatusIcon(recordId: recordId, onTap: onResolveConflict),
            ],
          ),
        ],
      ),
    );
  }
}
