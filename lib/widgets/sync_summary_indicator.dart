import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/auth_controller.dart';
import '../screens/attach_to_account_screen.dart';
import '../screens/sync_status_screen.dart';

class SyncStatusDisplay {
  final IconData icon;
  final String label;
  final Color Function(ThemeData theme) color;

  const SyncStatusDisplay({
    required this.icon,
    required this.label,
    required this.color,
  });
}

SyncStatusDisplay computeSyncStatusDisplay({
  required SyncSummary summary,
  required bool? serverAvailable,
}) {
  if (summary.conflictedCount > 0) {
    return SyncStatusDisplay(
      icon: Icons.error_outline,
      label: summary.conflictedCount == 1
          ? 'Sync error'
          : 'Sync error (${summary.conflictedCount})',
      color: (theme) => theme.colorScheme.error,
    );
  }
  if (serverAvailable == false) {
    return SyncStatusDisplay(
      icon: Icons.cloud_off,
      label: 'Offline',
      color: (theme) => theme.colorScheme.onSurfaceVariant,
    );
  }
  if (summary.pendingCount > 0) {
    return SyncStatusDisplay(
      icon: Icons.cloud_upload_outlined,
      label: '${summary.pendingCount} pending',
      color: (theme) => theme.colorScheme.onSurfaceVariant,
    );
  }
  return SyncStatusDisplay(
    icon: Icons.cloud_done_outlined,
    label: 'All changes saved',
    color: (theme) => theme.colorScheme.onSurfaceVariant,
  );
}

class SyncSummaryIndicator extends ConsumerWidget {
  const SyncSummaryIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverAvailable = ref.watch(serverAvailableProvider);
    final isOfflineVault =
        ref.watch(authControllerProvider) is AuthOfflineReady;
    if (isOfflineVault && serverAvailable.value == true) {
      return TextButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AttachToAccountScreen()),
        ),
        icon: const Icon(Icons.login, size: 18),
        label: const Text('Log in to sync'),
      );
    }

    final summary = ref.watch(syncSummaryProvider);
    final theme = Theme.of(context);
    final display = computeSyncStatusDisplay(
      summary: summary,
      serverAvailable: serverAvailable.value,
    );
    final color = display.color(theme);

    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(display.icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              display.label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
