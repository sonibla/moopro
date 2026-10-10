import 'package:flutter/material.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import '../theme/app_theme.dart';
import 'asset_form_dialog.dart' show assetKindIcon, assetKindLabel;

List<MapEntry<AssetKind, List<ldb.Asset>>> groupAssetsByKind(
  List<ldb.Asset> assets,
) {
  final sections = [
    for (final kind in AssetKind.values)
      MapEntry(
        kind,
        assets.where((a) => AssetKind.fromJson(a.kind) == kind).toList()
          ..sort((a, b) => a.symbol.compareTo(b.symbol)),
      ),
  ]..removeWhere((section) => section.value.isEmpty);
  return sections;
}

List<ldb.Asset> filterAssetsByQuery(List<ldb.Asset> assets, String query) {
  final q = query.trim().toLowerCase();
  return assets
      .where(
        (a) =>
            a.symbol.toLowerCase().contains(q) ||
            a.name.toLowerCase().contains(q),
      )
      .toList()
    ..sort((a, b) => a.symbol.compareTo(b.symbol));
}

Future<String?> showAssetPicker({
  required BuildContext context,
  required List<ldb.Asset> assets,
  required String? selectedId,
  String title = 'Select asset',
}) async {
  final content = _AssetPickerContent(
    assets: assets,
    selectedId: selectedId,
    title: title,
  );

  final wide = MediaQuery.sizeOf(context).width > 900;
  if (wide) {
    return showDialog<String>(
      context: context,
      builder: (_) =>
          Dialog(child: SizedBox(width: 420, height: 560, child: content)),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: content,
      ),
    ),
  );
}

class _AssetPickerContent extends StatefulWidget {
  final List<ldb.Asset> assets;
  final String? selectedId;
  final String title;

  const _AssetPickerContent({
    required this.assets,
    required this.selectedId,
    required this.title,
  });

  @override
  State<_AssetPickerContent> createState() => _AssetPickerContentState();
}

class _AssetPickerContentState extends State<_AssetPickerContent> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search assets...',
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    if (_query.isNotEmpty) {
      final matches = filterAssetsByQuery(widget.assets, _query);
      if (matches.isEmpty) {
        return const Center(child: Text('No matches.'));
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: matches.length,
        itemBuilder: (context, i) => _row(matches[i]),
      );
    }

    final sections = groupAssetsByKind(widget.assets);

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${assetKindLabel(section.key).toUpperCase()} (${section.value.length})',
              style: const TextStyle(fontSize: 11, letterSpacing: 0.5),
            ),
          ),
          for (final asset in section.value) _row(asset),
        ],
      ],
    );
  }

  Widget _row(ldb.Asset asset) {
    final selected = asset.id == widget.selectedId;
    return ListTile(
      tileColor: selected
          ? AppTheme.accentSoft(Theme.of(context).brightness)
          : null,
      leading: Icon(assetKindIcon(AssetKind.fromJson(asset.kind))),
      title: Text(asset.symbol),
      subtitle: asset.symbol == asset.name ? null : Text(asset.name),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(asset.id),
    );
  }
}
