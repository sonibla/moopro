import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/date_time_format_prefs.dart';
import '../domain/models.dart';
import '../domain/transaction_filter.dart';
import '../domain/transaction_kind_style.dart';
import '../theme/app_theme.dart';
import 'asset_form_dialog.dart' show assetDisplayTitle;
import 'asset_picker.dart';
import 'container_icon.dart';
import 'container_picker.dart';
import 'tag_picker.dart';

Iterable<ldb.Container> _realContainers(Iterable<ldb.Container> containers) =>
    containers.where(
      (c) =>
          c.id != externalHolderContainerId &&
          c.id != externalBudgetContainerId,
    );

ldb.Container? _containerById(List<ldb.Container> containers, String? id) {
  if (id == null) return null;
  for (final c in containers) {
    if (c.id == id) return c;
  }
  return null;
}

String _tagsSummary(Set<String> tags) => switch (tags.length) {
  0 => 'Tags',
  1 => tags.first,
  _ => '${tags.length} tags',
};

ldb.Asset? _assetById(List<ldb.Asset> assets, String? id) {
  if (id == null) return null;
  for (final a in assets) {
    if (a.id == id) return a;
  }
  return null;
}

class TransactionFilterBar extends StatefulWidget {
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onChanged;
  final List<ldb.Container> containers;
  final List<ldb.Asset> assets;

  final Map<String, int> tagCounts;

  final DateTimeFormatPrefs dateTimeFormatPrefs;

  const TransactionFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.containers,
    required this.assets,
    this.tagCounts = const {},
    this.dateTimeFormatPrefs = DateTimeFormatPrefs.defaults,
  });

  @override
  State<TransactionFilterBar> createState() => _TransactionFilterBarState();
}

class _TransactionFilterBarState extends State<TransactionFilterBar> {
  bool _mobileSearchExpanded = false;
  late final TextEditingController _searchController = TextEditingController(
    text: widget.filter.searchQuery,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch(String value) => widget.onChanged(
    widget.filter.copyWith(searchQuery: () => value.isEmpty ? null : value),
  );

  void _toggleKind(TransactionKind kind) {
    final kinds = {...widget.filter.kinds};
    if (!kinds.add(kind)) kinds.remove(kind);
    widget.onChanged(widget.filter.copyWith(kinds: kinds));
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: widget.filter.dateRange,
    );
    if (picked != null) {
      widget.onChanged(widget.filter.withDateScope(DateScope.custom, picked));
    }
  }

  Future<void> _pickContainer(BuildContext context, ContainerType type) async {
    final result = await showContainerPicker(
      context: context,
      type: type,
      title: type == ContainerType.holder
          ? 'Filter by holder'
          : 'Filter by budget',
      selectedId: widget.filter.containerId,
      allowNone: true,
    );
    if (result != null) {
      widget.onChanged(
        widget.filter.copyWith(containerId: () => result.containerId),
      );
    }
  }

  Future<void> _pickAsset(BuildContext context) async {
    final picked = await showAssetPicker(
      context: context,
      assets: widget.assets,
      selectedId: widget.filter.assetId,
    );
    if (picked != null) {
      widget.onChanged(widget.filter.copyWith(assetId: () => picked));
    }
  }

  Future<void> _pickTags(BuildContext context) async {
    final picked = await showTagPicker(
      context: context,
      tagCounts: widget.tagCounts,
      selected: widget.filter.tags,
    );
    if (picked != null) widget.onChanged(widget.filter.copyWith(tags: picked));
  }

  Future<void> _openMoreFilters(BuildContext context) async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MoreFiltersSheet(
        filter: widget.filter,
        containers: widget.containers,
        assets: widget.assets,
        tagCounts: widget.tagCounts,
        dateTimeFormatPrefs: widget.dateTimeFormatPrefs,
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: wide ? _desktopBar(context) : _mobileBar(context),
    );
  }

  Widget _desktopBar(BuildContext context) {
    final sortedContainers = _realContainers(widget.containers).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedContainer = _containerById(
      sortedContainers,
      widget.filter.containerId,
    );
    final selectedAsset = _assetById(widget.assets, widget.filter.assetId);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 20),
              hintText: 'Search notes, tags, amounts...',
            ),
            onChanged: _updateSearch,
          ),
        ),
        const SizedBox(width: 8),
        _typeFilterPill(context),
        const SizedBox(width: 8),
        _dateRangeFilterPill(context),
        const SizedBox(width: 8),
        _containerFilterPill(context, selectedContainer),
        const SizedBox(width: 8),
        _assetFilterPill(context, selectedAsset),
        if (widget.tagCounts.isNotEmpty || widget.filter.tags.isNotEmpty) ...[
          const SizedBox(width: 8),
          _tagFilterPill(context),
        ],
      ],
    );
  }

  Widget _typeFilterPill(BuildContext context) {
    final kinds = widget.filter.kinds;
    final label = switch (kinds.length) {
      0 => 'All types',
      1 => TransactionKindStyle.labels[kinds.first]!,
      _ => '${kinds.length} types',
    };
    return MenuAnchor(
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final kind in TransactionKind.values)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: kinds.contains(kind),
                  onChanged: (_) => _toggleKind(kind),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        TransactionKindStyle.iconOf(kind),
                        size: 18,
                        color: TransactionKindStyle.colorOf(
                          kind,
                          Theme.of(context).brightness,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(TransactionKindStyle.labels[kind]!),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      builder: (context, controller, _) => _pill(
        context: context,
        label: label,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  static FaIconData _presetIcon(DateRangePreset preset) => switch (preset) {
    DateRangePreset.last12Months => FontAwesomeIcons.calendarDays,
    DateRangePreset.yearToDate => FontAwesomeIcons.calendarCheck,
    DateRangePreset.monthToDate => FontAwesomeIcons.calendarDay,
  };

  Widget _dateRangeFilterPill(BuildContext context) {
    final filter = widget.filter;
    final range = filter.dateRange;
    final label = switch (filter.dateScope) {
      DateScope.all => 'Any dates',
      DateScope.past => 'Past',
      DateScope.future => 'Future',
      DateScope.custom =>
        range == null
            ? 'Custom range'
            : '${widget.dateTimeFormatPrefs.formatDate(range.start)} – '
                  '${widget.dateTimeFormatPrefs.formatDate(range.end)}',
    };
    return MenuAnchor(
      menuChildren: [
        for (final (scope, text, icon) in const [
          (DateScope.all, 'Any dates', FontAwesomeIcons.infinity),
          (DateScope.past, 'Past', FontAwesomeIcons.clockRotateLeft),
          (DateScope.future, 'Future', FontAwesomeIcons.forward),
        ])
          MenuItemButton(
            leadingIcon: FaIcon(icon, size: 16),
            onPressed: () => widget.onChanged(filter.withDateScope(scope)),
            child: Text(text),
          ),
        for (final preset in DateRangePreset.values)
          MenuItemButton(
            leadingIcon: FaIcon(_presetIcon(preset), size: 16),
            onPressed: () => widget.onChanged(
              filter.withDateScope(
                DateScope.custom,
                preset.resolve(DateTime.now()),
              ),
            ),
            child: Text(preset.label),
          ),
        MenuItemButton(
          leadingIcon: const FaIcon(FontAwesomeIcons.sliders, size: 16),
          onPressed: () => _pickDateRange(context),
          child: const Text('Custom range'),
        ),
      ],
      builder: (context, controller, _) => _pill(
        context: context,
        label: label,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        onClear: filter.dateScope == DateScope.all
            ? null
            : () => widget.onChanged(filter.withDateScope(DateScope.all)),
      ),
    );
  }

  Widget _containerFilterPill(BuildContext context, ldb.Container? selected) {
    final label = selected?.name ?? 'All budgets/holders';
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const ContainerTypeSwatch(type: ContainerType.budget),
          onPressed: () => _pickContainer(context, ContainerType.budget),
          child: const Text('Budget…'),
        ),
        MenuItemButton(
          leadingIcon: const ContainerTypeSwatch(type: ContainerType.holder),
          onPressed: () => _pickContainer(context, ContainerType.holder),
          child: const Text('Holder…'),
        ),
      ],
      builder: (context, controller, _) => _pill(
        context: context,
        label: label,
        icon: selected?.icon,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        onClear: selected == null
            ? null
            : () => widget.onChanged(
                widget.filter.copyWith(containerId: () => null),
              ),
      ),
    );
  }

  Widget _assetFilterPill(BuildContext context, ldb.Asset? selected) {
    final label = selected == null
        ? 'All assets'
        : assetDisplayTitle(selected.symbol, selected.name);
    return _pill(
      context: context,
      label: label,
      onTap: () => _pickAsset(context),
      onClear: selected == null
          ? null
          : () => widget.onChanged(widget.filter.copyWith(assetId: () => null)),
    );
  }

  Widget _tagFilterPill(BuildContext context) {
    final tags = widget.filter.tags;
    return Tooltip(
      message: tags.isEmpty ? '' : (tags.toList()..sort()).join(', '),
      child: _pill(
        context: context,
        label: _tagsSummary(tags),
        onTap: () => _pickTags(context),
        onClear: tags.isEmpty
            ? null
            : () => widget.onChanged(widget.filter.copyWith(tags: const {})),
      ),
    );
  }

  Widget _pill({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? icon,
  }) {
    final brightness = Theme.of(context).brightness;
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.card(brightness),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppTheme.lineStrong(brightness)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContainerName(
              label,
              icon: icon,
              style: TextStyle(color: AppTheme.ink(brightness)),
            ),
            const SizedBox(width: 2),
            if (onClear != null)
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.inkSoft(brightness),
                ),
              )
            else
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: AppTheme.inkSoft(brightness),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileBar(BuildContext context) {
    if (_mobileSearchExpanded) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search notes, tags, amounts...',
              ),
              onChanged: _updateSearch,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close search',
            onPressed: () => setState(() => _mobileSearchExpanded = false),
          ),
        ],
      );
    }

    final sheetActiveCount =
        (widget.filter.kinds.isEmpty ? 0 : 1) +
        (widget.filter.containerId == null ? 0 : 1) +
        (widget.filter.assetId == null ? 0 : 1) +
        (widget.filter.dateScope == DateScope.all ? 0 : 1) +
        (widget.filter.tags.isEmpty ? 0 : 1);

    return Row(
      children: [
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => setState(() => _mobileSearchExpanded = true),
        ),
        Badge(
          label: Text('$sheetActiveCount'),
          isLabelVisible: sheetActiveCount > 0,
          child: IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'More filters',
            onPressed: () => _openMoreFilters(context),
          ),
        ),
      ],
    );
  }
}

class _MoreFiltersSheet extends StatefulWidget {
  final TransactionFilter filter;
  final List<ldb.Container> containers;
  final List<ldb.Asset> assets;
  final Map<String, int> tagCounts;
  final DateTimeFormatPrefs dateTimeFormatPrefs;

  const _MoreFiltersSheet({
    required this.filter,
    required this.containers,
    required this.assets,
    required this.tagCounts,
    required this.dateTimeFormatPrefs,
  });

  @override
  State<_MoreFiltersSheet> createState() => _MoreFiltersSheetState();
}

class _MoreFiltersSheetState extends State<_MoreFiltersSheet> {
  late Set<TransactionKind> _kinds = {...widget.filter.kinds};
  late String? _containerId = widget.filter.containerId;
  late String? _assetId = widget.filter.assetId;
  late DateScope _dateScope = widget.filter.dateScope;
  late DateTimeRange? _dateRange = widget.filter.dateRange;
  late Set<String> _tags = {...widget.filter.tags};

  void _toggleKind(TransactionKind kind) {
    setState(() {
      final kinds = {..._kinds};
      if (!kinds.add(kind)) kinds.remove(kind);
      _kinds = kinds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedContainers = _realContainers(widget.containers).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More filters',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text('TYPE', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in TransactionKind.values)
                    FilterChip(
                      avatar: Icon(
                        TransactionKindStyle.iconOf(kind),
                        size: 18,
                        color: TransactionKindStyle.colorOf(
                          kind,
                          Theme.of(context).brightness,
                        ),
                      ),
                      label: Text(TransactionKindStyle.labels[kind]!),
                      selected: _kinds.contains(kind),
                      onSelected: (_) => _toggleKind(kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _containerId,
                decoration: const InputDecoration(labelText: 'Container'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final c in sortedContainers)
                    DropdownMenuItem(
                      value: c.id,
                      child: ContainerName(c.name, icon: c.icon),
                    ),
                ],
                onChanged: (v) => setState(() => _containerId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _assetId,
                decoration: const InputDecoration(labelText: 'Asset'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any')),
                  for (final a in widget.assets)
                    DropdownMenuItem(
                      value: a.id,
                      child: Text(assetDisplayTitle(a.symbol, a.name)),
                    ),
                ],
                onChanged: (v) => setState(() => _assetId = v),
              ),
              const SizedBox(height: 16),
              Text('DATES', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              SegmentedButton<DateScope>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DateScope.all, label: Text('All')),
                  ButtonSegment(value: DateScope.past, label: Text('Past')),
                  ButtonSegment(value: DateScope.future, label: Text('Future')),
                  ButtonSegment(value: DateScope.custom, label: Text('Custom')),
                ],
                selected: {_dateScope},
                onSelectionChanged: (s) => setState(() => _dateScope = s.first),
              ),
              if (_dateScope == DateScope.custom) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final preset in DateRangePreset.values)
                      ActionChip(
                        label: Text(preset.label),
                        onPressed: () => setState(
                          () => _dateRange = preset.resolve(DateTime.now()),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('customDateRangeField'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: _dateRange,
                    );
                    if (picked != null) setState(() => _dateRange = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date range'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateRange == null
                                ? 'Select dates'
                                : '${_fmt(_dateRange!.start)} – ${_fmt(_dateRange!.end)}',
                          ),
                        ),
                        const Icon(Icons.date_range),
                      ],
                    ),
                  ),
                ),
              ],
              if (widget.tagCounts.isNotEmpty || _tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  key: const ValueKey('tagsField'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    final picked = await showTagPicker(
                      context: context,
                      tagCounts: widget.tagCounts,
                      selected: _tags,
                    );
                    if (picked != null) setState(() => _tags = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Tags'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _tags.isEmpty ? 'Any' : _tagsSummary(_tags),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      TransactionFilter(searchQuery: widget.filter.searchQuery),
                    ),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      TransactionFilter(
                        kinds: _kinds,
                        containerId: _containerId,
                        assetId: _assetId,
                        tags: _tags,
                        dateScope: _dateScope,
                        dateRange: _dateScope == DateScope.custom
                            ? _dateRange
                            : null,
                        searchQuery: widget.filter.searchQuery,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) => widget.dateTimeFormatPrefs.formatDate(d);
}
