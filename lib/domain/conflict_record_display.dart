import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../widgets/amount_text.dart' show AmountSign;
import 'date_time_format_prefs.dart';
import 'models.dart';
import 'recurring_template_mapping.dart' show amountSignOfKind;
import 'transaction_kind_style.dart';

class ConflictRecordAmount {
  final Decimal quantity;
  final Asset asset;
  final AmountSign sign;

  const ConflictRecordAmount({
    required this.quantity,
    required this.asset,
    required this.sign,
  });
}

class ConflictRecordDisplay {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> detailParts;
  final ConflictRecordAmount? amount;
  final List<String> tags;

  const ConflictRecordDisplay({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.detailParts = const [],
    this.amount,
    this.tags = const [],
  });

  static const unavailable = ConflictRecordDisplay(
    icon: Icons.help_outline,
    iconColor: Colors.grey,
    title: 'Not available',
  );
}

class ConflictLookups {
  final List<MoneyContainer> containers;
  final List<Asset> assets;
  final Map<String, String> settingLabels;

  const ConflictLookups({
    required this.containers,
    required this.assets,
    this.settingLabels = const {},
  });

  MoneyContainer? _container(String id) =>
      containers.where((c) => c.id == id).firstOrNull;

  Asset? _asset(String id) => assets.where((a) => a.id == id).firstOrNull;

  String breadcrumb(String containerId) {
    final names = <String>[];
    String? current = containerId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      final c = _container(current);
      if (c == null) break;
      names.add(c.name);
      current = c.parentId;
    }
    return names.isEmpty ? containerId : names.reversed.join(' › ');
  }

  String assetLabel(String assetId) {
    final a = _asset(assetId);
    return a == null ? assetId : '${a.name} (${a.symbol})';
  }
}

ConflictRecordDisplay describeConflictRecord(
  Object? value, {
  required ConflictLookups lookups,
  required DateTimeFormatPrefs dateTimeFormatPrefs,
  required Brightness brightness,
}) {
  switch (value) {
    case null:
      return ConflictRecordDisplay.unavailable;

    case Asset a:
      return ConflictRecordDisplay(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: Colors.blueGrey,
        title: '${a.name} (${a.symbol})',
        detailParts: [_assetKindLabel(a.kind)],
      );

    case MoneyContainer c:
      return ConflictRecordDisplay(
        icon: Icons.account_tree_outlined,
        iconColor: Colors.blueGrey,
        title: lookups.breadcrumb(c.id),
        detailParts: [
          c.containerType == ContainerType.holder
              ? 'Holder account'
              : 'Budget category',
        ],
      );

    case MoneyTransaction t:
      final title = switch (t.kind) {
        TransactionKind.income =>
          '${lookups.breadcrumb(t.legIn.containerId)} · '
              '${lookups.breadcrumb(t.budgetLegIn!.containerId)}',
        TransactionKind.expense =>
          '${lookups.breadcrumb(t.legOut.containerId)} · '
              '${lookups.breadcrumb(t.budgetLegOut!.containerId)}',
        TransactionKind.holderTransfer ||
        TransactionKind.budgetTransfer ||
        TransactionKind.trade =>
          '${lookups.breadcrumb(t.legOut.containerId)} → '
              '${lookups.breadcrumb(t.legIn.containerId)}',
      };
      final asset = lookups._asset(t.legOut.assetId);
      return ConflictRecordDisplay(
        icon: TransactionKindStyle.iconOf(t.kind),
        iconColor: TransactionKindStyle.colorOf(t.kind, brightness),
        title: title,
        detailParts: [
          dateTimeFormatPrefs.formatCalendarDate(t.effectiveDate),
          if (t.note != null && t.note!.isNotEmpty) t.note!,
        ],
        amount: asset == null
            ? null
            : ConflictRecordAmount(
                quantity: t.legOut.quantity,
                asset: asset,
                sign: amountSignOfKind(t.kind),
              ),
        tags: t.tags,
      );

    case PriceSnapshot p:
      return ConflictRecordDisplay(
        icon: Icons.show_chart,
        iconColor: Colors.blueGrey,
        title: '${lookups.assetLabel(p.assetId)} price',
        detailParts: [
          '${p.price} ${lookups.assetLabel(p.currencyAssetId)}',
          'as of ${dateTimeFormatPrefs.formatDate(p.date)}',
        ],
      );

    case Setting s:
      return ConflictRecordDisplay(
        icon: Icons.settings_outlined,
        iconColor: Colors.blueGrey,
        title: lookups.settingLabels[s.id] ?? 'Setting',
        detailParts: [s.value],
      );

    default:
      return ConflictRecordDisplay(
        icon: Icons.help_outline,
        iconColor: Colors.grey,
        title: value.toString(),
      );
  }
}

const Map<String, String> settingDisplayLabels = {
  SettingIds.alphavantageApiKey: 'Alphavantage API key',
  SettingIds.dateFormat: 'Date format',
  SettingIds.timeFormat: 'Time format',
  SettingIds.statementImportHintResolutions: 'Statement import hints',
  SettingIds.defaultCurrencyAssetId: 'Default currency',
  SettingIds.themeMode: 'Theme',
  SettingIds.hideAmounts: 'Hide amounts',
};

String _assetKindLabel(AssetKind kind) => switch (kind) {
  AssetKind.fiat => 'Currency',
  AssetKind.stock => 'Stock',
  AssetKind.etf => 'ETF',
  AssetKind.crypto => 'Crypto',
  AssetKind.realEstateBond => 'Real estate bond',
  AssetKind.other => 'Other',
};
