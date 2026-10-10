import 'package:decimal/decimal.dart';

import 'calendar_date.dart';
import 'models.dart';
import 'transaction_list_grouping.dart';

class AssetTotal {
  final Asset asset;
  final Decimal total;
  const AssetTotal(this.asset, this.total);
}

class KindStats {
  final TransactionKind kind;
  final int count;
  final List<AssetTotal> totals;
  final List<AssetTotal> totalsIn;
  const KindStats({
    required this.kind,
    required this.count,
    required this.totals,
    this.totalsIn = const [],
  });
}

class SelectionStats {
  final int count;

  final List<KindStats> byKind;

  final List<AssetTotal> net;

  final CalendarDate? firstDate;
  final CalendarDate? lastDate;

  const SelectionStats({
    required this.count,
    required this.byKind,
    required this.net,
    this.firstDate,
    this.lastDate,
  });
}

SelectionStats computeSelectionStats(Iterable<TransactionRowItem> rows) {
  final counts = <TransactionKind, int>{};
  final outs = <TransactionKind, Map<String, AssetTotal>>{};
  final ins = <TransactionKind, Map<String, AssetTotal>>{};
  final net = <String, AssetTotal>{};
  CalendarDate? first, last;
  var count = 0;

  void add(Map<String, AssetTotal> into, Asset asset, Decimal q) {
    final prev = into[asset.id]?.total ?? Decimal.zero;
    into[asset.id] = AssetTotal(asset, prev + q);
  }

  for (final r in rows) {
    count++;
    counts[r.kind] = (counts[r.kind] ?? 0) + 1;
    final q = r.displayQuantity.abs();
    add(outs.putIfAbsent(r.kind, () => {}), r.displayAsset, q);
    if (r.kind == TransactionKind.trade &&
        r.tradeQuantityIn != null &&
        r.tradeAssetIn != null) {
      add(
        ins.putIfAbsent(r.kind, () => {}),
        r.tradeAssetIn!,
        r.tradeQuantityIn!,
      );
    }
    if (r.kind == TransactionKind.income) add(net, r.displayAsset, q);
    if (r.kind == TransactionKind.expense) add(net, r.displayAsset, -q);
    if (first == null || r.effectiveDate.compareTo(first) < 0) {
      first = r.effectiveDate;
    }
    if (last == null || r.effectiveDate.compareTo(last) > 0) {
      last = r.effectiveDate;
    }
  }

  List<AssetTotal> sorted(Map<String, AssetTotal>? m) =>
      (m?.values.toList() ?? [])
        ..sort((a, b) => a.asset.symbol.compareTo(b.asset.symbol));

  return SelectionStats(
    count: count,
    byKind: [
      for (final kind in TransactionKind.values)
        if (counts.containsKey(kind))
          KindStats(
            kind: kind,
            count: counts[kind]!,
            totals: sorted(outs[kind]),
            totalsIn: sorted(ins[kind]),
          ),
    ],
    net: sorted(net),
    firstDate: first,
    lastDate: last,
  );
}
