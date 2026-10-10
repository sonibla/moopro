import 'transaction_list_grouping.dart';

class ListGeometry {
  final List<double> _starts;
  final double totalHeight;

  ListGeometry._(this._starts, this.totalHeight);

  factory ListGeometry.of(
    List<TransactionListItem> items,
    double Function(TransactionListItem) heightOf,
  ) {
    final starts = <double>[];
    var y = 0.0;
    for (final item in items) {
      starts.add(y);
      y += heightOf(item);
    }
    return ListGeometry._(starts, y);
  }

  int indexAt(double y) {
    if (_starts.isEmpty) return -1;
    var lo = 0, hi = _starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_starts[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

Set<String> rangeSelection({
  required List<TransactionListItem> items,
  required int anchorIndex,
  required int currentIndex,
  required Set<String> baseline,
  required bool select,
}) {
  if (items.isEmpty) return {...baseline};
  final lo = (anchorIndex < currentIndex ? anchorIndex : currentIndex).clamp(
    0,
    items.length - 1,
  );
  final hi = (anchorIndex < currentIndex ? currentIndex : anchorIndex).clamp(
    0,
    items.length - 1,
  );
  final result = {...baseline};
  for (var i = lo; i <= hi; i++) {
    final item = items[i];
    final ids = switch (item) {
      TransactionRowItem() => [item.id],
      TransactionGroupItem() => item.leafIds,
      _ => const <String>[],
    };
    if (select) {
      result.addAll(ids);
    } else {
      result.removeAll(ids);
    }
  }
  return result;
}

int indexOfRow(List<TransactionListItem> items, String id) => items.indexWhere(
  (i) =>
      (i is TransactionRowItem && i.id == id) ||
      (i is TransactionGroupItem && i.leafIds.contains(id)),
);
