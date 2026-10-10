import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import '../domain/transaction_kind_style.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_picker.dart';
import '../widgets/container_picker.dart';
import '../widgets/tag_input.dart';
import '../domain/calendar_date.dart';

Future<void> showRecurringTemplateForm(
  BuildContext context, {
  ldb.RecurringTransactionTemplate? existing,
  ldb.Transaction? from,
}) {
  final screen = RecurringTemplateFormScreen(existing: existing, from: from);
  if (MediaQuery.sizeOf(context).width > 900) {
    return showDialog<void>(context: context, builder: (_) => screen);
  }
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

final recurringTemplateKinds = [
  for (final kind in TransactionKind.values)
    if (kind.canBeRecurring) kind,
];

const _unitLabels = {
  RecurrenceUnit.day: 'day(s)',
  RecurrenceUnit.week: 'week(s)',
  RecurrenceUnit.month: 'month(s)',
  RecurrenceUnit.year: 'year(s)',
};

class RecurringTemplateFormScreen extends ConsumerStatefulWidget {
  final ldb.RecurringTransactionTemplate? existing;

  final ldb.Transaction? from;

  const RecurringTemplateFormScreen({super.key, this.existing, this.from});

  @override
  ConsumerState<RecurringTemplateFormScreen> createState() =>
      _RecurringTemplateFormScreenState();
}

class _RecurringTemplateFormScreenState
    extends ConsumerState<RecurringTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  final _maxOccurrencesController = TextEditingController();

  TransactionKind _kind = TransactionKind.expense;
  String? _holderId;
  String? _budgetId;
  String? _fromHolderId;
  String? _toHolderId;
  String? _fromBudgetId;
  String? _toBudgetId;
  String? _assetId;
  List<String> _tags = [];
  RecurrenceUnit _unit = RecurrenceUnit.month;
  CalendarDate _startDate = CalendarDate.today();
  CalendarDate? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      final from = widget.from;
      if (from != null) _seedFromTransaction(from);
      return;
    }
    _kind = TransactionKind.fromJson(existing.kind);
    switch (_kind) {
      case TransactionKind.income:
        _holderId = existing.legInContainerId;
        _budgetId = existing.budgetLegInContainerId;
        break;
      case TransactionKind.expense:
        _holderId = existing.legOutContainerId;
        _budgetId = existing.budgetLegOutContainerId;
        break;
      case TransactionKind.holderTransfer:
        _fromHolderId = existing.legOutContainerId;
        _toHolderId = existing.legInContainerId;
        break;
      case TransactionKind.budgetTransfer:
        _fromBudgetId = existing.legOutContainerId;
        _toBudgetId = existing.legInContainerId;
        break;
      case TransactionKind.trade:
        break;
    }
    _assetId = existing.legOutAssetId;
    _quantityController.text = existing.legOutQuantity;
    _noteController.text = existing.note ?? '';
    _tags = decodeTagsColumn(existing.tags);
    _unit = RecurrenceUnit.fromJson(existing.ruleUnit);
    _intervalController.text = existing.ruleInterval.toString();
    _startDate = existing.ruleStartDate;
    _endDate = existing.ruleEndDate;
    if (existing.ruleMaxOccurrences != null) {
      _maxOccurrencesController.text = existing.ruleMaxOccurrences.toString();
    }
  }

  void _seedFromTransaction(ldb.Transaction tx) {
    final kind = TransactionKind.fromJson(tx.kind);
    if (!kind.canBeRecurring) return;
    _kind = kind;
    switch (kind) {
      case TransactionKind.income:
        _holderId = tx.legInContainerId;
        _budgetId = tx.budgetLegInContainerId;
        break;
      case TransactionKind.expense:
        _holderId = tx.legOutContainerId;
        _budgetId = tx.budgetLegOutContainerId;
        break;
      case TransactionKind.holderTransfer:
        _fromHolderId = tx.legOutContainerId;
        _toHolderId = tx.legInContainerId;
        break;
      case TransactionKind.budgetTransfer:
        _fromBudgetId = tx.legOutContainerId;
        _toBudgetId = tx.legInContainerId;
        break;
      case TransactionKind.trade:
        break;
    }
    _assetId = tx.legOutAssetId;
    _quantityController.text = tx.legOutQuantity;
    _noteController.text = tx.note ?? '';
    _tags = decodeTagsColumn(tx.tags);
    _startDate = tx.effectiveDate.addMonthsClamped(1);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _intervalController.dispose();
    _maxOccurrencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetsStreamProvider);
    final wide = MediaQuery.sizeOf(context).width > 900;

    final body = assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load assets: $e')),
      data: (assets) => assets.isEmpty
          ? const Center(child: Text('No assets yet.'))
          : _buildForm(context, assets, wide),
    );

    if (wide) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: body,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'New recurring' : 'Edit recurring',
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildForm(BuildContext context, List<ldb.Asset> assets, bool wide) {
    _assetId ??= assets.first.id;
    final fields = _formFields(context, assets);

    if (wide) {
      return Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? 'New recurring'
                          : 'Edit recurring',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (widget.existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: _saving ? null : _delete,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: fields,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: fields,
      ),
    );
  }

  List<Widget> _formFields(BuildContext context, List<ldb.Asset> assets) {
    return [
      _kindTabs(),
      const SizedBox(height: 24),
      _amountInput(assets),
      const SizedBox(height: 24),
      if (_kind == TransactionKind.income ||
          _kind == TransactionKind.expense) ...[
        ContainerPickerField(
          label: 'Holder',
          type: ContainerType.holder,
          value: _holderId,
          onChanged: (v) => setState(() => _holderId = v),
        ),
        const SizedBox(height: 16),
        ContainerPickerField(
          label: 'Budget',
          type: ContainerType.budget,
          value: _budgetId,
          onChanged: (v) => setState(() => _budgetId = v),
        ),
        const SizedBox(height: 16),
      ],
      if (_kind == TransactionKind.holderTransfer) ...[
        ContainerPickerField(
          label: 'From holder',
          type: ContainerType.holder,
          value: _fromHolderId,
          onChanged: (v) => setState(() => _fromHolderId = v),
        ),
        const SizedBox(height: 16),
        ContainerPickerField(
          label: 'To holder',
          type: ContainerType.holder,
          value: _toHolderId,
          onChanged: (v) => setState(() => _toHolderId = v),
        ),
        const SizedBox(height: 16),
      ],
      if (_kind == TransactionKind.budgetTransfer) ...[
        ContainerPickerField(
          label: 'From budget',
          type: ContainerType.budget,
          value: _fromBudgetId,
          onChanged: (v) => setState(() => _fromBudgetId = v),
        ),
        const SizedBox(height: 16),
        ContainerPickerField(
          label: 'To budget',
          type: ContainerType.budget,
          value: _toBudgetId,
          onChanged: (v) => setState(() => _toBudgetId = v),
        ),
        const SizedBox(height: 16),
      ],
      TextFormField(
        controller: _noteController,
        decoration: const InputDecoration(
          labelText: 'Note',
          hintText: 'Add a note...',
        ),
      ),
      const SizedBox(height: 16),
      Text('Tags', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      TagInput(tags: _tags, onChanged: (v) => setState(() => _tags = v)),
      const SizedBox(height: 24),
      Text('Recurrence', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      _recurrenceRow(),
      const SizedBox(height: 16),
      _dateField(label: 'Start date', value: _startDate, onTap: _pickStartDate),
      const SizedBox(height: 16),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('End date'),
        value: _endDate != null,
        onChanged: (v) => setState(() => _endDate = v ? _startDate : null),
      ),
      if (_endDate != null) ...[
        const SizedBox(height: 8),
        _dateField(label: 'End date', value: _endDate!, onTap: _pickEndDate),
        const SizedBox(height: 16),
      ],
      TextFormField(
        controller: _maxOccurrencesController,
        decoration: const InputDecoration(
          labelText: 'Max occurrences (optional)',
          hintText: 'Leave blank for unlimited',
        ),
        keyboardType: TextInputType.number,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          final parsed = int.tryParse(v.trim());
          if (parsed == null || parsed <= 0) {
            return 'Enter a positive whole number';
          }
          return null;
        },
      ),
    ];
  }

  Widget _kindTabs() {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in recurringTemplateKinds)
          ChoiceChip(
            avatar: Icon(
              TransactionKindStyle.iconOf(kind),
              size: 18,
              color: _kind == kind
                  ? TransactionKindStyle.colorOf(kind, brightness)
                  : AppTheme.inkSoft(brightness),
            ),
            label: Text(TransactionKindStyle.labels[kind]!),
            selected: _kind == kind,
            onSelected: (_) => setState(() => _kind = kind),
            selectedColor: TransactionKindStyle.colorOf(
              kind,
              brightness,
            ).withValues(alpha: 0.18),
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }

  Widget _amountInput(List<ldb.Asset> assets) {
    final brightness = Theme.of(context).brightness;
    final (sign, color) = switch (_kind) {
      TransactionKind.income => ('+', AppTheme.positiveAmountColor(brightness)),
      TransactionKind.expense => (
        '−',
        AppTheme.negativeAmountColor(brightness),
      ),
      _ => ('', AppTheme.ink(brightness)),
    };
    final amountStyle = AppTheme.amountTextStyle(
      TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: color),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (sign.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(sign, style: amountStyle),
          ),
        Expanded(
          child: TextFormField(
            controller: _quantityController,
            style: amountStyle,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final parsed = Decimal.tryParse(v.trim());
              if (parsed == null || parsed <= Decimal.zero) {
                return 'Enter a positive amount';
              }
              return null;
            },
          ),
        ),
        _assetChip(assets),
      ],
    );
  }

  Widget _assetChip(List<ldb.Asset> assets) {
    final brightness = Theme.of(context).brightness;
    ldb.Asset? selected;
    for (final a in assets) {
      if (a.id == _assetId) selected = a;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: () async {
        final picked = await showAssetPicker(
          context: context,
          assets: assets,
          selectedId: _assetId,
        );
        if (picked != null) setState(() => _assetId = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.card(brightness),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppTheme.lineStrong(brightness)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected?.symbol ?? 'Select',
              style: TextStyle(
                color: AppTheme.ink(brightness),
                fontWeight: FontWeight.w600,
              ),
            ),
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

  Widget _recurrenceRow() {
    return Row(
      children: [
        const Text('Every'),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextFormField(
            controller: _intervalController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            validator: (v) {
              final parsed = int.tryParse((v ?? '').trim());
              if (parsed == null || parsed <= 0) return 'N/A';
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<RecurrenceUnit>(
            initialValue: _unit,
            items: [
              for (final unit in RecurrenceUnit.values)
                DropdownMenuItem(value: unit, child: Text(_unitLabels[unit]!)),
            ],
            onChanged: (v) => setState(() => _unit = v ?? _unit),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required CalendarDate value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          ref.watch(dateTimeFormatPrefsProvider).formatCalendarDate(value),
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = CalendarDate.fromDateTime(picked));
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (_endDate ?? _startDate).toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endDate = CalendarDate.fromDateTime(picked));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final assetId = _assetId;
    if (assetId == null) return;
    final quantity = Decimal.parse(_quantityController.text.trim());
    final interval = int.parse(_intervalController.text.trim());
    final maxOccurrencesText = _maxOccurrencesController.text.trim();
    final rule = RecurrenceRule(
      startDate: _startDate,
      unit: _unit,
      interval: interval,
      endDate: _endDate,
      maxOccurrences: maxOccurrencesText.isEmpty
          ? null
          : int.parse(maxOccurrencesText),
    );
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final repo = ref.read(domainRepositoryProvider);

    setState(() => _saving = true);
    try {
      switch (_kind) {
        case TransactionKind.income:
          if (_holderId == null || _budgetId == null) return;
          await repo.createRecurringIncomeTemplate(
            id: widget.existing?.id,
            holderId: _holderId!,
            budgetId: _budgetId!,
            assetId: assetId,
            quantity: quantity,
            rule: rule,
            note: note,
            tags: _tags,
          );
          break;
        case TransactionKind.expense:
          if (_holderId == null || _budgetId == null) return;
          await repo.createRecurringExpenseTemplate(
            id: widget.existing?.id,
            holderId: _holderId!,
            budgetId: _budgetId!,
            assetId: assetId,
            quantity: quantity,
            rule: rule,
            note: note,
            tags: _tags,
          );
          break;
        case TransactionKind.holderTransfer:
          if (_fromHolderId == null || _toHolderId == null) return;
          await repo.createRecurringHolderTransferTemplate(
            id: widget.existing?.id,
            fromHolderId: _fromHolderId!,
            toHolderId: _toHolderId!,
            assetId: assetId,
            quantity: quantity,
            rule: rule,
            note: note,
            tags: _tags,
          );
          break;
        case TransactionKind.budgetTransfer:
          if (_fromBudgetId == null || _toBudgetId == null) return;
          await repo.createRecurringBudgetTransferTemplate(
            id: widget.existing?.id,
            fromBudgetId: _fromBudgetId!,
            toBudgetId: _toBudgetId!,
            assetId: assetId,
            quantity: quantity,
            rule: rule,
            note: note,
            tags: _tags,
          );
          break;
        case TransactionKind.trade:
          return;
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recurring transaction?'),
        content: const Text(
          'This stops future occurrences. Transactions already posted from it are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    await ref
        .read(domainRepositoryProvider)
        .deleteRecurringTemplate(existing.id);
    if (mounted) Navigator.of(context).pop();
  }
}
