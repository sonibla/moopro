import 'package:flutter/material.dart';

import '../domain/conflict_record_display.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'tag_pill_row.dart';

class ConflictRecordSummaryTile extends StatelessWidget {
  final ConflictRecordDisplay display;

  final Widget? trailingAction;
  final VoidCallback? onTap;

  const ConflictRecordSummaryTile({
    super.key,
    required this.display,
    this.trailingAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final detail = display.detailParts.where((p) => p.isNotEmpty).join(' · ');
    final hasTrailing = display.amount != null || trailingAction != null;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: display.iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.avatarTileRadius),
        ),
        child: Icon(display.icon, color: display.iconColor),
      ),
      title: Text(display.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: (detail.isEmpty && display.tags.isEmpty)
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (detail.isNotEmpty)
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (display.tags.isNotEmpty)
                  TagPillRow(tags: display.tags, height: 24),
              ],
            ),
      trailing: !hasTrailing
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (display.amount != null)
                  AmountText(
                    quantity: display.amount!.quantity,
                    asset: display.amount!.asset,
                    sign: display.amount!.sign,
                  ),
                if (display.amount != null && trailingAction != null)
                  const SizedBox(width: 8),
                ?trailingAction,
              ],
            ),
    );
  }
}
