import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import 'models.dart';

Decimal subtreeValue(
  String containerId,
  List<ldb.Container> containers,
  Map<String, Decimal> ownBalances,
) {
  var total = ownBalances[containerId] ?? Decimal.zero;
  for (final child in directChildren(containerId, containers)) {
    total += subtreeValue(child.id, containers, ownBalances);
  }
  return total;
}

List<ldb.Container> directChildren(
  String? containerId,
  List<ldb.Container> containers,
) =>
    containers.where((c) => c.parentId == containerId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

int containerColorIndex(String containerId, List<ldb.Container> containers) {
  final container = containers.where((c) => c.id == containerId).firstOrNull;
  if (container == null) return 0;
  final index = directChildren(
    container.parentId,
    containers,
  ).indexWhere((c) => c.id == containerId);
  return index < 0 ? 0 : index;
}

Set<String> descendantIds(String containerId, List<ldb.Container> containers) {
  final result = <String>{containerId};
  for (final child in directChildren(containerId, containers)) {
    result.addAll(descendantIds(child.id, containers));
  }
  return result;
}

Set<String> ancestorIds(String containerId, List<ldb.Container> containers) {
  final byId = {for (final c in containers) c.id: c};
  final result = <String>{};
  String? current = containerId;
  while (current != null && result.add(current)) {
    current = byId[current]?.parentId;
  }
  return result;
}

Decimal subtreePositiveValue(
  String containerId,
  List<ldb.Container> containers,
  Map<String, Decimal> ownBalances,
) {
  final own = ownBalances[containerId] ?? Decimal.zero;
  var total = own > Decimal.zero ? own : Decimal.zero;
  for (final child in directChildren(containerId, containers)) {
    total += subtreePositiveValue(child.id, containers, ownBalances);
  }
  return total;
}

Decimal subtreeDebtValue(
  String containerId,
  List<ldb.Container> containers,
  Map<String, Decimal> ownBalances,
) {
  final own = ownBalances[containerId] ?? Decimal.zero;
  var total = own < Decimal.zero ? own : Decimal.zero;
  for (final child in directChildren(containerId, containers)) {
    total += subtreeDebtValue(child.id, containers, ownBalances);
  }
  return total;
}

class PieTreeNode {
  final String id;
  final String label;
  final double value;
  final double debtValue;

  final String? icon;

  final int? colorIndex;

  final bool hasUnconvertible;

  final List<PieTreeNode> children;

  const PieTreeNode({
    required this.id,
    required this.label,
    required this.value,
    this.debtValue = 0,
    this.icon,
    this.colorIndex,
    this.hasUnconvertible = false,
    this.children = const [],
  });

  bool get hasDebt => debtValue < 0;
}

List<PieTreeNode> buildPieTree(
  List<ldb.Container> containers,
  Map<String, Decimal> ownBalances,
  String? parentId, {
  Map<String, Decimal>? ownDebtBalances,
  Set<String>? containersWithUnconvertible,
  List<ldb.Container>? colorSource,
}) {
  final debtSource = ownDebtBalances ?? ownBalances;
  final children = containers.where((c) => c.parentId == parentId).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return [
    for (final c in children)
      PieTreeNode(
        id: c.id,
        label: c.name,
        icon: c.icon,
        colorIndex: containerColorIndex(c.id, colorSource ?? containers),
        value: subtreePositiveValue(c.id, containers, ownBalances).toDouble(),
        debtValue: subtreeDebtValue(c.id, containers, debtSource).toDouble(),
        hasUnconvertible: containersWithUnconvertible?.contains(c.id) ?? false,
        children: buildPieTree(
          containers,
          ownBalances,
          c.id,
          ownDebtBalances: ownDebtBalances,
          containersWithUnconvertible: containersWithUnconvertible,
          colorSource: colorSource,
        ),
      ),
  ];
}

class FlatContainerRow {
  final ldb.Container container;
  final int depth;
  const FlatContainerRow({required this.container, required this.depth});
}

List<FlatContainerRow> flattenContainerTree(
  List<ldb.Container> containers, {
  String? parentId,
  int depth = 0,
}) {
  final result = <FlatContainerRow>[];
  for (final child in directChildren(parentId, containers)) {
    result.add(FlatContainerRow(container: child, depth: depth));
    result.addAll(
      flattenContainerTree(containers, parentId: child.id, depth: depth + 1),
    );
  }
  return result;
}

String breadcrumbPath(String containerId, List<ldb.Container> containers) {
  final byId = {for (final c in containers) c.id: c};
  final names = <String>[];
  String? current = containerId;
  final visited = <String>{};
  while (current != null && visited.add(current)) {
    final c = byId[current];
    if (c == null) break;
    names.add(c.name);
    current = c.parentId;
  }
  return names.reversed.join(' › ');
}

List<String> recentContainerIds(
  List<ldb.Transaction> transactions,
  List<ldb.Container> containers,
  ContainerType type, {
  int limit = 6,
}) {
  final typeById = {
    for (final c in containers) c.id: ContainerType.fromJson(c.containerType),
  };
  bool matches(String? id) =>
      id != null &&
      id != externalHolderContainerId &&
      id != externalBudgetContainerId &&
      typeById[id] == type;

  final sorted = [...transactions]
    ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  final seen = <String>{};
  final result = <String>[];
  for (final tx in sorted) {
    if (result.length >= limit) break;
    for (final id in [
      tx.legOutContainerId,
      tx.legInContainerId,
      tx.budgetLegOutContainerId,
      tx.budgetLegInContainerId,
    ]) {
      if (matches(id) && seen.add(id!)) {
        result.add(id);
        if (result.length >= limit) break;
      }
    }
  }
  return result;
}
