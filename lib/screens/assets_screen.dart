import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart'
    show
        Asset,
        AssetKind,
        ContainerType,
        externalBudgetContainerId,
        externalHolderContainerId;
import '../domain/multi_asset_rollup.dart';
import '../providers/app_providers.dart';
import '../widgets/amount_text.dart';
import '../widgets/asset_form_dialog.dart';
import '../widgets/asset_picker.dart'
    show filterAssetsByQuery, groupAssetsByKind;
import 'asset_price_history_screen.dart';

class AssetsScreen extends ConsumerStatefulWidget {
  const AssetsScreen({super.key});

  @override
  ConsumerState<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends ConsumerState<AssetsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  final Set<AssetKind> _selectedKinds = {};

  bool _hideUnowned = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(assetsStreamProvider);
    final snapshotsAsync = ref.watch(priceSnapshotsStreamProvider);
    ref.watch(transactionsStreamProvider);
    final containersAsync = ref.watch(containersStreamProvider);
    final defaultCurrencyAssetId = ref.watch(defaultCurrencyAssetIdProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const AssetFormDialog(),
        ),
        child: const Icon(Icons.add),
      ),
      body: assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(child: Text('No assets yet.'));
          }
          final searchMatches = filterAssetsByQuery(assets, _query);
          final latestPriceByAssetId = snapshotsAsync.maybeWhen(
            data: (snapshots) => _latestPriceByAssetId(snapshots, assets),
            orElse: () =>
                const <
                  String,
                  ({ldb.PriceSnapshot snapshot, ldb.Asset currency})
                >{},
          );
          final holderContainers = containersAsync.value
              ?.where(
                (c) =>
                    c.containerType == ContainerType.holder.name &&
                    c.id != externalHolderContainerId &&
                    c.id != externalBudgetContainerId,
              )
              .toList();
          final displayAssetId = defaultCurrencyAssetId ?? assets.first.id;
          final displayAsset = assets.firstWhere(
            (a) => a.id == displayAssetId,
            orElse: () => assets.first,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search assets…',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: holderContainers == null
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder<Map<String, AssetHolding>>(
                        future: _holdingsByAssetId(
                          holderContainers,
                          displayAssetId,
                        ),
                        builder: (context, snapshot) {
                          final holdingsByAssetId = snapshot.data ?? const {};
                          final heldFilteredMatches = _hideUnowned
                              ? searchMatches
                                    .where(
                                      (a) =>
                                          holdingsByAssetId.containsKey(a.id),
                                    )
                                    .toList()
                              : searchMatches;
                          return Column(
                            children: [
                              _filterRow(heldFilteredMatches),
                              const SizedBox(height: 8),
                              Expanded(
                                child: _list(
                                  searchMatches,
                                  latestPriceByAssetId,
                                  holdingsByAssetId,
                                  displayAsset,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, AssetHolding>> _holdingsByAssetId(
    List<ldb.Container> containers,
    String displayAssetId,
  ) async {
    final rollup = await computeMultiAssetRollup(
      balanceEngine: ref.read(balanceEngineProvider),
      priceEngine: ref.read(priceEngineProvider),
      containers: containers,
      displayAssetId: displayAssetId,
    );
    final merged = mergeHoldingsByAsset(rollup.ownHoldings.values);
    return {for (final h in merged) h.assetId: h};
  }

  Map<String, ({ldb.PriceSnapshot snapshot, ldb.Asset currency})>
  _latestPriceByAssetId(
    List<ldb.PriceSnapshot> snapshots,
    List<ldb.Asset> assets,
  ) {
    final assetsById = {for (final a in assets) a.id: a};
    final latest = <String, ldb.PriceSnapshot>{};
    for (final s in snapshots) {
      final current = latest[s.assetId];
      if (current == null || s.date.isAfter(current.date)) {
        latest[s.assetId] = s;
      }
    }
    return {
      for (final entry in latest.entries)
        if (assetsById[entry.value.currencyAssetId] case final currency?)
          entry.key: (snapshot: entry.value, currency: currency),
    };
  }

  Widget _filterRow(List<ldb.Asset> matches) {
    final counts = <AssetKind, int>{};
    for (final a in matches) {
      final kind = AssetKind.fromJson(a.kind);
      counts[kind] = (counts[kind] ?? 0) + 1;
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _hideUnowned,
                  onChanged: (value) => setState(() => _hideUnowned = value),
                ),
                const SizedBox(width: 4),
                const Text('Currently held only'),
              ],
            ),
          ),
          if (counts.length > 1)
            for (final kind in AssetKind.values)
              if (counts[kind] case final count?)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(assetKindIcon(kind), size: 18),
                    label: Text('${assetKindLabel(kind)} ($count)'),
                    selected: _selectedKinds.contains(kind),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedKinds.add(kind);
                      } else {
                        _selectedKinds.remove(kind);
                      }
                    }),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _list(
    List<ldb.Asset> searchMatches,
    Map<String, ({ldb.PriceSnapshot snapshot, ldb.Asset currency})>
    latestPriceByAssetId,
    Map<String, AssetHolding> holdingsByAssetId,
    ldb.Asset displayAsset,
  ) {
    var visible = _selectedKinds.isEmpty
        ? searchMatches
        : searchMatches
              .where((a) => _selectedKinds.contains(AssetKind.fromJson(a.kind)))
              .toList();
    if (_hideUnowned) {
      visible = visible
          .where((a) => holdingsByAssetId.containsKey(a.id))
          .toList();
    }

    if (visible.isEmpty) {
      return Center(
        child: Text(
          _query.trim().isEmpty && _selectedKinds.isEmpty && !_hideUnowned
              ? 'No assets yet.'
              : 'No matches.',
        ),
      );
    }

    if (_query.trim().isNotEmpty) {
      return ListView.separated(
        itemCount: visible.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _row(
          visible[index],
          latestPriceByAssetId[visible[index].id],
          holdingsByAssetId[visible[index].id],
          displayAsset,
        ),
      );
    }

    final sections = groupAssetsByKind(visible);
    return ListView(
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${assetKindLabel(section.key).toUpperCase()} (${section.value.length})',
              style: const TextStyle(fontSize: 11, letterSpacing: 0.5),
            ),
          ),
          for (final asset in section.value)
            _row(
              asset,
              latestPriceByAssetId[asset.id],
              holdingsByAssetId[asset.id],
              displayAsset,
            ),
        ],
      ],
    );
  }

  Widget _row(
    ldb.Asset asset,
    ({ldb.PriceSnapshot snapshot, ldb.Asset currency})? latestPrice,
    AssetHolding? holding,
    ldb.Asset displayAsset,
  ) {
    final kind = AssetKind.fromJson(asset.kind);
    final displaySymbol = asset.displaySymbol;
    final title = assetDisplayTitle(asset.symbol, asset.name);
    return ListTile(
      leading: Icon(assetKindIcon(kind)),
      title: Text(displaySymbol == null ? title : '$displaySymbol $title'),
      subtitle: latestPrice == null
          ? null
          : AmountText(
              quantity: Decimal.parse(latestPrice.snapshot.price),
              asset: _domainAsset(latestPrice.currency),
              style: Theme.of(context).textTheme.bodySmall,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ownedColumn(asset, holding, displayAsset),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AssetFormDialog(existing: asset),
            ),
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AssetPriceHistoryScreen(asset: asset),
        ),
      ),
    );
  }

  Widget _ownedColumn(
    ldb.Asset asset,
    AssetHolding? holding,
    ldb.Asset displayAsset,
  ) {
    final quantity = holding?.quantity ?? Decimal.zero;
    final quantityLine = AmountText(
      quantity: quantity,
      asset: _domainAsset(asset),
      style: asset.id == displayAsset.id
          ? null
          : Theme.of(context).textTheme.bodySmall,
    );
    if (asset.id == displayAsset.id) {
      return quantityLine;
    }

    final convertedValue = quantity == Decimal.zero
        ? Decimal.zero
        : holding?.convertedValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (convertedValue != null)
          AmountText(
            quantity: convertedValue,
            asset: _domainAsset(displayAsset),
          )
        else
          Text(
            'No price',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        quantityLine,
      ],
    );
  }

  Asset _domainAsset(ldb.Asset row) => Asset.fromJson(row.id, {
    'kind': row.kind,
    'symbol': row.symbol,
    'name': row.name,
    'displaySymbol': row.displaySymbol,
  });
}
