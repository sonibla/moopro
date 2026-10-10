import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../widgets/amount_text.dart';
import 'models.dart';
import 'transaction_display.dart';
import 'transaction_filter.dart';
import 'transaction_ordering.dart';
import 'calendar_date.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Asset _toDomainAsset(ldb.Asset a) => Asset.fromJson(a.id, {
  'kind': a.kind,
  'symbol': a.symbol,
  'name': a.name,
  'displaySymbol': a.displaySymbol,
});

sealed class TransactionListItem {
  const TransactionListItem();
}

class DateHeaderItem extends TransactionListItem {
  final String label;

  final List<String> rowIds;
  const DateHeaderItem(this.label, [this.rowIds = const []]);

  bool? selectionState(Set<String> selected) {
    if (rowIds.isEmpty) return false;
    final count = rowIds.where(selected.contains).length;
    if (count == 0) return false;
    return count == rowIds.length ? true : null;
  }
}

class NowMarkerItem extends TransactionListItem {
  const NowMarkerItem();

  static const double height = 32;
}

double offsetOfItem(
  List<TransactionListItem> items,
  int index,
  double Function(TransactionListItem) heightOf,
) {
  var offset = 0.0;
  for (var i = 0; i < index; i++) {
    offset += heightOf(items[i]);
  }
  return offset;
}

int indexOfNowMarker(List<TransactionListItem> items) =>
    items.indexWhere((i) => i is NowMarkerItem);

class TransactionRowItem extends TransactionListItem {
  final ldb.Transaction row;
  final String id;
  final CalendarDate effectiveDate;
  final DateTime postedAt;
  final String? note;
  final String title;
  final Decimal displayQuantity;
  final Asset displayAsset;
  final AmountSign sign;
  final TransactionKind kind;
  final List<String> tags;

  final Decimal? tradeQuantityIn;
  final Asset? tradeAssetIn;

  final String? reorderClusterId;
  final int reorderClusterSize;

  final int depth;

  const TransactionRowItem({
    required this.row,
    required this.id,
    required this.effectiveDate,
    required this.postedAt,
    this.note,
    required this.title,
    required this.displayQuantity,
    required this.displayAsset,
    required this.sign,
    required this.kind,
    this.tradeQuantityIn,
    this.tradeAssetIn,
    this.reorderClusterId,
    this.reorderClusterSize = 1,
    this.tags = const [],
    this.depth = 0,
  });

  TransactionRowItem withDepth(int depth) => depth == this.depth
      ? this
      : TransactionRowItem(
          row: row,
          id: id,
          effectiveDate: effectiveDate,
          postedAt: postedAt,
          note: note,
          title: title,
          displayQuantity: displayQuantity,
          displayAsset: displayAsset,
          sign: sign,
          kind: kind,
          tradeQuantityIn: tradeQuantityIn,
          tradeAssetIn: tradeAssetIn,
          reorderClusterId: reorderClusterId,
          reorderClusterSize: reorderClusterSize,
          tags: tags,
          depth: depth,
        );

  bool get isTwoAssetTrade =>
      kind == TransactionKind.trade &&
      tradeQuantityIn != null &&
      tradeAssetIn != null;

  bool get postedOnDifferentDay =>
      CalendarDate.fromDateTime(postedAt) != effectiveDate;
}

class TransactionGroupItem extends TransactionListItem {
  final String id;
  final TransactionKind kind;
  final Asset asset;
  final String sourceContainerId;
  final String sourceName;

  final Decimal total;

  final List<TransferDestination> destinations;

  final List<TransactionListItem> children;

  final List<String> leafIds;

  final int depth;

  const TransactionGroupItem({
    required this.id,
    required this.kind,
    required this.asset,
    required this.sourceContainerId,
    required this.sourceName,
    required this.total,
    required this.destinations,
    required this.children,
    required this.leafIds,
    this.depth = 0,
  });

  bool? selectionState(Set<String> selected) {
    if (leafIds.isEmpty) return false;
    final count = leafIds.where(selected.contains).length;
    if (count == 0) return false;
    return count == leafIds.length ? true : null;
  }
}

Iterable<TransactionRowItem> allRows(
  Iterable<TransactionListItem> items,
) sync* {
  for (final item in items) {
    if (item is TransactionRowItem) {
      yield item;
    } else if (item is TransactionGroupItem) {
      yield* allRows(item.children);
    }
  }
}

Set<String> selectableIds(Iterable<TransactionListItem> items) => {
  for (final i in items)
    if (i is TransactionRowItem)
      i.id
    else if (i is TransactionGroupItem)
      ...i.leafIds,
};

List<TransactionListItem> visibleItems(
  List<TransactionListItem> items,
  Set<String> expanded,
) {
  if (!items.any((i) => i is TransactionGroupItem)) return items;
  final out = <TransactionListItem>[];
  void add(TransactionListItem item) {
    out.add(item);
    if (item is TransactionGroupItem && expanded.contains(item.id)) {
      item.children.forEach(add);
    }
  }

  items.forEach(add);
  return out;
}

typedef TransferDestination = ({
  String containerId,
  String name,
  Decimal total,
});

bool _isTransferKind(TransactionKind k) =>
    k == TransactionKind.budgetTransfer || k == TransactionKind.holderTransfer;

List<TransactionListItem> collapseTransferRuns(
  List<TransactionListItem> items,
  String Function(String containerId) nameOf,
) {
  final out = <TransactionListItem>[];
  var i = 0;
  while (i < items.length) {
    final item = items[i];
    if (item is! TransactionRowItem || !_isTransferKind(item.kind)) {
      out.add(item);
      i++;
      continue;
    }
    final run = <TransactionRowItem>[item];
    var j = i + 1;
    while (j < items.length) {
      final next = items[j];
      if (next is! TransactionRowItem ||
          next.kind != item.kind ||
          next.row.legOutAssetId != item.row.legOutAssetId ||
          next.row.legInAssetId != item.row.legOutAssetId) {
        break;
      }
      run.add(next);
      j++;
    }
    if (item.row.legInAssetId != item.row.legOutAssetId) {
      out.add(item);
      i++;
      continue;
    }
    out.addAll(_groupRun(run, nameOf));
    i = j;
  }
  return out;
}

class _SourceNode {
  final String source;
  final List<TransactionRowItem> rows = [];
  final List<_SourceNode> kids = [];
  _SourceNode? parent;
  int firstIndex;
  _SourceNode(this.source, this.firstIndex);
}

List<TransactionListItem> _groupRun(
  List<TransactionRowItem> run,
  String Function(String) nameOf,
) {
  final nodes = <String, _SourceNode>{};
  for (var idx = 0; idx < run.length; idx++) {
    final row = run[idx];
    (nodes[row.row.legOutContainerId] ??= _SourceNode(
      row.row.legOutContainerId,
      idx,
    )).rows.add(row);
  }

  for (final node in nodes.values) {
    for (final candidate in nodes.values) {
      if (identical(candidate, node)) continue;
      if (!candidate.rows.any((r) => r.row.legInContainerId == node.source)) {
        continue;
      }
      var cyclic = false;
      for (var p = candidate; ; p = p.parent!) {
        if (identical(p, node)) {
          cyclic = true;
          break;
        }
        if (p.parent == null) break;
      }
      if (cyclic) continue;
      node.parent = candidate;
      candidate.kids.add(node);
      break;
    }
  }

  int minIndex(_SourceNode n) {
    var m = n.firstIndex;
    for (final k in n.kids) {
      final km = minIndex(k);
      if (km < m) m = km;
    }
    return m;
  }

  final roots = nodes.values.where((n) => n.parent == null).toList()
    ..sort((a, b) => minIndex(a).compareTo(minIndex(b)));
  return [for (final r in roots) _buildNode(r, nameOf, 0)];
}

TransactionListItem _buildNode(
  _SourceNode node,
  String Function(String) nameOf,
  int depth,
) {
  final children = <TransactionListItem>[];
  final placed = <_SourceNode>{};
  for (final row in node.rows) {
    children.add(row.withDepth(depth + 1));
    for (final kid in node.kids) {
      if (kid.source == row.row.legInContainerId && placed.add(kid)) {
        children.add(_buildNode(kid, nameOf, depth + 1));
      }
    }
  }

  final leafIds = <String>[
    for (final c in children)
      if (c is TransactionRowItem)
        c.id
      else if (c is TransactionGroupItem)
        ...c.leafIds,
  ];
  if (leafIds.length < 2) return node.rows.single.withDepth(depth);

  final byDest = <String, Decimal>{};
  var total = Decimal.zero;
  for (final row in node.rows) {
    total += row.displayQuantity;
    byDest.update(
      row.row.legInContainerId,
      (v) => v + row.displayQuantity,
      ifAbsent: () => row.displayQuantity,
    );
  }
  final first = node.rows.first;
  return TransactionGroupItem(
    id: '${node.source}|${([...leafIds]..sort()).first}',
    kind: first.kind,
    asset: first.displayAsset,
    sourceContainerId: node.source,
    sourceName: nameOf(node.source),
    total: total,
    destinations: [
      for (final e in byDest.entries)
        (containerId: e.key, name: nameOf(e.key), total: e.value),
    ]..sort((a, b) => b.total.compareTo(a.total)),
    children: children,
    leafIds: leafIds,
    depth: depth,
  );
}

class TransactionListGroupInput {
  final List<ldb.Transaction> rows;
  final TransactionFilter filter;
  final Map<String, String> containerNames;
  final Map<String, ldb.Asset> assetsById;
  final DateTime now;

  const TransactionListGroupInput({
    required this.rows,
    required this.filter,
    required this.containerNames,
    required this.assetsById,
    required this.now,
  });
}

String _dayLabel(CalendarDate date, DateTime now) {
  final today = CalendarDate.fromDateTime(now);
  final diff = date.daysUntil(today);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  final suffix = date.year == now.year ? '' : ', ${date.year}';
  return '${_monthNames[date.month - 1]} ${date.day}$suffix';
}

String _dayKey(CalendarDate date) => date.toIso();

List<TransactionListItem> buildTransactionListItems(
  TransactionListGroupInput input,
) {
  final filtered = applyTransactionFilter(
    input.rows,
    input.filter,
    containerNames: input.containerNames,
    assetsById: input.assetsById,
    now: input.now,
  );
  if (filtered.isEmpty) return const [];

  final withMoney = _orderForDisplay(
    filtered.map((row) => (row: row, tx: _toMoneyTransaction(row))).toList(),
  );

  final clusterKeyFor = <String, String>{};
  final clusterCounts = <String, int>{};
  for (final entry in withMoney) {
    final key = '${_dayKey(entry.tx.effectiveDate)}|${entry.tx.kind.name}';
    clusterKeyFor[entry.row.id] = key;
    clusterCounts[key] = (clusterCounts[key] ?? 0) + 1;
  }

  final items = <TransactionListItem>[];
  final today = CalendarDate.fromDateTime(input.now);
  var sawFutureDay = false;
  var markerAdded = false;
  String? currentDayKey;
  List<String>? currentDayIds;
  for (final entry in withMoney) {
    final row = entry.row;
    final tx = entry.tx;
    final asset = input.assetsById[row.legOutAssetId];
    if (asset == null) continue;

    final dayKey = _dayKey(tx.effectiveDate);
    if (dayKey != currentDayKey) {
      if (tx.effectiveDate.isAfter(today)) {
        sawFutureDay = true;
      } else if (sawFutureDay && !markerAdded) {
        items.add(const NowMarkerItem());
        markerAdded = true;
      }
      currentDayIds = <String>[];
      items.add(
        DateHeaderItem(_dayLabel(tx.effectiveDate, input.now), currentDayIds),
      );
      currentDayKey = dayKey;
    }
    currentDayIds!.add(row.id);
    final display = TransactionDisplay.of(
      row,
      (id) => input.containerNames[id] ?? id,
    );
    final clusterKey = clusterKeyFor[row.id]!;
    final clusterSize = clusterCounts[clusterKey]!;

    final assetIn = tx.kind == TransactionKind.trade
        ? input.assetsById[row.legInAssetId]
        : null;

    items.add(
      TransactionRowItem(
        row: row,
        id: row.id,
        effectiveDate: row.effectiveDate,
        postedAt: row.postedAt,
        note: row.note,
        title: display.title,
        displayQuantity: Decimal.parse(row.legOutQuantity),
        displayAsset: _toDomainAsset(asset),
        tradeQuantityIn: assetIn == null
            ? null
            : Decimal.parse(row.legInQuantity),
        tradeAssetIn: assetIn == null ? null : _toDomainAsset(assetIn),
        sign: display.sign,
        kind: tx.kind,
        reorderClusterId: clusterSize > 1 ? clusterKey : null,
        reorderClusterSize: clusterSize,
        tags: decodeTagsColumn(row.tags),
      ),
    );
  }
  return collapseTransferRuns(items, (id) => input.containerNames[id] ?? id);
}

MoneyTransaction _toMoneyTransaction(ldb.Transaction row) => MoneyTransaction(
  id: row.id,
  postedAt: row.postedAt,
  effectiveDate: row.effectiveDate,
  note: row.note,
  kind: TransactionKind.fromJson(row.kind),
  legOut: TransactionLeg(
    containerId: row.legOutContainerId,
    assetId: row.legOutAssetId,
    quantity: Decimal.parse(row.legOutQuantity),
  ),
  legIn: TransactionLeg(
    containerId: row.legInContainerId,
    assetId: row.legInAssetId,
    quantity: Decimal.parse(row.legInQuantity),
  ),
  budgetLegOut: row.budgetLegOutContainerId == null
      ? null
      : TransactionLeg(
          containerId: row.budgetLegOutContainerId!,
          assetId: row.budgetLegOutAssetId!,
          quantity: Decimal.parse(row.budgetLegOutQuantity!),
        ),
  budgetLegIn: row.budgetLegInContainerId == null
      ? null
      : TransactionLeg(
          containerId: row.budgetLegInContainerId!,
          assetId: row.budgetLegInAssetId!,
          quantity: Decimal.parse(row.budgetLegInQuantity!),
        ),
  manualOrderRank: row.manualOrderRank,
);

typedef _RowWithTx = ({ldb.Transaction row, MoneyTransaction tx});

List<_RowWithTx> _orderForDisplay(List<_RowWithTx> withMoney) {
  final byDay = <CalendarDate, List<_RowWithTx>>{};
  for (final entry in withMoney) {
    (byDay[entry.tx.effectiveDate] ??= []).add(entry);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  final result = <_RowWithTx>[];
  for (final day in days) {
    final ordered = sameDaySafeOrder(
      byDay[day]!,
      providedPairs: (e) => _providedPairs(e.tx),
      requiredPairs: (e) => _requiredPairs(e.tx),
      groupOf: (e) => e.tx.kind.name,
      tieBreakCompare: (a, b) => compareSameDayTiebreak(
        (
          id: a.tx.id,
          kind: a.tx.kind.name,
          manualOrderRank: a.tx.manualOrderRank,
          postedAt: a.tx.postedAt,
        ),
        (
          id: b.tx.id,
          kind: b.tx.kind.name,
          manualOrderRank: b.tx.manualOrderRank,
          postedAt: b.tx.postedAt,
        ),
      ),
    );
    result.addAll(ordered.reversed);
  }
  return result;
}

List<String> _providedPairs(MoneyTransaction tx) => [
  if (tx.legIn.containerId != externalHolderContainerId)
    transactionPairKey(tx.legIn.containerId, tx.legIn.assetId),
  if (tx.budgetLegIn != null &&
      tx.budgetLegIn!.containerId != externalBudgetContainerId)
    transactionPairKey(tx.budgetLegIn!.containerId, tx.budgetLegIn!.assetId),
];

List<String> _requiredPairs(MoneyTransaction tx) => [
  if (tx.legOut.containerId != externalHolderContainerId)
    transactionPairKey(tx.legOut.containerId, tx.legOut.assetId),
  if (tx.budgetLegOut != null &&
      tx.budgetLegOut!.containerId != externalBudgetContainerId)
    transactionPairKey(tx.budgetLegOut!.containerId, tx.budgetLegOut!.assetId),
];
