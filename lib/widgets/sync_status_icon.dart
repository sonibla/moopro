import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../sync/sync_engine.dart';

class SyncStatusIcon extends ConsumerWidget {
  final String recordId;
  final VoidCallback? onTap;

  const SyncStatusIcon({super.key, required this.recordId, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      recordSyncStatusesProvider.select(
        (async) => async.value?[recordId] ?? RecordSyncStatus.synced,
      ),
    );
    final theme = Theme.of(context);
    final IconData icon;
    final Color color;
    final String tooltip;
    switch (status) {
      case RecordSyncStatus.synced:
        icon = Icons.cloud_done_outlined;
        color = theme.colorScheme.onSurfaceVariant;
        tooltip = 'Saved to server';
        break;
      case RecordSyncStatus.pending:
        icon = Icons.cloud_upload_outlined;
        color = theme.colorScheme.onSurfaceVariant;
        tooltip = 'Not yet saved to server';
        break;
      case RecordSyncStatus.conflicted:
        icon = Icons.error_outline;
        color = theme.colorScheme.error;
        tooltip = 'Sync conflict — tap to resolve';
        break;
    }

    final iconWidget = Icon(icon, size: 16, color: color);
    final tappable = status == RecordSyncStatus.conflicted && onTap != null;

    return Tooltip(
      message: tooltip,
      child: tappable
          ? InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: iconWidget,
              ),
            )
          : iconWidget,
    );
  }
}

class GroupSyncStatusIcon extends ConsumerWidget {
  final List<String> recordIds;
  const GroupSyncStatusIcon({super.key, required this.recordIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      recordSyncStatusesProvider.select((async) {
        final map = async.value;
        if (map == null) return RecordSyncStatus.synced;
        var worst = RecordSyncStatus.synced;
        for (final id in recordIds) {
          final s = map[id] ?? RecordSyncStatus.synced;
          if (s == RecordSyncStatus.conflicted) return s;
          if (s == RecordSyncStatus.pending) worst = s;
        }
        return worst;
      }),
    );
    if (status == RecordSyncStatus.synced) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final conflicted = status == RecordSyncStatus.conflicted;
    return Tooltip(
      message: conflicted
          ? 'A transfer in this group has a sync conflict'
          : 'Some transfers in this group are not yet saved to server',
      child: Icon(
        conflicted ? Icons.error_outline : Icons.cloud_upload_outlined,
        size: 16,
        color: conflicted
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
