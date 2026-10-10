import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'bank_icons.dart';
import 'container_icon.dart';
import 'fa_icon_registry.g.dart';

class ContainerIconPick {
  final String? key;
  const ContainerIconPick(this.key);
}

Future<ContainerIconPick?> showContainerIconPicker(
  BuildContext context, {
  String? selected,
}) {
  return showDialog<ContainerIconPick>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: ContainerIconPickerContent(selected: selected),
      ),
    ),
  );
}

class _PickerItem {
  final String key;
  final String label;
  final String searchText;
  const _PickerItem(this.key, this.label, this.searchText);
}

final List<_PickerItem> _bankItems = [
  for (final b in bankIconRegistry.values)
    _PickerItem(
      ContainerIconKey.bank(b.id),
      b.name,
      '${b.name} ${b.id} ${b.aliases.join(' ')}'.toLowerCase(),
    ),
];

final List<_PickerItem> _faItems = [
  for (final e in faIconRegistry.entries)
    _PickerItem(
      ContainerIconKey.fontAwesome(e.key),
      e.value.label,
      '${e.value.label} ${e.key} ${e.value.terms}'.toLowerCase(),
    ),
];

final List<_PickerItem> _allItems = [..._bankItems, ..._faItems];

class ContainerIconPickerContent extends StatefulWidget {
  final String? selected;
  const ContainerIconPickerContent({super.key, this.selected});

  @override
  State<ContainerIconPickerContent> createState() =>
      _ContainerIconPickerContentState();
}

class _ContainerIconPickerContentState
    extends State<ContainerIconPickerContent> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PickerItem> _filter(List<_PickerItem> items) {
    final tokens = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return items;
    return [
      for (final i in items)
        if (tokens.every(i.searchText.contains)) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filter(_allItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Choose icon', style: theme.textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search icons',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 4),
        ListTile(
          dense: true,
          leading: const Icon(Icons.hide_image_outlined),
          title: const Text('No icon'),
          selected: widget.selected == null,
          onTap: () => Navigator.of(context).pop(const ContainerIconPick(null)),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No icons match',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 52,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _IconCell(
                    item: items[i],
                    selected: items[i].key == widget.selected,
                  ),
                ),
        ),
      ],
    );
  }
}

class _IconCell extends StatelessWidget {
  final _PickerItem item;
  final bool selected;
  const _IconCell({required this.item, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: item.label,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
          onTap: () => Navigator.of(context).pop(ContainerIconPick(item.key)),
          child: Center(
            child: ContainerIcon(
              item.key,
              size: 22,
              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
