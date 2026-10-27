import 'package:flutter/material.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/date_time_format_prefs.dart';
import '../domain/container_tree.dart';
import '../domain/models.dart';
import '../domain/transaction_kind_style.dart';
import '../domain/transaction_list_grouping.dart';
import '../domain/transaction_table_columns.dart';
import '../theme/app_theme.dart';
import 'amount_text.dart';
import 'conflict_resolve_button.dart';
import 'container_icon.dart';
import 'drag_select_region.dart';
import 'now_marker.dart';
import 'sync_status_icon.dart';
import 'tag_pill_row.dart';

class TransactionTable extends StatelessWidget {
  final List<TransactionListItem> items;
  final List<ldb.Container> containers;
  final Set<String> selectedIds;
  final ValueChanged<TransactionRowItem> onTapRow;
  final void Function(String id, bool selected) onSelectedChanged;

  final void Function(Iterable<String> ids, bool selected) onSetSelected;

  final ValueChanged<Set<String>>? onDragSelect;
  final void Function(TransactionRowItem row) onDelete;
  final void Function(TransactionRowItem row) onResolveConflict;

  final void Function(TransactionRowItem row)? onReorderCluster;

  final void Function(TransactionRowItem row)? onMakeRecurring;

  final void Function(TransactionGroupItem group)? onShowFlow;
  final DateTimeFormatPrefs dateTimeFormatPrefs;

  final Set<String> expandedGroupIds;
  final ValueChanged<String>? onToggleGroup;

  final ScrollController? controller;

  const TransactionTable({
    super.key,
    required this.items,
    required this.containers,
    required this.selectedIds,
    required this.onTapRow,
    required this.onSelectedChanged,
    required this.onSetSelected,
    this.onDragSelect,
    required this.onDelete,
    required this.onResolveConflict,
    this.onReorderCluster,
    this.onMakeRecurring,
    this.onShowFlow,
    this.dateTimeFormatPrefs = DateTimeFormatPrefs.defaults,
    this.expandedGroupIds = const {},
    this.onToggleGroup,
    this.controller,
  });

  static const double _checkboxWidth = 48;
  static const double _dateWidth = 96;
  static const double _typeWidth = 140;
  static const double _amountWidth = 160;
  static const double _syncWidth = 32;
  static const double _actionsWidth = 120;

  static final ButtonStyle _actionButtonStyle = IconButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  static const double _rowHeight = 52;
  static const double _headerHeight = 40;
  static const double _tagsRowHeight = 24;
  static const double _tradeAmountExtraHeight = 18;

  List<String> get _allRowIds => selectableIds(items).toList();

  static const double _destLineHeight = 18;

  static double groupHeaderHeight(TransactionGroupItem g) {
    final lines = g.destinations.length * _destLineHeight + 16;
    return lines > _rowHeight ? lines : _rowHeight;
  }

  static double heightFor(TransactionListItem item) {
    if (item is DateHeaderItem) return _headerHeight;
    if (item is NowMarkerItem) return NowMarkerItem.height;
    if (item is TransactionGroupItem) return groupHeaderHeight(item);
    final row = item as TransactionRowItem;
    var h = _rowHeight;
    if (row.isTwoAssetTrade) h += _tradeAmountExtraHeight;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _HeaderRow(
            theme: theme,
            allSelected: _allRowIds.isEmpty
                ? false
                : _allRowIds.every(selectedIds.contains)
                ? true
                : _allRowIds.any(selectedIds.contains)
                ? null
                : false,
            onToggleAll: _allRowIds.isEmpty
                ? null
                : () => onSetSelected(
                    _allRowIds,
                    !_allRowIds.every(selectedIds.contains),
                  ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('No transactions yet — tap + to add one.'),
                )
              : _TableList(
                  items: items,
                  heightOf: heightFor,
                  controller: controller,
                  selectedIds: selectedIds,
                  onDragSelect: onDragSelect,
                  mouseDragZoneWidth: 16 + _checkboxWidth,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is DateHeaderItem) {
                      return _dayHeader(theme, item);
                    }
                    if (item is NowMarkerItem) return const NowMarkerRow();
                    if (item is TransactionGroupItem) {
                      return _groupHeader(
                        context,
                        theme,
                        item,
                        expandedGroupIds.contains(item.id),
                      );
                    }
                    return _row(context, theme, item as TransactionRowItem);
                  },
                ),
        ),
      ],
    );
  }

  Widget _groupHeader(
    BuildContext context,
    ThemeData theme,
    TransactionGroupItem group,
    bool expanded,
  ) {
    final selection = group.selectionState(selectedIds);
    final isBudget = group.kind == TransactionKind.budgetTransfer;
    ({String name, String path, String? icon}) leg(String id) {
      final matches = containers.where((c) => c.id == id);
      if (matches.isEmpty) return (name: id, path: id, icon: null);
      final c = matches.first;
      return (name: c.name, path: breadcrumbPath(id, containers), icon: c.icon);
    }

    Widget destinations() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in group.destinations)
          SizedBox(
            height: _destLineHeight,
            child: Row(
              children: [
                Text('→ ', style: theme.textTheme.bodySmall),
                AmountText(
                  quantity: d.total,
                  asset: group.asset,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: isBudget
                      ? _budgetName(leg(d.containerId), theme)
                      : ContainerName(
                          leg(d.containerId).name,
                          icon: leg(d.containerId).icon,
                          maxLines: 1,
                          style: theme.textTheme.bodySmall,
                        ),
                ),
              ],
            ),
          ),
      ],
    );

    final source = leg(group.sourceContainerId);
    return Container(
      key: ValueKey('group-header-${group.id}'),
      decoration: BoxDecoration(
        color: selection == true ? AppTheme.accentSoft(theme.brightness) : null,
        border: Border(
          bottom: BorderSide(color: AppTheme.line(theme.brightness)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16 + 24.0 * group.depth, 4, 16, 4),
      child: InkWell(
        onTap: onToggleGroup == null ? null : () => onToggleGroup!(group.id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _checkboxWidth,
              child: Checkbox(
                tristate: true,
                value: selection,
                onChanged: (_) =>
                    onSetSelected(group.leafIds, selection != true),
              ),
            ),
            SizedBox(
              width: _dateWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more),
                ),
              ),
            ),
            SizedBox(
              width: _typeWidth,
              child: _TypeBadge(kind: group.kind),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${group.leafIds.length} transfers · ${source.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SizedBox(
              width: _amountWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AmountText(
                    quantity: group.total,
                    asset: group.asset,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: isBudget
                    ? destinations()
                    : Text('—', style: theme.textTheme.bodySmall),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: isBudget
                    ? Text('—', style: theme.textTheme.bodySmall)
                    : destinations(),
              ),
            ),
            SizedBox(
              width: _syncWidth,
              child: Center(
                child: GroupSyncStatusIcon(recordIds: group.leafIds),
              ),
            ),
            SizedBox(
              width: _actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onShowFlow != null)
                    IconButton(
                      icon: const Icon(Icons.stacked_line_chart, size: 18),
                      tooltip: 'Show flow',
                      visualDensity: VisualDensity.compact,
                      style: _actionButtonStyle,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => onShowFlow!(group),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayHeader(ThemeData theme, DateHeaderItem item) => Container(
    alignment: Alignment.bottomLeft,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
    child: Row(
      children: [
        SizedBox(
          width: _checkboxWidth,
          child: Checkbox(
            tristate: true,
            value: item.selectionState(selectedIds),
            onChanged: (_) => onSetSelected(
              item.rowIds,
              item.selectionState(selectedIds) != true,
            ),
          ),
        ),
        Text(
          item.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    ),
  );

  Widget _row(BuildContext context, ThemeData theme, TransactionRowItem row) {
    final selected = selectedIds.contains(row.id);
    final columns = transactionTableColumns(row.row, containers);
    final description = row.note ?? '';

    return Container(
      decoration: BoxDecoration(
        color: selected ? AppTheme.accentSoft(theme.brightness) : null,
        border: Border(
          bottom: BorderSide(color: AppTheme.line(theme.brightness)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16 + 24.0 * row.depth, 4, 16, 4),
      child: InkWell(
        onTap: () => onTapRow(row),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _checkboxWidth,
              child: Checkbox(
                value: selected,
                onChanged: (v) => onSelectedChanged(row.id, v ?? false),
              ),
            ),
            SizedBox(
              width: _dateWidth,
              child: Text(
                dateTimeFormatPrefs.formatCalendarDate(row.effectiveDate),
                style: AppTheme.amountTextStyle(
                  theme.textTheme.labelSmall,
                ).copyWith(color: AppTheme.inkSoft(theme.brightness)),
              ),
            ),
            SizedBox(
              width: _typeWidth,
              child: _TypeBadge(kind: row.kind),
            ),
            Expanded(
              flex: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (row.tags.isNotEmpty)
                    TagPillRow(tags: row.tags, height: _tagsRowHeight),
                ],
              ),
            ),
            SizedBox(
              width: _amountWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: row.isTwoAssetTrade
                      ? TradeAmountText(
                          quantityOut: row.displayQuantity,
                          assetOut: row.displayAsset,
                          quantityIn: row.tradeQuantityIn!,
                          assetIn: row.tradeAssetIn!,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        )
                      : AmountText(
                          quantity: row.displayQuantity,
                          asset: row.displayAsset,
                          sign: row.sign,
                          style: theme.textTheme.bodySmall,
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: columns.budgetFrom != null && columns.budgetTo != null
                    ? Row(
                        children: [
                          Flexible(
                            child: _budgetName(columns.budgetFrom!, theme),
                          ),
                          Text(' → ', style: theme.textTheme.bodySmall),
                          Flexible(
                            child: _budgetName(columns.budgetTo!, theme),
                          ),
                        ],
                      )
                    : columns.budget != null
                    ? _budgetName(columns.budget!, theme)
                    : Text('—', style: theme.textTheme.bodySmall),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: columns.holderFrom != null && columns.holderTo != null
                    ? Row(
                        children: [
                          Flexible(
                            child: ContainerName(
                              columns.holderFrom!.name,
                              icon: columns.holderFrom!.icon,
                              maxLines: 1,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(' → ', style: theme.textTheme.bodySmall),
                          Flexible(
                            child: ContainerName(
                              columns.holderTo!.name,
                              icon: columns.holderTo!.icon,
                              maxLines: 1,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      )
                    : ContainerName(
                        columns.holderPath ?? '—',
                        icon: columns.holderIcon,
                        maxLines: 1,
                        style: theme.textTheme.bodySmall,
                      ),
              ),
            ),
            SizedBox(
              width: _syncWidth,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SyncStatusIcon(recordId: row.id),
                    ConflictResolveButton(
                      recordId: row.id,
                      onPressed: () => onResolveConflict(row),
                      size: _syncWidth,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _actionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (row.reorderClusterSize > 1 && onReorderCluster != null)
                    IconButton(
                      icon: const Icon(Icons.unfold_more, size: 18),
                      tooltip:
                          'Reorder ${row.reorderClusterSize} same-day entries',
                      visualDensity: VisualDensity.compact,
                      style: _actionButtonStyle,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => onReorderCluster!(row),
                    ),
                  if (onMakeRecurring != null && row.kind.canBeRecurring)
                    IconButton(
                      icon: const Icon(Icons.event_repeat, size: 18),
                      tooltip: 'Make recurring',
                      visualDensity: VisualDensity.compact,
                      style: _actionButtonStyle,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => onMakeRecurring!(row),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit',
                    visualDensity: VisualDensity.compact,
                    style: _actionButtonStyle,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => onTapRow(row),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    style: _actionButtonStyle,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => onDelete(row),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableList extends StatefulWidget {
  final List<TransactionListItem> items;
  final double Function(TransactionListItem) heightOf;
  final ScrollController? controller;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>>? onDragSelect;
  final double mouseDragZoneWidth;
  final IndexedWidgetBuilder itemBuilder;

  const _TableList({
    required this.items,
    required this.controller,
    required this.heightOf,
    required this.selectedIds,
    required this.onDragSelect,
    required this.mouseDragZoneWidth,
    required this.itemBuilder,
  });

  @override
  State<_TableList> createState() => _TableListState();
}

class _TableListState extends State<_TableList> {
  ScrollController? _owned;
  ScrollController get _controller =>
      widget.controller ?? (_owned ??= ScrollController());

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.builder(
      controller: _controller,
      itemCount: widget.items.length,
      itemExtentBuilder: (index, _) => widget.heightOf(widget.items[index]),
      itemBuilder: widget.itemBuilder,
    );
    final onDragSelect = widget.onDragSelect;
    if (onDragSelect == null) return list;
    return DragSelectRegion(
      items: widget.items,
      heightOf: widget.heightOf,
      controller: _controller,
      selectedIds: widget.selectedIds,
      onSelectionChanged: onDragSelect,
      mouseDragZoneWidth: widget.mouseDragZoneWidth,
      child: list,
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final ThemeData theme;
  final bool? allSelected;
  final VoidCallback? onToggleAll;
  const _HeaderRow({
    required this.theme,
    required this.allSelected,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: AppTheme.inkSoft(theme.brightness),
      letterSpacing: 0.5,
    );
    Widget label(String text) => Text(text.toUpperCase(), style: style);
    return Row(
      children: [
        SizedBox(
          width: TransactionTable._checkboxWidth,
          child: Checkbox(
            tristate: true,
            value: allSelected,
            onChanged: onToggleAll == null ? null : (_) => onToggleAll!(),
          ),
        ),
        SizedBox(width: TransactionTable._dateWidth, child: label('Date')),
        SizedBox(width: TransactionTable._typeWidth, child: label('Type')),
        Expanded(flex: 2, child: label('Description')),
        SizedBox(
          width: TransactionTable._amountWidth,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: label('Amount'),
            ),
          ),
        ),
        Expanded(flex: 3, child: label('Budget')),
        Expanded(flex: 2, child: label('Holder')),
        const SizedBox(width: TransactionTable._syncWidth),
        const SizedBox(width: TransactionTable._actionsWidth),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TransactionKind kind;
  const _TypeBadge({required this.kind});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = TransactionKindStyle.colorOf(kind, brightness);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TransactionKindStyle.iconOf(kind), color: color, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                TransactionKindStyle.labels[kind]!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _budgetName(
  ({String name, String path, String? icon}) leg,
  ThemeData theme,
) => Tooltip(
  message: leg.path,
  child: ContainerName(
    leg.name,
    icon: leg.icon,
    maxLines: 1,
    style: theme.textTheme.bodySmall,
  ),
);
