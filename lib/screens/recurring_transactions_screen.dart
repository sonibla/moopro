import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/container_tree.dart';
import '../domain/models.dart';
import '../domain/recurring_template_mapping.dart';
import '../domain/recurrence_rule.dart';
import '../domain/transaction_kind_style.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/amount_text.dart';
import '../widgets/tag_pill_row.dart';
import 'recurring_template_form_screen.dart';

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesStreamProvider);
    final containersAsync = ref.watch(containersStreamProvider);
    final assetsAsync = ref.watch(assetsStreamProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurringScreenFab',
        onPressed: () => showRecurringTemplateForm(context),
        child: const Icon(Icons.add),
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (templates) => containersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load containers: $e')),
          data: (containers) => assetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load assets: $e')),
            data: (assets) =>
                _body(context, ref, templates, containers, assets),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    List<ldb.RecurringTransactionTemplate> templates,
    List<ldb.Container> containers,
    List<ldb.Asset> assets,
  ) {
    if (templates.isEmpty) {
      return const Center(child: Text('No recurring transactions yet.'));
    }
    final active = [
      for (final t in templates)
        if (t.active) t,
    ];
    final paused = [
      for (final t in templates)
        if (!t.active) t,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader(context, 'Active'),
          for (final t in active)
            _templateTile(context, ref, t, containers, assets),
        ],
        if (paused.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(context, 'Paused'),
          for (final t in paused)
            _templateTile(context, ref, t, containers, assets),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _templateTile(
    BuildContext context,
    WidgetRef ref,
    ldb.RecurringTransactionTemplate t,
    List<ldb.Container> containers,
    List<ldb.Asset> assets,
  ) {
    final brightness = Theme.of(context).brightness;
    final kind = TransactionKind.fromJson(t.kind);
    final asset = _assetById(assets, t.legOutAssetId);
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    final kindColor = TransactionKindStyle.colorOf(kind, brightness);
    final tags = decodeTagsColumn(t.tags);
    final rule = RecurrenceRule(
      startDate: t.ruleStartDate,
      unit: RecurrenceUnit.fromJson(t.ruleUnit),
      interval: t.ruleInterval,
      endDate: t.ruleEndDate,
      maxOccurrences: t.ruleMaxOccurrences,
    );
    final nextDue = t.active
        ? nextOccurrence(rule, after: t.lastGeneratedOccurrenceDate)
        : null;

    final summary = recurringTemplateSummary(
      kind,
      legOutContainerId: t.legOutContainerId,
      legInContainerId: t.legInContainerId,
      budgetLegOutContainerId: t.budgetLegOutContainerId,
      budgetLegInContainerId: t.budgetLegInContainerId,
      containers: containers,
    );
    final hasNote = t.note != null && t.note!.trim().isNotEmpty;
    final subtitleParts = [
      if (hasNote) t.note!.trim(),
      'every ${t.ruleInterval} ${_unitLabel(rule.unit, t.ruleInterval)}',
      if (nextDue != null) 'next ${prefs.formatCalendarDate(nextDue)}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kindColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.avatarTileRadius),
          ),
          child: Icon(TransactionKindStyle.iconOf(kind), color: kindColor),
        ),
        title: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitleParts.join(' · ')),
            if (tags.isNotEmpty) TagPillRow(tags: tags, height: 24),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset != null)
              AmountText(
                quantity: Decimal.parse(t.legOutQuantity),
                asset: assetFromCacheRow(asset),
                sign: amountSignOfKind(kind),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            IconButton(
              icon: Icon(
                t.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              tooltip: t.active ? 'Pause' : 'Resume',
              onPressed: () => ref
                  .read(domainRepositoryProvider)
                  .setRecurringTemplateActive(t.id, !t.active),
            ),
          ],
        ),
        onTap: () => showRecurringTemplateForm(context, existing: t),
      ),
    );
  }

  String _unitLabel(RecurrenceUnit unit, int interval) {
    final base = switch (unit) {
      RecurrenceUnit.day => 'day',
      RecurrenceUnit.week => 'week',
      RecurrenceUnit.month => 'month',
      RecurrenceUnit.year => 'year',
    };
    return interval == 1 ? base : '${base}s';
  }

  ldb.Asset? _assetById(List<ldb.Asset> assets, String id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }
}

String recurringTemplateSummary(
  TransactionKind kind, {
  required String legOutContainerId,
  required String legInContainerId,
  String? budgetLegOutContainerId,
  String? budgetLegInContainerId,
  required List<ldb.Container> containers,
}) {
  switch (kind) {
    case TransactionKind.income:
      return '${breadcrumbPath(legInContainerId, containers)} · '
          '${breadcrumbPath(budgetLegInContainerId!, containers)}';
    case TransactionKind.expense:
      return '${breadcrumbPath(legOutContainerId, containers)} · '
          '${breadcrumbPath(budgetLegOutContainerId!, containers)}';
    case TransactionKind.holderTransfer:
    case TransactionKind.budgetTransfer:
      return '${breadcrumbPath(legOutContainerId, containers)} → '
          '${breadcrumbPath(legInContainerId, containers)}';
    case TransactionKind.trade:
      return '';
  }
}
