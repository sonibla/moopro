import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/date_time_format_prefs.dart';
import '../domain/domain_repository.dart';
import '../domain/recurring_template_mapping.dart';
import '../domain/transaction_kind_style.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'tag_pill_row.dart';
import '../providers/app_providers.dart';
import '../screens/recurring_transactions_screen.dart'
    show recurringTemplateSummary;

Future<void> showDueRecurringOccurrencesDialog(
  BuildContext context,
  List<DueRecurringOccurrence> occurrences,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DueRecurringOccurrencesDialog(occurrences: occurrences),
  );
}

class DueRecurringOccurrencesDialog extends ConsumerStatefulWidget {
  final List<DueRecurringOccurrence> occurrences;

  const DueRecurringOccurrencesDialog({super.key, required this.occurrences});

  @override
  ConsumerState<DueRecurringOccurrencesDialog> createState() =>
      _DueRecurringOccurrencesDialogState();
}

class _DueRecurringOccurrencesDialogState
    extends ConsumerState<DueRecurringOccurrencesDialog> {
  bool _applying = false;
  late final List<DueRecurringOccurrence> _sorted;
  late final Set<DueRecurringOccurrence> _selected;

  @override
  void initState() {
    super.initState();
    _sorted = [...widget.occurrences]
      ..sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    _selected = {..._sorted};
  }

  @override
  Widget build(BuildContext context) {
    final containers = ref.watch(containersStreamProvider).value ?? const [];
    final assets = ref.watch(assetsStreamProvider).value ?? const [];
    final prefs = ref.watch(dateTimeFormatPrefsProvider);

    return AlertDialog(
      title: const Text('Recurring transactions due'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final o in _sorted)
                _row(context, o, containers, assets, prefs),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applying ? null : () => Navigator.of(context).pop(),
          child: const Text('Skip for now'),
        ),
        TextButton(
          onPressed: _applying || _selected.isEmpty ? null : _skipSelected,
          child: Text('Skip selected (${_selected.length})'),
        ),
        FilledButton(
          onPressed: _applying || _selected.isEmpty ? null : _apply,
          child: _applying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _selected.length == _sorted.length
                      ? 'Apply all'
                      : 'Apply selected (${_selected.length})',
                ),
        ),
      ],
    );
  }

  void _toggle(DueRecurringOccurrence o, bool value) {
    setState(() {
      for (final other in _sorted) {
        if (other.template.id != o.template.id) continue;
        if (value && !other.occurrenceDate.isAfter(o.occurrenceDate)) {
          _selected.add(other);
        } else if (!value && !other.occurrenceDate.isBefore(o.occurrenceDate)) {
          _selected.remove(other);
        }
      }
    });
  }

  Widget _row(
    BuildContext context,
    DueRecurringOccurrence o,
    List<ldb.Container> containers,
    List<ldb.Asset> assets,
    DateTimeFormatPrefs prefs,
  ) {
    final t = o.template;
    final brightness = Theme.of(context).brightness;
    final kindColor = TransactionKindStyle.colorOf(t.kind, brightness);
    final note = t.note?.trim();
    ldb.Asset? asset;
    for (final a in assets) {
      if (a.id == t.legOut.assetId) asset = a;
    }
    final summary = recurringTemplateSummary(
      t.kind,
      legOutContainerId: t.legOut.containerId,
      legInContainerId: t.legIn.containerId,
      budgetLegOutContainerId: t.budgetLegOut?.containerId,
      budgetLegInContainerId: t.budgetLegIn?.containerId,
      containers: containers,
    );
    final selected = _selected.contains(o);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !_applying,
      onTap: () => _toggle(o, !selected),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: selected,
            onChanged: _applying ? null : (v) => _toggle(o, v ?? false),
          ),
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kindColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.avatarTileRadius),
            ),
            child: Icon(TransactionKindStyle.iconOf(t.kind), color: kindColor),
          ),
        ],
      ),
      title: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              prefs.formatCalendarDate(o.occurrenceDate),
              if (note != null && note.isNotEmpty) note,
            ].join(' · '),
          ),
          if (t.tags.isNotEmpty) TagPillRow(tags: t.tags, height: 24),
        ],
      ),
      trailing: asset == null
          ? null
          : AmountText(
              quantity: t.legOut.quantity,
              asset: assetFromCacheRow(asset),
              sign: amountSignOfKind(t.kind),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
    );
  }

  Future<void> _skipSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip selected occurrences?'),
        content: Text(
          'No transaction will be created for the $count selected '
          'occurrence${count == 1 ? '' : 's'}, and you won\'t be asked about '
          '${count == 1 ? 'it' : 'them'} again. The next occurrence of each '
          'recurring transaction is unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _applying = true);
    try {
      await ref.read(domainRepositoryProvider).skipDueRecurringOccurrences([
        for (final o in _sorted)
          if (_selected.contains(o)) o,
      ]);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(domainRepositoryProvider).applyDueRecurringOccurrences([
        for (final o in _sorted)
          if (_selected.contains(o)) o,
      ]);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }
}
