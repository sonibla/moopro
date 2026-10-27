import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cache_row_mapping.dart';
import '../domain/conflict_record_display.dart';
import '../domain/domain_repository.dart';
import '../domain/recurring_template_mapping.dart' show assetFromCacheRow;
import '../providers/app_providers.dart';
import 'conflict_record_tile.dart';

Future<void> showSyncConflictComparison(
  BuildContext context, {
  required String recordId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SyncConflictComparisonDialog(recordId: recordId),
  );
}

class _SyncConflictComparisonDialog extends ConsumerStatefulWidget {
  final String recordId;

  const _SyncConflictComparisonDialog({required this.recordId});

  @override
  ConsumerState<_SyncConflictComparisonDialog> createState() =>
      _SyncConflictComparisonDialogState();
}

class _SyncConflictComparisonDialogState
    extends ConsumerState<_SyncConflictComparisonDialog> {
  late final Future<ConflictComparison> _future = ref
      .read(domainRepositoryProvider)
      .loadConflictComparison(widget.recordId);
  bool _resolving = false;

  Future<void> _resolve(
    Future<void> Function(DomainRepository repo) action,
  ) async {
    setState(() => _resolving = true);
    await action(ref.read(domainRepositoryProvider));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync conflict'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<ConflictComparison>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final comparison = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This was changed elsewhere before your edit could be '
                    'saved. Choose which version to keep, or close this and '
                    'decide later.',
                  ),
                  const SizedBox(height: 16),
                  if (comparison.local != null)
                    _VersionCard(title: 'Your edit', value: comparison.local)
                  else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        "Your previous edit isn't available anymore. You "
                        'can only keep the server version.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _VersionCard(
                    title: 'Current server version',
                    value: comparison.server,
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resolving ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: _resolving
              ? null
              : () =>
                    _resolve((repo) => repo.keepServerVersion(widget.recordId)),
          child: const Text('Keep server version'),
        ),
        FutureBuilder<ConflictComparison>(
          future: _future,
          builder: (context, snapshot) {
            final hasLocal = snapshot.data?.local != null;
            return TextButton(
              onPressed: (!hasLocal || _resolving)
                  ? null
                  : () => _resolve(
                      (repo) => repo.keepLocalVersion(widget.recordId),
                    ),
              child: const Text('Keep my edit'),
            );
          },
        ),
      ],
    );
  }
}

class _VersionCard extends ConsumerWidget {
  final String title;
  final Object? value;

  const _VersionCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final containers = (ref.watch(containersStreamProvider).value ?? const [])
        .map(containerFromCacheRow)
        .toList();
    final assets = (ref.watch(assetsStreamProvider).value ?? const [])
        .map(assetFromCacheRow)
        .toList();
    final display = describeConflictRecord(
      value,
      lookups: ConflictLookups(
        containers: containers,
        assets: assets,
        settingLabels: settingDisplayLabels,
      ),
      dateTimeFormatPrefs: ref.watch(dateTimeFormatPrefsProvider),
      brightness: theme.brightness,
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(title, style: theme.textTheme.labelLarge),
          ),
          ConflictRecordSummaryTile(display: display),
        ],
      ),
    );
  }
}
