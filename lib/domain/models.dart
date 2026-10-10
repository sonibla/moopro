import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'calendar_date.dart';

enum AssetKind {
  fiat,
  stock,
  etf,
  crypto,
  realEstateBond,
  other;

  static AssetKind fromJson(String value) =>
      AssetKind.values.firstWhere((k) => k.name == value);
}

abstract class VaultRecordTypes {
  static const asset = 'asset';
  static const container = 'container';
  static const transaction = 'transaction';
  static const priceSnapshot = 'price_snapshot';
  static const setting = 'setting';
  static const recurringTransactionTemplate = 'recurring_transaction_template';
}

const String externalHolderContainerId = 'externalholder00';
const String externalBudgetContainerId = 'externalbudget00';

abstract class SettingIds {
  static const alphavantageApiKey = '5e77163900000001';

  static const dateFormat = '5e77163900000002';

  static const timeFormat = '5e77163900000003';

  static const statementImportHintResolutions = '5e77163900000004';

  static const defaultCurrencyAssetId = '5e77163900000005';

  static const themeMode = '5e77163900000006';

  static const hideAmounts = '5e77163900000007';
}

class Asset {
  final String id;
  final AssetKind kind;
  final String symbol;
  final String name;

  final String? alphaVantageSymbol;

  final String? displaySymbol;

  const Asset({
    required this.id,
    required this.kind,
    required this.symbol,
    required this.name,
    this.alphaVantageSymbol,
    this.displaySymbol,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'symbol': symbol,
    'name': name,
    'alphaVantageSymbol': alphaVantageSymbol,
    'displaySymbol': displaySymbol,
  };

  factory Asset.fromJson(String id, Map<String, dynamic> json) => Asset(
    id: id,
    kind: AssetKind.fromJson(json['kind'] as String),
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    alphaVantageSymbol: json['alphaVantageSymbol'] as String?,
    displaySymbol: json['displaySymbol'] as String?,
  );

  Asset copyWith({
    String? symbol,
    String? name,
    String? alphaVantageSymbol,
    bool clearAlphaVantageSymbol = false,
    String? displaySymbol,
    bool clearDisplaySymbol = false,
  }) => Asset(
    id: id,
    kind: kind,
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    alphaVantageSymbol: clearAlphaVantageSymbol
        ? null
        : (alphaVantageSymbol ?? this.alphaVantageSymbol),
    displaySymbol: clearDisplaySymbol
        ? null
        : (displaySymbol ?? this.displaySymbol),
  );
}

enum ContainerType {
  holder,
  budget;

  static ContainerType fromJson(String value) =>
      ContainerType.values.firstWhere((t) => t.name == value);
}

class MoneyContainer {
  final String id;
  final String name;
  final ContainerType containerType;
  final String? parentId;

  final String? icon;

  const MoneyContainer({
    required this.id,
    required this.name,
    required this.containerType,
    this.parentId,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'containerType': containerType.name,
    'parentId': parentId,
    if (icon != null) 'icon': icon,
  };

  factory MoneyContainer.fromJson(String id, Map<String, dynamic> json) =>
      MoneyContainer(
        id: id,
        name: json['name'] as String,
        containerType: ContainerType.fromJson(json['containerType'] as String),
        parentId: json['parentId'] as String?,
        icon: json['icon'] as String?,
      );

  MoneyContainer copyWith({
    String? name,
    String? Function()? parentId,
    String? Function()? icon,
  }) => MoneyContainer(
    id: id,
    name: name ?? this.name,
    containerType: containerType,
    parentId: parentId != null ? parentId() : this.parentId,
    icon: icon != null ? icon() : this.icon,
  );
}

class Setting {
  final String id;
  final String value;

  const Setting({required this.id, required this.value});

  Map<String, dynamic> toJson() => {'value': value};

  factory Setting.fromJson(String id, Map<String, dynamic> json) =>
      Setting(id: id, value: json['value'] as String);
}

abstract class MoneyLeg {
  final String containerId;
  final String assetId;
  final Decimal quantity;

  const MoneyLeg({
    required this.containerId,
    required this.assetId,
    required this.quantity,
  });
}

class TransactionLeg extends MoneyLeg {
  final Decimal? balanceAfter;

  const TransactionLeg({
    required super.containerId,
    required super.assetId,
    required super.quantity,
    this.balanceAfter,
  });

  TransactionLeg withBalanceAfter(Decimal value) => TransactionLeg(
    containerId: containerId,
    assetId: assetId,
    quantity: quantity,
    balanceAfter: value,
  );

  Map<String, dynamic> toJson() => {
    'containerId': containerId,
    'assetId': assetId,
    'quantity': quantity.toString(),
    'balanceAfter': balanceAfter?.toString(),
  };

  factory TransactionLeg.fromJson(Map<String, dynamic> json) => TransactionLeg(
    containerId: json['containerId'] as String,
    assetId: json['assetId'] as String,
    quantity: Decimal.parse(json['quantity'] as String),
    balanceAfter: json['balanceAfter'] == null
        ? null
        : Decimal.parse(json['balanceAfter'] as String),
  );
}

class RecurringLeg extends MoneyLeg {
  const RecurringLeg({
    required super.containerId,
    required super.assetId,
    required super.quantity,
  });

  Map<String, dynamic> toJson() => {
    'containerId': containerId,
    'assetId': assetId,
    'quantity': quantity.toString(),
  };

  factory RecurringLeg.fromJson(Map<String, dynamic> json) => RecurringLeg(
    containerId: json['containerId'] as String,
    assetId: json['assetId'] as String,
    quantity: Decimal.parse(json['quantity'] as String),
  );

  TransactionLeg toTransactionLeg() => TransactionLeg(
    containerId: containerId,
    assetId: assetId,
    quantity: quantity,
  );
}

enum TransactionKind {
  income,
  expense,
  holderTransfer,
  budgetTransfer,
  trade;

  static TransactionKind fromJson(String value) =>
      TransactionKind.values.firstWhere((k) => k.name == value);

  bool get canBeRecurring => this != TransactionKind.trade;
}

class MoneyTransaction {
  final String id;
  final DateTime postedAt;
  final CalendarDate effectiveDate;
  final String? note;
  final TransactionKind kind;
  final TransactionLeg legOut;
  final TransactionLeg legIn;
  final TransactionLeg? budgetLegOut;
  final TransactionLeg? budgetLegIn;

  final List<String> tags;

  final int manualOrderRank;

  const MoneyTransaction({
    required this.id,
    required this.postedAt,
    required this.effectiveDate,
    this.note,
    required this.kind,
    required this.legOut,
    required this.legIn,
    this.budgetLegOut,
    this.budgetLegIn,
    this.tags = const [],
    this.manualOrderRank = 0,
  });

  Map<String, dynamic> toJson() => {
    'postedAt': postedAt.toUtc().toIso8601String(),
    'effectiveDate': effectiveDate.toIso(),
    'note': note,
    'kind': kind.name,
    'legOut': legOut.toJson(),
    'legIn': legIn.toJson(),
    'budgetLegOut': budgetLegOut?.toJson(),
    'budgetLegIn': budgetLegIn?.toJson(),
    'tags': tags,
    'manualOrderRank': manualOrderRank,
  };

  factory MoneyTransaction.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => MoneyTransaction(
    id: id,
    postedAt: DateTime.parse(json['postedAt'] as String),
    effectiveDate: CalendarDate.parse(json['effectiveDate'] as String),
    note: json['note'] as String?,
    kind: TransactionKind.fromJson(json['kind'] as String),
    legOut: TransactionLeg.fromJson(json['legOut'] as Map<String, dynamic>),
    legIn: TransactionLeg.fromJson(json['legIn'] as Map<String, dynamic>),
    budgetLegOut: json['budgetLegOut'] == null
        ? null
        : TransactionLeg.fromJson(json['budgetLegOut'] as Map<String, dynamic>),
    budgetLegIn: json['budgetLegIn'] == null
        ? null
        : TransactionLeg.fromJson(json['budgetLegIn'] as Map<String, dynamic>),
    tags: json['tags'] == null
        ? const []
        : (json['tags'] as List).cast<String>(),
    manualOrderRank: json['manualOrderRank'] as int? ?? 0,
  );
}

enum RecurrenceUnit {
  day,
  week,
  month,
  year;

  static RecurrenceUnit fromJson(String value) =>
      RecurrenceUnit.values.firstWhere((u) => u.name == value);
}

class RecurrenceRule {
  final CalendarDate startDate;
  final RecurrenceUnit unit;

  final int interval;

  final CalendarDate? endDate;

  final int? maxOccurrences;

  const RecurrenceRule({
    required this.startDate,
    required this.unit,
    required this.interval,
    this.endDate,
    this.maxOccurrences,
  });

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso(),
    'unit': unit.name,
    'interval': interval,
    'endDate': endDate?.toIso(),
    'maxOccurrences': maxOccurrences,
  };

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) => RecurrenceRule(
    startDate: CalendarDate.parse(json['startDate'] as String),
    unit: RecurrenceUnit.fromJson(json['unit'] as String),
    interval: json['interval'] as int,
    endDate: json['endDate'] == null
        ? null
        : CalendarDate.parse(json['endDate'] as String),
    maxOccurrences: json['maxOccurrences'] as int?,
  );
}

class RecurringTransactionTemplate {
  final String id;
  final TransactionKind kind;
  final RecurringLeg legOut;
  final RecurringLeg legIn;
  final RecurringLeg? budgetLegOut;
  final RecurringLeg? budgetLegIn;
  final String? note;
  final List<String> tags;
  final RecurrenceRule rule;

  final CalendarDate? lastGeneratedOccurrenceDate;

  final bool active;

  const RecurringTransactionTemplate({
    required this.id,
    required this.kind,
    required this.legOut,
    required this.legIn,
    this.budgetLegOut,
    this.budgetLegIn,
    this.note,
    this.tags = const [],
    required this.rule,
    this.lastGeneratedOccurrenceDate,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'legOut': legOut.toJson(),
    'legIn': legIn.toJson(),
    'budgetLegOut': budgetLegOut?.toJson(),
    'budgetLegIn': budgetLegIn?.toJson(),
    'note': note,
    'tags': tags,
    'rule': rule.toJson(),
    'lastGeneratedOccurrenceDate': lastGeneratedOccurrenceDate?.toIso(),
    'active': active,
  };

  factory RecurringTransactionTemplate.fromJson(
    String id,
    Map<String, dynamic> json,
  ) => RecurringTransactionTemplate(
    id: id,
    kind: TransactionKind.fromJson(json['kind'] as String),
    legOut: RecurringLeg.fromJson(json['legOut'] as Map<String, dynamic>),
    legIn: RecurringLeg.fromJson(json['legIn'] as Map<String, dynamic>),
    budgetLegOut: json['budgetLegOut'] == null
        ? null
        : RecurringLeg.fromJson(json['budgetLegOut'] as Map<String, dynamic>),
    budgetLegIn: json['budgetLegIn'] == null
        ? null
        : RecurringLeg.fromJson(json['budgetLegIn'] as Map<String, dynamic>),
    note: json['note'] as String?,
    tags: json['tags'] == null
        ? const []
        : (json['tags'] as List).cast<String>(),
    rule: RecurrenceRule.fromJson(json['rule'] as Map<String, dynamic>),
    lastGeneratedOccurrenceDate: json['lastGeneratedOccurrenceDate'] == null
        ? null
        : CalendarDate.parse(json['lastGeneratedOccurrenceDate'] as String),
    active: json['active'] as bool? ?? true,
  );

  RecurringTransactionTemplate copyWith({
    RecurringLeg? legOut,
    RecurringLeg? legIn,
    RecurringLeg? budgetLegOut,
    RecurringLeg? budgetLegIn,
    String? note,
    bool clearNote = false,
    List<String>? tags,
    RecurrenceRule? rule,
    CalendarDate? lastGeneratedOccurrenceDate,
    bool? active,
  }) => RecurringTransactionTemplate(
    id: id,
    kind: kind,
    legOut: legOut ?? this.legOut,
    legIn: legIn ?? this.legIn,
    budgetLegOut: budgetLegOut ?? this.budgetLegOut,
    budgetLegIn: budgetLegIn ?? this.budgetLegIn,
    note: clearNote ? null : (note ?? this.note),
    tags: tags ?? this.tags,
    rule: rule ?? this.rule,
    lastGeneratedOccurrenceDate:
        lastGeneratedOccurrenceDate ?? this.lastGeneratedOccurrenceDate,
    active: active ?? this.active,
  );
}

enum PriceSnapshotSource {
  fetched,
  manual;

  static PriceSnapshotSource fromJson(String value) =>
      PriceSnapshotSource.values.firstWhere((s) => s.name == value);
}

class PriceSnapshot {
  final String id;
  final String assetId;
  final DateTime date;
  final Decimal price;

  final String currencyAssetId;
  final PriceSnapshotSource source;

  const PriceSnapshot({
    required this.id,
    required this.assetId,
    required this.date,
    required this.price,
    required this.currencyAssetId,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'date': date.toUtc().toIso8601String(),
    'price': price.toString(),
    'currencyAssetId': currencyAssetId,
    'source': source.name,
  };

  factory PriceSnapshot.fromJson(String id, Map<String, dynamic> json) =>
      PriceSnapshot(
        id: id,
        assetId: json['assetId'] as String,
        date: DateTime.parse(json['date'] as String),
        price: Decimal.parse(json['price'] as String),
        currencyAssetId: json['currencyAssetId'] as String,
        source: PriceSnapshotSource.fromJson(json['source'] as String),
      );
}

String encodeTagsColumn(List<String> tags) => jsonEncode(tags);

List<String> decodeTagsColumn(String raw) =>
    raw.isEmpty ? const [] : (jsonDecode(raw) as List).cast<String>();
