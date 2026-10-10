import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../api/models.dart';
import '../auth/vault_session.dart';
import '../backup/backup_models.dart';
import '../crypto/vault_crypto.dart';
import '../db/database.dart' as ldb;
import '../db/domain_cache_database.dart' as cache;
import '../sync/sync_engine.dart';
import 'balance_engine.dart';
import 'calendar_date.dart';
import 'id_generator.dart';
import 'models.dart';
import 'recurrence_rule.dart';
import 'recurring_template_mapping.dart';

class VaultNotEmptyException implements Exception {
  const VaultNotEmptyException();
}

class DomainRepository {
  final ldb.AppDatabase syncDb;
  final cache.DomainCacheDatabase cacheDb;
  final SyncEngine syncEngine;
  final BalanceEngine balanceEngine;
  final VaultSessionManager vaultSession;

  final void Function(List<VaultRecordConflict> conflicts)? onSyncConflict;

  DomainRepository({
    required this.syncDb,
    required this.cacheDb,
    required this.syncEngine,
    required this.balanceEngine,
    required this.vaultSession,
    this.onSyncConflict,
  });

  Uint8List get _dek {
    final dek = vaultSession.currentDek;
    if (dek == null) {
      throw StateError('Cannot write domain records: vault is locked');
    }
    return dek;
  }

  Future<void> initializeAfterUnlock() async {
    await ensureExternalContainer();
    await applyAllLocalVaultRecords();
  }

  Future<void> _mutexTail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _mutexTail.then((_) => action());
    _mutexTail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<PullResult> syncNow() {
    return _serialized(() async {
      final result = await syncEngine.sync();
      await applyPulledRecords(result.appliedRecords);
      if (result.conflicts.isNotEmpty) {
        onSyncConflict?.call(result.conflicts);
      }
      return result;
    });
  }

  void _syncSoon() {
    unawaited(() async {
      try {
        await syncNow();
      } catch (_) {}
    }());
  }

  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      syncEngine.watchRecordStatuses();

  Stream<SyncCounts> watchSyncCounts() => syncEngine.watchSyncCounts();

  Future<void> acknowledgeConflict(String id) =>
      syncEngine.acknowledgeConflict(id);

  Future<bool> hasNewRemoteData() => syncEngine.hasNewRemoteData();

  Stream<List<cache.Asset>> watchAssets() => (cacheDb.select(
    cacheDb.assets,
  )..where((t) => t.deleted.equals(false))).watch();

  Future<Asset> createAsset({
    String? id,
    required AssetKind kind,
    required String symbol,
    required String name,
    String? displaySymbol,
  }) async {
    if (id != null) {
      final row = await (cacheDb.select(
        cacheDb.assets,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row != null) {
        final updated = _assetFromRow(row).copyWith(
          symbol: symbol,
          name: name,
          displaySymbol: displaySymbol,
          clearDisplaySymbol: displaySymbol == null,
        );
        await _writeAssetRecord(updated, deleted: false);
        return updated;
      }
    }
    final asset = Asset(
      id: id ?? generateRecordId(),
      kind: kind,
      symbol: symbol,
      name: name,
      displaySymbol: displaySymbol,
    );
    await _writeAssetRecord(asset, deleted: false);
    return asset;
  }

  Future<void> seedDefaultFiatAssetIfNeeded() async {
    final existing = await cacheDb.select(cacheDb.assets).get();
    if (existing.isNotEmpty) return;
    await createAsset(kind: AssetKind.fiat, symbol: 'EUR', name: 'Euro');
  }

  Future<void> setAssetAlphaVantageSymbol(
    String assetId,
    String? symbol,
  ) async {
    final row = await (cacheDb.select(
      cacheDb.assets,
    )..where((t) => t.id.equals(assetId))).getSingleOrNull();
    if (row == null) return;
    await _writeAssetRecord(
      _assetFromRow(row).copyWith(
        alphaVantageSymbol: symbol,
        clearAlphaVantageSymbol: symbol == null,
      ),
      deleted: false,
    );
  }

  Asset _assetFromRow(cache.Asset row) => Asset(
    id: row.id,
    kind: AssetKind.fromJson(row.kind),
    symbol: row.symbol,
    name: row.name,
    alphaVantageSymbol: row.alphaVantageSymbol,
    displaySymbol: row.displaySymbol,
  );

  Future<void> _writeAssetRecord(Asset asset, {required bool deleted}) {
    return _serialized(() => _doWriteAssetRecord(asset, deleted: deleted));
  }

  Future<void> _doWriteAssetRecord(Asset asset, {required bool deleted}) async {
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(asset.toJson())),
    );
    final encrypted = await VaultCrypto.encryptRecord(
      dek: _dek,
      recordId: asset.id,
      type: VaultRecordTypes.asset,
      plaintext: plaintext,
    );
    await syncEngine.stageLocalChange(
      id: asset.id,
      type: VaultRecordTypes.asset,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      deleted: deleted,
    );
    await cacheDb
        .into(cacheDb.assets)
        .insertOnConflictUpdate(
          cache.AssetsCompanion(
            id: Value(asset.id),
            kind: Value(asset.kind.name),
            symbol: Value(asset.symbol),
            name: Value(asset.name),
            alphaVantageSymbol: Value(asset.alphaVantageSymbol),
            displaySymbol: Value(asset.displaySymbol),
            deleted: Value(deleted),
          ),
        );
    _syncSoon();
  }

  Future<void> _applyAssetRecord(VaultRecordResponse record) async {
    final asset = await _decryptAsset(record);
    if (asset == null) return;
    await cacheDb
        .into(cacheDb.assets)
        .insertOnConflictUpdate(
          cache.AssetsCompanion(
            id: Value(asset.id),
            kind: Value(asset.kind.name),
            symbol: Value(asset.symbol),
            name: Value(asset.name),
            alphaVantageSymbol: Value(asset.alphaVantageSymbol),
            displaySymbol: Value(asset.displaySymbol),
            deleted: Value(record.deleted),
          ),
        );
  }

  Future<Asset?> _decryptAsset(VaultRecordResponse record) async {
    try {
      final plaintext = await VaultCrypto.decryptRecord(
        dek: _dek,
        recordId: record.id,
        type: record.type,
        ciphertext: record.ciphertext,
        nonce: record.nonce,
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return Asset.fromJson(record.id, json);
    } on VaultCryptoException {
      return null;
    }
  }

  Future<void> ensureExternalContainer() async {
    await cacheDb
        .into(cacheDb.containers)
        .insertOnConflictUpdate(
          cache.ContainersCompanion(
            id: const Value(externalHolderContainerId),
            name: const Value('External'),
            containerType: Value(ContainerType.holder.name),
            parentId: const Value(null),
            deleted: const Value(false),
          ),
        );
    await cacheDb
        .into(cacheDb.containers)
        .insertOnConflictUpdate(
          cache.ContainersCompanion(
            id: const Value(externalBudgetContainerId),
            name: const Value('External'),
            containerType: Value(ContainerType.budget.name),
            parentId: const Value(null),
            deleted: const Value(false),
          ),
        );
  }

  Stream<List<cache.Container>> watchContainers() => (cacheDb.select(
    cacheDb.containers,
  )..where((t) => t.deleted.equals(false))).watch();

  Future<MoneyContainer> createContainer({
    String? id,
    required String name,
    required ContainerType containerType,
    String? parentId,
    String? icon,
  }) async {
    final container = MoneyContainer(
      id: id ?? generateRecordId(),
      name: name,
      containerType: containerType,
      parentId: parentId,
      icon: icon,
    );
    await _writeContainerRecord(container, deleted: false);
    return container;
  }

  Future<void> deleteContainer(String id) async {
    final row = await (cacheDb.select(
      cacheDb.containers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final container = MoneyContainer(
      id: row.id,
      name: row.name,
      containerType: ContainerType.fromJson(row.containerType),
      parentId: row.parentId,
      icon: row.icon,
    );
    await _writeContainerRecord(container, deleted: true);
  }

  Future<void> _writeContainerRecord(
    MoneyContainer container, {
    required bool deleted,
  }) {
    return _serialized(
      () => _doWriteContainerRecord(container, deleted: deleted),
    );
  }

  Future<void> _doWriteContainerRecord(
    MoneyContainer container, {
    required bool deleted,
  }) async {
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(container.toJson())),
    );
    final encrypted = await VaultCrypto.encryptRecord(
      dek: _dek,
      recordId: container.id,
      type: VaultRecordTypes.container,
      plaintext: plaintext,
    );
    await syncEngine.stageLocalChange(
      id: container.id,
      type: VaultRecordTypes.container,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      deleted: deleted,
    );
    await cacheDb
        .into(cacheDb.containers)
        .insertOnConflictUpdate(
          cache.ContainersCompanion(
            id: Value(container.id),
            name: Value(container.name),
            containerType: Value(container.containerType.name),
            parentId: Value(container.parentId),
            icon: Value(container.icon),
            deleted: Value(deleted),
          ),
        );
    _syncSoon();
  }

  Future<void> _applyContainerRecord(VaultRecordResponse record) async {
    final container = await _decryptContainer(record);
    if (container == null) return;
    await cacheDb
        .into(cacheDb.containers)
        .insertOnConflictUpdate(
          cache.ContainersCompanion(
            id: Value(container.id),
            name: Value(container.name),
            containerType: Value(container.containerType.name),
            parentId: Value(container.parentId),
            icon: Value(container.icon),
            deleted: Value(record.deleted),
          ),
        );
  }

  Future<MoneyContainer?> _decryptContainer(VaultRecordResponse record) async {
    try {
      final plaintext = await VaultCrypto.decryptRecord(
        dek: _dek,
        recordId: record.id,
        type: record.type,
        ciphertext: record.ciphertext,
        nonce: record.nonce,
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return MoneyContainer.fromJson(record.id, json);
    } on VaultCryptoException {
      return null;
    }
  }

  Stream<cache.Setting?> watchSetting(String id) =>
      (cacheDb.select(cacheDb.settings)
            ..where((t) => t.id.equals(id) & t.deleted.equals(false)))
          .watchSingleOrNull();

  Future<void> setSetting(String id, String value) =>
      _writeSettingRecord(Setting(id: id, value: value), deleted: false);

  Future<void> clearSetting(String id) =>
      _writeSettingRecord(Setting(id: id, value: ''), deleted: true);

  Future<void> _writeSettingRecord(Setting setting, {required bool deleted}) {
    return _serialized(() => _doWriteSettingRecord(setting, deleted: deleted));
  }

  Future<void> _doWriteSettingRecord(
    Setting setting, {
    required bool deleted,
  }) async {
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(setting.toJson())),
    );
    final encrypted = await VaultCrypto.encryptRecord(
      dek: _dek,
      recordId: setting.id,
      type: VaultRecordTypes.setting,
      plaintext: plaintext,
    );
    await syncEngine.stageLocalChange(
      id: setting.id,
      type: VaultRecordTypes.setting,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      deleted: deleted,
    );
    await cacheDb
        .into(cacheDb.settings)
        .insertOnConflictUpdate(
          cache.SettingsCompanion(
            id: Value(setting.id),
            value: Value(setting.value),
            deleted: Value(deleted),
          ),
        );
    _syncSoon();
  }

  Future<void> _applySettingRecord(VaultRecordResponse record) async {
    final setting = await _decryptSetting(record);
    if (setting == null) return;
    await cacheDb
        .into(cacheDb.settings)
        .insertOnConflictUpdate(
          cache.SettingsCompanion(
            id: Value(setting.id),
            value: Value(setting.value),
            deleted: Value(record.deleted),
          ),
        );
  }

  Future<Setting?> _decryptSetting(VaultRecordResponse record) async {
    try {
      final plaintext = await VaultCrypto.decryptRecord(
        dek: _dek,
        recordId: record.id,
        type: record.type,
        ciphertext: record.ciphertext,
        nonce: record.nonce,
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return Setting.fromJson(record.id, json);
    } on VaultCryptoException {
      return null;
    }
  }

  Stream<List<cache.PriceSnapshot>> watchPriceSnapshots() => (cacheDb.select(
    cacheDb.priceSnapshots,
  )..where((t) => t.deleted.equals(false))).watch();

  Future<PriceSnapshot> createPriceSnapshot({
    String? id,
    required String assetId,
    required DateTime date,
    required Decimal price,
    required String currencyAssetId,
    PriceSnapshotSource source = PriceSnapshotSource.manual,
  }) async {
    if (assetId == currencyAssetId) {
      throw ArgumentError(
        'A price snapshot must price an asset in a different asset',
      );
    }
    final snapshot = PriceSnapshot(
      id: id ?? generateRecordId(),
      assetId: assetId,
      date: date,
      price: price,
      currencyAssetId: currencyAssetId,
      source: source,
    );
    await _writePriceSnapshotRecord(snapshot, deleted: false);
    return snapshot;
  }

  Future<void> deletePriceSnapshot(String id) async {
    final row = await (cacheDb.select(
      cacheDb.priceSnapshots,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _writePriceSnapshotRecord(_priceSnapshotFromRow(row), deleted: true);
  }

  PriceSnapshot _priceSnapshotFromRow(cache.PriceSnapshot row) => PriceSnapshot(
    id: row.id,
    assetId: row.assetId,
    date: row.date,
    price: Decimal.parse(row.price),
    currencyAssetId: row.currencyAssetId,
    source: PriceSnapshotSource.fromJson(row.source),
  );

  Future<void> _writePriceSnapshotRecord(
    PriceSnapshot snapshot, {
    required bool deleted,
  }) {
    return _serialized(
      () => _doWritePriceSnapshotRecord(snapshot, deleted: deleted),
    );
  }

  Future<void> _doWritePriceSnapshotRecord(
    PriceSnapshot snapshot, {
    required bool deleted,
  }) async {
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(snapshot.toJson())),
    );
    final encrypted = await VaultCrypto.encryptRecord(
      dek: _dek,
      recordId: snapshot.id,
      type: VaultRecordTypes.priceSnapshot,
      plaintext: plaintext,
    );
    await syncEngine.stageLocalChange(
      id: snapshot.id,
      type: VaultRecordTypes.priceSnapshot,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      deleted: deleted,
    );
    await cacheDb
        .into(cacheDb.priceSnapshots)
        .insertOnConflictUpdate(
          cache.PriceSnapshotsCompanion(
            id: Value(snapshot.id),
            assetId: Value(snapshot.assetId),
            date: Value(snapshot.date),
            price: Value(snapshot.price.toString()),
            currencyAssetId: Value(snapshot.currencyAssetId),
            source: Value(snapshot.source.name),
            deleted: Value(deleted),
          ),
        );
    _syncSoon();
  }

  Future<void> _applyPriceSnapshotRecord(VaultRecordResponse record) async {
    final snapshot = await _decryptPriceSnapshot(record);
    if (snapshot == null) return;
    await cacheDb
        .into(cacheDb.priceSnapshots)
        .insertOnConflictUpdate(
          cache.PriceSnapshotsCompanion(
            id: Value(snapshot.id),
            assetId: Value(snapshot.assetId),
            date: Value(snapshot.date),
            price: Value(snapshot.price.toString()),
            currencyAssetId: Value(snapshot.currencyAssetId),
            source: Value(snapshot.source.name),
            deleted: Value(record.deleted),
          ),
        );
  }

  Future<PriceSnapshot?> _decryptPriceSnapshot(
    VaultRecordResponse record,
  ) async {
    try {
      final plaintext = await VaultCrypto.decryptRecord(
        dek: _dek,
        recordId: record.id,
        type: record.type,
        ciphertext: record.ciphertext,
        nonce: record.nonce,
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return PriceSnapshot.fromJson(record.id, json);
    } on VaultCryptoException {
      return null;
    }
  }

  Stream<List<cache.Transaction>> watchTransactions() =>
      (cacheDb.select(cacheDb.transactions)
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.effectiveDate)]))
          .watch();

  TransactionLeg _leg(String containerId, String assetId, Decimal quantity) =>
      TransactionLeg(
        containerId: containerId,
        assetId: assetId,
        quantity: quantity,
      );

  Future<MoneyTransaction> recordIncome({
    String? id,
    required String holderId,
    required String budgetId,
    required String assetId,
    required Decimal quantity,
    required CalendarDate effectiveDate,
    DateTime? postedAt,
    String? note,
    List<String> tags = const [],
  }) {
    return _createTransaction(
      MoneyTransaction(
        id: id ?? generateRecordId(),
        postedAt: postedAt ?? DateTime.now(),
        effectiveDate: effectiveDate,
        note: note,
        kind: TransactionKind.income,
        legOut: _leg(externalHolderContainerId, assetId, quantity),
        legIn: _leg(holderId, assetId, quantity),
        budgetLegOut: _leg(externalBudgetContainerId, assetId, quantity),
        budgetLegIn: _leg(budgetId, assetId, quantity),
        tags: tags,
      ),
    );
  }

  Future<MoneyTransaction> recordExpense({
    String? id,
    required String holderId,
    required String budgetId,
    required String assetId,
    required Decimal quantity,
    required CalendarDate effectiveDate,
    DateTime? postedAt,
    String? note,
    List<String> tags = const [],
  }) {
    return _createTransaction(
      MoneyTransaction(
        id: id ?? generateRecordId(),
        postedAt: postedAt ?? DateTime.now(),
        effectiveDate: effectiveDate,
        note: note,
        kind: TransactionKind.expense,
        legOut: _leg(holderId, assetId, quantity),
        legIn: _leg(externalHolderContainerId, assetId, quantity),
        budgetLegOut: _leg(budgetId, assetId, quantity),
        budgetLegIn: _leg(externalBudgetContainerId, assetId, quantity),
        tags: tags,
      ),
    );
  }

  Future<MoneyTransaction> recordHolderTransfer({
    String? id,
    required String fromHolderId,
    required String toHolderId,
    required String assetId,
    required Decimal quantity,
    required CalendarDate effectiveDate,
    DateTime? postedAt,
    String? note,
    List<String> tags = const [],
  }) {
    return _createTransaction(
      MoneyTransaction(
        id: id ?? generateRecordId(),
        postedAt: postedAt ?? DateTime.now(),
        effectiveDate: effectiveDate,
        note: note,
        kind: TransactionKind.holderTransfer,
        legOut: _leg(fromHolderId, assetId, quantity),
        legIn: _leg(toHolderId, assetId, quantity),
        tags: tags,
      ),
    );
  }

  Future<MoneyTransaction> recordBudgetTransfer({
    String? id,
    required String fromBudgetId,
    required String toBudgetId,
    required String assetId,
    required Decimal quantity,
    required CalendarDate effectiveDate,
    DateTime? postedAt,
    String? note,
    List<String> tags = const [],
  }) {
    return _createTransaction(
      MoneyTransaction(
        id: id ?? generateRecordId(),
        postedAt: postedAt ?? DateTime.now(),
        effectiveDate: effectiveDate,
        note: note,
        kind: TransactionKind.budgetTransfer,
        legOut: _leg(fromBudgetId, assetId, quantity),
        legIn: _leg(toBudgetId, assetId, quantity),
        tags: tags,
      ),
    );
  }

  Future<MoneyTransaction> recordTrade({
    String? id,
    required String holderId,
    required String budgetId,
    required String assetOutId,
    required Decimal quantityOut,
    required String assetInId,
    required Decimal quantityIn,
    required CalendarDate effectiveDate,
    DateTime? postedAt,
    String? note,
    List<String> tags = const [],
  }) {
    return _createTransaction(
      MoneyTransaction(
        id: id ?? generateRecordId(),
        postedAt: postedAt ?? DateTime.now(),
        effectiveDate: effectiveDate,
        note: note,
        kind: TransactionKind.trade,
        legOut: _leg(holderId, assetOutId, quantityOut),
        legIn: _leg(holderId, assetInId, quantityIn),
        budgetLegOut: _leg(budgetId, assetOutId, quantityOut),
        budgetLegIn: _leg(budgetId, assetInId, quantityIn),
        tags: tags,
      ),
    );
  }

  Future<MoneyTransaction> _createTransaction(MoneyTransaction tx) async {
    await _validateTransaction(tx);
    await _writeTransactionRecord(tx, deleted: false, stageForSync: true);
    return tx;
  }

  Future<void> updateTransaction(MoneyTransaction tx) async {
    await _validateTransaction(tx);
    await _writeTransactionRecord(tx, deleted: false, stageForSync: true);
  }

  Future<void> deleteTransaction(String id) async {
    final row = await (cacheDb.select(
      cacheDb.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _writeTransactionRecord(
      _transactionFromRow(row),
      deleted: true,
      stageForSync: true,
    );
  }

  Future<void> deleteTransactions(Iterable<String> ids) {
    return _serialized(() async {
      final writes = <_PendingWrite>[];
      for (final id in ids) {
        final row = await (cacheDb.select(
          cacheDb.transactions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null) continue;
        writes.add(_PendingWrite(tx: _transactionFromRow(row), deleted: true));
      }
      await _doWriteTransactionRecordsBatch(writes);
    });
  }

  Future<List<MoneyTransaction>> copyTransactions(
    List<cache.Transaction> originals, {
    required CalendarDate effectiveDate,
    DateTime? postedAt,
  }) {
    return _serialized(() async {
      final resolvedPostedAt = postedAt ?? DateTime.now();
      final copies = <MoneyTransaction>[];
      for (final row in originals) {
        final original = _transactionFromRow(row);
        final copy = MoneyTransaction(
          id: generateRecordId(),
          postedAt: resolvedPostedAt,
          effectiveDate: effectiveDate,
          note: original.note,
          kind: original.kind,
          legOut: _leg(
            original.legOut.containerId,
            original.legOut.assetId,
            original.legOut.quantity,
          ),
          legIn: _leg(
            original.legIn.containerId,
            original.legIn.assetId,
            original.legIn.quantity,
          ),
          budgetLegOut: original.budgetLegOut == null
              ? null
              : _leg(
                  original.budgetLegOut!.containerId,
                  original.budgetLegOut!.assetId,
                  original.budgetLegOut!.quantity,
                ),
          budgetLegIn: original.budgetLegIn == null
              ? null
              : _leg(
                  original.budgetLegIn!.containerId,
                  original.budgetLegIn!.assetId,
                  original.budgetLegIn!.quantity,
                ),
          tags: original.tags,
        );
        await _validateTransaction(copy);
        copies.add(copy);
      }
      await _doWriteTransactionRecordsBatch([
        for (final tx in copies) _PendingWrite(tx: tx, deleted: false),
      ]);
      return copies;
    });
  }

  Future<void> editTransactionTags(
    Iterable<String> ids, {
    List<String> add = const [],
    List<String> remove = const [],
  }) {
    return _serialized(() async {
      final removeSet = remove.toSet();
      final writes = <_PendingWrite>[];
      for (final id in ids) {
        final row = await (cacheDb.select(
          cacheDb.transactions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row == null || row.deleted) continue;
        final tx = _transactionFromRow(row);
        final next = [
          for (final t in tx.tags)
            if (!removeSet.contains(t)) t,
        ];
        for (final t in add) {
          if (!removeSet.contains(t) && !next.contains(t)) next.add(t);
        }
        if (next.length == tx.tags.length &&
            [
              for (var i = 0; i < next.length; i++) next[i] == tx.tags[i],
            ].every((same) => same)) {
          continue;
        }
        writes.add(
          _PendingWrite(
            tx: MoneyTransaction(
              id: tx.id,
              postedAt: tx.postedAt,
              effectiveDate: tx.effectiveDate,
              note: tx.note,
              kind: tx.kind,
              legOut: tx.legOut,
              legIn: tx.legIn,
              budgetLegOut: tx.budgetLegOut,
              budgetLegIn: tx.budgetLegIn,
              tags: next,
              manualOrderRank: tx.manualOrderRank,
            ),
            deleted: false,
          ),
        );
      }
      await _doWriteTransactionRecordsBatch(writes);
    });
  }

  Future<void> reorderTransactions(Map<String, int> newRankById) {
    return _serialized(() async {
      final writes = <_PendingWrite>[];
      for (final entry in newRankById.entries) {
        final row = await (cacheDb.select(
          cacheDb.transactions,
        )..where((t) => t.id.equals(entry.key))).getSingleOrNull();
        if (row == null) continue;
        final tx = _transactionFromRow(row);
        writes.add(
          _PendingWrite(
            tx: MoneyTransaction(
              id: tx.id,
              postedAt: tx.postedAt,
              effectiveDate: tx.effectiveDate,
              note: tx.note,
              kind: tx.kind,
              legOut: tx.legOut,
              legIn: tx.legIn,
              budgetLegOut: tx.budgetLegOut,
              budgetLegIn: tx.budgetLegIn,
              tags: tx.tags,
              manualOrderRank: entry.value,
            ),
            deleted: false,
          ),
        );
      }
      await _doWriteTransactionRecordsBatch(writes);
    });
  }

  Future<void> _validateTransaction(MoneyTransaction tx) async {
    Future<ContainerType> typeOf(String containerId) async {
      if (containerId == externalHolderContainerId) return ContainerType.holder;
      if (containerId == externalBudgetContainerId) return ContainerType.budget;
      final row = await (cacheDb.select(
        cacheDb.containers,
      )..where((t) => t.id.equals(containerId))).getSingleOrNull();
      if (row == null) {
        throw ArgumentError('Unknown container: $containerId');
      }
      return ContainerType.fromJson(row.containerType);
    }

    bool isSentinel(String containerId) =>
        containerId == externalHolderContainerId ||
        containerId == externalBudgetContainerId;

    Future<void> requireNonSentinelType(
      String containerId,
      ContainerType expected,
      String label,
    ) async {
      if (isSentinel(containerId)) {
        throw ArgumentError('$label may not be the external sentinel');
      }
      final actual = await typeOf(containerId);
      if (actual != expected) {
        throw ArgumentError(
          '$label must be a ${expected.name} container, got ${actual.name}',
        );
      }
    }

    switch (tx.kind) {
      case TransactionKind.income:
        if (tx.legOut.containerId != externalHolderContainerId ||
            tx.budgetLegOut?.containerId != externalBudgetContainerId) {
          throw ArgumentError(
            'income must originate from both external sentinels',
          );
        }
        await requireNonSentinelType(
          tx.legIn.containerId,
          ContainerType.holder,
          'income holder',
        );
        await requireNonSentinelType(
          tx.budgetLegIn!.containerId,
          ContainerType.budget,
          'income budget',
        );
        break;
      case TransactionKind.expense:
        if (tx.legIn.containerId != externalHolderContainerId ||
            tx.budgetLegIn?.containerId != externalBudgetContainerId) {
          throw ArgumentError('expense must go to both external sentinels');
        }
        await requireNonSentinelType(
          tx.legOut.containerId,
          ContainerType.holder,
          'expense holder',
        );
        await requireNonSentinelType(
          tx.budgetLegOut!.containerId,
          ContainerType.budget,
          'expense budget',
        );
        break;
      case TransactionKind.holderTransfer:
        if (tx.budgetLegOut != null || tx.budgetLegIn != null) {
          throw ArgumentError('holderTransfer must not touch any budget');
        }
        await requireNonSentinelType(
          tx.legOut.containerId,
          ContainerType.holder,
          'holderTransfer from',
        );
        await requireNonSentinelType(
          tx.legIn.containerId,
          ContainerType.holder,
          'holderTransfer to',
        );
        break;
      case TransactionKind.budgetTransfer:
        if (tx.budgetLegOut != null || tx.budgetLegIn != null) {
          throw ArgumentError('budgetTransfer must not touch any holder');
        }
        await requireNonSentinelType(
          tx.legOut.containerId,
          ContainerType.budget,
          'budgetTransfer from',
        );
        await requireNonSentinelType(
          tx.legIn.containerId,
          ContainerType.budget,
          'budgetTransfer to',
        );
        break;
      case TransactionKind.trade:
        if (tx.legOut.containerId != tx.legIn.containerId) {
          throw ArgumentError('trade must stay within a single holder');
        }
        if (tx.legOut.assetId == tx.legIn.assetId) {
          throw ArgumentError('trade legs must be different assets');
        }
        await requireNonSentinelType(
          tx.legOut.containerId,
          ContainerType.holder,
          'trade holder',
        );
        if (tx.budgetLegOut == null || tx.budgetLegIn == null) {
          throw ArgumentError('trade must include a budget');
        }
        if (tx.budgetLegOut!.containerId != tx.budgetLegIn!.containerId) {
          throw ArgumentError('trade budget legs must be the same budget');
        }
        if (tx.budgetLegOut!.assetId != tx.legOut.assetId ||
            tx.budgetLegOut!.quantity != tx.legOut.quantity) {
          throw ArgumentError('trade budgetLegOut must mirror legOut exactly');
        }
        if (tx.budgetLegIn!.assetId != tx.legIn.assetId ||
            tx.budgetLegIn!.quantity != tx.legIn.quantity) {
          throw ArgumentError('trade budgetLegIn must mirror legIn exactly');
        }
        await requireNonSentinelType(
          tx.budgetLegOut!.containerId,
          ContainerType.budget,
          'trade budget',
        );
        break;
    }
  }

  MoneyTransaction _transactionFromRow(cache.Transaction row) =>
      MoneyTransaction(
        id: row.id,
        postedAt: row.postedAt,
        effectiveDate: row.effectiveDate,
        note: row.note,
        kind: TransactionKind.fromJson(row.kind),
        legOut: TransactionLeg(
          containerId: row.legOutContainerId,
          assetId: row.legOutAssetId,
          quantity: Decimal.parse(row.legOutQuantity),
          balanceAfter: row.legOutBalanceAfter == null
              ? null
              : Decimal.parse(row.legOutBalanceAfter!),
        ),
        legIn: TransactionLeg(
          containerId: row.legInContainerId,
          assetId: row.legInAssetId,
          quantity: Decimal.parse(row.legInQuantity),
          balanceAfter: row.legInBalanceAfter == null
              ? null
              : Decimal.parse(row.legInBalanceAfter!),
        ),
        budgetLegOut: row.budgetLegOutContainerId == null
            ? null
            : TransactionLeg(
                containerId: row.budgetLegOutContainerId!,
                assetId: row.budgetLegOutAssetId!,
                quantity: Decimal.parse(row.budgetLegOutQuantity!),
                balanceAfter: row.budgetLegOutBalanceAfter == null
                    ? null
                    : Decimal.parse(row.budgetLegOutBalanceAfter!),
              ),
        budgetLegIn: row.budgetLegInContainerId == null
            ? null
            : TransactionLeg(
                containerId: row.budgetLegInContainerId!,
                assetId: row.budgetLegInAssetId!,
                quantity: Decimal.parse(row.budgetLegInQuantity!),
                balanceAfter: row.budgetLegInBalanceAfter == null
                    ? null
                    : Decimal.parse(row.budgetLegInBalanceAfter!),
              ),
        tags: decodeTagsColumn(row.tags),
        manualOrderRank: row.manualOrderRank,
      );

  Future<void> _writeTransactionRecord(
    MoneyTransaction tx, {
    required bool deleted,
    required bool stageForSync,
  }) {
    return _serialized(
      () => _doWriteTransactionRecord(
        tx,
        deleted: deleted,
        stageForSync: stageForSync,
      ),
    );
  }

  Future<void> _doWriteTransactionRecord(
    MoneyTransaction tx, {
    required bool deleted,
    required bool stageForSync,
  }) async {
    var neutral = false;
    if (stageForSync && !deleted) {
      final existing = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(tx.id))).getSingleOrNull();
      if (existing != null &&
          !existing.deleted &&
          _isBalanceNeutralEdit(existing, tx)) {
        neutral = true;
        final stored = _transactionFromRow(existing);
        tx = MoneyTransaction(
          id: tx.id,
          postedAt: tx.postedAt,
          effectiveDate: tx.effectiveDate,
          note: tx.note,
          kind: tx.kind,
          legOut: stored.legOut,
          legIn: stored.legIn,
          budgetLegOut: stored.budgetLegOut,
          budgetLegIn: stored.budgetLegIn,
          tags: tx.tags,
          manualOrderRank: tx.manualOrderRank,
        );
      }
    }
    if (stageForSync) {
      final plaintext = Uint8List.fromList(
        utf8.encode(jsonEncode(tx.toJson())),
      );
      final encrypted = await VaultCrypto.encryptRecord(
        dek: _dek,
        recordId: tx.id,
        type: VaultRecordTypes.transaction,
        plaintext: plaintext,
      );
      await syncEngine.stageLocalChange(
        id: tx.id,
        type: VaultRecordTypes.transaction,
        ciphertext: encrypted.ciphertext,
        nonce: encrypted.nonce,
        deleted: deleted,
      );
    }

    Set<String> touched = const {};
    await cacheDb.transaction(() async {
      final oldRow = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(tx.id))).getSingleOrNull();

      await cacheDb
          .into(cacheDb.transactions)
          .insertOnConflictUpdate(_transactionCompanion(tx, deleted: deleted));

      if (neutral) return;

      touched = await balanceEngine.onTransactionChanged(
        oldLegs: oldRow != null ? _rowLegs(oldRow) : null,
        oldDate: oldRow?.effectiveDate,
        newLegs: deleted ? null : _txLegs(tx),
        newDate: deleted ? null : tx.effectiveDate,
      );
    });

    if (stageForSync) {
      final others = touched.where((id) => id != tx.id);
      if (others.isNotEmpty) {
        await syncDb.transaction(() async {
          for (final otherId in others) {
            await _restageTransactionCache(otherId);
          }
        });
      }
      _syncSoon();
    }
  }

  Future<void> _doWriteTransactionRecordsBatch(
    List<_PendingWrite> writes,
  ) async {
    if (writes.isEmpty) return;

    await syncDb.transaction(() async {
      for (final write in writes) {
        final plaintext = Uint8List.fromList(
          utf8.encode(jsonEncode(write.tx.toJson())),
        );
        final encrypted = await VaultCrypto.encryptRecord(
          dek: _dek,
          recordId: write.tx.id,
          type: VaultRecordTypes.transaction,
          plaintext: plaintext,
        );
        await syncEngine.stageLocalChange(
          id: write.tx.id,
          type: VaultRecordTypes.transaction,
          ciphertext: encrypted.ciphertext,
          nonce: encrypted.nonce,
          deleted: write.deleted,
        );
      }
    });

    final earliestDateByPair = <String, CalendarDate>{};
    final pairByKey = <String, MapEntry<String, String>>{};
    void noteAffectedPair(
      String containerId,
      String assetId,
      CalendarDate date,
    ) {
      final key = '$containerId|$assetId';
      final existing = earliestDateByPair[key];
      if (existing == null || date.isBefore(existing)) {
        earliestDateByPair[key] = date;
        pairByKey[key] = MapEntry(containerId, assetId);
      }
    }

    final writtenIds = writes.map((w) => w.tx.id).toSet();
    final touchedAll = <String>{};

    await cacheDb.transaction(() async {
      for (final write in writes) {
        final oldRow = await (cacheDb.select(
          cacheDb.transactions,
        )..where((t) => t.id.equals(write.tx.id))).getSingleOrNull();

        await cacheDb
            .into(cacheDb.transactions)
            .insertOnConflictUpdate(
              _transactionCompanion(write.tx, deleted: write.deleted),
            );

        if (oldRow != null &&
            !oldRow.deleted &&
            !write.deleted &&
            _isBalanceNeutralEdit(oldRow, write.tx)) {
          continue;
        }

        if (oldRow != null) {
          for (final leg in _rowLegs(oldRow)) {
            noteAffectedPair(leg.key, leg.value, oldRow.effectiveDate);
          }
        }
        if (!write.deleted) {
          for (final leg in _txLegs(write.tx)) {
            noteAffectedPair(leg.key, leg.value, write.tx.effectiveDate);
          }
        }
      }

      for (final key in earliestDateByPair.keys) {
        final pair = pairByKey[key]!;
        final touched = await balanceEngine.onTransactionChanged(
          oldLegs: null,
          oldDate: null,
          newLegs: [MapEntry(pair.key, pair.value)],
          newDate: earliestDateByPair[key],
        );
        touchedAll.addAll(touched);
      }
    });

    final othersToRestage = touchedAll.where((id) => !writtenIds.contains(id));
    if (othersToRestage.isNotEmpty) {
      await syncDb.transaction(() async {
        for (final otherId in othersToRestage) {
          await _restageTransactionCache(otherId);
        }
      });
    }
    _syncSoon();
  }

  bool _isBalanceNeutralEdit(cache.Transaction old, MoneyTransaction next) {
    Map<String, dynamic> balanceFields(MoneyTransaction t) {
      final json = t.toJson()
        ..remove('note')
        ..remove('tags');
      for (final leg in ['legOut', 'legIn', 'budgetLegOut', 'budgetLegIn']) {
        (json[leg] as Map<String, dynamic>?)?.remove('balanceAfter');
      }
      return json;
    }

    return jsonEncode(balanceFields(_transactionFromRow(old))) ==
        jsonEncode(balanceFields(next));
  }

  Future<void> importResolvedTransactions({
    required List<MoneyContainer> containersToCreate,
    required List<MoneyTransaction> transactions,
    void Function(int done, int total)? onProgress,
    int chunkSize = 200,
  }) {
    return _serialized(() async {
      for (final container in containersToCreate) {
        await _doWriteContainerRecord(container, deleted: false);
      }

      for (final tx in transactions) {
        await _validateTransaction(tx);
      }

      final total = transactions.length;
      onProgress?.call(0, total);
      var done = 0;
      for (var i = 0; i < transactions.length; i += chunkSize) {
        final end = (i + chunkSize < transactions.length)
            ? i + chunkSize
            : transactions.length;
        final chunk = transactions.sublist(i, end);
        await _doWriteTransactionRecordsBatch([
          for (final tx in chunk) _PendingWrite(tx: tx, deleted: false),
        ]);
        done += chunk.length;
        onProgress?.call(done, total);
      }
    });
  }

  Future<void> importPriceSnapshots({
    required List<PriceSnapshot> snapshots,
    void Function(int done, int total)? onProgress,
  }) {
    return _serialized(() async {
      final total = snapshots.length;
      onProgress?.call(0, total);
      var done = 0;
      for (final snapshot in snapshots) {
        await _doWritePriceSnapshotRecord(snapshot, deleted: false);
        done++;
        onProgress?.call(done, total);
      }
    });
  }

  Stream<List<cache.RecurringTransactionTemplate>> watchRecurringTemplates() =>
      (cacheDb.select(
        cacheDb.recurringTransactionTemplates,
      )..where((t) => t.deleted.equals(false))).watch();

  RecurringLeg _recurringLeg(
    String containerId,
    String assetId,
    Decimal quantity,
  ) => RecurringLeg(
    containerId: containerId,
    assetId: assetId,
    quantity: quantity,
  );

  Future<RecurringTransactionTemplate> createRecurringIncomeTemplate({
    String? id,
    required String holderId,
    required String budgetId,
    required String assetId,
    required Decimal quantity,
    required RecurrenceRule rule,
    String? note,
    List<String> tags = const [],
  }) => _upsertRecurringTemplate(
    RecurringTransactionTemplate(
      id: id ?? generateRecordId(),
      kind: TransactionKind.income,
      legOut: _recurringLeg(externalHolderContainerId, assetId, quantity),
      legIn: _recurringLeg(holderId, assetId, quantity),
      budgetLegOut: _recurringLeg(externalBudgetContainerId, assetId, quantity),
      budgetLegIn: _recurringLeg(budgetId, assetId, quantity),
      rule: rule,
      note: note,
      tags: tags,
    ),
  );

  Future<RecurringTransactionTemplate> createRecurringExpenseTemplate({
    String? id,
    required String holderId,
    required String budgetId,
    required String assetId,
    required Decimal quantity,
    required RecurrenceRule rule,
    String? note,
    List<String> tags = const [],
  }) => _upsertRecurringTemplate(
    RecurringTransactionTemplate(
      id: id ?? generateRecordId(),
      kind: TransactionKind.expense,
      legOut: _recurringLeg(holderId, assetId, quantity),
      legIn: _recurringLeg(externalHolderContainerId, assetId, quantity),
      budgetLegOut: _recurringLeg(budgetId, assetId, quantity),
      budgetLegIn: _recurringLeg(externalBudgetContainerId, assetId, quantity),
      rule: rule,
      note: note,
      tags: tags,
    ),
  );

  Future<RecurringTransactionTemplate> createRecurringHolderTransferTemplate({
    String? id,
    required String fromHolderId,
    required String toHolderId,
    required String assetId,
    required Decimal quantity,
    required RecurrenceRule rule,
    String? note,
    List<String> tags = const [],
  }) => _upsertRecurringTemplate(
    RecurringTransactionTemplate(
      id: id ?? generateRecordId(),
      kind: TransactionKind.holderTransfer,
      legOut: _recurringLeg(fromHolderId, assetId, quantity),
      legIn: _recurringLeg(toHolderId, assetId, quantity),
      rule: rule,
      note: note,
      tags: tags,
    ),
  );

  Future<RecurringTransactionTemplate> createRecurringBudgetTransferTemplate({
    String? id,
    required String fromBudgetId,
    required String toBudgetId,
    required String assetId,
    required Decimal quantity,
    required RecurrenceRule rule,
    String? note,
    List<String> tags = const [],
  }) => _upsertRecurringTemplate(
    RecurringTransactionTemplate(
      id: id ?? generateRecordId(),
      kind: TransactionKind.budgetTransfer,
      legOut: _recurringLeg(fromBudgetId, assetId, quantity),
      legIn: _recurringLeg(toBudgetId, assetId, quantity),
      rule: rule,
      note: note,
      tags: tags,
    ),
  );

  Future<void> _validateRecurringTemplateShape(
    RecurringTransactionTemplate template,
  ) {
    final placeholder = DateTime.utc(1970);
    return _validateTransaction(
      MoneyTransaction(
        id: template.id,
        postedAt: placeholder,
        effectiveDate: CalendarDate(1970, 1, 1),
        kind: template.kind,
        legOut: template.legOut.toTransactionLeg(),
        legIn: template.legIn.toTransactionLeg(),
        budgetLegOut: template.budgetLegOut?.toTransactionLeg(),
        budgetLegIn: template.budgetLegIn?.toTransactionLeg(),
      ),
    );
  }

  Future<RecurringTransactionTemplate> _upsertRecurringTemplate(
    RecurringTransactionTemplate template,
  ) async {
    await _validateRecurringTemplateShape(template);
    final existingRow = await (cacheDb.select(
      cacheDb.recurringTransactionTemplates,
    )..where((t) => t.id.equals(template.id))).getSingleOrNull();
    final resolved = existingRow == null
        ? template
        : template.copyWith(
            lastGeneratedOccurrenceDate:
                existingRow.lastGeneratedOccurrenceDate,
            active: existingRow.active,
          );
    await _writeRecurringTemplateRecord(resolved, deleted: false);
    return resolved;
  }

  Future<void> setRecurringTemplateActive(String id, bool active) async {
    final row = await (cacheDb.select(
      cacheDb.recurringTransactionTemplates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _writeRecurringTemplateRecord(
      _recurringTemplateFromRow(row).copyWith(active: active),
      deleted: false,
    );
  }

  Future<void> deleteRecurringTemplate(String id) async {
    final row = await (cacheDb.select(
      cacheDb.recurringTransactionTemplates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await _writeRecurringTemplateRecord(
      _recurringTemplateFromRow(row),
      deleted: true,
    );
  }

  Future<List<DueRecurringOccurrence>> dueRecurringOccurrences({
    CalendarDate? asOf,
  }) async {
    final cutoff = asOf ?? CalendarDate.today();
    final rows = await (cacheDb.select(
      cacheDb.recurringTransactionTemplates,
    )..where((t) => t.deleted.equals(false) & t.active.equals(true))).get();
    final due = <DueRecurringOccurrence>[];
    for (final row in rows) {
      final template = _recurringTemplateFromRow(row);
      for (final date in occurrencesBetween(
        template.rule,
        after: template.lastGeneratedOccurrenceDate,
        upTo: cutoff,
      )) {
        due.add(
          DueRecurringOccurrence(template: template, occurrenceDate: date),
        );
      }
    }
    due.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    return due;
  }

  Future<void> applyDueRecurringOccurrences(
    List<DueRecurringOccurrence> occurrences,
  ) {
    return _serialized(() async {
      final byTemplateId = <String, List<DueRecurringOccurrence>>{};
      for (final occurrence in occurrences) {
        byTemplateId
            .putIfAbsent(occurrence.template.id, () => [])
            .add(occurrence);
      }

      final now = DateTime.now();
      final writes = <_PendingWrite>[];
      for (final group in byTemplateId.values) {
        group.sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
        for (final occurrence in group) {
          final template = occurrence.template;
          final tx = MoneyTransaction(
            id: generateRecordId(),
            postedAt: now,
            effectiveDate: occurrence.occurrenceDate,
            note: template.note,
            kind: template.kind,
            legOut: template.legOut.toTransactionLeg(),
            legIn: template.legIn.toTransactionLeg(),
            budgetLegOut: template.budgetLegOut?.toTransactionLeg(),
            budgetLegIn: template.budgetLegIn?.toTransactionLeg(),
            tags: template.tags,
          );
          await _validateTransaction(tx);
          writes.add(_PendingWrite(tx: tx, deleted: false));
        }
      }
      await _doWriteTransactionRecordsBatch(writes);

      for (final group in byTemplateId.values) {
        final template = group.first.template;
        final latest = group
            .map((o) => o.occurrenceDate)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        await _doWriteRecurringTemplateRecord(
          template.copyWith(lastGeneratedOccurrenceDate: latest),
          deleted: false,
        );
      }
    });
  }

  Future<void> skipDueRecurringOccurrences(
    List<DueRecurringOccurrence> occurrences,
  ) {
    return _serialized(() async {
      final byTemplateId = <String, List<DueRecurringOccurrence>>{};
      for (final occurrence in occurrences) {
        byTemplateId
            .putIfAbsent(occurrence.template.id, () => [])
            .add(occurrence);
      }
      for (final group in byTemplateId.values) {
        final latest = group
            .map((o) => o.occurrenceDate)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        await _doWriteRecurringTemplateRecord(
          group.first.template.copyWith(lastGeneratedOccurrenceDate: latest),
          deleted: false,
        );
      }
    });
  }

  RecurringTransactionTemplate _recurringTemplateFromRow(
    cache.RecurringTransactionTemplate row,
  ) => recurringTemplateFromRow(row);

  cache.RecurringTransactionTemplatesCompanion _recurringTemplateCompanion(
    RecurringTransactionTemplate t, {
    required bool deleted,
  }) => cache.RecurringTransactionTemplatesCompanion(
    id: Value(t.id),
    kind: Value(t.kind.name),
    legOutContainerId: Value(t.legOut.containerId),
    legOutAssetId: Value(t.legOut.assetId),
    legOutQuantity: Value(t.legOut.quantity.toString()),
    legInContainerId: Value(t.legIn.containerId),
    legInAssetId: Value(t.legIn.assetId),
    legInQuantity: Value(t.legIn.quantity.toString()),
    budgetLegOutContainerId: Value(t.budgetLegOut?.containerId),
    budgetLegOutAssetId: Value(t.budgetLegOut?.assetId),
    budgetLegOutQuantity: Value(t.budgetLegOut?.quantity.toString()),
    budgetLegInContainerId: Value(t.budgetLegIn?.containerId),
    budgetLegInAssetId: Value(t.budgetLegIn?.assetId),
    budgetLegInQuantity: Value(t.budgetLegIn?.quantity.toString()),
    note: Value(t.note),
    tags: Value(encodeTagsColumn(t.tags)),
    ruleUnit: Value(t.rule.unit.name),
    ruleInterval: Value(t.rule.interval),
    ruleStartDate: Value(t.rule.startDate),
    ruleEndDate: Value(t.rule.endDate),
    ruleMaxOccurrences: Value(t.rule.maxOccurrences),
    lastGeneratedOccurrenceDate: Value(t.lastGeneratedOccurrenceDate),
    active: Value(t.active),
    deleted: Value(deleted),
  );

  Future<void> _writeRecurringTemplateRecord(
    RecurringTransactionTemplate template, {
    required bool deleted,
  }) {
    return _serialized(
      () => _doWriteRecurringTemplateRecord(template, deleted: deleted),
    );
  }

  Future<void> _doWriteRecurringTemplateRecord(
    RecurringTransactionTemplate template, {
    required bool deleted,
  }) async {
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(template.toJson())),
    );
    final encrypted = await VaultCrypto.encryptRecord(
      dek: _dek,
      recordId: template.id,
      type: VaultRecordTypes.recurringTransactionTemplate,
      plaintext: plaintext,
    );
    await syncEngine.stageLocalChange(
      id: template.id,
      type: VaultRecordTypes.recurringTransactionTemplate,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      deleted: deleted,
    );
    await cacheDb
        .into(cacheDb.recurringTransactionTemplates)
        .insertOnConflictUpdate(
          _recurringTemplateCompanion(template, deleted: deleted),
        );
    _syncSoon();
  }

  Future<void> _applyRecurringTemplateRecord(VaultRecordResponse record) async {
    final template = await _decryptRecurringTemplate(record);
    if (template == null) return;
    await cacheDb
        .into(cacheDb.recurringTransactionTemplates)
        .insertOnConflictUpdate(
          _recurringTemplateCompanion(template, deleted: record.deleted),
        );
  }

  Future<RecurringTransactionTemplate?> _decryptRecurringTemplate(
    VaultRecordResponse record,
  ) async {
    try {
      final plaintext = await VaultCrypto.decryptRecord(
        dek: _dek,
        recordId: record.id,
        type: record.type,
        ciphertext: record.ciphertext,
        nonce: record.nonce,
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return RecurringTransactionTemplate.fromJson(record.id, json);
    } on VaultCryptoException {
      return null;
    }
  }

  Future<BackupPayload> buildBackupPayload() async {
    final assetRows = await (cacheDb.select(
      cacheDb.assets,
    )..where((t) => t.deleted.equals(false))).get();
    final containerRows = await (cacheDb.select(
      cacheDb.containers,
    )..where((t) => t.deleted.equals(false))).get();
    final transactionRows = await (cacheDb.select(
      cacheDb.transactions,
    )..where((t) => t.deleted.equals(false))).get();
    final priceSnapshotRows = await (cacheDb.select(
      cacheDb.priceSnapshots,
    )..where((t) => t.deleted.equals(false))).get();
    final settingRows = await (cacheDb.select(
      cacheDb.settings,
    )..where((t) => t.deleted.equals(false))).get();

    final entities = buildBackupEntities(
      assets: [for (final row in assetRows) _assetFromRow(row)],
      containers: [
        for (final row in containerRows)
          if (row.id != externalHolderContainerId &&
              row.id != externalBudgetContainerId)
            MoneyContainer(
              id: row.id,
              name: row.name,
              containerType: ContainerType.fromJson(row.containerType),
              parentId: row.parentId,
              icon: row.icon,
            ),
      ],
      transactions: [
        for (final row in transactionRows) _transactionFromRow(row),
      ],
      priceSnapshots: [
        for (final row in priceSnapshotRows) _priceSnapshotFromRow(row),
      ],
      settings: [
        for (final row in settingRows) Setting(id: row.id, value: row.value),
      ],
    );

    return BackupPayload(
      schemaVersion: BackupPayload.currentSchemaVersion,
      exportedAt: DateTime.now().toUtc(),
      entities: entities,
    );
  }

  Future<bool> _isEmptyForRestore() async {
    final containers = await cacheDb.select(cacheDb.containers).get();
    final hasRealContainer = containers.any(
      (c) =>
          c.id != externalHolderContainerId &&
          c.id != externalBudgetContainerId,
    );
    if (hasRealContainer) return false;

    final transactions = await cacheDb.select(cacheDb.transactions).get();
    if (transactions.isNotEmpty) return false;

    final priceSnapshots = await cacheDb.select(cacheDb.priceSnapshots).get();
    if (priceSnapshots.isNotEmpty) return false;

    final assets = await cacheDb.select(cacheDb.assets).get();
    if (assets.length > 1) return false;

    return true;
  }

  Future<void> restoreBackup(
    BackupPayload payload, {
    void Function(int done, int total)? onProgress,
  }) {
    return _serialized(() async {
      if (!await _isEmptyForRestore()) {
        throw const VaultNotEmptyException();
      }

      final byType = <String, List<BackupEntity>>{};
      for (final entity in payload.entities) {
        (byType[entity.type] ??= []).add(entity);
      }

      final total = payload.entities.length;
      var done = 0;
      onProgress?.call(done, total);

      for (final entity in byType[VaultRecordTypes.asset] ?? const []) {
        final asset = Asset.fromJson(entity.id, entity.data);
        await _doWriteAssetRecord(asset, deleted: false);
        done++;
        onProgress?.call(done, total);
      }

      for (final entity in byType[VaultRecordTypes.container] ?? const []) {
        final container = MoneyContainer.fromJson(entity.id, entity.data);
        await _doWriteContainerRecord(container, deleted: false);
        done++;
        onProgress?.call(done, total);
      }

      final transactionEntities =
          byType[VaultRecordTypes.transaction] ?? const [];
      final transactionsToWrite = [
        for (final entity in transactionEntities)
          MoneyTransaction.fromJson(entity.id, entity.data),
      ];
      for (final tx in transactionsToWrite) {
        await _validateTransaction(tx);
      }
      const chunkSize = 200;
      for (var i = 0; i < transactionsToWrite.length; i += chunkSize) {
        final end = (i + chunkSize < transactionsToWrite.length)
            ? i + chunkSize
            : transactionsToWrite.length;
        final chunk = transactionsToWrite.sublist(i, end);
        await _doWriteTransactionRecordsBatch([
          for (final tx in chunk) _PendingWrite(tx: tx, deleted: false),
        ]);
        done += chunk.length;
        onProgress?.call(done, total);
      }

      for (final entity in byType[VaultRecordTypes.priceSnapshot] ?? const []) {
        final snapshot = PriceSnapshot.fromJson(entity.id, entity.data);
        await _doWritePriceSnapshotRecord(snapshot, deleted: false);
        done++;
        onProgress?.call(done, total);
      }

      for (final entity in byType[VaultRecordTypes.setting] ?? const []) {
        final setting = Setting.fromJson(entity.id, entity.data);
        await _doWriteSettingRecord(setting, deleted: false);
        done++;
        onProgress?.call(done, total);
      }
    });
  }

  Future<void> _restageTransactionCache(String id) async {
    final row = await (cacheDb.select(
      cacheDb.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final tx = _transactionFromRow(row);
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(tx.toJson())));
    final encrypted = await VaultCrypto.encryptRecord(
      dek: _dek,
      recordId: tx.id,
      type: VaultRecordTypes.transaction,
      plaintext: plaintext,
    );
    await syncEngine.stageLocalChange(
      id: tx.id,
      type: VaultRecordTypes.transaction,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      deleted: row.deleted,
    );
  }

  cache.TransactionsCompanion _transactionCompanion(
    MoneyTransaction tx, {
    required bool deleted,
  }) => cache.TransactionsCompanion(
    id: Value(tx.id),
    postedAt: Value(tx.postedAt),
    effectiveDate: Value(tx.effectiveDate),
    note: Value(tx.note),
    kind: Value(tx.kind.name),
    legOutContainerId: Value(tx.legOut.containerId),
    legOutAssetId: Value(tx.legOut.assetId),
    legOutQuantity: Value(tx.legOut.quantity.toString()),
    legOutBalanceAfter: Value(tx.legOut.balanceAfter?.toString()),
    legInContainerId: Value(tx.legIn.containerId),
    legInAssetId: Value(tx.legIn.assetId),
    legInQuantity: Value(tx.legIn.quantity.toString()),
    legInBalanceAfter: Value(tx.legIn.balanceAfter?.toString()),
    budgetLegOutContainerId: Value(tx.budgetLegOut?.containerId),
    budgetLegOutAssetId: Value(tx.budgetLegOut?.assetId),
    budgetLegOutQuantity: Value(tx.budgetLegOut?.quantity.toString()),
    budgetLegOutBalanceAfter: Value(tx.budgetLegOut?.balanceAfter?.toString()),
    budgetLegInContainerId: Value(tx.budgetLegIn?.containerId),
    budgetLegInAssetId: Value(tx.budgetLegIn?.assetId),
    budgetLegInQuantity: Value(tx.budgetLegIn?.quantity.toString()),
    budgetLegInBalanceAfter: Value(tx.budgetLegIn?.balanceAfter?.toString()),
    tags: Value(encodeTagsColumn(tx.tags)),
    manualOrderRank: Value(tx.manualOrderRank),
    deleted: Value(deleted),
  );

  List<MapEntry<String, String>> _txLegs(MoneyTransaction tx) => [
    MapEntry(tx.legOut.containerId, tx.legOut.assetId),
    MapEntry(tx.legIn.containerId, tx.legIn.assetId),
    if (tx.budgetLegOut != null)
      MapEntry(tx.budgetLegOut!.containerId, tx.budgetLegOut!.assetId),
    if (tx.budgetLegIn != null)
      MapEntry(tx.budgetLegIn!.containerId, tx.budgetLegIn!.assetId),
  ];

  List<MapEntry<String, String>> _rowLegs(cache.Transaction row) => [
    MapEntry(row.legOutContainerId, row.legOutAssetId),
    MapEntry(row.legInContainerId, row.legInAssetId),
    if (row.budgetLegOutContainerId != null)
      MapEntry(row.budgetLegOutContainerId!, row.budgetLegOutAssetId!),
    if (row.budgetLegInContainerId != null)
      MapEntry(row.budgetLegInContainerId!, row.budgetLegInAssetId!),
  ];

  Future<void> _applyTransactionRecordsBatch(
    List<VaultRecordResponse> records, {
    int chunkSize = 200,
  }) async {
    if (records.isEmpty) return;

    for (var i = 0; i < records.length; i += chunkSize) {
      final end = (i + chunkSize < records.length)
          ? i + chunkSize
          : records.length;
      final chunk = records.sublist(i, end);

      final writes = <_PendingWrite>[];
      for (final record in chunk) {
        final tx = await _decryptTransaction(record);
        if (tx == null) continue;
        writes.add(_PendingWrite(tx: tx, deleted: record.deleted));
      }
      if (writes.isEmpty) continue;

      final earliestDateByPair = <String, CalendarDate>{};
      final pairByKey = <String, MapEntry<String, String>>{};
      void noteAffectedPair(
        String containerId,
        String assetId,
        CalendarDate date,
      ) {
        final key = '$containerId|$assetId';
        final existing = earliestDateByPair[key];
        if (existing == null || date.isBefore(existing)) {
          earliestDateByPair[key] = date;
          pairByKey[key] = MapEntry(containerId, assetId);
        }
      }

      await cacheDb.transaction(() async {
        for (final write in writes) {
          final oldRow = await (cacheDb.select(
            cacheDb.transactions,
          )..where((t) => t.id.equals(write.tx.id))).getSingleOrNull();

          await cacheDb
              .into(cacheDb.transactions)
              .insertOnConflictUpdate(
                _transactionCompanion(write.tx, deleted: write.deleted),
              );

          if (oldRow != null) {
            for (final leg in _rowLegs(oldRow)) {
              noteAffectedPair(leg.key, leg.value, oldRow.effectiveDate);
            }
          }
          if (!write.deleted) {
            for (final leg in _txLegs(write.tx)) {
              noteAffectedPair(leg.key, leg.value, write.tx.effectiveDate);
            }
          }
        }

        for (final key in earliestDateByPair.keys) {
          final pair = pairByKey[key]!;
          await balanceEngine.onTransactionChanged(
            oldLegs: null,
            oldDate: null,
            newLegs: [MapEntry(pair.key, pair.value)],
            newDate: earliestDateByPair[key],
          );
        }
      });
    }
  }

  Future<MoneyTransaction?> _decryptTransaction(
    VaultRecordResponse record,
  ) async {
    try {
      final plaintext = await VaultCrypto.decryptRecord(
        dek: _dek,
        recordId: record.id,
        type: record.type,
        ciphertext: record.ciphertext,
        nonce: record.nonce,
      );
      final json = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return MoneyTransaction.fromJson(record.id, json);
    } on VaultCryptoException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> applyPulledRecords(List<VaultRecordResponse> records) async {
    final transactionRecords = <VaultRecordResponse>[];
    for (final record in records) {
      switch (record.type) {
        case VaultRecordTypes.asset:
          await _applyAssetRecord(record);
          break;
        case VaultRecordTypes.container:
          await _applyContainerRecord(record);
          break;
        case VaultRecordTypes.transaction:
          transactionRecords.add(record);
          break;
        case VaultRecordTypes.priceSnapshot:
          await _applyPriceSnapshotRecord(record);
          break;
        case VaultRecordTypes.setting:
          await _applySettingRecord(record);
          break;
        case VaultRecordTypes.recurringTransactionTemplate:
          await _applyRecurringTemplateRecord(record);
          break;
        default:
          break;
      }
    }
    await _applyTransactionRecordsBatch(transactionRecords);
  }

  Future<void> applyAllLocalVaultRecords() async {
    final rows = await syncDb.select(syncDb.localVaultRecords).get();

    final transactionRecords = <VaultRecordResponse>[];
    for (final r in rows) {
      final asResponse = VaultRecordResponse(
        id: r.id,
        type: r.type,
        ciphertext: r.ciphertext,
        nonce: r.nonce,
        version: r.version ?? 0,
        updatedAt: r.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        deleted: r.deleted,
      );
      switch (r.type) {
        case VaultRecordTypes.asset:
          await _applyAssetRecord(asResponse);
          break;
        case VaultRecordTypes.container:
          await _applyContainerRecord(asResponse);
          break;
        case VaultRecordTypes.transaction:
          transactionRecords.add(asResponse);
          break;
        case VaultRecordTypes.priceSnapshot:
          await _applyPriceSnapshotRecord(asResponse);
          break;
        case VaultRecordTypes.setting:
          await _applySettingRecord(asResponse);
          break;
        case VaultRecordTypes.recurringTransactionTemplate:
          await _applyRecurringTemplateRecord(asResponse);
          break;
        default:
          break;
      }
    }

    const chunkSize = 200;
    for (var i = 0; i < transactionRecords.length; i += chunkSize) {
      final end = (i + chunkSize < transactionRecords.length)
          ? i + chunkSize
          : transactionRecords.length;
      final chunk = transactionRecords.sublist(i, end);

      final writes = <_PendingWrite>[];
      for (final record in chunk) {
        final tx = await _decryptTransaction(record);
        if (tx == null) continue;
        writes.add(_PendingWrite(tx: tx, deleted: record.deleted));
      }
      if (writes.isEmpty) continue;

      await cacheDb.transaction(() async {
        for (final write in writes) {
          await cacheDb
              .into(cacheDb.transactions)
              .insertOnConflictUpdate(
                _transactionCompanion(write.tx, deleted: write.deleted),
              );
        }
      });
    }
    Map<String, List<String?>> snapshotBalances(List<cache.Transaction> rows) =>
        {
          for (final r in rows)
            r.id: [
              r.legOutBalanceAfter,
              r.legInBalanceAfter,
              r.budgetLegOutBalanceAfter,
              r.budgetLegInBalanceAfter,
            ],
        };
    final before = snapshotBalances(
      await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.deleted.equals(false))).get(),
    );
    await balanceEngine.rebuildAll();
    final after = snapshotBalances(
      await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.deleted.equals(false))).get(),
    );
    final shifted = [
      for (final e in after.entries)
        if (before[e.key] != null && !_sameBalances(before[e.key]!, e.value))
          e.key,
    ];
    if (shifted.isNotEmpty) {
      await syncDb.transaction(() async {
        for (final id in shifted) {
          await _restageTransactionCache(id);
        }
      });
      _syncSoon();
    }
  }

  static bool _sameBalances(List<String?> a, List<String?> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class DueRecurringOccurrence {
  final RecurringTransactionTemplate template;
  final CalendarDate occurrenceDate;

  const DueRecurringOccurrence({
    required this.template,
    required this.occurrenceDate,
  });
}

class _PendingWrite {
  final MoneyTransaction tx;
  final bool deleted;

  const _PendingWrite({required this.tx, required this.deleted});
}
