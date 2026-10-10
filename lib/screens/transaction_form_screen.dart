import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import '../domain/multi_asset_rollup.dart';
import '../domain/transaction_kind_style.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/asset_picker.dart';
import '../widgets/container_picker.dart';
import '../widgets/tag_input.dart';
import '../domain/calendar_date.dart';

typedef _FormSnapshot = ({
  CalendarDate effectiveDate,
  DateTime postedAt,
  TransactionKind kind,
  String? holderId,
  String? budgetId,
  String? fromHolderId,
  String? toHolderId,
  String? fromBudgetId,
  String? toBudgetId,
  String? assetId,
  String? tradeHolderId,
  String? tradeBudgetId,
  String? giveAssetId,
  String? getAssetId,
  List<String> tags,
  String note,
  String quantity,
  String giveQuantity,
  String getQuantity,
});

Future<void> showTransactionForm(
  BuildContext context, {
  ldb.Transaction? existing,
  TransactionKind? initialKind,
}) {
  final screen = TransactionFormScreen(
    existing: existing,
    initialKind: initialKind,
  );
  if (MediaQuery.sizeOf(context).width > 900) {
    return showDialog<void>(context: context, builder: (_) => screen);
  }
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class TransactionFormScreen extends ConsumerStatefulWidget {
  final ldb.Transaction? existing;

  final TransactionKind? initialKind;

  const TransactionFormScreen({super.key, this.existing, this.initialKind});

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _quantityController = TextEditingController();
  final _dialogFieldsScrollController = ScrollController();

  CalendarDate _effectiveDate = CalendarDate.today();
  DateTime _postedAt = DateTime.now();
  TransactionKind _kind = TransactionKind.expense;
  String? _holderId;
  String? _budgetId;
  String? _fromHolderId;
  String? _toHolderId;
  String? _fromBudgetId;
  String? _toBudgetId;
  String? _assetId;
  String? _tradeHolderId;
  String? _tradeBudgetId;
  String? _giveAssetId;
  final _giveQuantityController = TextEditingController();
  String? _getAssetId;
  final _getQuantityController = TextEditingController();

  Map<String, Decimal>? _tradeHolderBalancesOfGiveAsset;
  Map<String, Decimal>? _tradeBudgetBalancesOfGiveAsset;
  List<String> _tags = [];
  bool _saving = false;

  _FormSnapshot? _initialSnapshot;

  bool _forceClose = false;

  _FormSnapshot _currentSnapshot() => (
    effectiveDate: _effectiveDate,
    postedAt: _postedAt,
    kind: _kind,
    holderId: _holderId,
    budgetId: _budgetId,
    fromHolderId: _fromHolderId,
    toHolderId: _toHolderId,
    fromBudgetId: _fromBudgetId,
    toBudgetId: _toBudgetId,
    assetId: _assetId,
    tradeHolderId: _tradeHolderId,
    tradeBudgetId: _tradeBudgetId,
    giveAssetId: _giveAssetId,
    getAssetId: _getAssetId,
    tags: List<String>.of(_tags),
    note: _noteController.text,
    quantity: _quantityController.text,
    giveQuantity: _giveQuantityController.text,
    getQuantity: _getQuantityController.text,
  );

  bool get _isDirty {
    final initial = _initialSnapshot;
    if (initial == null) return false;
    final current = _currentSnapshot();
    return current.effectiveDate != initial.effectiveDate ||
        current.postedAt != initial.postedAt ||
        current.kind != initial.kind ||
        current.holderId != initial.holderId ||
        current.budgetId != initial.budgetId ||
        current.fromHolderId != initial.fromHolderId ||
        current.toHolderId != initial.toHolderId ||
        current.fromBudgetId != initial.fromBudgetId ||
        current.toBudgetId != initial.toBudgetId ||
        current.assetId != initial.assetId ||
        current.tradeHolderId != initial.tradeHolderId ||
        current.tradeBudgetId != initial.tradeBudgetId ||
        current.giveAssetId != initial.giveAssetId ||
        current.getAssetId != initial.getAssetId ||
        current.note != initial.note ||
        current.quantity != initial.quantity ||
        current.giveQuantity != initial.giveQuantity ||
        current.getQuantity != initial.getQuantity ||
        !listEquals(current.tags, initial.tags);
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('This transaction has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handlePopInvoked(bool didPop, void result) async {
    if (didPop) return;
    final discard = await _confirmDiscard();
    if (discard && mounted) {
      setState(() => _forceClose = true);
      Navigator.of(context).pop();
    }
  }

  void _requestClose() {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    _confirmDiscard().then((discard) {
      if (discard && mounted) Navigator.of(context).pop();
    });
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null && widget.initialKind != null) {
      _kind = widget.initialKind!;
    }
    if (existing != null) {
      _effectiveDate = existing.effectiveDate;
      _postedAt = existing.postedAt;
      _noteController.text = existing.note ?? '';
      _kind = TransactionKind.fromJson(existing.kind);
      _quantityController.text = existing.legOutQuantity;
      _assetId = existing.legOutAssetId;
      _tags = decodeTagsColumn(existing.tags);
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
          _tradeHolderId = existing.legOutContainerId;
          _tradeBudgetId = existing.budgetLegOutContainerId;
          _giveAssetId = existing.legOutAssetId;
          _giveQuantityController.text = existing.legOutQuantity;
          _getAssetId = existing.legInAssetId;
          _getQuantityController.text = existing.legInQuantity;
          break;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _quantityController.dispose();
    _giveQuantityController.dispose();
    _getQuantityController.dispose();
    _dialogFieldsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final containersAsync = ref.watch(containersStreamProvider);
    final assetsAsync = ref.watch(assetsStreamProvider);
    final wide = MediaQuery.sizeOf(context).width > 900;

    final body = containersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load containers: $e')),
      data: (containers) => assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load assets: $e')),
        data: (assets) => assets.isEmpty
            ? const Center(child: Text('No assets yet.'))
            : _buildForm(context, containers, assets, wide),
      ),
    );

    final Widget scaffold;
    if (wide) {
      scaffold = Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: body,
        ),
      );
    } else {
      scaffold = Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null ? 'New transaction' : 'Edit transaction',
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
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card(Theme.of(context).brightness),
              border: Border(
                top: BorderSide(
                  color: AppTheme.line(Theme.of(context).brightness),
                ),
              ),
            ),
            child: _saveButton(fullWidth: true),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_isDirty || _forceClose,
      onPopInvokedWithResult: _handlePopInvoked,
      child: scaffold,
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<ldb.Container> containers,
    List<ldb.Asset> assets,
    bool wide,
  ) {
    _assetId ??= assets.first.id;
    _giveAssetId ??= assets.first.id;
    _getAssetId ??= assets.length > 1 ? assets[1].id : assets.first.id;
    _initialSnapshot ??= _currentSnapshot();

    final fields = _formFields(context, containers, assets, wide);

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
                          ? 'New transaction'
                          : 'Edit transaction',
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
                    onPressed: _requestClose,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Scrollbar(
                controller: _dialogFieldsScrollController,
                child: SingleChildScrollView(
                  controller: _dialogFieldsScrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fields,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _requestClose,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  _saveButton(),
                ],
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

  List<Widget> _formFields(
    BuildContext context,
    List<ldb.Container> containers,
    List<ldb.Asset> assets,
    bool wide,
  ) {
    return [
      _typeTabs(),
      const SizedBox(height: 24),
      if (_kind == TransactionKind.trade)
        ..._tradeFields(containers, assets)
      else ...[
        _amountInput(assets),
        const SizedBox(height: 24),
      ],
      if (_kind == TransactionKind.income ||
          _kind == TransactionKind.expense) ...[
        _paired(
          ContainerPickerField(
            label: 'Holder',
            type: ContainerType.holder,
            value: _holderId,
            onChanged: (v) => setState(() => _holderId = v),
          ),
          ContainerPickerField(
            label: 'Budget',
            type: ContainerType.budget,
            value: _budgetId,
            onChanged: (v) => setState(() => _budgetId = v),
          ),
          wide,
        ),
        const SizedBox(height: 16),
      ],
      if (_kind == TransactionKind.holderTransfer) ...[
        _paired(
          ContainerPickerField(
            label: 'From holder',
            type: ContainerType.holder,
            value: _fromHolderId,
            onChanged: (v) => setState(() => _fromHolderId = v),
          ),
          ContainerPickerField(
            label: 'To holder',
            type: ContainerType.holder,
            value: _toHolderId,
            onChanged: (v) => setState(() => _toHolderId = v),
          ),
          wide,
        ),
        const SizedBox(height: 16),
      ],
      if (_kind == TransactionKind.budgetTransfer) ...[
        _paired(
          ContainerPickerField(
            label: 'From budget',
            type: ContainerType.budget,
            value: _fromBudgetId,
            onChanged: (v) => setState(() => _fromBudgetId = v),
          ),
          ContainerPickerField(
            label: 'To budget',
            type: ContainerType.budget,
            value: _toBudgetId,
            onChanged: (v) => setState(() => _toBudgetId = v),
          ),
          wide,
        ),
        const SizedBox(height: 16),
      ],
      _paired(
        _dateField(
          label: 'Effective date',
          value: _effectiveDate,
          onTap: _pickEffectiveDate,
        ),
        _postedAtField(),
        wide,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _noteController,
        decoration: const InputDecoration(
          labelText: 'Note',
          hintText: 'Add a note...',
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      Text('Tags', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      TagInput(tags: _tags, onChanged: (v) => setState(() => _tags = v)),
    ];
  }

  Widget _paired(Widget a, Widget b, bool wide) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    }
    return Column(children: [a, const SizedBox(height: 16), b]);
  }

  Widget _typeTabs() {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in TransactionKind.values) _typePill(kind, brightness),
      ],
    );
  }

  Widget _typePill(TransactionKind kind, Brightness brightness) {
    final active = _kind == kind;
    final color = TransactionKindStyle.colorOf(kind, brightness);
    return ChoiceChip(
      avatar: Icon(
        TransactionKindStyle.iconOf(kind),
        size: 18,
        color: active ? color : AppTheme.inkSoft(brightness),
      ),
      label: Text(TransactionKindStyle.labels[kind]!),
      selected: active,
      onSelected: (_) => setState(() => _kind = kind),
      selectedColor: color.withValues(alpha: 0.18),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: active ? color : AppTheme.lineStrong(brightness)),
      labelStyle: TextStyle(
        color: active ? color : AppTheme.ink(brightness),
        fontWeight: active ? FontWeight.w700 : FontWeight.normal,
      ),
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
            onChanged: (_) => setState(() {}),
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
        _assetChip(assets, _assetId, (v) => setState(() => _assetId = v)),
      ],
    );
  }

  Widget _assetChip(
    List<ldb.Asset> assets,
    String? assetId,
    ValueChanged<String?> onChanged,
  ) {
    final brightness = Theme.of(context).brightness;
    final selected = _assetById(assets, assetId);
    return InkWell(
      borderRadius: BorderRadius.circular(100),
      onTap: () async {
        final picked = await showAssetPicker(
          context: context,
          assets: assets,
          selectedId: assetId,
        );
        if (picked != null) onChanged(picked);
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

  Widget _dateField({
    required String label,
    required CalendarDate value,
    required VoidCallback onTap,
  }) {
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(prefs.formatCalendarDate(value)),
      ),
    );
  }

  Widget _postedAtField() {
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: _pickPostedAt,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Posted',
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.restore, size: 18),
                tooltip: 'Match effective date (midnight)',
                onPressed: _matchPostedAtToEffectiveDate,
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.schedule, size: 18),
              ),
            ],
          ),
        ),
        child: Text(prefs.formatDateTime(_postedAt)),
      ),
    );
  }

  Widget _saveButton({bool fullWidth = false}) {
    final brightness = Theme.of(context).brightness;
    final color = TransactionKindStyle.colorOf(_kind, brightness);
    final label = 'Save ${TransactionKindStyle.labels[_kind]!.toLowerCase()}';
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: _saving ? null : _save,
      child: _saving
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(),
            )
          : Text(label),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  List<Widget> _tradeFields(
    List<ldb.Container> containers,
    List<ldb.Asset> assets,
  ) {
    Widget assetAmountCard({
      required String label,
      required String? assetId,
      required TextEditingController controller,
      required ValueChanged<String?> onAssetChanged,
    }) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: AppTheme.amountTextStyle(
                        Theme.of(context).textTheme.headlineSmall,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _maybeAutofillTrade(assets);
                        _updateTradeEligibility(containers);
                      },
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
                  _assetChip(assets, assetId, onAssetChanged),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final holderIds = containers
        .where(
          (c) =>
              c.containerType == ContainerType.holder.name &&
              c.id != externalHolderContainerId &&
              c.id != externalBudgetContainerId,
        )
        .map((c) => c.id)
        .toSet();
    final budgetIds = containers
        .where(
          (c) =>
              c.containerType == ContainerType.budget.name &&
              c.id != externalHolderContainerId &&
              c.id != externalBudgetContainerId,
        )
        .map((c) => c.id)
        .toSet();
    final eligibleHolderIds = _tradeHolderBalancesOfGiveAsset?.keys.toSet();
    final eligibleBudgetIds = _tradeBudgetBalancesOfGiveAsset?.keys.toSet();
    final holderExcludeIds =
        (eligibleHolderIds == null || eligibleHolderIds.isEmpty)
        ? const <String>{}
        : holderIds.difference(eligibleHolderIds);
    final budgetExcludeIds =
        (eligibleBudgetIds == null || eligibleBudgetIds.isEmpty)
        ? const <String>{}
        : budgetIds.difference(eligibleBudgetIds);

    return [
      assetAmountCard(
        label: 'YOU GIVE',
        assetId: _giveAssetId,
        controller: _giveQuantityController,
        onAssetChanged: (v) {
          setState(() => _giveAssetId = v);
          _maybeAutofillTrade(assets);
          _updateTradeEligibility(containers);
        },
      ),
      Center(
        child: IconButton(
          icon: const Icon(Icons.swap_vert),
          tooltip: 'Swap',
          onPressed: _swapTradeSides,
        ),
      ),
      assetAmountCard(
        label: 'YOU GET',
        assetId: _getAssetId,
        controller: _getQuantityController,
        onAssetChanged: (v) {
          setState(() => _getAssetId = v);
          _maybeAutofillTrade(assets);
          _updateTradeEligibility(containers);
        },
      ),
      if (_tradeRateCaption(assets) != null) ...[
        const SizedBox(height: 4),
        Text(
          _tradeRateCaption(assets)!,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: 16),
      ContainerPickerField(
        label: 'Holder',
        type: ContainerType.holder,
        value: _tradeHolderId,
        excludeIds: holderExcludeIds,
        onChanged: (v) => setState(() => _tradeHolderId = v),
      ),
      const SizedBox(height: 16),
      ContainerPickerField(
        label: 'Budget',
        type: ContainerType.budget,
        value: _tradeBudgetId,
        excludeIds: budgetExcludeIds,
        onChanged: (v) => setState(() => _tradeBudgetId = v),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _updateTradeEligibility(List<ldb.Container> containers) async {
    final giveAssetId = _giveAssetId;
    if (giveAssetId == null) {
      if (_tradeHolderBalancesOfGiveAsset == null &&
          _tradeBudgetBalancesOfGiveAsset == null) {
        return;
      }
      setState(() {
        _tradeHolderBalancesOfGiveAsset = null;
        _tradeBudgetBalancesOfGiveAsset = null;
      });
      return;
    }

    bool isTracked(ldb.Container c) =>
        c.id != externalHolderContainerId && c.id != externalBudgetContainerId;
    final holders = containers
        .where(
          (c) => c.containerType == ContainerType.holder.name && isTracked(c),
        )
        .toList();
    final budgets = containers
        .where(
          (c) => c.containerType == ContainerType.budget.name && isTracked(c),
        )
        .toList();

    final balanceEngine = ref.read(balanceEngineProvider);
    final holderBalances = await computeSingleAssetBalances(
      balanceEngine: balanceEngine,
      containers: holders,
      assetId: giveAssetId,
    );
    final budgetBalances = await computeSingleAssetBalances(
      balanceEngine: balanceEngine,
      containers: budgets,
      assetId: giveAssetId,
    );
    if (!mounted || _giveAssetId != giveAssetId) {
      return;
    }

    setState(() {
      _tradeHolderBalancesOfGiveAsset = holderBalances;
      _tradeBudgetBalancesOfGiveAsset = budgetBalances;
      if (holderBalances.isNotEmpty &&
          (_tradeHolderId == null ||
              !holderBalances.containsKey(_tradeHolderId))) {
        _tradeHolderId = holderBalances.length == 1
            ? holderBalances.keys.single
            : null;
      }
      if (budgetBalances.isNotEmpty &&
          (_tradeBudgetId == null ||
              !budgetBalances.containsKey(_tradeBudgetId))) {
        _tradeBudgetId = budgetBalances.length == 1
            ? budgetBalances.keys.single
            : null;
      }
    });
  }

  void _swapTradeSides() {
    setState(() {
      final asset = _giveAssetId;
      _giveAssetId = _getAssetId;
      _getAssetId = asset;
      final quantity = _giveQuantityController.text;
      _giveQuantityController.text = _getQuantityController.text;
      _getQuantityController.text = quantity;
    });
  }

  Future<void> _maybeAutofillTrade(List<ldb.Asset> assets) async {
    final giveAssetId = _giveAssetId;
    final getAssetId = _getAssetId;
    if (giveAssetId == null ||
        getAssetId == null ||
        giveAssetId == getAssetId) {
      return;
    }
    final giveText = _giveQuantityController.text.trim();
    final getText = _getQuantityController.text.trim();
    final give = Decimal.tryParse(giveText);
    final get = Decimal.tryParse(getText);
    final priceEngine = ref.read(priceEngineProvider);

    Future<void> fill({
      required Decimal sourceQty,
      required String sourceText,
      required TextEditingController sourceController,
      required TextEditingController targetController,
      required String fromAssetId,
      required String toAssetId,
    }) async {
      final price = await priceEngine.latestPrice(
        fromAssetId,
        toAssetId,
        _effectiveDate
            .addDays(1)
            .toDateTime()
            .subtract(const Duration(milliseconds: 1)),
      );
      if (!mounted || price == null) return;
      if (targetController.text.trim().isNotEmpty) return;
      if (sourceController.text.trim() != sourceText) return;
      if (_giveAssetId != giveAssetId || _getAssetId != getAssetId) return;
      final decimals =
          _assetById(assets, toAssetId)?.kind == AssetKind.crypto.name ? 8 : 2;
      setState(
        () => targetController.text = (sourceQty * price).toStringAsFixed(
          decimals,
        ),
      );
    }

    if (give != null && give > Decimal.zero && getText.isEmpty) {
      await fill(
        sourceQty: give,
        sourceText: giveText,
        sourceController: _giveQuantityController,
        targetController: _getQuantityController,
        fromAssetId: giveAssetId,
        toAssetId: getAssetId,
      );
    } else if (get != null && get > Decimal.zero && giveText.isEmpty) {
      await fill(
        sourceQty: get,
        sourceText: getText,
        sourceController: _getQuantityController,
        targetController: _giveQuantityController,
        fromAssetId: getAssetId,
        toAssetId: giveAssetId,
      );
    }
  }

  String? _tradeRateCaption(List<ldb.Asset> assets) {
    final give = Decimal.tryParse(_giveQuantityController.text.trim());
    final get = Decimal.tryParse(_getQuantityController.text.trim());
    if (give == null ||
        get == null ||
        give == Decimal.zero ||
        get == Decimal.zero) {
      return null;
    }
    final giveAsset = _assetById(assets, _giveAssetId);
    final getAsset = _assetById(assets, _getAssetId);
    if (giveAsset == null || getAsset == null) return null;
    final rate = get.toDouble() / give.toDouble();
    return 'Rate: 1 ${giveAsset.symbol} ≈ ${rate.toStringAsFixed(6)} ${getAsset.symbol}';
  }

  ldb.Asset? _assetById(List<ldb.Asset> assets, String? id) {
    for (final a in assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> _pickEffectiveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _effectiveDate = CalendarDate.fromDateTime(picked));
    }
  }

  Future<void> _pickPostedAt() async {
    final use24HourTime = ref.read(dateTimeFormatPrefsProvider).use24HourTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _postedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_postedAt),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: use24HourTime),
        child: child!,
      ),
    );
    if (pickedTime == null) return;
    setState(
      () => _postedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }

  void _matchPostedAtToEffectiveDate() {
    setState(() => _postedAt = _effectiveDate.toDateTime());
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    switch (_kind) {
      case TransactionKind.income:
      case TransactionKind.expense:
        if (_holderId == null || _budgetId == null) return;
        break;
      case TransactionKind.holderTransfer:
        if (_fromHolderId == null || _toHolderId == null) return;
        break;
      case TransactionKind.budgetTransfer:
        if (_fromBudgetId == null || _toBudgetId == null) return;
        break;
      case TransactionKind.trade:
        if (_tradeHolderId == null ||
            _tradeBudgetId == null ||
            _giveAssetId == null ||
            _getAssetId == null) {
          return;
        }
        break;
    }

    setState(() => _saving = true);
    try {
      final note = _noteController.text.trim();
      final repo = ref.read(domainRepositoryProvider);
      final id = widget.existing?.id;

      switch (_kind) {
        case TransactionKind.income:
          await repo.recordIncome(
            id: id,
            holderId: _holderId!,
            budgetId: _budgetId!,
            assetId: _assetId!,
            quantity: Decimal.parse(_quantityController.text.trim()),
            effectiveDate: _effectiveDate,
            postedAt: _postedAt,
            note: note.isEmpty ? null : note,
            tags: _tags,
          );
          break;
        case TransactionKind.expense:
          await repo.recordExpense(
            id: id,
            holderId: _holderId!,
            budgetId: _budgetId!,
            assetId: _assetId!,
            quantity: Decimal.parse(_quantityController.text.trim()),
            effectiveDate: _effectiveDate,
            postedAt: _postedAt,
            note: note.isEmpty ? null : note,
            tags: _tags,
          );
          break;
        case TransactionKind.holderTransfer:
          await repo.recordHolderTransfer(
            id: id,
            fromHolderId: _fromHolderId!,
            toHolderId: _toHolderId!,
            assetId: _assetId!,
            quantity: Decimal.parse(_quantityController.text.trim()),
            effectiveDate: _effectiveDate,
            postedAt: _postedAt,
            note: note.isEmpty ? null : note,
            tags: _tags,
          );
          break;
        case TransactionKind.budgetTransfer:
          await repo.recordBudgetTransfer(
            id: id,
            fromBudgetId: _fromBudgetId!,
            toBudgetId: _toBudgetId!,
            assetId: _assetId!,
            quantity: Decimal.parse(_quantityController.text.trim()),
            effectiveDate: _effectiveDate,
            postedAt: _postedAt,
            note: note.isEmpty ? null : note,
            tags: _tags,
          );
          break;
        case TransactionKind.trade:
          await repo.recordTrade(
            id: id,
            holderId: _tradeHolderId!,
            budgetId: _tradeBudgetId!,
            assetOutId: _giveAssetId!,
            quantityOut: Decimal.parse(_giveQuantityController.text.trim()),
            assetInId: _getAssetId!,
            quantityIn: Decimal.parse(_getQuantityController.text.trim()),
            effectiveDate: _effectiveDate,
            postedAt: _postedAt,
            note: note.isEmpty ? null : note,
            tags: _tags,
          );
          break;
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(domainRepositoryProvider).deleteTransaction(existing.id);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
