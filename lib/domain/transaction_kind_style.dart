import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'models.dart';

abstract class TransactionKindStyle {
  static const Color _holderTransferLight = Color(0xFF6B6558);
  static const Color _holderTransferDark = Color(0xFFB0A99A);
  static const Color _budgetTransferLight = Color(0xFFB8791F);
  static const Color _budgetTransferDark = Color(0xFFD9A44E);
  static const Color _tradeLight = Color(0xFF46557F);
  static const Color _tradeDark = Color(0xFF93A2C9);

  static IconData iconOf(TransactionKind kind) {
    switch (kind) {
      case TransactionKind.income:
        return Icons.arrow_circle_down_rounded;
      case TransactionKind.expense:
        return Icons.arrow_circle_up_rounded;
      case TransactionKind.holderTransfer:
        return Icons.account_balance;
      case TransactionKind.budgetTransfer:
        return Icons.pie_chart;
      case TransactionKind.trade:
        return Icons.currency_exchange;
    }
  }

  static Color colorOf(TransactionKind kind, Brightness brightness) {
    switch (kind) {
      case TransactionKind.income:
        return AppTheme.positiveAmountColor(brightness);
      case TransactionKind.expense:
        return AppTheme.negativeAmountColor(brightness);
      case TransactionKind.holderTransfer:
        return brightness == Brightness.dark
            ? _holderTransferDark
            : _holderTransferLight;
      case TransactionKind.budgetTransfer:
        return brightness == Brightness.dark
            ? _budgetTransferDark
            : _budgetTransferLight;
      case TransactionKind.trade:
        return brightness == Brightness.dark ? _tradeDark : _tradeLight;
    }
  }

  static const Map<TransactionKind, String> labels = {
    TransactionKind.income: 'Income',
    TransactionKind.expense: 'Expense',
    TransactionKind.holderTransfer: 'Holder xfer',
    TransactionKind.budgetTransfer: 'Budget xfer',
    TransactionKind.trade: 'Trade',
  };
}
