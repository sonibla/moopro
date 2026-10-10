import '../db/domain_cache_database.dart' as ldb;
import 'container_tree.dart';
import 'models.dart';

class TransactionTableColumns {
  final ({String name, String path, String? icon})? budget;
  final ({String name, String path, String? icon})? budgetFrom;
  final ({String name, String path, String? icon})? budgetTo;

  final String? holderPath;

  final String? holderIcon;

  final ({String name, String? icon})? holderFrom;
  final ({String name, String? icon})? holderTo;

  const TransactionTableColumns({
    this.budget,
    this.budgetFrom,
    this.budgetTo,
    this.holderPath,
    this.holderIcon,
    this.holderFrom,
    this.holderTo,
  });
}

TransactionTableColumns transactionTableColumns(
  ldb.Transaction row,
  List<ldb.Container> containers,
) {
  String path(String id) => breadcrumbPath(id, containers);
  ({String name, String path, String? icon}) leg(String id) {
    final c = containers.firstWhere((c) => c.id == id);
    return (name: c.name, path: path(id), icon: c.icon);
  }

  String? iconOf(String id) {
    for (final c in containers) {
      if (c.id == id) return c.icon;
    }
    return null;
  }

  switch (TransactionKind.fromJson(row.kind)) {
    case TransactionKind.income:
      return TransactionTableColumns(
        budget: leg(row.budgetLegInContainerId!),
        holderPath: path(row.legInContainerId),
        holderIcon: iconOf(row.legInContainerId),
      );
    case TransactionKind.expense:
      return TransactionTableColumns(
        budget: leg(row.budgetLegOutContainerId!),
        holderPath: path(row.legOutContainerId),
        holderIcon: iconOf(row.legOutContainerId),
      );
    case TransactionKind.holderTransfer:
      return TransactionTableColumns(
        holderPath:
            '${path(row.legOutContainerId)} → ${path(row.legInContainerId)}',
        holderFrom: (
          name: path(row.legOutContainerId),
          icon: iconOf(row.legOutContainerId),
        ),
        holderTo: (
          name: path(row.legInContainerId),
          icon: iconOf(row.legInContainerId),
        ),
      );
    case TransactionKind.budgetTransfer:
      return TransactionTableColumns(
        budgetFrom: leg(row.legOutContainerId),
        budgetTo: leg(row.legInContainerId),
      );
    case TransactionKind.trade:
      return TransactionTableColumns(
        budget: row.budgetLegOutContainerId == null
            ? null
            : leg(row.budgetLegOutContainerId!),
        holderPath: path(row.legOutContainerId),
        holderIcon: iconOf(row.legOutContainerId),
      );
  }
}
