import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/domain_repository.dart';
import '../domain/models.dart';
import '../providers/app_providers.dart';

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
                        "Your previous edit isn't available anymore — you "
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

class _VersionCard extends StatelessWidget {
  final String title;
  final Object? value;

  const _VersionCard({required this.title, required this.value});

  String _describe(Object? value) {
    switch (value) {
      case null:
        return 'Not available';
      case Asset a:
        return '${a.name} (${a.symbol})';
      case MoneyContainer c:
        return '${c.name} — ${c.containerType.name}';
      case MoneyTransaction t:
        final note = t.note;
        return '${t.kind.name}: ${t.legOut.quantity} ${t.legOut.assetId} '
            '→ ${t.legIn.quantity} ${t.legIn.assetId}'
            '${(note != null && note.isNotEmpty) ? ' — $note' : ''}';
      case PriceSnapshot p:
        return '${p.price} (as of ${p.date.toIso8601String().split('T').first})';
      case Setting s:
        return s.value;
      default:
        return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(_describe(value), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
