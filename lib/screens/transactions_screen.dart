import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/date_time_format_prefs.dart';
import '../domain/selection_range.dart';
import '../domain/selection_stats.dart';
import '../domain/models.dart';
import '../domain/transaction_filter.dart' show tagUsageCounts;
import '../domain/transaction_kind_style.dart';
import '../domain/transaction_list_grouping.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/amount_text.dart';
import '../widgets/copy_transactions_dialog.dart';
import '../widgets/drag_select_region.dart';
import '../widgets/expandable_add_fab.dart';
import '../widgets/now_marker.dart';
import '../widgets/selection_stats_dialog.dart';
import '../widgets/sync_conflict_dialog.dart';
import '../widgets/transaction_filter_bar.dart';
import '../widgets/transaction_group_tile.dart';
import '../widgets/mass_edit_tags_dialog.dart';
import '../widgets/transaction_selection_bar.dart';
import '../widgets/transaction_table.dart';
import '../widgets/transaction_tile.dart';
import 'recurring_template_form_screen.dart' show showRecurringTemplateForm;
import 'transaction_form_screen.dart';
import 'transfer_flow_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static const double _headerHeight = 40;

  final Set<String> _selectedIds = {};

  final Set<String> _expandedGroupIds = {};
  List<TransactionListItem>? _visibleSource;
  List<TransactionListItem> _visibleCache = const [];
  final _scroll = ScrollController();

  String? _lastToggledId;

  bool? _nowIsAbove;
  List<TransactionListItem> _items = const [];
  bool _didInitialScrollToNow = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateNowButton);
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateNowButton);
    _scroll.dispose();
    super.dispose();
  }

  double _heightOf(TransactionListItem item) =>
      MediaQuery.sizeOf(context).width > 900
      ? TransactionTable.heightFor(item)
      : _mobileHeightOf(item);

  void _toggleGroup(String id) => setState(() {
    if (!_expandedGroupIds.remove(id)) _expandedGroupIds.add(id);
    _visibleSource = null;
  });

  List<TransactionListItem> _visible(List<TransactionListItem> items) {
    if (!identical(items, _visibleSource)) {
      _visibleSource = items;
      _visibleCache = visibleItems(items, _expandedGroupIds);
      _nowOffsetKey = null;
    }
    return _visibleCache;
  }

  List<TransactionListItem>? _nowOffsetKey;
  bool _nowOffsetWide = false;
  double? _nowOffset;

  double? _nowMarkerOffset() {
    final wide = MediaQuery.sizeOf(context).width > 900;
    if (!identical(_nowOffsetKey, _items) || _nowOffsetWide != wide) {
      final index = indexOfNowMarker(_items);
      _nowOffset = index < 0 ? null : offsetOfItem(_items, index, _heightOf);
      _nowOffsetKey = _items;
      _nowOffsetWide = wide;
    }
    return _nowOffset;
  }

  double get _nowTarget => _nowMarkerOffset() ?? 0;

  void _updateNowButton() {
    if (!_scroll.hasClients || _items.isEmpty) {
      if (_nowIsAbove != null) setState(() => _nowIsAbove = null);
      return;
    }
    final target = _nowTarget;
    final hasMarker = _nowMarkerOffset() != null;
    final pos = _scroll.position;
    bool? above;
    if (target + (hasMarker ? NowMarkerItem.height : 1) <= pos.pixels) {
      above = true;
    } else if (target >= pos.pixels + pos.viewportDimension) {
      above = false;
    }
    if (above != _nowIsAbove) setState(() => _nowIsAbove = above);
  }

  void _scrollToNow() {
    if (!_scroll.hasClients) return;
    final target = _nowTarget
        .clamp(0, _scroll.position.maxScrollExtent)
        .toDouble();
    final distance = (target - _scroll.position.pixels).abs();
    if (distance < 1) return;
    final ms = (200 + distance * 0.2).clamp(300, 800).round();
    _scroll.animateTo(
      target,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeInOut,
    );
  }

  void _onItems(
    List<TransactionListItem> items,
    List<TransactionListItem> visible,
  ) {
    _items = visible;
    _expandedGroupIds.retainAll(_groupIds(items).toSet());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (!_didInitialScrollToNow) {
        if (_nowMarkerOffset() != null) {
          _didInitialScrollToNow = true;
          _scrollToNow();
        }
      }
      _updateNowButton();
    });
  }

  bool _selectionModeForced = false;

  bool get _selecting => _selectedIds.isNotEmpty || _selectionModeForced;

  void _toggleSelected(String id, bool selected) {
    final items = ref.read(transactionListItemsProvider).value;
    final anchor = _lastToggledId;
    _lastToggledId = id;
    if (HardwareKeyboard.instance.isShiftPressed &&
        anchor != null &&
        items != null) {
      final from = indexOfRow(items, anchor);
      final to = indexOfRow(items, id);
      if (from >= 0 && to >= 0) {
        _replaceSelection(
          rangeSelection(
            items: items,
            anchorIndex: from,
            currentIndex: to,
            baseline: _selectedIds,
            select: selected,
          ),
        );
        return;
      }
    }
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _replaceSelection(Set<String> ids) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(ids);
    });
  }

  void _setSelected(Iterable<String> ids, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.addAll(ids);
      } else {
        _selectedIds.removeAll(ids);
      }
    });
  }

  void _toggleDay(DateHeaderItem header) =>
      _setSelected(header.rowIds, header.selectionState(_selectedIds) != true);

  List<String> _allRowIds(List<TransactionListItem> items) =>
      selectableIds(items).toList();

  static Iterable<String> _groupIds(Iterable<TransactionListItem> items) sync* {
    for (final i in items) {
      if (i is TransactionGroupItem) {
        yield i.id;
        yield* _groupIds(i.children);
      }
    }
  }

  void _selectAllOrNone(List<TransactionListItem> items) {
    final ids = _allRowIds(items);
    final allSelected = ids.isNotEmpty && ids.every(_selectedIds.contains);
    _setSelected(ids, !allSelected);
  }

  void _enterSelectionMode() => setState(() => _selectionModeForced = true);

  void _clearSelection() => setState(() {
    _selectedIds.clear();
    _selectionModeForced = false;
  });

  Future<void> _delete() async {
    final ids = {..._selectedIds};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${ids.length} transaction${ids.length == 1 ? '' : 's'}?',
        ),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(domainRepositoryProvider).deleteTransactions(ids);
    if (mounted) _clearSelection();
  }

  Future<void> _deleteSingle(TransactionRowItem row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(domainRepositoryProvider).deleteTransaction(row.id);
  }

  Future<void> _copy(List<TransactionListItem> items) async {
    final originals = allRows(
      items,
    ).where((r) => _selectedIds.contains(r.id)).map((r) => r.row).toList();
    final result = await showCopyTransactionsDialog(
      context,
      count: originals.length,
    );
    if (result == null) return;
    await ref
        .read(domainRepositoryProvider)
        .copyTransactions(
          originals,
          effectiveDate: result.effectiveDate,
          postedAt: result.postedAt,
        );
    if (mounted) _clearSelection();
  }

  Future<void> _showStatistics(List<TransactionListItem> items) async {
    final stats = computeSelectionStats(
      allRows(items).where((r) => _selectedIds.contains(r.id)),
    );
    await showSelectionStatsDialog(context, stats);
  }

  Future<void> _massEdit(List<TransactionListItem> items) async {
    final selected = allRows(
      items,
    ).where((r) => _selectedIds.contains(r.id)).toList();
    final result = await showMassEditTagsDialog(
      context,
      count: selected.length,
      presentTags: ({for (final r in selected) ...r.tags}.toList()..sort()),
    );
    if (result == null) return;
    await ref
        .read(domainRepositoryProvider)
        .editTransactionTags(
          selected.map((r) => r.id),
          add: result.add,
          remove: result.remove,
        );
    if (mounted) _clearSelection();
  }

  Future<void> _openReorderSheet(
    TransactionRowItem tapped,
    List<TransactionListItem> items,
  ) async {
    final cluster = allRows(
      items,
    ).where((r) => r.reorderClusterId == tapped.reorderClusterId).toList();
    final order = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReorderClusterSheet(cluster: cluster),
    );
    if (order == null) return;

    final newRankById = <String, int>{
      for (var i = 0; i < order.length; i++) order[i]: order.length - i,
    };
    await ref.read(domainRepositoryProvider).reorderTransactions(newRankById);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(transactionListItemsProvider);
    final containersAsync = ref.watch(containersStreamProvider);
    final assetsAsync = ref.watch(assetsStreamProvider);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final filter = ref.watch(transactionFilterProvider);

    ref.listen(transactionsStreamProvider, (_, next) {
      final live = next.value;
      if (live == null || _selectedIds.isEmpty) return;
      final existing = {for (final t in live) t.id};
      if (_selectedIds.every(existing.contains)) return;
      setState(() => _selectedIds.retainAll(existing));
    });

    return Scaffold(
      floatingActionButton: _selecting
          ? null
          : ExpandableAddFab(
              onSelectKind: (kind) =>
                  showTransactionForm(context, initialKind: kind),
            ),
      body: Column(
        children: [
          if (_selecting)
            TransactionSelectionBar(
              selectedCount: _selectedIds.length,
              totalCount: itemsAsync.value == null
                  ? 0
                  : _allRowIds(itemsAsync.value!).length,
              onSelectAll: () => itemsAsync.whenData(_selectAllOrNone),
              onClose: _clearSelection,
              onCopy: () => itemsAsync.whenData((items) => _copy(items)),
              onMassEdit: () =>
                  itemsAsync.whenData((items) => _massEdit(items)),
              onStatistics: () =>
                  itemsAsync.whenData((items) => _showStatistics(items)),
              onDelete: _delete,
            )
          else
            Row(
              children: [
                Expanded(
                  child: containersAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (containers) => assetsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (assets) => TransactionFilterBar(
                        filter: filter,
                        onChanged: (f) =>
                            ref.read(transactionFilterProvider.notifier).state =
                                f,
                        containers: containers,
                        assets: assets,
                        tagCounts: tagUsageCounts(
                          transactionsAsync.value ?? const [],
                        ),
                        dateTimeFormatPrefs: ref.watch(
                          dateTimeFormatPrefsProvider,
                        ),
                      ),
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).width <= 900)
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: 'Select transactions',
                    onPressed: _enterSelectionMode,
                  ),
              ],
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _listArea(itemsAsync, containersAsync)),
                if (_nowIsAbove != null && !_selecting)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('scrollToNow'),
                        onPressed: _scrollToNow,
                        icon: Icon(
                          _nowIsAbove!
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                        ),
                        label: const Text('Now'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listArea(
    AsyncValue<List<TransactionListItem>> itemsAsync,
    AsyncValue<List<ldb.Container>> containersAsync,
  ) {
    return RefreshIndicator(
      notificationPredicate: (n) =>
          !_selecting && defaultScrollNotificationPredicate(n),
      onRefresh: () => ref.read(domainRepositoryProvider).syncNow(),
      child: itemsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load transactions: $e')),
        data: (items) {
          _expandedGroupIds.retainAll(_groupIds(items).toSet());
          final visible = _visible(items);
          _onItems(items, visible);
          return MediaQuery.sizeOf(context).width > 900
              ? TransactionTable(
                  items: visible,
                  controller: _scroll,
                  containers: containersAsync.value ?? const [],
                  selectedIds: _selectedIds,
                  onTapRow: (row) =>
                      showTransactionForm(context, existing: row.row),
                  onSelectedChanged: _toggleSelected,
                  onSetSelected: _setSelected,
                  onDragSelect: _replaceSelection,
                  onDelete: _deleteSingle,
                  onReorderCluster: (row) => _openReorderSheet(row, items),
                  onMakeRecurring: (row) =>
                      showRecurringTemplateForm(context, from: row.row),
                  onShowFlow: (g) => showTransferFlow(context, g),
                  dateTimeFormatPrefs: ref.watch(dateTimeFormatPrefsProvider),
                  expandedGroupIds: _expandedGroupIds,
                  onToggleGroup: _toggleGroup,
                  onResolveConflict: (row) => showSyncConflictDialog(
                    context,
                    onDismiss: () => ref
                        .read(domainRepositoryProvider)
                        .acknowledgeConflict(row.id),
                    onOpen: () =>
                        showTransactionForm(context, existing: row.row),
                  ),
                )
              : _mobileList(visible, items);
        },
      ),
    );
  }

  Widget _mobileList(
    List<TransactionListItem> items,
    List<TransactionListItem> allItems,
  ) {
    final dateTimeFormatPrefs = ref.watch(dateTimeFormatPrefsProvider);
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: const Center(
                child: Text('No transactions yet — tap + to add one.'),
              ),
            ),
          ],
        ),
      );
    }

    return DragSelectRegion(
      items: items,
      heightOf: _mobileHeightOf,
      controller: _scroll,
      selectedIds: _selectedIds,
      onSelectionChanged: _replaceSelection,
      child: _mobileListView(items, allItems, dateTimeFormatPrefs),
    );
  }

  static double _mobileHeightOf(TransactionListItem item) {
    if (item is DateHeaderItem) return _headerHeight;
    if (item is NowMarkerItem) return NowMarkerItem.height;
    if (item is TransactionGroupItem) {
      return TransactionGroupTile.headerHeight(item);
    }
    final row = item as TransactionRowItem;
    return TransactionTile.heightFor(
      row.tags,
      isTwoAssetTrade: row.isTwoAssetTrade,
    );
  }

  Widget _mobileListView(
    List<TransactionListItem> items,
    List<TransactionListItem> allItems,
    DateTimeFormatPrefs dateTimeFormatPrefs,
  ) {
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      itemExtentBuilder: (index, dimensions) => _mobileHeightOf(items[index]),
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is NowMarkerItem) return const NowMarkerRow();
        if (item is DateHeaderItem) {
          final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _setSelected(item.rowIds, true),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
              child: Row(
                children: [
                  if (_selecting)
                    Checkbox(
                      tristate: true,
                      value: item.selectionState(_selectedIds),
                      onChanged: (_) => _toggleDay(item),
                    )
                  else
                    const SizedBox(width: 4),
                  Text(item.label, style: labelStyle),
                ],
              ),
            ),
          );
        }
        if (item is TransactionGroupItem) {
          return TransactionGroupTile(
            key: ValueKey('group-${item.id}'),
            group: item,
            expanded: _expandedGroupIds.contains(item.id),
            onToggle: () => _toggleGroup(item.id),
            onShowFlow: () => showTransferFlow(context, item),
            selectionMode: _selecting,
            selectionState: item.selectionState(_selectedIds),
            onSelectedChanged: (v) => _setSelected(item.leafIds, v),
          );
        }
        return _mobileRow(
          context,
          item as TransactionRowItem,
          allItems,
          dateTimeFormatPrefs,
        );
      },
    );
  }

  Widget _mobileRow(
    BuildContext context,
    TransactionRowItem row,
    List<TransactionListItem> items,
    DateTimeFormatPrefs dateTimeFormatPrefs,
  ) {
    void openForEdit() => showTransactionForm(context, existing: row.row);

    return Padding(
      padding: EdgeInsets.only(left: 16.0 * row.depth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.line(Theme.of(context).brightness),
            ),
          ),
        ),
        child: TransactionTile(
          key: ValueKey(row.id),
          date: row.effectiveDate,
          note: row.note,
          title: row.title,
          displayQuantity: row.displayQuantity,
          displayAsset: row.displayAsset,
          sign: row.sign,
          kind: row.kind,
          recordId: row.id,
          tradeQuantityIn: row.tradeQuantityIn,
          tradeAssetIn: row.tradeAssetIn,
          showDateInline: false,
          dateTimeFormatPrefs: dateTimeFormatPrefs,
          postedAtIfDifferentDay: row.postedOnDifferentDay
              ? row.postedAt
              : null,
          onTap: openForEdit,
          selectionMode: _selecting,
          selected: _selectedIds.contains(row.id),
          onSelectedChanged: (v) => _toggleSelected(row.id, v),
          reorderClusterSize: row.reorderClusterSize,
          onReorderCluster: () => _openReorderSheet(row, items),
          onMakeRecurring: row.kind.canBeRecurring
              ? () => showRecurringTemplateForm(context, from: row.row)
              : null,
          tags: row.tags,
          onResolveConflict: () => showSyncConflictDialog(
            context,
            onDismiss: () =>
                ref.read(domainRepositoryProvider).acknowledgeConflict(row.id),
            onOpen: openForEdit,
          ),
        ),
      ),
    );
  }
}

class _ReorderClusterSheet extends StatefulWidget {
  final List<TransactionRowItem> cluster;
  const _ReorderClusterSheet({required this.cluster});

  @override
  State<_ReorderClusterSheet> createState() => _ReorderClusterSheetState();
}

class _ReorderClusterSheetState extends State<_ReorderClusterSheet> {
  final List<TransactionRowItem> _order = [];

  @override
  void initState() {
    super.initState();
    _order.addAll(widget.cluster);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reorder same-day entries',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _order.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    final item = _order.removeAt(oldIndex);
                    _order.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final row = _order[index];
                  final kindColor = TransactionKindStyle.colorOf(
                    row.kind,
                    Theme.of(context).brightness,
                  );
                  return ListTile(
                    key: ValueKey(row.id),
                    leading: Icon(
                      TransactionKindStyle.iconOf(row.kind),
                      color: kindColor,
                    ),
                    title: Text(row.title, overflow: TextOverflow.ellipsis),
                    subtitle: row.note != null && row.note!.isNotEmpty
                        ? Text(row.note!, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (row.kind == TransactionKind.trade &&
                            row.tradeQuantityIn != null &&
                            row.tradeAssetIn != null)
                          TradeAmountText(
                            quantityOut: row.displayQuantity,
                            assetOut: row.displayAsset,
                            quantityIn: row.tradeQuantityIn!,
                            assetIn: row.tradeAssetIn!,
                            textAlign: TextAlign.end,
                          )
                        else
                          AmountText(
                            quantity: row.displayQuantity,
                            asset: row.displayAsset,
                            sign: row.sign,
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop([for (final r in _order) r.id]),
                  child: const Text('Save order'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
