import '../db/domain_cache_database.dart' as ldb;
import '../widgets/amount_text.dart';
import 'models.dart';

class TransactionDisplay {
  final String title;
  final AmountSign sign;

  const TransactionDisplay({required this.title, required this.sign});

  factory TransactionDisplay.of(
    ldb.Transaction tx,
    String Function(String id) nameOf,
  ) {
    final kind = TransactionKind.fromJson(tx.kind);
    switch (kind) {
      case TransactionKind.income:
        return TransactionDisplay(
          sign: AmountSign.positive,
          title:
              '${nameOf(tx.legInContainerId)} · ${nameOf(tx.budgetLegInContainerId ?? '')}',
        );
      case TransactionKind.expense:
        return TransactionDisplay(
          sign: AmountSign.negative,
          title:
              '${nameOf(tx.legOutContainerId)} · ${nameOf(tx.budgetLegOutContainerId ?? '')}',
        );
      case TransactionKind.holderTransfer:
      case TransactionKind.budgetTransfer:
      case TransactionKind.trade:
        return TransactionDisplay(
          sign: AmountSign.neutral,
          title:
              '${nameOf(tx.legOutContainerId)} → ${nameOf(tx.legInContainerId)}',
        );
    }
  }
}
