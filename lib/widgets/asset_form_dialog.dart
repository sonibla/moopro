import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import '../providers/app_providers.dart';

String assetKindLabel(AssetKind kind) => switch (kind) {
  AssetKind.fiat => 'Fiat currency',
  AssetKind.stock => 'Stock',
  AssetKind.etf => 'ETF',
  AssetKind.crypto => 'Crypto',
  AssetKind.realEstateBond => 'Real estate bond',
  AssetKind.other => 'Other',
};

IconData assetKindIcon(AssetKind kind) => switch (kind) {
  AssetKind.fiat => Icons.attach_money,
  AssetKind.stock => Icons.trending_up,
  AssetKind.etf => Icons.pie_chart_outline,
  AssetKind.crypto => Icons.currency_bitcoin,
  AssetKind.realEstateBond => Icons.apartment,
  AssetKind.other => Icons.category_outlined,
};

String assetDisplayTitle(String symbol, String name) =>
    symbol == name ? symbol : '$symbol — $name';

class AssetFormDialog extends ConsumerStatefulWidget {
  final ldb.Asset? existing;

  const AssetFormDialog({super.key, this.existing});

  @override
  ConsumerState<AssetFormDialog> createState() => _AssetFormDialogState();
}

typedef _FormSnapshot = ({
  AssetKind kind,
  String symbol,
  String name,
  String displaySymbol,
});

class _AssetFormDialogState extends ConsumerState<AssetFormDialog> {
  final _symbolController = TextEditingController();
  final _nameController = TextEditingController();
  final _displaySymbolController = TextEditingController();
  AssetKind _kind = AssetKind.fiat;
  bool _saving = false;

  late final _FormSnapshot _initialSnapshot;

  bool _forceClose = false;

  String? get _suggestedDisplaySymbol {
    if (_kind != AssetKind.fiat || _displaySymbolController.text.isNotEmpty) {
      return null;
    }
    final code = _symbolController.text.trim().toUpperCase();
    if (code.length != 3) return null;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    return symbol == code ? null : symbol;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _kind = AssetKind.fromJson(existing.kind);
      _symbolController.text = existing.symbol;
      _nameController.text = existing.name;
      _displaySymbolController.text = existing.displaySymbol ?? '';
    }
    _symbolController.addListener(_onSymbolChanged);
    _initialSnapshot = _currentSnapshot();
  }

  void _onSymbolChanged() => setState(() {});

  @override
  void dispose() {
    _symbolController.removeListener(_onSymbolChanged);
    _symbolController.dispose();
    _nameController.dispose();
    _displaySymbolController.dispose();
    super.dispose();
  }

  _FormSnapshot _currentSnapshot() => (
    kind: _kind,
    symbol: _symbolController.text,
    name: _nameController.text,
    displaySymbol: _displaySymbolController.text,
  );

  bool get _isDirty => _currentSnapshot() != _initialSnapshot;

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('This asset has unsaved changes.'),
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
    final isEdit = widget.existing != null;
    final suggestion = _suggestedDisplaySymbol;
    return PopScope(
      canPop: !_isDirty || _forceClose,
      onPopInvokedWithResult: _handlePopInvoked,
      child: _buildDialog(context, isEdit, suggestion),
    );
  }

  Widget _buildDialog(BuildContext context, bool isEdit, String? suggestion) {
    return AlertDialog(
      title: Text(isEdit ? 'Edit asset' : 'New asset'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEdit)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(assetKindIcon(_kind)),
                title: const Text('Kind'),
                subtitle: Text(assetKindLabel(_kind)),
              )
            else
              DropdownButtonFormField<AssetKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: [
                  for (final kind in AssetKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(assetKindLabel(kind)),
                    ),
                ],
                onChanged: (kind) => setState(() => _kind = kind ?? _kind),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _symbolController,
              decoration: const InputDecoration(
                labelText: 'Symbol',
                hintText: 'AAPL, BTC, USD…',
              ),
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Apple Inc., Bitcoin…',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _displaySymbolController,
              decoration: InputDecoration(
                labelText: 'Display glyph (optional)',
                hintText: 'e.g. €, ₿ — shown instead of the symbol above',
                suffixIcon: suggestion == null
                    ? null
                    : IconButton(
                        tooltip: 'Use "$suggestion"',
                        icon: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 18),
                        ),
                        onPressed: () => setState(
                          () => _displaySymbolController.text = suggestion,
                        ),
                      ),
              ),
              maxLength: 4,
              onChanged: (_) => setState(() {}),
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

  Future<void> _save() async {
    final symbol = _symbolController.text.trim();
    final name = _nameController.text.trim();
    if (symbol.isEmpty || name.isEmpty) return;
    final displaySymbol = _displaySymbolController.text.trim();
    setState(() => _saving = true);
    try {
      final asset = await ref
          .read(domainRepositoryProvider)
          .createAsset(
            id: widget.existing?.id,
            kind: _kind,
            symbol: symbol,
            name: name,
            displaySymbol: displaySymbol.isEmpty ? null : displaySymbol,
          );
      if (mounted) Navigator.of(context).pop(asset);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
