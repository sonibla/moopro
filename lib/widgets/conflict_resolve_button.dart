import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../sync/sync_engine.dart';

class ConflictResolveButton extends ConsumerWidget {
  final String recordId;
  final VoidCallback? onPressed;

  final double? size;

  const ConflictResolveButton({
    super.key,
    required this.recordId,
    required this.onPressed,
    this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicted = ref.watch(
      recordSyncStatusesProvider.select(
        (async) =>
            (async.value?[recordId] ?? RecordSyncStatus.synced) ==
            RecordSyncStatus.conflicted,
      ),
    );
    if (!conflicted) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      tooltip: 'Sync conflict — tap to resolve',
      onPressed: onPressed,
      padding: size == null ? null : EdgeInsets.zero,
      constraints: size == null
          ? null
          : BoxConstraints.tightFor(width: size, height: size),
    );
  }
}
