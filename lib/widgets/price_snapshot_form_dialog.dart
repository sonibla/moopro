import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart' show PriceSnapshotSource;
import '../providers/app_providers.dart';
import 'asset_form_dialog.dart' show assetDisplayTitle;

class PriceSnapshotFormDialog extends ConsumerStatefulWidget {
  final ldb.Asset asset;

  final List<ldb.Asset> otherAssets;

  final ldb.PriceSnapshot? existing;

  const PriceSnapshotFormDialog({
    super.key,
    required this.asset,
    required this.otherAssets,
    this.existing,
  });

  @override
  ConsumerState<PriceSnapshotFormDialog> createState() =>
      _PriceSnapshotFormDialogState();
}

typedef _FormSnapshot = ({
  DateTime date,
  String price,
  String? currencyAssetId,
});

class _PriceSnapshotFormDialogState
    extends ConsumerState<PriceSnapshotFormDialog> {
  final _priceController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _currencyAssetId;
  bool _saving = false;

  late final _FormSnapshot _initialSnapshot;

  bool _forceClose = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _date = existing.date;
      _priceController.text = existing.price;
      _currencyAssetId = existing.currencyAssetId;
    } else {
      _currencyAssetId = widget.otherAssets.firstOrNull?.id;
    }
    _initialSnapshot = _currentSnapshot();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  _FormSnapshot _currentSnapshot() => (
    date: _date,
    price: _priceController.text,
    currencyAssetId: _currencyAssetId,
  );

  bool get _isDirty => _currentSnapshot() != _initialSnapshot;

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('This price has unsaved changes.'),
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty || _forceClose,
      onPopInvokedWithResult: _handlePopInvoked,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(
        isEdit
            ? 'Edit price for ${widget.asset.symbol}'
            : 'New price for ${widget.asset.symbol}',
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                ref.watch(dateTimeFormatPrefsProvider).formatDate(_date),
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currencyAssetId,
              decoration: const InputDecoration(labelText: 'Priced in'),
              items: [
                for (final a in widget.otherAssets)
                  DropdownMenuItem(
                    value: a.id,
                    child: Text(assetDisplayTitle(a.symbol, a.name)),
                  ),
              ],
              onChanged: (v) => setState(() => _currencyAssetId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _requestClose, child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final price = Decimal.tryParse(_priceController.text.trim());
    final currencyAssetId = _currencyAssetId;
    if (price == null || currencyAssetId == null) return;
    setState(() => _saving = true);
    final existingSource = widget.existing?.source;
    try {
      await ref
          .read(domainRepositoryProvider)
          .createPriceSnapshot(
            id: widget.existing?.id,
            assetId: widget.asset.id,
            date: _date,
            price: price,
            currencyAssetId: currencyAssetId,
            source: existingSource == null
                ? PriceSnapshotSource.manual
                : PriceSnapshotSource.fromJson(existingSource),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
