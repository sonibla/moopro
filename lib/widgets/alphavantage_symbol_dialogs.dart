import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../market_data/alphavantage_client.dart';
import '../providers/app_providers.dart';

Future<String?> showAlphaVantageSymbolSearchDialog({
  required BuildContext context,
  required String apiKey,
}) async {
  final content = _AlphaVantageSearchContent(apiKey: apiKey);

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

class _AlphaVantageSearchContent extends ConsumerStatefulWidget {
  final String apiKey;

  const _AlphaVantageSearchContent({required this.apiKey});

  @override
  ConsumerState<_AlphaVantageSearchContent> createState() =>
      _AlphaVantageSearchContentState();
}

enum _SearchStatus { idle, loading, error, rateLimited }

class _AlphaVantageSearchContentState
    extends ConsumerState<_AlphaVantageSearchContent> {
  final _controller = TextEditingController();
  Timer? _debounce;
  _SearchStatus _status = _SearchStatus.idle;
  String? _errorMessage;
  List<AlphaVantageSymbolMatch> _matches = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final keywords = value.trim();
    if (keywords.isEmpty) {
      setState(() {
        _matches = const [];
        _status = _SearchStatus.idle;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _search(keywords),
    );
  }

  Future<void> _search(String keywords) async {
    setState(() => _status = _SearchStatus.loading);
    try {
      final matches = await ref
          .read(alphaVantageClientProvider)
          .searchSymbols(apiKey: widget.apiKey, keywords: keywords);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _status = _SearchStatus.idle;
      });
    } on AlphaVantageException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.rateLimited
            ? _SearchStatus.rateLimited
            : _SearchStatus.error;
        _errorMessage = e.message;
      });
    }
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
                    'Link AlphaVantage symbol',
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
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or ticker…',
              ),
              onChanged: _onChanged,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_status) {
      case _SearchStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _SearchStatus.rateLimited:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'AlphaVantage daily limit reached — try again tomorrow.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _SearchStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _errorMessage ?? 'Search failed.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      case _SearchStatus.idle:
        if (_matches.isEmpty) {
          return const Center(child: Text('No matches yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _matches.length,
          itemBuilder: (context, i) {
            final m = _matches[i];
            return ListTile(
              title: Text('${m.symbol} — ${m.name}'),
              subtitle: Text('${m.type} · ${m.region} · ${m.currency}'),
              onTap: () => Navigator.of(context).pop(m.symbol),
            );
          },
        );
    }
  }
}

Future<String?> showAlphaVantageManualSymbolDialog({
  required BuildContext context,
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ManualSymbolDialog(initialValue: initialValue),
  );
}

class _ManualSymbolDialog extends StatefulWidget {
  final String? initialValue;

  const _ManualSymbolDialog({this.initialValue});

  @override
  State<_ManualSymbolDialog> createState() => _ManualSymbolDialogState();
}

class _ManualSymbolDialogState extends State<_ManualSymbolDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link AlphaVantage symbol'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Currency code',
          hintText: 'BTC, ETH…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            Navigator.of(context).pop(value.isEmpty ? null : value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
