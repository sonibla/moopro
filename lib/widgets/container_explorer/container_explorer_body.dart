import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/domain_cache_database.dart' as ldb;
import '../../domain/calendar_date.dart';
import '../../domain/container_tree.dart';
import '../../domain/models.dart';
import '../../domain/transaction_filter.dart';
import '../../providers/app_providers.dart';
import '../amount_text.dart';
import '../asset_view_controls.dart';
import '../balance_chart_section.dart';
import '../container_form_dialog.dart';
import '../container_icon.dart';
import '../container_picker.dart';
import '../pie_chart_card.dart';
import '../sync_conflict_dialog.dart';
import '../sync_status_icon.dart';
import 'container_breakdown_card.dart';
import 'explorer_data.dart';

const double _wideBreakpoint = 1100;

const double _stackedPieSize = 320;

const double _wideCardChrome = 170;

class ContainerExplorerBody extends ConsumerStatefulWidget {
  final ContainerType type;
  const ContainerExplorerBody({super.key, required this.type});

  @override
  ConsumerState<ContainerExplorerBody> createState() =>
      _ContainerExplorerBodyState();
}

class _ContainerExplorerBodyState extends ConsumerState<ContainerExplorerBody> {
  String? _displayAssetId;
  AssetFilter? _assetFilter;
  String? _focusId;

  CalendarDate? _asOf;

  bool get _nested => widget.type == ContainerType.budget;

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionsStreamProvider);
    final containersAsync = ref.watch(containersStreamProvider);
    final assetsAsync = ref.watch(assetsStreamProvider);
    final templates = ref.watch(recurringTemplatesStreamProvider);
    final prices = ref.watch(priceSnapshotsStreamProvider);

    Widget loading() => const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => ref.read(domainRepositoryProvider).syncNow(),
      child: txs.when(
        loading: loading,
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (transactions) => containersAsync.when(
          loading: loading,
          error: (e, _) => Center(child: Text('Failed to load containers: $e')),
          data: (containers) => assetsAsync.when(
            loading: loading,
            error: (e, _) => Center(child: Text('Failed to load assets: $e')),
            data: (assets) => templates.when(
              loading: loading,
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (templateRows) => prices.when(
                loading: loading,
                error: (e, _) => Center(child: Text('Failed to load: $e')),
                data: (priceRows) => _body(
                  context,
                  transactions,
                  containers,
                  assets,
                  templateRows,
                  priceRows,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<ldb.Transaction> transactions,
    List<ldb.Container> allContainers,
    List<ldb.Asset> assets,
    List<ldb.RecurringTransactionTemplate> templates,
    List<ldb.PriceSnapshot> priceRows,
  ) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    if (assets.isEmpty) {
      return const Center(child: Text('No assets yet.'));
    }
    final theme = Theme.of(context);
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    final displayAssetId =
        _displayAssetId ??
        ref.watch(defaultCurrencyAssetIdProvider) ??
        assets.first.id;
    final assetsById = {for (final a in assets) a.id: a};

    final containers = allContainers
        .where(
          (c) =>
              c.containerType == widget.type.name &&
              c.id != externalHolderContainerId &&
              c.id != externalBudgetContainerId,
        )
        .toList();
    final focus = containers.where((c) => c.id == _focusId).firstOrNull;
    final focusId = focus?.id;

    final today = CalendarDate.today();
    final asOf = _asOf ?? today;
    final forecaster = ref.read(balanceForecasterProvider)
      ..update(transactions: transactions, templates: templates, today: today);

    final data = computeExplorerData(
      forecaster: forecaster,
      containers: containers,
      priceSnapshots: priceRows,
      assetsById: assetsById,
      displayAssetId: displayAssetId,
      filter: _assetFilter,
      asOf: asOf,
      nested: _nested,
      focusId: focusId,
    );
    final displayAsset = _domainAsset(data.displayAsset);
    final total = focus == null
        ? data.mergedOwnBalances.values.fold<Decimal>(
            Decimal.zero,
            (sum, v) => sum + v,
          )
        : _nested
        ? subtreeValue(focus.id, containers, data.mergedOwnBalances)
        : data.mergedOwnBalances[focus.id] ?? Decimal.zero;
    final hasUnconvertible = focus == null
        ? data.fullRollup.containersWithUnconvertible.isNotEmpty
        : data.fullRollup.containersWithUnconvertible.contains(focus.id);

    final isForecast = asOf.isAfter(today);
    final dateText = prefs.formatCalendarDate(asOf);

    final includesChildren =
        _nested &&
        focus != null &&
        descendantIds(focus.id, containers).length > 1;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('focusBack'),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: focus == null
                        ? null
                        : () => _setFocus(focus.parentId),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        key: const ValueKey('containerSelector'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pickContainer(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (focus != null) ...[
                                ContainerIcon(focus.icon, size: 24),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  focus?.name ??
                                      (widget.type == ContainerType.holder
                                          ? 'All holders'
                                          : 'All budgets'),
                                  style: theme.textTheme.titleLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('openTransactions'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    tooltip: 'Show transactions',
                    onPressed: focus == null
                        ? null
                        : () {
                            ref.read(transactionFilterProvider.notifier).state =
                                TransactionFilter(containerId: focus.id);
                            ref.read(selectedTabProvider.notifier).state =
                                transactionsTabIndex;
                          },
                  ),
                  IconButton(
                    key: const ValueKey('editFocusedContainer'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: focus == null
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                ContainerFormDialog(existing: focus),
                          ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: ContainerBreadcrumb(
                  path: focus == null
                      ? const []
                      : pieAncestorPath(data.chartTree, focus.id) ?? const [],
                  onSelectRoot: () => _setFocus(null),
                  onSelect: _setFocus,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                includesChildren
                    ? 'Total (incl. sub-budgets) on $dateText'
                    : 'Total on $dateText',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              AmountText(
                quantity: total,
                asset: displayAsset,
                style: theme.textTheme.displaySmall,
              ),
              if (hasUnconvertible) ...[
                const SizedBox(height: 4),
                Text(
                  'Holds an asset with no known price — not included in this total.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DisplayAssetSelector(
                assets: assets,
                selectedAssetId: displayAssetId,
                onChanged: (id) => setState(() => _displayAssetId = id),
              ),
              AssetFilterSelector(
                assets: assets,
                selected: _assetFilter,
                onChanged: (f) => setState(() => _assetFilter = f),
              ),
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('asOfMenuToday'),
                    leadingIcon: const Icon(Icons.today),
                    onPressed: _asOf == null
                        ? null
                        : () => setState(() => _asOf = null),
                    child: const Text('Today'),
                  ),
                  MenuItemButton(
                    key: const ValueKey('asOfMenuPick'),
                    leadingIcon: const Icon(Icons.edit_calendar),
                    onPressed: () => _pickDate(context, asOf, today),
                    child: const Text('Pick a date…'),
                  ),
                ],
                builder: (context, controller, _) => ActionChip(
                  key: const ValueKey('asOfChip'),
                  avatar: const Icon(Icons.event, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('As of $dateText${isForecast ? ' · forecast' : ''}'),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideBreakpoint;
            final balance = BalanceChartSection(
              expandChart: wide,
              showLegend: false,
              containers: containers,
              assets: assets,
              displayAssetId: displayAssetId,
              assetFilter: _assetFilter,
              focusId: focusId,
              onFocusChanged: _setFocus,
              asOf: asOf,
              onAsOfChanged: (d) =>
                  setState(() => _asOf = d == today ? null : d),
            );
            final pie = PieChartCard(
              margin: wide ? const EdgeInsets.fromLTRB(8, 8, 4, 8) : null,
              showBreadcrumb: false,
              expandChart: wide,
              maxChartSize: wide ? 760 : _stackedPieSize,
              nodes: data.chartTree,
              focusId: focusId,
              onFocusChanged: _setFocus,
              drillDown: _nested,
              showLegend: false,
              amountLabel: (v) =>
                  explorerAmountLabel(v, data.chartAsset, hidden: hideAmounts),
              showAmountsInLegend: data.showAmountsInLegend,
            );
            if (!wide) return Column(children: [balance, pie]);
            final pieChartSize =
                ((constraints.maxWidth - 12) / 2 - 12 - 8 - 32 - 16).clamp(
                  300.0,
                  760.0,
                );
            return SizedBox(
              height: pieChartSize + _wideCardChrome,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: balance),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: pie,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        ContainerBreakdownCard(
          nodes: data.chartTree,
          focusId: focusId,
          onFocusChanged: _setFocus,
          drillDown: _nested,
          amountLabel: (v) =>
              explorerAmountLabel(v, data.chartAsset, hidden: hideAmounts),
          showAmounts: data.showAmountsInLegend,
          holdings: focusId == null
              ? data.rootHoldings
              : data.holdingsByContainerId?[focusId],
          holdingQuantityLabel: (id, qty) =>
              _holdingQuantityLabel(id, qty, assetsById, hideAmounts),
          filterNote: _assetFilter == null ? null : 'filtered',
          rowTrailing: (id) => SyncStatusIcon(
            recordId: id,
            onTap: () => showSyncConflictDialog(
              context,
              onDismiss: () =>
                  ref.read(domainRepositoryProvider).acknowledgeConflict(id),
              onOpen: () => _setFocus(id),
            ),
          ),
        ),
      ],
    );
  }

  void _setFocus(String? id) => setState(() => _focusId = id);

  Future<void> _pickContainer(BuildContext context) async {
    final result = await showContainerPicker(
      context: context,
      type: widget.type,
      title: widget.type == ContainerType.holder
          ? 'Show holder'
          : 'Show budget',
      selectedId: _focusId,
      allowNone: true,
    );
    if (result != null) _setFocus(result.containerId);
  }

  Future<void> _pickDate(
    BuildContext context,
    CalendarDate current,
    CalendarDate today,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 10, 12, 31),
    );
    if (picked == null) return;
    final day = CalendarDate.fromDateTime(picked);
    setState(() => _asOf = day == today ? null : day);
  }

  Asset _domainAsset(ldb.Asset row) => Asset.fromJson(row.id, {
    'kind': row.kind,
    'symbol': row.symbol,
    'name': row.name,
    'displaySymbol': row.displaySymbol,
  });

  String _holdingQuantityLabel(
    String assetId,
    Decimal quantity,
    Map<String, ldb.Asset> assetsById,
    bool hidden,
  ) {
    final asset = assetsById[assetId];
    if (asset == null) return quantity.toString();
    final decimals = asset.kind == AssetKind.crypto.name ? 8 : 2;
    return '${asset.symbol} — ${hidden ? kHiddenAmount : quantity.toStringAsFixed(decimals)}';
  }
}
