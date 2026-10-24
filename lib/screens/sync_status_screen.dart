import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart' show SettingIds, VaultRecordTypes;
import '../providers/app_providers.dart';
import '../widgets/sync_conflict_comparison_dialog.dart';
import '../widgets/sync_summary_indicator.dart';

const Map<String, String> _settingLabels = {
  SettingIds.alphavantageApiKey: 'Alphavantage API key',
  SettingIds.dateFormat: 'Date format',
  SettingIds.timeFormat: 'Time format',
  SettingIds.statementImportHintResolutions: 'Statement import hints',
  SettingIds.defaultCurrencyAssetId: 'Default currency',
  SettingIds.themeMode: 'Theme',
  SettingIds.hideAmounts: 'Hide amounts',
};

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  String _labelFor(WidgetRef ref, String type, String id) {
    switch (type) {
      case VaultRecordTypes.asset:
        final asset = ref
            .watch(assetsStreamProvider)
            .value
            ?.where((a) => a.id == id)
            .firstOrNull;
        return asset == null ? 'Asset' : '${asset.name} (${asset.symbol})';
      case VaultRecordTypes.container:
        final container = ref
            .watch(containersStreamProvider)
            .value
            ?.where((c) => c.id == id)
            .firstOrNull;
        return container == null ? 'Container' : container.name;
      case VaultRecordTypes.transaction:
        final tx = ref
            .watch(transactionsStreamProvider)
            .value
            ?.where((t) => t.id == id)
            .firstOrNull;
        if (tx == null) return 'Transaction';
        final note = tx.note;
        return (note != null && note.isNotEmpty)
            ? 'Transaction: $note'
            : 'Transaction (${tx.kind})';
      case VaultRecordTypes.priceSnapshot:
        final snapshot = ref
            .watch(priceSnapshotsStreamProvider)
            .value
            ?.where((p) => p.id == id)
            .firstOrNull;
        return snapshot == null
            ? 'Price snapshot'
            : 'Price snapshot (${snapshot.price})';
      case VaultRecordTypes.setting:
        return _settingLabels[id] ?? 'Setting';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverAvailable = ref.watch(serverAvailableProvider);
    final summary = ref.watch(syncSummaryProvider);
    final display = computeSyncStatusDisplay(
      summary: summary,
      serverAvailable: serverAvailable.value,
    );
    final theme = Theme.of(context);

    final conflicted = ref.watch(conflictedRecordsProvider).value ?? const [];
    final pending = ref.watch(pendingRecordsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Sync status')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(display.icon, color: display.color(theme)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(display.label, style: theme.textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(domainRepositoryProvider).syncNow(force: true),
                child: const Text('Sync now'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (conflicted.isEmpty && pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('All changes saved.')),
            ),
          if (conflicted.isNotEmpty) ...[
            Text(
              'Needs your attention (${conflicted.length})',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final item in conflicted)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(_labelFor(ref, item.type, item.id)),
                  subtitle: const Text(
                    'Changed elsewhere before your edit was saved',
                  ),
                  trailing: TextButton(
                    onPressed: () =>
                        showSyncConflictComparison(context, recordId: item.id),
                    child: const Text('Review'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (pending.isNotEmpty) ...[
            Text(
              'Pending (${pending.length})',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final item in pending)
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(_labelFor(ref, item.type, item.id)),
                subtitle: const Text('Will sync once online'),
              ),
          ],
        ],
      ),
    );
  }
}
