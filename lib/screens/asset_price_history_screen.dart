import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/date_time_format_prefs.dart';
import '../domain/models.dart'
    show Asset, AssetKind, ContainerType, PriceSnapshotSource;
import '../domain/multi_asset_rollup.dart';
import '../providers/app_providers.dart';
import '../widgets/amount_text.dart';
import '../widgets/asset_form_dialog.dart'
    show AssetFormDialog, assetDisplayTitle, assetKindLabel;
import '../widgets/line_chart_card.dart';
import '../widgets/market_data_section.dart';
import '../widgets/price_snapshot_form_dialog.dart';

class AssetPriceHistoryScreen extends ConsumerStatefulWidget {
  final ldb.Asset asset;
  const AssetPriceHistoryScreen({super.key, required this.asset});

  @override
  ConsumerState<AssetPriceHistoryScreen> createState() =>
      _AssetPriceHistoryScreenState();
}

class _AssetPriceHistoryScreenState
    extends ConsumerState<AssetPriceHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  ldb.Asset _live(List<ldb.Asset> assets) {
    for (final a in assets) {
      if (a.id == widget.asset.id) return a;
    }
    return widget.asset;
  }

  @override
  Widget build(BuildContext context) {
    final snapshotsAsync = ref.watch(priceSnapshotsStreamProvider);
    final assetsAsync = ref.watch(assetsStreamProvider);
    final containersAsync = ref.watch(containersStreamProvider);
    ref.watch(transactionsStreamProvider);

    final liveAssets = assetsAsync.value;
    final liveAsset = liveAssets == null ? widget.asset : _live(liveAssets);

    return Scaffold(
      appBar: AppBar(
        title: Text(assetDisplayTitle(liveAsset.symbol, liveAsset.name)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit asset',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AssetFormDialog(existing: liveAsset),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Price History'),
            Tab(text: 'Holders'),
            Tab(text: 'Budgets'),
            Tab(text: 'Metadata'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index != 0
          ? null
          : assetsAsync.maybeWhen(
              data: (assets) {
                final otherAssets =
                    assets.where((a) => a.id != liveAsset.id).toList()
                      ..sort((a, b) => a.symbol.compareTo(b.symbol));
                if (otherAssets.isEmpty) return null;
                return FloatingActionButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => PriceSnapshotFormDialog(
                      asset: liveAsset,
                      otherAssets: otherAssets,
                    ),
                  ),
                  child: const Icon(Icons.add),
                );
              },
              orElse: () => null,
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          snapshotsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load: $e')),
            data: (snapshots) => assetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (assets) => _priceHistoryTab(liveAsset, snapshots, assets),
            ),
          ),
          containersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load: $e')),
            data: (containers) =>
                _holdingsTab(liveAsset, containers, ContainerType.holder),
          ),
          containersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load: $e')),
            data: (containers) =>
                _holdingsTab(liveAsset, containers, ContainerType.budget),
          ),
          _metadataTab(liveAsset),
        ],
      ),
    );
  }

  Widget _priceHistoryTab(
    ldb.Asset liveAsset,
    List<ldb.PriceSnapshot> snapshots,
    List<ldb.Asset> assets,
  ) {
    final assetsById = {for (final a in assets) a.id: a};
    final forThisAsset =
        snapshots.where((s) => s.assetId == liveAsset.id).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final otherAssets = assets.where((a) => a.id != liveAsset.id).toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    final dateTimeFormatPrefs = ref.watch(dateTimeFormatPrefsProvider);

    final marketDataSection = MarketDataSection(
      asset: liveAsset,
      otherAssets: otherAssets,
      existingSnapshots: forThisAsset,
    );

    if (forThisAsset.isEmpty) {
      return Column(
        children: [
          marketDataSection,
          Expanded(
            child: assets.length <= 1
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No other assets to price this against yet — create one '
                        'first (e.g. your home currency).',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : const Center(child: Text('No price history yet.')),
          ),
        ],
      );
    }

    final chartCurrencyId = forThisAsset.first.currencyAssetId;
    final chartCurrency = assetsById[chartCurrencyId];
    final chartPoints = [
      for (final s in forThisAsset)
        if (s.currencyAssetId == chartCurrencyId)
          LineChartPoint(
            date: s.date,
            value: Decimal.parse(s.price).toDouble(),
          ),
    ];
    final chartDecimals =
        chartCurrency != null &&
            AssetKind.fromJson(chartCurrency.kind) == AssetKind.crypto
        ? 8
        : 2;
    final chartUnit = chartCurrency == null
        ? ''
        : (chartCurrency.displaySymbol ?? chartCurrency.symbol);

    return Column(
      children: [
        marketDataSection,
        Expanded(
          child: ListView(
            children: [
              LineChartCard(
                title:
                    'Price history${chartUnit.isEmpty ? '' : ' ($chartUnit)'}',
                points: chartPoints,
                valueLabel: (v) =>
                    '${v.toStringAsFixed(chartDecimals)} $chartUnit',
                dateLabel: dateTimeFormatPrefs.formatDate,
              ),
              const Divider(height: 1),
              for (final snapshot in forThisAsset) ...[
                _snapshotTile(
                  liveAsset,
                  snapshot,
                  assetsById[snapshot.currencyAssetId],
                  otherAssets,
                  dateTimeFormatPrefs,
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _snapshotTile(
    ldb.Asset liveAsset,
    ldb.PriceSnapshot snapshot,
    ldb.Asset? currency,
    List<ldb.Asset> otherAssets,
    DateTimeFormatPrefs dateTimeFormatPrefs,
  ) {
    return ListTile(
      title: Text(dateTimeFormatPrefs.formatDate(snapshot.date)),
      subtitle: Text(
        PriceSnapshotSource.fromJson(snapshot.source) ==
                PriceSnapshotSource.manual
            ? 'Manual entry'
            : 'Fetched',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currency != null)
            AmountText(
              quantity: Decimal.parse(snapshot.price),
              asset: _domainAsset(currency),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => ref
                .read(domainRepositoryProvider)
                .deletePriceSnapshot(snapshot.id),
          ),
        ],
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => PriceSnapshotFormDialog(
          asset: liveAsset,
          otherAssets: otherAssets,
          existing: snapshot,
        ),
      ),
    );
  }

  Widget _holdingsTab(
    ldb.Asset liveAsset,
    List<ldb.Container> containers,
    ContainerType type,
  ) {
    return FutureBuilder<Map<String, Map<String, Decimal>>>(
      future: computeHoldingsByAssetAndContainer(
        balanceEngine: ref.read(balanceEngineProvider),
        containers: containers,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final byContainerId = snapshot.data![liveAsset.id] ?? const {};
        final containersById = {for (final c in containers) c.id: c};
        final rows = [
          for (final entry in byContainerId.entries)
            if (containersById[entry.key] case final container?)
              if (ContainerType.fromJson(container.containerType) == type)
                (container: container, quantity: entry.value),
        ]..sort((a, b) => a.container.name.compareTo(b.container.name));

        if (rows.isEmpty) {
          return Center(
            child: Text(
              type == ContainerType.holder
                  ? 'Not currently held in any holder.'
                  : 'Not currently held in any budget.',
            ),
          );
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => ListTile(
            title: Text(rows[index].container.name),
            trailing: AmountText(
              quantity: rows[index].quantity,
              asset: _domainAsset(liveAsset),
            ),
          ),
        );
      },
    );
  }

  Widget _metadataTab(ldb.Asset liveAsset) {
    final kind = AssetKind.fromJson(liveAsset.kind);
    final rows = [
      (label: 'Kind', value: assetKindLabel(kind)),
      (label: 'Symbol', value: liveAsset.symbol),
      (label: 'Name', value: liveAsset.name),
      if (liveAsset.displaySymbol case final glyph?)
        (label: 'Display glyph', value: glyph),
      (
        label: 'AlphaVantage',
        value: liveAsset.alphaVantageSymbol ?? 'Not linked',
      ),
    ];
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => ListTile(
        title: Text(rows[index].label),
        trailing: Text(rows[index].value),
      ),
    );
  }

  Asset _domainAsset(ldb.Asset row) => Asset.fromJson(row.id, {
    'kind': row.kind,
    'symbol': row.symbol,
    'name': row.name,
    'displaySymbol': row.displaySymbol,
  });
}
