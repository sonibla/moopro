library;

import 'dart:convert';

class ImportHintResolutions {
  final Map<String, String> holders;
  final Map<String, String> budgetTransfers;
  final Map<String, String> assets;

  const ImportHintResolutions({
    this.holders = const {},
    this.budgetTransfers = const {},
    this.assets = const {},
  });

  static const empty = ImportHintResolutions();

  factory ImportHintResolutions.decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return empty;
      return ImportHintResolutions(
        holders: _section(decoded, 'holders'),
        budgetTransfers: _section(decoded, 'budgetTransfers'),
        assets: _section(decoded, 'assets'),
      );
    } on FormatException {
      return empty;
    }
  }

  static Map<String, String> _section(
    Map<String, dynamic> decoded,
    String key,
  ) {
    final section = decoded[key];
    if (section is! Map) return const {};
    return section.map((k, v) => MapEntry(k as String, v as String));
  }

  String encode() => jsonEncode({
    'holders': holders,
    'budgetTransfers': budgetTransfers,
    'assets': assets,
  });

  ImportHintResolutions withHolder(String hint, String containerId) =>
      ImportHintResolutions(
        holders: {...holders, hint: containerId},
        budgetTransfers: budgetTransfers,
        assets: assets,
      );

  ImportHintResolutions withBudgetTransfer(String hint, String containerId) =>
      ImportHintResolutions(
        holders: holders,
        budgetTransfers: {...budgetTransfers, hint: containerId},
        assets: assets,
      );

  ImportHintResolutions withAsset(String hint, String assetId) =>
      ImportHintResolutions(
        holders: holders,
        budgetTransfers: budgetTransfers,
        assets: {...assets, hint: assetId},
      );
}
