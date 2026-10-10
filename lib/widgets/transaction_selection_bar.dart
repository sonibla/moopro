import 'package:flutter/material.dart';

class TransactionSelectionBar extends StatelessWidget
    implements PreferredSizeWidget {
  final int selectedCount;

  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onMassEdit;
  final VoidCallback onStatistics;
  final VoidCallback onDelete;

  const TransactionSelectionBar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClose,
    required this.onCopy,
    required this.onMassEdit,
    required this.onStatistics,
    required this.onDelete,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allSelected = totalCount > 0 && selectedCount >= totalCount;
    final selectAllLabel = allSelected
        ? 'Deselect all'
        : 'Select all ($totalCount)';
    final compact = MediaQuery.sizeOf(context).width < 900;
    final disabledColor = scheme.onInverseSurface.withValues(alpha: 0.38);
    final actions = <({IconData icon, String label, VoidCallback? onTap})>[
      (
        icon: allSelected ? Icons.deselect : Icons.select_all,
        label: selectAllLabel,
        onTap: totalCount == 0 ? null : onSelectAll,
      ),
      (
        icon: Icons.bar_chart,
        label: 'Statistics',
        onTap: selectedCount == 0 ? null : onStatistics,
      ),
      (
        icon: Icons.sell_outlined,
        label: 'Mass edit',
        onTap: selectedCount == 0 ? null : onMassEdit,
      ),
      (
        icon: Icons.content_copy,
        label: 'Copy to date',
        onTap: selectedCount == 0 ? null : onCopy,
      ),
      (
        icon: Icons.delete_outline,
        label: 'Delete',
        onTap: selectedCount == 0 ? null : onDelete,
      ),
    ];
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
        onPressed: onClose,
      ),
      backgroundColor: scheme.inverseSurface,
      foregroundColor: scheme.onInverseSurface,
      elevation: 0,
      title: Text(
        '$selectedCount selected',
        style: TextStyle(color: scheme.onInverseSurface),
      ),
      actions: [
        for (final a in actions)
          if (compact)
            IconButton(
              icon: Icon(a.icon),
              tooltip: a.label,
              onPressed: a.onTap,
              style: IconButton.styleFrom(
                disabledForegroundColor: disabledColor,
              ),
            )
          else
            TextButton.icon(
              icon: Icon(a.icon),
              label: Text(a.label),
              onPressed: a.onTap,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onInverseSurface,
                disabledForegroundColor: disabledColor,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        const SizedBox(width: 8),
      ],
    );
  }
}
