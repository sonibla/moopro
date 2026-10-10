import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../domain/models.dart';
import '../domain/transaction_kind_style.dart';

class ExpandableAddFab extends StatelessWidget {
  final ValueChanged<TransactionKind> onSelectKind;

  const ExpandableAddFab({super.key, required this.onSelectKind});

  static const _kinds = [
    TransactionKind.trade,
    TransactionKind.budgetTransfer,
    TransactionKind.holderTransfer,
    TransactionKind.expense,
    TransactionKind.income,
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      spacing: 8,
      spaceBetweenChildren: 8,
      heroTag: 'transactionsScreenFab',
      tooltip: 'Add transaction',
      shape: const CircleBorder(),
      renderOverlay: false,
      children: [
        for (final kind in _kinds)
          SpeedDialChild(
            key: ValueKey(kind.name),
            label: TransactionKindStyle.labels[kind],
            backgroundColor: TransactionKindStyle.colorOf(kind, brightness),
            foregroundColor: Theme.of(context).colorScheme.surface,
            child: Icon(TransactionKindStyle.iconOf(kind)),
            onTap: () => onSelectKind(kind),
          ),
      ],
    );
  }
}
