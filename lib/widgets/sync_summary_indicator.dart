import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/auth_controller.dart';
import '../screens/attach_to_account_screen.dart';

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

    final IconData icon;
    final String label;
    final Color color;
    if (summary.conflictedCount > 0) {
      icon = Icons.error_outline;
      label = summary.conflictedCount == 1
          ? 'Sync error'
          : 'Sync error (${summary.conflictedCount})';
      color = theme.colorScheme.error;
    } else if (serverAvailable.value == false) {
      icon = Icons.cloud_off;
      label = 'Offline';
      color = theme.colorScheme.onSurfaceVariant;
    } else if (summary.pendingCount > 0) {
      icon = Icons.cloud_upload_outlined;
      label = '${summary.pendingCount} pending';
      color = theme.colorScheme.onSurfaceVariant;
    } else {
      icon = Icons.cloud_done_outlined;
      label = 'All changes saved';
      color = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
