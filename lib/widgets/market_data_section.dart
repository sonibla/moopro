import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import '../market_data/alphavantage_client.dart';
import '../providers/app_providers.dart';
import 'alphavantage_symbol_dialogs.dart';
import 'asset_form_dialog.dart' show assetDisplayTitle;

class MarketDataSection extends ConsumerStatefulWidget {
  final ldb.Asset asset;

  final List<ldb.Asset> otherAssets;

  final List<ldb.PriceSnapshot> existingSnapshots;

  const MarketDataSection({
    super.key,
    required this.asset,
    required this.otherAssets,
    required this.existingSnapshots,
  });

  @override
  ConsumerState<MarketDataSection> createState() => _MarketDataSectionState();
}

enum _FetchStatus { idle, loading, error, rateLimited }

class _MarketDataSectionState extends ConsumerState<MarketDataSection> {
  _FetchStatus _status = _FetchStatus.idle;
  String? _errorMessage;

  AssetKind get _kind => AssetKind.fromJson(widget.asset.kind);

  @override
  Widget build(BuildContext context) {
    if (_kind != AssetKind.stock &&
        _kind != AssetKind.etf &&
        _kind != AssetKind.crypto) {
      return const SizedBox.shrink();
    }

    final apiKey = ref
        .watch(settingStreamProvider(SettingIds.alphavantageApiKey))
        .value
        ?.value;
    final hasApiKey = apiKey != null && apiKey.isNotEmpty;
    final linked = widget.asset.alphaVantageSymbol;
    final isLinked = linked != null && linked.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('AlphaVantage symbol'),
          subtitle: Text(isLinked ? linked : 'Not linked'),
          trailing: TextButton(
            onPressed: _editLink,
            child: Text(isLinked ? 'Change' : 'Link'),
          ),
        ),
        if (isLinked)
          ListTile(
            leading: _statusIcon(),
            title: const Text('Fetch latest price'),
            subtitle: _statusSubtitle(hasApiKey),
            enabled:
                hasApiKey &&
                _status != _FetchStatus.loading &&
                widget.otherAssets.isNotEmpty,
            onTap:
                (!hasApiKey ||
                    _status == _FetchStatus.loading ||
                    widget.otherAssets.isEmpty)
                ? null
                : () => _fetch(apiKey, linked),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _statusIcon() {
    switch (_status) {
      case _FetchStatus.loading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _FetchStatus.error:
        return const Icon(Icons.error_outline, color: Colors.red);
      case _FetchStatus.rateLimited:
        return const Icon(Icons.hourglass_bottom, color: Colors.orange);
      case _FetchStatus.idle:
        return const Icon(Icons.cloud_download_outlined);
    }
  }

  Widget? _statusSubtitle(bool hasApiKey) {
    if (!hasApiKey) {
      return const Text('Set your AlphaVantage API key in Settings first.');
    }
    if (widget.otherAssets.isEmpty) {
      return const Text('Create another asset to price this against first.');
    }
    switch (_status) {
      case _FetchStatus.loading:
        return const Text('Fetching…');
      case _FetchStatus.error:
        return Text(_errorMessage ?? 'Fetch failed.');
      case _FetchStatus.rateLimited:
        return const Text(
          'AlphaVantage daily limit reached — try again tomorrow.',
        );
      case _FetchStatus.idle:
        return null;
    }
  }

  Future<void> _editLink() async {
    final apiKey =
        ref
            .read(settingStreamProvider(SettingIds.alphavantageApiKey))
            .value
            ?.value ??
        '';
    String? result;
    if (_kind == AssetKind.crypto) {
      result = await showAlphaVantageManualSymbolDialog(
        context: context,
        initialValue: widget.asset.alphaVantageSymbol ?? widget.asset.symbol,
      );
    } else {
      result = await showAlphaVantageSymbolSearchDialog(
        context: context,
        apiKey: apiKey,
      );
    }
    if (result == null || !mounted) return;
    await ref
        .read(domainRepositoryProvider)
        .setAssetAlphaVantageSymbol(widget.asset.id, result);
  }

  String? _defaultCurrencyAssetId() {
    if (widget.existingSnapshots.isNotEmpty) {
      return widget.existingSnapshots.first.currencyAssetId;
    }
    return widget.otherAssets.isEmpty ? null : widget.otherAssets.first.id;
  }

  Future<void> _fetch(String apiKey, String linkedSymbol) async {
    final currencyAssetId = await _pickCurrencyAssetId();
    if (currencyAssetId == null || !mounted) return;
    final currencyAsset = widget.otherAssets.firstWhere(
      (a) => a.id == currencyAssetId,
    );

    setState(() {
      _status = _FetchStatus.loading;
      _errorMessage = null;
    });

    try {
      final client = ref.read(alphaVantageClientProvider);
      final quote = _kind == AssetKind.crypto
          ? await client.fetchCryptoExchangeRate(
              apiKey: apiKey,
              fromCurrency: linkedSymbol,
              toCurrency: currencyAsset.symbol,
            )
          : await client.fetchEquityQuote(apiKey: apiKey, symbol: linkedSymbol);

      await ref
          .read(domainRepositoryProvider)
          .createPriceSnapshot(
            assetId: widget.asset.id,
            date: quote.asOf,
            price: quote.price,
            currencyAssetId: currencyAssetId,
            source: PriceSnapshotSource.fetched,
          );
      if (!mounted) return;
      setState(() => _status = _FetchStatus.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fetched ${quote.price} ${currencyAsset.symbol}'),
        ),
      );
    } on AlphaVantageException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.rateLimited ? _FetchStatus.rateLimited : _FetchStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  Future<String?> _pickCurrencyAssetId() {
    return showDialog<String>(
      context: context,
      builder: (_) => _CurrencyPickerDialog(
        assetSymbol: widget.asset.symbol,
        otherAssets: widget.otherAssets,
        initialValue: _defaultCurrencyAssetId(),
      ),
    );
  }
}

class _CurrencyPickerDialog extends StatefulWidget {
  final String assetSymbol;
  final List<ldb.Asset> otherAssets;
  final String? initialValue;

  const _CurrencyPickerDialog({
    required this.assetSymbol,
    required this.otherAssets,
    required this.initialValue,
  });

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  String? _currencyAssetId;

  @override
  void initState() {
    super.initState();
    _currencyAssetId = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Fetch ${widget.assetSymbol} price in…'),
      content: SizedBox(
        width: 360,
        child: DropdownButtonFormField<String>(
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _currencyAssetId == null
              ? null
              : () => Navigator.of(context).pop(_currencyAssetId),
          child: const Text('Fetch'),
        ),
      ],
    );
  }
}
