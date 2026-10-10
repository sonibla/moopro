import 'package:decimal/decimal.dart';

import 'models.dart';
import 'transaction_list_grouping.dart';

class FlowNode {
  final String id;
  final String name;

  final int layer;

  final Decimal value;

  const FlowNode({
    required this.id,
    required this.name,
    required this.layer,
    required this.value,
  });
}

class FlowLink {
  final String from;
  final String to;
  final Decimal value;

  final bool isBack;

  const FlowLink({
    required this.from,
    required this.to,
    required this.value,
    required this.isBack,
  });
}

class TransferFlow {
  final Asset asset;
  final List<FlowNode> nodes;
  final List<FlowLink> links;

  const TransferFlow({
    required this.asset,
    required this.nodes,
    required this.links,
  });

  int get layerCount =>
      nodes.isEmpty ? 0 : nodes.map((n) => n.layer).reduce(_max) + 1;

  factory TransferFlow.fromGroup(
    TransactionGroupItem group,
    String Function(String containerId) nameOf,
  ) {
    final sums = <(String, String), Decimal>{};
    for (final row in allRows(group.children)) {
      final from = row.row.legOutContainerId;
      final to = row.row.legInContainerId;
      if (from == to) continue;
      sums.update(
        (from, to),
        (v) => v + row.displayQuantity,
        ifAbsent: () => row.displayQuantity,
      );
    }

    final ids = <String>[group.sourceContainerId];
    for (final (from, to) in sums.keys) {
      if (!ids.contains(from)) ids.add(from);
      if (!ids.contains(to)) ids.add(to);
    }

    final layers = <String, int>{group.sourceContainerId: 0};
    for (var level = 0; ; level++) {
      var grew = false;
      for (final (from, to) in sums.keys) {
        if (layers[from] == level && !layers.containsKey(to)) {
          layers[to] = level + 1;
          grew = true;
        }
      }
      if (!grew && !layers.values.any((l) => l > level)) break;
    }
    for (final id in ids) {
      layers.putIfAbsent(id, () => 0);
    }
    final back = {
      for (final e in sums.keys)
        if (layers[e.$2]! <= layers[e.$1]!) e,
    };

    final nodes = <FlowNode>[
      for (final id in ids)
        FlowNode(
          id: id,
          name: nameOf(id),
          layer: layers[id]!,
          value: _throughput(id, sums),
        ),
    ];
    return TransferFlow(
      asset: group.asset,
      nodes: nodes,
      links: [
        for (final e in sums.entries)
          FlowLink(
            from: e.key.$1,
            to: e.key.$2,
            value: e.value,
            isBack: back.contains(e.key),
          ),
      ],
    );
  }
}

int _max(int a, int b) => a > b ? a : b;

Decimal _throughput(String id, Map<(String, String), Decimal> sums) {
  var inflow = Decimal.zero;
  var outflow = Decimal.zero;
  for (final e in sums.entries) {
    if (e.key.$1 == id) outflow += e.value;
    if (e.key.$2 == id) inflow += e.value;
  }
  return inflow > outflow ? inflow : outflow;
}
