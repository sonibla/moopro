import 'package:flutter/material.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import 'asset_form_dialog.dart' show assetDisplayTitle, assetKindLabel;

sealed class AssetFilter {
  const AssetFilter();
}

class SingleAssetFilter extends AssetFilter {
  final String assetId;
  const SingleAssetFilter(this.assetId);
}

class AssetKindFilterSelection extends AssetFilter {
  final AssetKind kind;
  const AssetKindFilterSelection(this.kind);
}

class DisplayAssetSelector extends StatelessWidget {
  final List<ldb.Asset> assets;
  final String selectedAssetId;
  final ValueChanged<String> onChanged;

  const DisplayAssetSelector({
    super.key,
    required this.assets,
    required this.selectedAssetId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = assets.where((a) => a.id == selectedAssetId).firstOrNull;
    return PopupMenuButton<String>(
      tooltip: 'Convert to',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final a in assets)
          PopupMenuItem(
            value: a.id,
            child: Text(assetDisplayTitle(a.symbol, a.name)),
          ),
      ],
      child: Chip(
        label: Text('Convert to ${selected?.symbol ?? '…'}'),
        avatar: const Icon(Icons.arrow_drop_down, size: 18),
      ),
    );
  }
}

class AssetFilterSelector extends StatelessWidget {
  final List<ldb.Asset> assets;
  final AssetFilter? selected;
  final ValueChanged<AssetFilter?> onChanged;

  const AssetFilterSelector({
    super.key,
    required this.assets,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = selected;
    if (current != null) {
      return InputChip(
        label: Text(_labelFor(current)),
        onDeleted: () => onChanged(null),
      );
    }
    return PopupMenuButton<Object>(
      tooltip: 'Filter',
      onSelected: (value) => onChanged(
        value is AssetKind
            ? AssetKindFilterSelection(value)
            : SingleAssetFilter(value as String),
      ),
      itemBuilder: (context) => [
        for (final kind in AssetKind.values)
          PopupMenuItem(
            value: kind,
            child: Text('Type: ${assetKindLabel(kind)}'),
          ),
        const PopupMenuDivider(),
        for (final a in assets)
          PopupMenuItem(
            value: a.id,
            child: Text(assetDisplayTitle(a.symbol, a.name)),
          ),
      ],
      child: const Chip(
        label: Text('All assets'),
        avatar: Icon(Icons.arrow_drop_down, size: 18),
      ),
    );
  }

  String _labelFor(AssetFilter filter) => switch (filter) {
    SingleAssetFilter(:final assetId) =>
      'Asset: ${assets.where((a) => a.id == assetId).firstOrNull?.symbol ?? assetId}',
    AssetKindFilterSelection(:final kind) => 'Type: ${assetKindLabel(kind)}',
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
