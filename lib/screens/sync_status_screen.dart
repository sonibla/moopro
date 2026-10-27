import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cache_row_mapping.dart';
import '../domain/conflict_record_display.dart';
import '../domain/models.dart' show Setting, VaultRecordTypes;
import '../domain/recurring_template_mapping.dart' show assetFromCacheRow;
import '../providers/app_providers.dart';
import '../widgets/conflict_record_tile.dart';
import '../widgets/sync_conflict_comparison_dialog.dart';
import '../widgets/sync_summary_indicator.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  Object? _valueFor(WidgetRef ref, String type, String id) {
    switch (type) {
      case VaultRecordTypes.asset:
        final row = ref
            .watch(assetsStreamProvider)
            .value
            ?.where((a) => a.id == id)
            .firstOrNull;
        return row == null ? null : assetFromCacheRow(row);
      case VaultRecordTypes.container:
        final row = ref
            .watch(containersStreamProvider)
            .value
            ?.where((c) => c.id == id)
            .firstOrNull;
        return row == null ? null : containerFromCacheRow(row);
      case VaultRecordTypes.transaction:
        final row = ref
            .watch(transactionsStreamProvider)
            .value
            ?.where((t) => t.id == id)
            .firstOrNull;
        return row == null ? null : transactionFromCacheRow(row);
      case VaultRecordTypes.priceSnapshot:
        final row = ref
            .watch(priceSnapshotsStreamProvider)
            .value
            ?.where((p) => p.id == id)
            .firstOrNull;
        return row == null ? null : priceSnapshotFromCacheRow(row);
      case VaultRecordTypes.setting:
        return Setting(id: id, value: '');
      default:
        return null;
    }
  }

  ConflictRecordDisplay _displayFor(
    BuildContext context,
    WidgetRef ref,
    String type,
    String id,
  ) {
    final value = _valueFor(ref, type, id);
    final containers = (ref.watch(containersStreamProvider).value ?? const [])
        .map(containerFromCacheRow)
        .toList();
    final assets = (ref.watch(assetsStreamProvider).value ?? const [])
        .map(assetFromCacheRow)
        .toList();
    return describeConflictRecord(
      value,
      lookups: ConflictLookups(
        containers: containers,
        assets: assets,
        settingLabels: settingDisplayLabels,
      ),
      dateTimeFormatPrefs: ref.watch(dateTimeFormatPrefsProvider),
      brightness: Theme.of(context).brightness,
    );
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
                child: ConflictRecordSummaryTile(
                  display: _displayFor(context, ref, item.type, item.id),
                  trailingAction: TextButton(
                    onPressed: () =>
                        showSyncConflictComparison(context, recordId: item.id),
                    child: const Text('Review'),
                  ),
                  onTap: () =>
                      showSyncConflictComparison(context, recordId: item.id),
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
              ConflictRecordSummaryTile(
                display: _displayFor(context, ref, item.type, item.id),
              ),
          ],
        ],
      ),
    );
  }
}
