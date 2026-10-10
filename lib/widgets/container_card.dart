import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'container_icon.dart';
import 'sync_status_icon.dart';

class ContainerCard extends StatelessWidget {
  final String name;
  final String? icon;
  final ContainerType containerType;
  final Decimal value;
  final Asset valueAsset;
  final String recordId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final VoidCallback? onResolveConflict;

  const ContainerCard({
    super.key,
    required this.name,
    this.icon,
    required this.containerType,
    required this.value,
    required this.valueAsset,
    required this.recordId,
    this.onTap,
    this.onLongPress,
    this.onResolveConflict,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ContainerName(
                        name,
                        icon: icon,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        containerType == ContainerType.holder
                            ? 'Holder'
                            : 'Budget',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AmountText(quantity: value, asset: valueAsset),
                    const SizedBox(height: 2),
                    SyncStatusIcon(
                      recordId: recordId,
                      onTap: onResolveConflict,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
