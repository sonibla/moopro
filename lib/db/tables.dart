import 'package:drift/drift.dart';

import '../domain/calendar_date.dart';

class SyncState extends Table {
  IntColumn get id => integer()();
  IntColumn get lastSyncedVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalVaultKeyMaterial extends Table {
  IntColumn get id => integer()();
  BlobColumn get kdfSalt => blob()();
  TextColumn get kdfParamsJson => text()();
  BlobColumn get wrappedDek => blob()();
  BlobColumn get wrapNonce => blob()();

  @override
  Set<Column> get primaryKey => {id};
}

class RecordVersionHighWaterMark extends Table {
  TextColumn get recordId => text()();
  IntColumn get highestVersionSeen => integer()();

  @override
  Set<Column> get primaryKey => {recordId};
}

class Assets extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get alphaVantageSymbol => text().nullable()();
  TextColumn get displaySymbol => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Containers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get containerType => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get postedAt => dateTime()();
  TextColumn get effectiveDate => text().map(const CalendarDateConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get kind => text()();
  TextColumn get legOutContainerId => text()();
  TextColumn get legOutAssetId => text()();
  TextColumn get legOutQuantity => text()();
  TextColumn get legOutBalanceAfter => text().nullable()();
  TextColumn get legInContainerId => text()();
  TextColumn get legInAssetId => text()();
  TextColumn get legInQuantity => text()();
  TextColumn get legInBalanceAfter => text().nullable()();
  TextColumn get budgetLegOutContainerId => text().nullable()();
  TextColumn get budgetLegOutAssetId => text().nullable()();
  TextColumn get budgetLegOutQuantity => text().nullable()();
  TextColumn get budgetLegOutBalanceAfter => text().nullable()();
  TextColumn get budgetLegInContainerId => text().nullable()();
  TextColumn get budgetLegInAssetId => text().nullable()();
  TextColumn get budgetLegInQuantity => text().nullable()();
  TextColumn get budgetLegInBalanceAfter => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  IntColumn get manualOrderRank => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PriceSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get price => text()();
  TextColumn get currencyAssetId => text()();
  TextColumn get source => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get id => text()();
  TextColumn get value => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class RecurringTransactionTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get legOutContainerId => text()();
  TextColumn get legOutAssetId => text()();
  TextColumn get legOutQuantity => text()();
  TextColumn get legInContainerId => text()();
  TextColumn get legInAssetId => text()();
  TextColumn get legInQuantity => text()();
  TextColumn get budgetLegOutContainerId => text().nullable()();
  TextColumn get budgetLegOutAssetId => text().nullable()();
  TextColumn get budgetLegOutQuantity => text().nullable()();
  TextColumn get budgetLegInContainerId => text().nullable()();
  TextColumn get budgetLegInAssetId => text().nullable()();
  TextColumn get budgetLegInQuantity => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  TextColumn get ruleUnit => text()();
  IntColumn get ruleInterval => integer()();
  TextColumn get ruleStartDate => text().map(const CalendarDateConverter())();
  TextColumn get ruleEndDate =>
      text().map(const CalendarDateConverter()).nullable()();
  IntColumn get ruleMaxOccurrences => integer().nullable()();
  TextColumn get lastGeneratedOccurrenceDate =>
      text().map(const CalendarDateConverter()).nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class BalanceCheckpoints extends Table {
  TextColumn get containerId => text()();
  TextColumn get assetId => text()();
  DateTimeColumn get checkpointDate => dateTime()();
  TextColumn get quantity => text()();

  @override
  Set<Column> get primaryKey => {containerId, assetId, checkpointDate};
}
