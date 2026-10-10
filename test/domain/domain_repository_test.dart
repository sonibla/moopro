import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/api/vault_api.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/crypto/vault_crypto.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/balance_series.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/domain/models.dart' hide Asset, PriceSnapshot;
import 'package:moopro/domain/models.dart' as domain show Asset, PriceSnapshot;
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/domain/calendar_date.dart';

class FakeVaultApi extends VaultApi {
  final List<VaultRecordResponse> serverRecords;
  int _nextVersion;

  FakeVaultApi({List<VaultRecordResponse>? sharedServerRecords})
    : serverRecords = sharedServerRecords ?? [],
      _nextVersion = 1,
      super(ApiClient());

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async {
    return serverRecords.where((r) => r.version > sinceVersion).toList();
  }

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async {
    final conflicts = <VaultRecordConflict>[];
    for (final upsert in records) {
      final current = serverRecords
          .where((r) => r.id == upsert.id)
          .firstOrNull
          ?.version;
      if (upsert.baseVersion != current) {
        conflicts.add(
          VaultRecordConflict(id: upsert.id, currentVersion: current),
        );
      }
    }
    if (conflicts.isNotEmpty) {
      throw VaultConflictException(conflicts);
    }

    final results = <VaultRecordResponse>[];
    for (final upsert in records) {
      final assigned = VaultRecordResponse(
        id: upsert.id,
        type: upsert.type,
        ciphertext: upsert.ciphertext,
        nonce: upsert.nonce,
        version: _nextVersion++,
        updatedAt: DateTime.utc(2026, 1, 1),
        deleted: upsert.deleted,
      );
      serverRecords.removeWhere((r) => r.id == upsert.id);
      serverRecords.add(assigned);
      results.add(assigned);
    }
    return results;
  }
}

class _OfflineVaultApi extends VaultApi {
  _OfflineVaultApi() : super(ApiClient());

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async =>
      throw Exception('offline');

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async => throw Exception('offline');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => this.isEmpty ? null : first;
}

class FixedDekVaultSession extends VaultSessionManager {
  final Uint8List _dek;

  FixedDekVaultSession(this._dek)
    : super(
        authApi: AuthApi(ApiClient()),
        localUnlockStore: LocalUnlockStore(),
        localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
          AppDatabase(NativeDatabase.memory()),
        ),
      );

  @override
  Uint8List? get currentDek => _dek;
}

class _CountingVaultApi extends FakeVaultApi {
  int calls = 0;

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) {
    calls++;
    return super.pull(sinceVersion: sinceVersion);
  }

  @override
  Future<List<VaultRecordResponse>> push(List<VaultRecordUpsert> records) {
    calls++;
    return super.push(records);
  }
}

DomainRepository _buildRepository(
  AppDatabase syncDb,
  DomainCacheDatabase cacheDb,
  VaultApi vaultApi,
  Uint8List dek, {
  bool Function()? canSync,
}) {
  final syncEngine = SyncEngine(db: syncDb, vaultApi: vaultApi);
  final balanceEngine = BalanceEngine(cacheDb);
  final vaultSession = FixedDekVaultSession(dek);
  return DomainRepository(
    syncDb: syncDb,
    cacheDb: cacheDb,
    syncEngine: syncEngine,
    balanceEngine: balanceEngine,
    vaultSession: vaultSession,
    canSync: canSync ?? () => true,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DomainCacheDatabase cacheDb;
  late Uint8List dek;
  late DomainRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cacheDb = DomainCacheDatabase(NativeDatabase.memory());
    dek = VaultCrypto.generateDek();
    repo = _buildRepository(db, cacheDb, FakeVaultApi(), dek);
  });

  tearDown(() async {
    await db.close();
    await cacheDb.close();
  });

  group('assets', () {
    test(
      'createAsset stages a vault record and upserts the Assets table',
      () async {
        final asset = await repo.createAsset(
          kind: AssetKind.fiat,
          symbol: 'USD',
          name: 'US Dollar',
        );

        final row = await (cacheDb.select(
          cacheDb.assets,
        )..where((t) => t.id.equals(asset.id))).getSingle();
        expect(row.symbol, equals('USD'));
        expect(row.kind, equals('fiat'));

        final staged = await (db.select(
          db.localVaultRecords,
        )..where((t) => t.id.equals(asset.id))).getSingle();
        expect(staged.type, equals(VaultRecordTypes.asset));
      },
    );

    test('seedDefaultFiatAssetIfNeeded only seeds once', () async {
      await repo.seedDefaultFiatAssetIfNeeded();
      await repo.seedDefaultFiatAssetIfNeeded();
      final assets = await cacheDb.select(cacheDb.assets).get();
      expect(assets, hasLength(1));
      expect(assets.single.symbol, equals('EUR'));
    });

    test('setAssetAlphaVantageSymbol links, edits in place, then clears back '
        'to null', () async {
      final asset = await repo.createAsset(
        kind: AssetKind.stock,
        symbol: 'TSCO',
        name: 'Tesco',
      );
      expect(
        (await (cacheDb.select(
          cacheDb.assets,
        )..where((t) => t.id.equals(asset.id))).getSingle()).alphaVantageSymbol,
        isNull,
      );

      await repo.setAssetAlphaVantageSymbol(asset.id, 'TSCO.LON');
      var row = await (cacheDb.select(
        cacheDb.assets,
      )..where((t) => t.id.equals(asset.id))).getSingle();
      expect(row.alphaVantageSymbol, equals('TSCO.LON'));
      expect(row.symbol, equals('TSCO'));
      expect(row.deleted, isFalse);

      await repo.setAssetAlphaVantageSymbol(asset.id, 'TSCO.LSE');
      final rows = await cacheDb.select(cacheDb.assets).get();
      expect(rows, hasLength(1));
      row = rows.single;
      expect(row.alphaVantageSymbol, equals('TSCO.LSE'));

      await repo.setAssetAlphaVantageSymbol(asset.id, null);
      row = await (cacheDb.select(
        cacheDb.assets,
      )..where((t) => t.id.equals(asset.id))).getSingle();
      expect(row.alphaVantageSymbol, isNull);
    });

    test('setAssetAlphaVantageSymbol on an unknown id is a no-op', () async {
      await repo.setAssetAlphaVantageSymbol('does-not-exist', 'AAPL');
    });

    test('createAsset stores displaySymbol, and an empty value clears it '
        'back to null', () async {
      final asset = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
        displaySymbol: '€',
      );
      var row = await (cacheDb.select(
        cacheDb.assets,
      )..where((t) => t.id.equals(asset.id))).getSingle();
      expect(row.displaySymbol, equals('€'));

      await repo.createAsset(
        id: asset.id,
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      row = await (cacheDb.select(
        cacheDb.assets,
      )..where((t) => t.id.equals(asset.id))).getSingle();
      expect(row.displaySymbol, isNull);
    });

    test('createAsset with an existing id edits symbol/name in place — same '
        'row, kind and alphaVantageSymbol untouched even if a different kind '
        'is passed', () async {
      final asset = await repo.createAsset(
        kind: AssetKind.stock,
        symbol: 'TSCO',
        name: 'Tesco',
      );
      await repo.setAssetAlphaVantageSymbol(asset.id, 'TSCO.LON');

      final updated = await repo.createAsset(
        id: asset.id,
        kind: AssetKind.crypto,
        symbol: 'TSCO',
        name: 'Tesco plc',
      );
      expect(updated.id, equals(asset.id));
      expect(updated.kind, equals(AssetKind.stock));

      final rows = await cacheDb.select(cacheDb.assets).get();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.kind, equals('stock'));
      expect(row.name, equals('Tesco plc'));
      expect(row.alphaVantageSymbol, equals('TSCO.LON'));
    });
  });

  group('settings', () {
    test(
      'setSetting stages a vault record and upserts the Settings table',
      () async {
        await repo.setSetting(SettingIds.alphavantageApiKey, 'test-key-123');

        final row =
            await (cacheDb.select(cacheDb.settings)
                  ..where((t) => t.id.equals(SettingIds.alphavantageApiKey)))
                .getSingle();
        expect(row.value, equals('test-key-123'));
        expect(row.deleted, isFalse);

        final staged =
            await (db.select(db.localVaultRecords)
                  ..where((t) => t.id.equals(SettingIds.alphavantageApiKey)))
                .getSingle();
        expect(staged.type, equals(VaultRecordTypes.setting));
      },
    );

    test('watchSetting is null before set, then reflects the current value, '
        'then null again after clearSetting', () async {
      expect(
        await repo.watchSetting(SettingIds.alphavantageApiKey).first,
        isNull,
      );

      await repo.setSetting(SettingIds.alphavantageApiKey, 'abc');
      expect(
        (await repo.watchSetting(SettingIds.alphavantageApiKey).first)?.value,
        equals('abc'),
      );

      await repo.clearSetting(SettingIds.alphavantageApiKey);
      expect(
        await repo.watchSetting(SettingIds.alphavantageApiKey).first,
        isNull,
      );
    });

    test('setSetting with an existing id overwrites it in place, not a '
        'second row', () async {
      await repo.setSetting(SettingIds.alphavantageApiKey, 'first');
      await repo.setSetting(SettingIds.alphavantageApiKey, 'second');

      final rows = await cacheDb.select(cacheDb.settings).get();
      expect(rows, hasLength(1));
      expect(rows.single.value, equals('second'));
    });
  });

  group('priceSnapshots', () {
    late domain.Asset eur;
    late domain.Asset aapl;

    setUp(() async {
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      aapl = await repo.createAsset(
        kind: AssetKind.stock,
        symbol: 'AAPL',
        name: 'Apple',
      );
    });

    test('createPriceSnapshot stages a vault record and upserts the '
        'PriceSnapshots table', () async {
      final snapshot = await repo.createPriceSnapshot(
        assetId: aapl.id,
        date: DateTime.utc(2026, 1, 5),
        price: Decimal.parse('172.34'),
        currencyAssetId: eur.id,
      );

      final row = await (cacheDb.select(
        cacheDb.priceSnapshots,
      )..where((t) => t.id.equals(snapshot.id))).getSingle();
      expect(row.assetId, equals(aapl.id));
      expect(row.currencyAssetId, equals(eur.id));
      expect(row.price, equals('172.34'));
      expect(row.source, equals('manual'));

      final staged = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals(snapshot.id))).getSingle();
      expect(staged.type, equals(VaultRecordTypes.priceSnapshot));
    });

    test('createPriceSnapshot with an existing id edits it in place', () async {
      final original = await repo.createPriceSnapshot(
        assetId: aapl.id,
        date: DateTime.utc(2026, 1, 5),
        price: Decimal.parse('172.34'),
        currencyAssetId: eur.id,
      );

      await repo.createPriceSnapshot(
        id: original.id,
        assetId: aapl.id,
        date: DateTime.utc(2026, 1, 5),
        price: Decimal.parse('175.00'),
        currencyAssetId: eur.id,
      );

      final rows = await cacheDb.select(cacheDb.priceSnapshots).get();
      expect(rows, hasLength(1));
      expect(Decimal.parse(rows.single.price), equals(Decimal.parse('175.00')));
    });

    test('createPriceSnapshot rejects pricing an asset in itself', () async {
      expect(
        () => repo.createPriceSnapshot(
          assetId: aapl.id,
          date: DateTime.utc(2026, 1, 5),
          price: Decimal.parse('1'),
          currencyAssetId: aapl.id,
        ),
        throwsArgumentError,
      );
    });

    test('deletePriceSnapshot soft-deletes the row (excluded from '
        'watchPriceSnapshots, still present with deleted=true)', () async {
      final snapshot = await repo.createPriceSnapshot(
        assetId: aapl.id,
        date: DateTime.utc(2026, 1, 5),
        price: Decimal.parse('172.34'),
        currencyAssetId: eur.id,
      );

      await repo.deletePriceSnapshot(snapshot.id);

      final row = await (cacheDb.select(
        cacheDb.priceSnapshots,
      )..where((t) => t.id.equals(snapshot.id))).getSingle();
      expect(row.deleted, isTrue);

      final visible = await repo.watchPriceSnapshots().first;
      expect(visible.where((s) => s.id == snapshot.id), isEmpty);
    });

    test('deletePriceSnapshot on an unknown id is a no-op', () async {
      await repo.deletePriceSnapshot('does-not-exist');
    });
  });

  group('containers', () {
    test(
      'ensureExternalContainer seeds both sentinels, not staged for sync',
      () async {
        await repo.ensureExternalContainer();

        final holderRow = await (cacheDb.select(
          cacheDb.containers,
        )..where((t) => t.id.equals(externalHolderContainerId))).getSingle();
        expect(holderRow.name, equals('External'));
        expect(holderRow.containerType, equals(ContainerType.holder.name));

        final budgetRow = await (cacheDb.select(
          cacheDb.containers,
        )..where((t) => t.id.equals(externalBudgetContainerId))).getSingle();
        expect(budgetRow.containerType, equals(ContainerType.budget.name));

        final staged =
            await (db.select(db.localVaultRecords)..where(
                  (t) =>
                      t.id.equals(externalHolderContainerId) |
                      t.id.equals(externalBudgetContainerId),
                ))
                .get();
        expect(staged, isEmpty);
      },
    );

    test(
      'createContainer stores icon; edit changes it; null clears it',
      () async {
        row(String id) => (cacheDb.select(
          cacheDb.containers,
        )..where((t) => t.id.equals(id))).getSingle();

        final c = await repo.createContainer(
          name: 'Main bank',
          containerType: ContainerType.holder,
          icon: 'bank:ing',
        );
        expect((await row(c.id)).icon, equals('bank:ing'));

        await repo.createContainer(
          id: c.id,
          name: 'Main bank',
          containerType: ContainerType.holder,
          icon: 'fa:solidHouse',
        );
        expect((await row(c.id)).icon, equals('fa:solidHouse'));

        await repo.createContainer(
          id: c.id,
          name: 'Main bank',
          containerType: ContainerType.holder,
        );
        expect((await row(c.id)).icon, isNull);
      },
    );

    test('deleteContainer keeps the icon on the tombstone', () async {
      final c = await repo.createContainer(
        name: 'Main bank',
        containerType: ContainerType.holder,
        icon: 'fa:solidHouse',
      );
      await repo.deleteContainer(c.id);
      final row = await (cacheDb.select(
        cacheDb.containers,
      )..where((t) => t.id.equals(c.id))).getSingle();
      expect(row.deleted, isTrue);
      expect(row.icon, equals('fa:solidHouse'));
    });

    test('createContainer then deleteContainer soft-deletes', () async {
      final container = await repo.createContainer(
        name: 'Main bank',
        containerType: ContainerType.holder,
      );
      await repo.deleteContainer(container.id);

      final row = await (cacheDb.select(
        cacheDb.containers,
      )..where((t) => t.id.equals(container.id))).getSingle();
      expect(row.deleted, isTrue);
    });

    test(
      'editing a container reuses its id (does not orphan children)',
      () async {
        final parent = await repo.createContainer(
          name: 'Savings',
          containerType: ContainerType.budget,
        );
        final child = await repo.createContainer(
          name: 'Vacation',
          containerType: ContainerType.budget,
          parentId: parent.id,
        );

        await repo.createContainer(
          id: parent.id,
          name: 'Savings (renamed)',
          containerType: ContainerType.budget,
        );

        final parentRow = await (cacheDb.select(
          cacheDb.containers,
        )..where((t) => t.id.equals(parent.id))).getSingle();
        expect(parentRow.name, equals('Savings (renamed)'));
        expect(parentRow.deleted, isFalse);

        final childRow = await (cacheDb.select(
          cacheDb.containers,
        )..where((t) => t.id.equals(child.id))).getSingle();
        expect(childRow.parentId, equals(parent.id));
      },
    );
  });

  group('income/expense', () {
    late domain.Asset eur;
    late MoneyContainer bank;
    late MoneyContainer budget;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      bank = await repo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      budget = await repo.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
    });

    test('recordIncome moves the holder and budget legs together, keeping '
        'their totals equal', () async {
      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('250'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('250')),
      );
      expect(
        await balanceEngine.currentBalance(budget.id, eur.id),
        equals(Decimal.parse('250')),
      );
    });

    test('recordExpense reverses both legs together', () async {
      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('250'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );
      await repo.recordExpense(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('100'),
        effectiveDate: CalendarDate(2026, 1, 15),
      );

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('150')),
      );
      expect(
        await balanceEngine.currentBalance(budget.id, eur.id),
        equals(Decimal.parse('150')),
      );
    });

    test('tags round-trip through create and an in-place edit', () async {
      final tx = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('250'),
        effectiveDate: CalendarDate(2026, 1, 10),
        tags: const ['Japan trip', 'Reimbursable'],
      );

      final row = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(tx.id))).getSingle();
      expect(
        decodeTagsColumn(row.tags),
        equals(['Japan trip', 'Reimbursable']),
      );

      await repo.recordIncome(
        id: tx.id,
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('250'),
        effectiveDate: CalendarDate(2026, 1, 10),
        tags: const ['Paris trip'],
      );

      final edited = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(tx.id))).getSingle();
      expect(decodeTagsColumn(edited.tags), equals(['Paris trip']));
    });

    test('sum(holder balances) == sum(budget balances) holds across a mixed '
        'sequence of income/expense/transfers', () async {
      final bank2 = await repo.createContainer(
        name: 'Savings account',
        containerType: ContainerType.holder,
      );
      final budget2 = await repo.createContainer(
        name: 'Rent',
        containerType: ContainerType.budget,
      );

      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('1000'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
      await repo.recordExpense(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('200'),
        effectiveDate: CalendarDate(2026, 1, 5),
      );
      await repo.recordHolderTransfer(
        fromHolderId: bank.id,
        toHolderId: bank2.id,
        assetId: eur.id,
        quantity: Decimal.parse('300'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );
      await repo.recordBudgetTransfer(
        fromBudgetId: budget.id,
        toBudgetId: budget2.id,
        assetId: eur.id,
        quantity: Decimal.parse('150'),
        effectiveDate: CalendarDate(2026, 1, 12),
      );

      final balanceEngine = BalanceEngine(cacheDb);
      final holderTotal =
          await balanceEngine.currentBalance(bank.id, eur.id) +
          await balanceEngine.currentBalance(bank2.id, eur.id);
      final budgetTotal =
          await balanceEngine.currentBalance(budget.id, eur.id) +
          await balanceEngine.currentBalance(budget2.id, eur.id);
      expect(holderTotal, equals(budgetTotal));
      expect(holderTotal, equals(Decimal.parse('800')));
    });

    test('a holder cannot transfer directly into a budget', () async {
      expect(
        () => repo.recordHolderTransfer(
          fromHolderId: bank.id,
          toHolderId: budget.id,
          assetId: eur.id,
          quantity: Decimal.parse('50'),
          effectiveDate: CalendarDate(2026, 1, 10),
        ),
        throwsArgumentError,
      );
    });

    test('a budget cannot transfer directly into a holder', () async {
      expect(
        () => repo.recordBudgetTransfer(
          fromBudgetId: budget.id,
          toBudgetId: bank.id,
          assetId: eur.id,
          quantity: Decimal.parse('50'),
          effectiveDate: CalendarDate(2026, 1, 10),
        ),
        throwsArgumentError,
      );
    });

    test('income into the external sentinel itself is rejected', () async {
      expect(
        () => repo.recordIncome(
          holderId: externalHolderContainerId,
          budgetId: budget.id,
          assetId: eur.id,
          quantity: Decimal.parse('50'),
          effectiveDate: CalendarDate(2026, 1, 10),
        ),
        throwsArgumentError,
      );
    });

    test('deleteTransaction reverses both legs of an income row', () async {
      final tx = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('250'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      await repo.deleteTransaction(tx.id);

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.zero),
      );
      expect(
        await balanceEngine.currentBalance(budget.id, eur.id),
        equals(Decimal.zero),
      );
    });

    test('rapid successive writes do not race the fire-and-forget background '
        'sync they each trigger', () async {
      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('2000'),
        effectiveDate: CalendarDate(2026, 1, 10),
        note: 'Paycheck',
      );

      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('2000')),
      );
    });

    test('a cold rebuild (applyAllLocalVaultRecords, e.g. a fresh re-unlock '
        'with an empty in-memory cache) reproduces the same balances as '
        'the incremental path that created them', () async {
      final bank2 = await repo.createContainer(
        name: 'Savings',
        containerType: ContainerType.holder,
      );
      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('1000'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
      await repo.recordExpense(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('200'),
        effectiveDate: CalendarDate(2026, 1, 5),
      );
      await repo.recordHolderTransfer(
        fromHolderId: bank.id,
        toHolderId: bank2.id,
        assetId: eur.id,
        quantity: Decimal.parse('300'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      final freshCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final freshRepo = _buildRepository(db, freshCacheDb, FakeVaultApi(), dek);
      await freshRepo.ensureExternalContainer();
      await freshRepo.applyAllLocalVaultRecords();

      final freshEngine = BalanceEngine(freshCacheDb);
      expect(
        await freshEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('500')),
      );
      expect(
        await freshEngine.currentBalance(bank2.id, eur.id),
        equals(Decimal.parse('300')),
      );
      expect(
        await freshEngine.currentBalance(budget.id, eur.id),
        equals(Decimal.parse('800')),
      );

      await freshCacheDb.close();
    });
  });

  group('trade', () {
    late domain.Asset eur;
    late domain.Asset usd;
    late MoneyContainer broker;
    late MoneyContainer investments;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      usd = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'USD',
        name: 'US Dollar',
      );
      broker = await repo.createContainer(
        name: 'Broker',
        containerType: ContainerType.holder,
      );
      investments = await repo.createContainer(
        name: 'Investments',
        containerType: ContainerType.budget,
      );
      await repo.recordIncome(
        holderId: broker.id,
        budgetId: investments.id,
        assetId: eur.id,
        quantity: Decimal.parse('1000'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
    });

    test('converts one asset into another within a single holder, leaving '
        'the holder\'s EUR down and USD up by the traded amounts', () async {
      await repo.recordTrade(
        holderId: broker.id,
        budgetId: investments.id,
        assetOutId: eur.id,
        quantityOut: Decimal.parse('500'),
        assetInId: usd.id,
        quantityIn: Decimal.parse('540'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(broker.id, eur.id),
        equals(Decimal.parse('500')),
      );
      expect(
        await balanceEngine.currentBalance(broker.id, usd.id),
        equals(Decimal.parse('540')),
      );
    });

    test('moves a matching budget leg too (unlike a holderTransfer/'
        'budgetTransfer), mirroring the holder legs exactly, so the '
        "budget's balances move by the same amounts", () async {
      final tx = await repo.recordTrade(
        holderId: broker.id,
        budgetId: investments.id,
        assetOutId: eur.id,
        quantityOut: Decimal.parse('500'),
        assetInId: usd.id,
        quantityIn: Decimal.parse('540'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );
      expect(tx.budgetLegOut, isNotNull);
      expect(tx.budgetLegIn, isNotNull);
      expect(tx.budgetLegOut!.containerId, investments.id);
      expect(tx.budgetLegIn!.containerId, investments.id);

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(investments.id, eur.id),
        equals(Decimal.parse('500')),
      );
      expect(
        await balanceEngine.currentBalance(investments.id, usd.id),
        equals(Decimal.parse('540')),
      );
    });

    test('_validateTransaction rejects a manually-constructed trade with no '
        'budget leg at all', () async {
      expect(
        () => repo.updateTransaction(
          MoneyTransaction(
            id: 'manual-trade-no-budget',
            postedAt: DateTime.utc(2026, 1, 10),
            effectiveDate: CalendarDate(2026, 1, 10),
            kind: TransactionKind.trade,
            legOut: TransactionLeg(
              containerId: broker.id,
              assetId: eur.id,
              quantity: Decimal.parse('500'),
            ),
            legIn: TransactionLeg(
              containerId: broker.id,
              assetId: usd.id,
              quantity: Decimal.parse('540'),
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'rejects budgetLegOut/budgetLegIn naming two different budgets',
      () async {
        final otherBudget = await repo.createContainer(
          name: 'Other budget',
          containerType: ContainerType.budget,
        );
        expect(
          () => repo.updateTransaction(
            MoneyTransaction(
              id: 'manual-trade-split-budget',
              postedAt: DateTime.utc(2026, 1, 10),
              effectiveDate: CalendarDate(2026, 1, 10),
              kind: TransactionKind.trade,
              legOut: TransactionLeg(
                containerId: broker.id,
                assetId: eur.id,
                quantity: Decimal.parse('500'),
              ),
              legIn: TransactionLeg(
                containerId: broker.id,
                assetId: usd.id,
                quantity: Decimal.parse('540'),
              ),
              budgetLegOut: TransactionLeg(
                containerId: investments.id,
                assetId: eur.id,
                quantity: Decimal.parse('500'),
              ),
              budgetLegIn: TransactionLeg(
                containerId: otherBudget.id,
                assetId: usd.id,
                quantity: Decimal.parse('540'),
              ),
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'rejects a budget-leg quantity that doesn\'t match the holder leg',
      () async {
        expect(
          () => repo.updateTransaction(
            MoneyTransaction(
              id: 'manual-trade-mismatched-quantity',
              postedAt: DateTime.utc(2026, 1, 10),
              effectiveDate: CalendarDate(2026, 1, 10),
              kind: TransactionKind.trade,
              legOut: TransactionLeg(
                containerId: broker.id,
                assetId: eur.id,
                quantity: Decimal.parse('500'),
              ),
              legIn: TransactionLeg(
                containerId: broker.id,
                assetId: usd.id,
                quantity: Decimal.parse('540'),
              ),
              budgetLegOut: TransactionLeg(
                containerId: investments.id,
                assetId: eur.id,
                quantity: Decimal.parse('300'),
              ),
              budgetLegIn: TransactionLeg(
                containerId: investments.id,
                assetId: usd.id,
                quantity: Decimal.parse('540'),
              ),
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test('editing a trade in place (same id) updates both legs, including '
        'the budget ones', () async {
      final tx = await repo.recordTrade(
        holderId: broker.id,
        budgetId: investments.id,
        assetOutId: eur.id,
        quantityOut: Decimal.parse('500'),
        assetInId: usd.id,
        quantityIn: Decimal.parse('540'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      await repo.recordTrade(
        id: tx.id,
        holderId: broker.id,
        budgetId: investments.id,
        assetOutId: eur.id,
        quantityOut: Decimal.parse('200'),
        assetInId: usd.id,
        quantityIn: Decimal.parse('216'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(broker.id, eur.id),
        equals(Decimal.parse('800')),
      );
      expect(
        await balanceEngine.currentBalance(broker.id, usd.id),
        equals(Decimal.parse('216')),
      );
      expect(
        await balanceEngine.currentBalance(investments.id, eur.id),
        equals(Decimal.parse('800')),
      );
      expect(
        await balanceEngine.currentBalance(investments.id, usd.id),
        equals(Decimal.parse('216')),
      );
    });

    test(
      'deleting a trade reverses both legs, including the budget ones',
      () async {
        final tx = await repo.recordTrade(
          holderId: broker.id,
          budgetId: investments.id,
          assetOutId: eur.id,
          quantityOut: Decimal.parse('500'),
          assetInId: usd.id,
          quantityIn: Decimal.parse('540'),
          effectiveDate: CalendarDate(2026, 1, 10),
        );

        await repo.deleteTransaction(tx.id);

        final balanceEngine = BalanceEngine(cacheDb);
        expect(
          await balanceEngine.currentBalance(broker.id, eur.id),
          equals(Decimal.parse('1000')),
        );
        expect(
          await balanceEngine.currentBalance(broker.id, usd.id),
          equals(Decimal.zero),
        );
        expect(
          await balanceEngine.currentBalance(investments.id, eur.id),
          equals(Decimal.parse('1000')),
        );
        expect(
          await balanceEngine.currentBalance(investments.id, usd.id),
          equals(Decimal.zero),
        );
      },
    );

    test('rejects trading an asset for itself', () async {
      expect(
        () => repo.recordTrade(
          holderId: broker.id,
          budgetId: investments.id,
          assetOutId: eur.id,
          quantityOut: Decimal.parse('500'),
          assetInId: eur.id,
          quantityIn: Decimal.parse('500'),
          effectiveDate: CalendarDate(2026, 1, 10),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a trade spanning two different holders — defense in depth '
        'against a manually-constructed or pulled-from-another-device '
        'record, since recordTrade\'s single holderId parameter can\'t '
        'express this shape at all', () async {
      final otherBroker = await repo.createContainer(
        name: 'Other broker',
        containerType: ContainerType.holder,
      );
      expect(
        () => repo.updateTransaction(
          MoneyTransaction(
            id: 'manual-trade',
            postedAt: DateTime.utc(2026, 1, 10),
            effectiveDate: CalendarDate(2026, 1, 10),
            kind: TransactionKind.trade,
            legOut: TransactionLeg(
              containerId: broker.id,
              assetId: eur.id,
              quantity: Decimal.parse('500'),
            ),
            legIn: TransactionLeg(
              containerId: otherBroker.id,
              assetId: usd.id,
              quantity: Decimal.parse('540'),
            ),
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('batch write helpers (delete/copy/reorder)', () {
    late domain.Asset eur;
    late MoneyContainer bank;
    late MoneyContainer budget;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      bank = await repo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      budget = await repo.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
    });

    test('deleteTransactions removes every selected row in one batch, '
        'reversing all their legs', () async {
      final tx1 = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('100'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );
      final tx2 = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('50'),
        effectiveDate: CalendarDate(2026, 1, 11),
      );

      await repo.deleteTransactions([tx1.id, tx2.id]);

      final rows = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.isIn([tx1.id, tx2.id]))).get();
      expect(rows.every((r) => r.deleted), isTrue);
      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.zero),
      );
      expect(
        await balanceEngine.currentBalance(budget.id, eur.id),
        equals(Decimal.zero),
      );
    });

    test('copyTransactions duplicates the originals onto a new date with '
        'fresh ids, leaving the originals untouched', () async {
      final original = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('75'),
        effectiveDate: CalendarDate(2026, 1, 10),
        note: 'Freelance',
      );
      final originalRow = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(original.id))).getSingle();

      final copies = await repo.copyTransactions([
        originalRow,
      ], effectiveDate: CalendarDate(2026, 2, 1));

      expect(copies, hasLength(1));
      final copy = copies.single;
      expect(copy.id, isNot(equals(original.id)));
      expect(copy.effectiveDate, equals(CalendarDate(2026, 2, 1)));
      expect(copy.note, equals('Freelance'));
      expect(copy.legIn.containerId, equals(bank.id));
      expect(copy.legIn.quantity, equals(Decimal.parse('75')));

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('150')),
      );

      final stillThere = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(original.id))).getSingle();
      expect(stillThere.deleted, isFalse);
      expect(stillThere.effectiveDate, equals(CalendarDate(2026, 1, 10)));
    });

    test('editTransactionTags adds and removes tags across transactions, '
        'leaving untouched rows and other fields alone', () async {
      final a = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('10'),
        effectiveDate: CalendarDate(2026, 1, 10),
        tags: ['trip', 'food'],
      );
      final b = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('20'),
        effectiveDate: CalendarDate(2026, 1, 11),
      );
      final c = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('30'),
        effectiveDate: CalendarDate(2026, 1, 12),
        tags: ['food'],
      );

      await repo.editTransactionTags(
        [a.id, b.id],
        add: ['new', 'trip'],
        remove: ['food'],
      );

      Future<List<String>> tagsOf(String id) async => decodeTagsColumn(
        (await (cacheDb.select(
          cacheDb.transactions,
        )..where((t) => t.id.equals(id))).getSingle()).tags,
      );
      expect(await tagsOf(a.id), ['trip', 'new']);
      expect(await tagsOf(b.id), ['new', 'trip']);
      expect(await tagsOf(c.id), ['food']);

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('60')),
      );
    });

    test('editTransactionTags only re-stages the edited rows, not the later '
        'transactions on the same holder/budget', () async {
      final ids = <String>[];
      for (var day = 1; day <= 5; day++) {
        final tx = await repo.recordIncome(
          holderId: bank.id,
          budgetId: budget.id,
          assetId: eur.id,
          quantity: Decimal.parse('10'),
          effectiveDate: CalendarDate(2026, 1, day),
        );
        ids.add(tx.id);
      }
      await db
          .update(db.localVaultRecords)
          .write(const LocalVaultRecordsCompanion(dirty: Value(false)));

      await repo.editTransactionTags([ids.first], add: ['trip']);

      final dirty = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.dirty.equals(true))).get();
      expect(dirty.map((r) => r.id), [ids.first]);

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('50')),
      );
    });

    test(
      'updateTransaction with only a new note re-stages just that row',
      () async {
        final ids = <String>[];
        late MoneyTransaction first;
        for (var day = 1; day <= 4; day++) {
          final tx = await repo.recordIncome(
            holderId: bank.id,
            budgetId: budget.id,
            assetId: eur.id,
            quantity: Decimal.parse('10'),
            effectiveDate: CalendarDate(2026, 1, day),
            postedAt: DateTime.utc(2026, 1, day, 8),
          );
          ids.add(tx.id);
          if (day == 1) first = tx;
        }
        await db
            .update(db.localVaultRecords)
            .write(const LocalVaultRecordsCompanion(dirty: Value(false)));
        final current = first;
        await repo.updateTransaction(
          MoneyTransaction(
            id: current.id,
            postedAt: current.postedAt,
            effectiveDate: current.effectiveDate,
            note: 'renamed',
            kind: current.kind,
            legOut: current.legOut,
            legIn: current.legIn,
            budgetLegOut: current.budgetLegOut,
            budgetLegIn: current.budgetLegIn,
            tags: current.tags,
            manualOrderRank: current.manualOrderRank,
          ),
        );
        final dirty = await (db.select(
          db.localVaultRecords,
        )..where((t) => t.dirty.equals(true))).get();
        expect(dirty.map((r) => r.id), [ids.first]);
      },
    );

    test('reorderTransactions rewrites manualOrderRank so display order '
        'follows the requested order without touching postedAt/'
        'effectiveDate/legs', () async {
      final tx1 = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('10'),
        effectiveDate: CalendarDate(2026, 1, 10),
        postedAt: DateTime.utc(2026, 1, 10, 8),
      );
      final tx2 = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('20'),
        effectiveDate: CalendarDate(2026, 1, 10),
        postedAt: DateTime.utc(2026, 1, 10, 9),
      );

      await repo.reorderTransactions({tx1.id: 1, tx2.id: 2});

      final rows = {
        for (final row in await (cacheDb.select(
          cacheDb.transactions,
        )..where((t) => t.id.isIn([tx1.id, tx2.id]))).get())
          row.id: row,
      };
      expect(rows[tx1.id]!.manualOrderRank, equals(1));
      expect(rows[tx2.id]!.manualOrderRank, equals(2));
      expect(
        rows[tx1.id]!.postedAt.toUtc(),
        equals(DateTime.utc(2026, 1, 10, 8)),
      );
      expect(
        rows[tx2.id]!.postedAt.toUtc(),
        equals(DateTime.utc(2026, 1, 10, 9)),
      );
      expect(rows[tx1.id]!.effectiveDate, equals(CalendarDate(2026, 1, 10)));
      expect(rows[tx1.id]!.legInQuantity, equals('10'));

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('30')),
      );
    });

    test('reordering same-day expenses keeps the balance series equal to '
        'the engine balance', () async {
      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('100'),
        effectiveDate: CalendarDate(2026, 10, 1),
      );
      Future<MoneyTransaction> expense(String q, int hour) =>
          repo.recordExpense(
            holderId: bank.id,
            budgetId: budget.id,
            assetId: eur.id,
            quantity: Decimal.parse(q),
            effectiveDate: CalendarDate(2026, 10, 5),
            postedAt: DateTime.utc(2026, 10, 5, hour),
          );
      final a = await expense('14.28', 8);
      final b = await expense('4.68', 9);

      Future<void> expectConsistent() async {
        final rows = await cacheDb.select(cacheDb.transactions).get();
        final series = buildBalanceSeries(rows)['${bank.id}|${eur.id}']!;
        expect(
          series.valueAt(CalendarDate(2026, 10, 9)),
          equals(Decimal.parse('81.04')),
        );
        expect(
          await BalanceEngine(cacheDb).currentBalance(bank.id, eur.id),
          equals(Decimal.parse('81.04')),
        );
      }

      await expectConsistent();
      await repo.reorderTransactions({b.id: 1, a.id: 2});
      await expectConsistent();
      await repo.reorderTransactions({a.id: 1, b.id: 2});
      await expectConsistent();
    });
  });

  group('importResolvedTransactions', () {
    late domain.Asset eur;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
    });

    test('creates the planned containers, writes every transaction, and '
        'leaves correct balances', () async {
      final bankId = 'importedbank00001';
      final budgetId = 'importedbudget001';
      final progressCalls = <List<int>>[];

      await repo.importResolvedTransactions(
        containersToCreate: [
          MoneyContainer(
            id: bankId,
            name: 'Old Bank',
            containerType: ContainerType.holder,
          ),
          MoneyContainer(
            id: budgetId,
            name: 'Old Budget',
            containerType: ContainerType.budget,
          ),
        ],
        transactions: [
          MoneyTransaction(
            id: 'importedtx0000001',
            postedAt: DateTime.utc(2021, 1, 1),
            effectiveDate: CalendarDate(2021, 1, 1),
            kind: TransactionKind.income,
            legOut: TransactionLeg(
              containerId: externalHolderContainerId,
              assetId: eur.id,
              quantity: Decimal.parse('100'),
            ),
            legIn: TransactionLeg(
              containerId: bankId,
              assetId: eur.id,
              quantity: Decimal.parse('100'),
            ),
            budgetLegOut: TransactionLeg(
              containerId: externalBudgetContainerId,
              assetId: eur.id,
              quantity: Decimal.parse('100'),
            ),
            budgetLegIn: TransactionLeg(
              containerId: budgetId,
              assetId: eur.id,
              quantity: Decimal.parse('100'),
            ),
          ),
          MoneyTransaction(
            id: 'importedtx0000002',
            postedAt: DateTime.utc(2021, 1, 2),
            effectiveDate: CalendarDate(2021, 1, 2),
            kind: TransactionKind.expense,
            legOut: TransactionLeg(
              containerId: bankId,
              assetId: eur.id,
              quantity: Decimal.parse('30'),
            ),
            legIn: TransactionLeg(
              containerId: externalHolderContainerId,
              assetId: eur.id,
              quantity: Decimal.parse('30'),
            ),
            budgetLegOut: TransactionLeg(
              containerId: budgetId,
              assetId: eur.id,
              quantity: Decimal.parse('30'),
            ),
            budgetLegIn: TransactionLeg(
              containerId: externalBudgetContainerId,
              assetId: eur.id,
              quantity: Decimal.parse('30'),
            ),
          ),
        ],
        onProgress: (done, total) => progressCalls.add([done, total]),
      );

      final containerRows = await (cacheDb.select(
        cacheDb.containers,
      )..where((t) => t.id.isIn([bankId, budgetId]))).get();
      expect(containerRows, hasLength(2));

      final txRows =
          await (cacheDb.select(cacheDb.transactions)..where(
                (t) => t.id.isIn(['importedtx0000001', 'importedtx0000002']),
              ))
              .get();
      expect(txRows, hasLength(2));

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bankId, eur.id),
        equals(Decimal.parse('70')),
      );
      expect(
        await balanceEngine.currentBalance(budgetId, eur.id),
        equals(Decimal.parse('70')),
      );

      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last, equals([2, 2]));
    });

    test(
      'chunking (small chunkSize) still writes every row correctly',
      () async {
        final bankId = 'importedbank00002';
        final budgetId = 'importedbudget002';
        final transactions = [
          for (var i = 0; i < 5; i++)
            MoneyTransaction(
              id: 'importedtxchunk$i',
              postedAt: DateTime.utc(2021, 1, 1 + i),
              effectiveDate: CalendarDate(2021, 1, 1 + i),
              kind: TransactionKind.income,
              legOut: TransactionLeg(
                containerId: externalHolderContainerId,
                assetId: eur.id,
                quantity: Decimal.parse('10'),
              ),
              legIn: TransactionLeg(
                containerId: bankId,
                assetId: eur.id,
                quantity: Decimal.parse('10'),
              ),
              budgetLegOut: TransactionLeg(
                containerId: externalBudgetContainerId,
                assetId: eur.id,
                quantity: Decimal.parse('10'),
              ),
              budgetLegIn: TransactionLeg(
                containerId: budgetId,
                assetId: eur.id,
                quantity: Decimal.parse('10'),
              ),
            ),
        ];

        await repo.importResolvedTransactions(
          containersToCreate: [
            MoneyContainer(
              id: bankId,
              name: 'Chunk Bank',
              containerType: ContainerType.holder,
            ),
            MoneyContainer(
              id: budgetId,
              name: 'Chunk Budget',
              containerType: ContainerType.budget,
            ),
          ],
          transactions: transactions,
          chunkSize: 2,
        );

        final balanceEngine = BalanceEngine(cacheDb);
        expect(
          await balanceEngine.currentBalance(bankId, eur.id),
          equals(Decimal.parse('50')),
        );
      },
    );

    test('rejects an invalid transaction (e.g. wrong container type) '
        'before writing anything', () async {
      final wrongTypeContainer = 'importedbadcontnr';

      await expectLater(
        repo.importResolvedTransactions(
          containersToCreate: [
            MoneyContainer(
              id: wrongTypeContainer,
              name: 'Actually A Budget',
              containerType: ContainerType.budget,
            ),
          ],
          transactions: [
            MoneyTransaction(
              id: 'importedtxinvalid1',
              postedAt: DateTime.utc(2021, 1, 1),
              effectiveDate: CalendarDate(2021, 1, 1),
              kind: TransactionKind.holderTransfer,
              legOut: TransactionLeg(
                containerId: wrongTypeContainer,
                assetId: eur.id,
                quantity: Decimal.parse('10'),
              ),
              legIn: TransactionLeg(
                containerId: externalHolderContainerId,
                assetId: eur.id,
                quantity: Decimal.parse('10'),
              ),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('importPriceSnapshots', () {
    late domain.Asset eur;
    late domain.Asset aapl;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      aapl = await repo.createAsset(
        kind: AssetKind.stock,
        symbol: 'AAPL',
        name: 'Apple Inc.',
      );
    });

    test('writes every snapshot and reports progress', () async {
      final progressCalls = <List<int>>[];

      await repo.importPriceSnapshots(
        snapshots: [
          domain.PriceSnapshot(
            id: 'importedprice00001',
            assetId: aapl.id,
            date: DateTime.utc(2024, 1, 1),
            price: Decimal.parse('150'),
            currencyAssetId: eur.id,
            source: PriceSnapshotSource.manual,
          ),
          domain.PriceSnapshot(
            id: 'importedprice00002',
            assetId: aapl.id,
            date: DateTime.utc(2024, 2, 1),
            price: Decimal.parse('160'),
            currencyAssetId: eur.id,
            source: PriceSnapshotSource.manual,
          ),
        ],
        onProgress: (done, total) => progressCalls.add([done, total]),
      );

      final rows =
          await (cacheDb.select(cacheDb.priceSnapshots)..where(
                (t) => t.id.isIn(['importedprice00001', 'importedprice00002']),
              ))
              .get();
      expect(rows, hasLength(2));
      expect(progressCalls.last, equals([2, 2]));
    });

    test('an empty snapshot list is a no-op, not an error', () async {
      await repo.importPriceSnapshots(snapshots: const []);
    });
  });

  group('per-transaction balance cache', () {
    late domain.Asset eur;
    late MoneyContainer bank;
    late MoneyContainer budget;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      bank = await repo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      budget = await repo.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
    });

    test('a transaction caches its own post-transaction balance', () async {
      final tx = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('250'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );

      final row = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(tx.id))).getSingle();
      expect(row.legInBalanceAfter, equals('250'));
      expect(row.budgetLegInBalanceAfter, equals('250'));
    });

    test('editing an earlier transaction updates a later transaction\'s '
        'cached balance and re-stages it', () async {
      final earlier = await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('100'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
      final later = await repo.recordExpense(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('30'),
        effectiveDate: CalendarDate(2026, 1, 5),
      );

      final beforeRow = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(later.id))).getSingle();
      expect(beforeRow.legOutBalanceAfter, equals('70'));
      final beforeCiphertext = (await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals(later.id))).getSingle()).ciphertext;

      await repo.recordIncome(
        id: earlier.id,
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('600'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );

      final afterRow = await (cacheDb.select(
        cacheDb.transactions,
      )..where((t) => t.id.equals(later.id))).getSingle();
      expect(afterRow.legOutBalanceAfter, equals('570'));

      final afterCiphertext = (await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals(later.id))).getSingle()).ciphertext;
      expect(afterCiphertext, isNot(equals(beforeCiphertext)));
    });
  });

  group('multi-device sync', () {
    test('a transaction created on one device is visible on another after '
        'sync', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      await deviceA.ensureExternalContainer();
      await deviceB.ensureExternalContainer();

      final eur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final bank = await deviceA.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final budget = await deviceA.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
      await deviceA.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('1000'),
        effectiveDate: CalendarDate(2026, 1, 5),
        note: 'Salary',
      );

      expect(await cacheDb.select(cacheDb.transactions).get(), isEmpty);

      await deviceA.syncNow();
      await deviceB.syncNow();

      final bBank = await (deviceB.cacheDb.select(
        deviceB.cacheDb.containers,
      )..where((t) => t.id.equals(bank.id))).getSingle();
      expect(bBank.name, equals('Bank'));

      final bTx = await deviceB.cacheDb
          .select(deviceB.cacheDb.transactions)
          .get();
      expect(bTx, hasLength(1));
      expect(bTx.single.note, equals('Salary'));

      final bBalance = BalanceEngine(deviceB.cacheDb);
      expect(
        await bBalance.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('1000')),
      );
      expect(
        await bBalance.currentBalance(budget.id, eur.id),
        equals(Decimal.parse('1000')),
      );

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });

    test(
      'a container icon synced from one device is visible on another',
      () async {
        final sharedServer = <VaultRecordResponse>[];
        final deviceA = _buildRepository(
          AppDatabase(NativeDatabase.memory()),
          DomainCacheDatabase(NativeDatabase.memory()),
          FakeVaultApi(sharedServerRecords: sharedServer),
          dek,
        );
        final deviceB = _buildRepository(
          AppDatabase(NativeDatabase.memory()),
          DomainCacheDatabase(NativeDatabase.memory()),
          FakeVaultApi(sharedServerRecords: sharedServer),
          dek,
        );
        final bank = await deviceA.createContainer(
          name: 'Bank',
          containerType: ContainerType.holder,
          icon: 'bank:ing',
        );
        final plain = await deviceA.createContainer(
          name: 'Cash',
          containerType: ContainerType.holder,
        );
        await deviceA.syncNow();
        await deviceB.syncNow();

        bRow(String id) => (deviceB.cacheDb.select(
          deviceB.cacheDb.containers,
        )..where((t) => t.id.equals(id))).getSingle();
        expect((await bRow(bank.id)).icon, equals('bank:ing'));
        expect((await bRow(plain.id)).icon, isNull);

        await deviceA.syncDb.close();
        await deviceA.cacheDb.close();
        await deviceB.syncDb.close();
        await deviceB.cacheDb.close();
      },
    );

    test('a price snapshot created on one device is visible on another '
        'after sync', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      final eur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final aapl = await deviceA.createAsset(
        kind: AssetKind.stock,
        symbol: 'AAPL',
        name: 'Apple',
      );
      await deviceA.createPriceSnapshot(
        assetId: aapl.id,
        date: DateTime.utc(2026, 1, 5),
        price: Decimal.parse('172.34'),
        currencyAssetId: eur.id,
      );

      await deviceA.syncNow();
      await deviceB.syncNow();

      final bSnapshots = await deviceB.cacheDb
          .select(deviceB.cacheDb.priceSnapshots)
          .get();
      expect(bSnapshots, hasLength(1));
      expect(bSnapshots.single.price, equals('172.34'));
      expect(bSnapshots.single.assetId, equals(aapl.id));
      expect(bSnapshots.single.currencyAssetId, equals(eur.id));

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });

    test('a setting set on one device is visible on another after sync — '
        'both upsert the same well-known id, not a duplicate row', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      await deviceA.setSetting(SettingIds.alphavantageApiKey, 'shared-key');
      await deviceA.syncNow();
      await deviceB.syncNow();

      final bSetting = await deviceB
          .watchSetting(SettingIds.alphavantageApiKey)
          .first;
      expect(bSetting?.value, equals('shared-key'));

      final bRows = await deviceB.cacheDb
          .select(deviceB.cacheDb.settings)
          .get();
      expect(bRows, hasLength(1));

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });

    test('Asset.alphaVantageSymbol survives an encrypt/sync/decrypt round trip '
        'to another device', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      final asset = await deviceA.createAsset(
        kind: AssetKind.stock,
        symbol: 'TSCO',
        name: 'Tesco',
      );
      await deviceA.setAssetAlphaVantageSymbol(asset.id, 'TSCO.LON');
      await deviceA.syncNow();
      await deviceB.syncNow();

      final bRow = await (deviceB.cacheDb.select(
        deviceB.cacheDb.assets,
      )..where((t) => t.id.equals(asset.id))).getSingle();
      expect(bRow.alphaVantageSymbol, equals('TSCO.LON'));

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });

    test(
      'tags survive an encrypt/sync/decrypt round trip to another device',
      () async {
        final sharedServer = <VaultRecordResponse>[];
        final deviceA = _buildRepository(
          AppDatabase(NativeDatabase.memory()),
          DomainCacheDatabase(NativeDatabase.memory()),
          FakeVaultApi(sharedServerRecords: sharedServer),
          dek,
        );
        final deviceB = _buildRepository(
          AppDatabase(NativeDatabase.memory()),
          DomainCacheDatabase(NativeDatabase.memory()),
          FakeVaultApi(sharedServerRecords: sharedServer),
          dek,
        );

        await deviceA.ensureExternalContainer();
        await deviceB.ensureExternalContainer();

        final eur = await deviceA.createAsset(
          kind: AssetKind.fiat,
          symbol: 'EUR',
          name: 'Euro',
        );
        final bank = await deviceA.createContainer(
          name: 'Bank',
          containerType: ContainerType.holder,
        );
        final budget = await deviceA.createContainer(
          name: 'Groceries',
          containerType: ContainerType.budget,
        );
        await deviceA.recordIncome(
          holderId: bank.id,
          budgetId: budget.id,
          assetId: eur.id,
          quantity: Decimal.parse('1000'),
          effectiveDate: CalendarDate(2026, 1, 5),
          tags: const ['Japan trip'],
        );

        await deviceA.syncNow();
        await deviceB.syncNow();

        final bTx = await deviceB.cacheDb
            .select(deviceB.cacheDb.transactions)
            .get();
        expect(bTx, hasLength(1));
        expect(decodeTagsColumn(bTx.single.tags), equals(['Japan trip']));

        await deviceA.syncDb.close();
        await deviceA.cacheDb.close();
        await deviceB.syncDb.close();
        await deviceB.cacheDb.close();
      },
    );

    test('a fresh device that syncs an existing account before seeding a '
        'default asset does not create a duplicate EUR', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      await deviceA.ensureExternalContainer();
      final eur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      await deviceA.syncNow();

      await deviceB.ensureExternalContainer();
      await deviceB.syncNow();
      await deviceB.seedDefaultFiatAssetIfNeeded();

      final bAssets = await deviceB.cacheDb
          .select(deviceB.cacheDb.assets)
          .get();
      expect(bAssets, hasLength(1));
      expect(bAssets.single.id, equals(eur.id));

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });
  });

  group('sync status visibility', () {
    test('a genuine two-device conflict is reported as conflicted (not '
        'silently dropped), and clears once acknowledged', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      await deviceA.ensureExternalContainer();
      await deviceB.ensureExternalContainer();

      final bank = await deviceA.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      await deviceA.syncNow();
      await deviceB.syncNow();

      final bStatusesBefore = await deviceB.watchRecordStatuses().first;
      expect(bStatusesBefore[bank.id], equals(RecordSyncStatus.synced));

      await deviceA.createContainer(
        id: bank.id,
        name: 'Bank (renamed by A)',
        containerType: ContainerType.holder,
      );
      await deviceA.syncNow();

      await deviceB.createContainer(
        id: bank.id,
        name: 'Bank (renamed by B)',
        containerType: ContainerType.holder,
      );
      await deviceB.syncNow();

      final bStatusesAfterConflict = await deviceB.watchRecordStatuses().first;
      expect(
        bStatusesAfterConflict[bank.id],
        equals(RecordSyncStatus.conflicted),
      );

      final bContainer = await (deviceB.cacheDb.select(
        deviceB.cacheDb.containers,
      )..where((t) => t.id.equals(bank.id))).getSingle();
      expect(bContainer.name, equals('Bank (renamed by A)'));

      final stillConflicted = await deviceB.watchRecordStatuses().first;
      expect(stillConflicted[bank.id], equals(RecordSyncStatus.conflicted));

      await deviceB.acknowledgeConflict(bank.id);
      final bStatusesAfterAck = await deviceB.watchRecordStatuses().first;
      expect(bStatusesAfterAck[bank.id], equals(RecordSyncStatus.synced));

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });
  });

  group('recurring templates', () {
    late domain.Asset eur;
    late MoneyContainer bank;
    late MoneyContainer budget;

    setUp(() async {
      await repo.ensureExternalContainer();
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      bank = await repo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      budget = await repo.createContainer(
        name: 'Rent budget',
        containerType: ContainerType.budget,
      );
    });

    RecurrenceRule monthlyFrom(CalendarDate start) => RecurrenceRule(
      startDate: start,
      unit: RecurrenceUnit.month,
      interval: 1,
    );

    test('createRecurringExpenseTemplate stages a vault record and upserts '
        'the table', () async {
      final template = await repo.createRecurringExpenseTemplate(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('800'),
        rule: monthlyFrom(CalendarDate(2026, 1, 1)),
      );

      final row = await (cacheDb.select(
        cacheDb.recurringTransactionTemplates,
      )..where((t) => t.id.equals(template.id))).getSingle();
      expect(row.kind, equals('expense'));
      expect(row.legOutContainerId, equals(bank.id));
      expect(row.budgetLegOutContainerId, equals(budget.id));
      expect(row.legOutQuantity, equals('800'));
      expect(row.active, isTrue);
      expect(row.lastGeneratedOccurrenceDate, isNull);

      final staged = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals(template.id))).getSingle();
      expect(
        staged.type,
        equals(VaultRecordTypes.recurringTransactionTemplate),
      );
    });

    test(
      'createRecurringHolderTransferTemplate rejects a budget container '
      'passed as a holder — same validation switch as a real transaction',
      () async {
        expect(
          () => repo.createRecurringHolderTransferTemplate(
            fromHolderId: budget.id,
            toHolderId: bank.id,
            assetId: eur.id,
            quantity: Decimal.parse('1'),
            rule: monthlyFrom(CalendarDate(2026, 1, 1)),
          ),
          throwsArgumentError,
        );
      },
    );

    test('dueRecurringOccurrences expands every missed monthly occurrence up '
        'to asOf', () async {
      await repo.createRecurringExpenseTemplate(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('800'),
        rule: monthlyFrom(CalendarDate(2026, 1, 1)),
      );

      final due = await repo.dueRecurringOccurrences(
        asOf: CalendarDate(2026, 3, 15),
      );
      expect(
        due.map((o) => o.occurrenceDate),
        equals([
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 2, 1),
          CalendarDate(2026, 3, 1),
        ]),
      );
    });

    test('applyDueRecurringOccurrences posts real transactions and advances '
        'the cursor; a second call with nothing new due is a no-op', () async {
      final template = await repo.createRecurringExpenseTemplate(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('800'),
        rule: monthlyFrom(CalendarDate(2026, 1, 1)),
      );

      final asOf = CalendarDate(2026, 3, 15);
      final due = await repo.dueRecurringOccurrences(asOf: asOf);
      expect(due, hasLength(3));

      await repo.applyDueRecurringOccurrences(due);

      final txRows = await cacheDb.select(cacheDb.transactions).get();
      expect(txRows, hasLength(3));
      expect(
        txRows.map((r) => r.effectiveDate).toSet(),
        equals({
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 2, 1),
          CalendarDate(2026, 3, 1),
        }),
      );

      final balanceEngine = BalanceEngine(cacheDb);
      expect(
        await balanceEngine.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('-2400')),
      );

      final row = await (cacheDb.select(
        cacheDb.recurringTransactionTemplates,
      )..where((t) => t.id.equals(template.id))).getSingle();
      expect(row.lastGeneratedOccurrenceDate, equals(CalendarDate(2026, 3, 1)));

      final dueAgain = await repo.dueRecurringOccurrences(asOf: asOf);
      expect(dueAgain, isEmpty);
      await repo.applyDueRecurringOccurrences(dueAgain);
      final txRowsAfter = await cacheDb.select(cacheDb.transactions).get();
      expect(txRowsAfter, hasLength(3));
    });

    test('a paused template generates no due occurrences', () async {
      final template = await repo.createRecurringExpenseTemplate(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('800'),
        rule: monthlyFrom(CalendarDate(2026, 1, 1)),
      );
      await repo.setRecurringTemplateActive(template.id, false);

      final due = await repo.dueRecurringOccurrences(
        asOf: CalendarDate(2026, 3, 15),
      );
      expect(due, isEmpty);

      final row = await (cacheDb.select(
        cacheDb.recurringTransactionTemplates,
      )..where((t) => t.id.equals(template.id))).getSingle();
      expect(row.active, isFalse);
    });

    test('deleteRecurringTemplate soft-deletes: hidden from watch, no more '
        'due occurrences', () async {
      final template = await repo.createRecurringExpenseTemplate(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('800'),
        rule: monthlyFrom(CalendarDate(2026, 1, 1)),
      );

      await repo.deleteRecurringTemplate(template.id);

      final visible = await repo.watchRecurringTemplates().first;
      expect(visible, isEmpty);

      final due = await repo.dueRecurringOccurrences(
        asOf: CalendarDate(2026, 3, 15),
      );
      expect(due, isEmpty);
    });

    test('a recurring template record syncs to a second device', () async {
      final sharedServer = <VaultRecordResponse>[];
      final deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      final deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );

      await deviceA.ensureExternalContainer();
      await deviceB.ensureExternalContainer();

      final aBank = await deviceA.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final aBudget = await deviceA.createContainer(
        name: 'Rent',
        containerType: ContainerType.budget,
      );
      final aEur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      await deviceA.syncNow();
      await deviceB.syncNow();

      await deviceA.createRecurringExpenseTemplate(
        holderId: aBank.id,
        budgetId: aBudget.id,
        assetId: aEur.id,
        quantity: Decimal.parse('800'),
        rule: monthlyFrom(CalendarDate(2026, 1, 1)),
      );
      await deviceA.syncNow();
      await deviceB.syncNow();

      final bRows = await deviceB.cacheDb
          .select(deviceB.cacheDb.recurringTransactionTemplates)
          .get();
      expect(bRows, hasLength(1));
      expect(bRows.single.legOutContainerId, equals(aBank.id));

      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });
  });

  group('applying a large pull (perf/correctness regression)', () {
    late DomainRepository deviceA;
    late DomainRepository deviceB;

    setUp(() async {
      final sharedServer = <VaultRecordResponse>[];
      deviceA = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      deviceB = _buildRepository(
        AppDatabase(NativeDatabase.memory()),
        DomainCacheDatabase(NativeDatabase.memory()),
        FakeVaultApi(sharedServerRecords: sharedServer),
        dek,
      );
      await deviceA.ensureExternalContainer();
      await deviceB.ensureExternalContainer();
    });

    tearDown(() async {
      await deviceA.syncDb.close();
      await deviceA.cacheDb.close();
      await deviceB.syncDb.close();
      await deviceB.cacheDb.close();
    });

    test('pulling a batch of records emits watchTransactions() once for the '
        'whole batch, not once per record', () async {
      final eur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final bank = await deviceA.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final budget = await deviceA.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
      for (var i = 0; i < 20; i++) {
        await deviceA.recordIncome(
          holderId: bank.id,
          budgetId: budget.id,
          assetId: eur.id,
          quantity: Decimal.parse('10'),
          effectiveDate: CalendarDate(2026, 1, 1 + i),
        );
      }
      await deviceA.syncNow();

      final emissions = <int>[];
      final sub = deviceB.watchTransactions().listen(
        (rows) => emissions.add(rows.length),
      );
      await pumpEventQueue();
      final countBeforeSync = emissions.length;

      await deviceB.syncNow();
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length - countBeforeSync, equals(1));
      expect(emissions.last, equals(20));
    });

    test('balances/checkpoints after a batched pull are identical to '
        'applying the same transactions one at a time', () async {
      final eur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final bank = await deviceA.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final rent = await deviceA.createContainer(
        name: 'Rent',
        containerType: ContainerType.budget,
      );
      final groceries = await deviceA.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );

      await deviceA.recordIncome(
        holderId: bank.id,
        budgetId: rent.id,
        assetId: eur.id,
        quantity: Decimal.parse('500'),
        effectiveDate: CalendarDate(2026, 3, 1),
      );
      await deviceA.recordExpense(
        holderId: bank.id,
        budgetId: groceries.id,
        assetId: eur.id,
        quantity: Decimal.parse('50'),
        effectiveDate: CalendarDate(2026, 1, 10),
      );
      await deviceA.recordIncome(
        holderId: bank.id,
        budgetId: groceries.id,
        assetId: eur.id,
        quantity: Decimal.parse('200'),
        effectiveDate: CalendarDate(2026, 2, 15),
      );
      await deviceA.recordExpense(
        holderId: bank.id,
        budgetId: rent.id,
        assetId: eur.id,
        quantity: Decimal.parse('300'),
        effectiveDate: CalendarDate(2026, 1, 5),
      );

      await deviceA.syncNow();
      await deviceB.syncNow();

      final bBalance = BalanceEngine(deviceB.cacheDb);
      expect(
        await bBalance.currentBalance(bank.id, eur.id),
        equals(Decimal.parse('350')),
      );
      expect(
        await bBalance.currentBalance(rent.id, eur.id),
        equals(Decimal.parse('200')),
      );
      expect(
        await bBalance.currentBalance(groceries.id, eur.id),
        equals(Decimal.parse('150')),
      );

      final aBalance = BalanceEngine(deviceA.cacheDb);
      expect(
        await bBalance.currentBalance(bank.id, eur.id),
        equals(await aBalance.currentBalance(bank.id, eur.id)),
      );
      expect(
        await bBalance.currentBalance(rent.id, eur.id),
        equals(await aBalance.currentBalance(rent.id, eur.id)),
      );
      expect(
        await bBalance.currentBalance(groceries.id, eur.id),
        equals(await aBalance.currentBalance(groceries.id, eur.id)),
      );
    });

    test('records applied via a batched pull are never left dirty (must '
        'never be re-pushed)', () async {
      final eur = await deviceA.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final bank = await deviceA.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final budget = await deviceA.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
      final tx = await deviceA.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('10'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
      await deviceA.syncNow();

      await deviceB.syncNow();

      final statuses = await deviceB.watchRecordStatuses().first;
      expect(statuses[tx.id], equals(RecordSyncStatus.synced));

      final row = await (deviceB.syncDb.select(
        deviceB.syncDb.localVaultRecords,
      )..where((t) => t.id.equals(tx.id))).getSingle();
      expect(row.dirty, isFalse);
    });
  });

  group('restaging a cascading local edit (perf regression)', () {
    test('a backdated create that shifts many later transactions\' cached '
        'balances restages them via one syncDb commit, not one per '
        'touched record', () async {
      final offlineDb = AppDatabase(NativeDatabase.memory());
      final offlineCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final offlineRepo = _buildRepository(
        offlineDb,
        offlineCacheDb,
        _OfflineVaultApi(),
        dek,
      );
      await offlineRepo.ensureExternalContainer();

      final eur = await offlineRepo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final bank = await offlineRepo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final budget = await offlineRepo.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );

      for (var i = 0; i < 10; i++) {
        await offlineRepo.recordIncome(
          holderId: bank.id,
          budgetId: budget.id,
          assetId: eur.id,
          quantity: Decimal.parse('10'),
          effectiveDate: CalendarDate(2026, 2, 1 + i),
        );
      }

      final emissions = <int>[];
      final sub = offlineRepo.watchRecordStatuses().listen(
        (s) => emissions.add(s.length),
      );
      await pumpEventQueue();
      final countBefore = emissions.length;

      await offlineRepo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('5'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length - countBefore, equals(2));

      await offlineDb.close();
      await offlineCacheDb.close();
    });
  });

  group('offline-only vault (canSync false)', () {
    late _CountingVaultApi api;
    late DomainRepository offlineRepo;

    setUp(() {
      api = _CountingVaultApi();
      offlineRepo = _buildRepository(
        db,
        cacheDb,
        api,
        dek,
        canSync: () => false,
      );
    });

    test(
      'syncNow never contacts the server and reports nothing pulled',
      () async {
        final result = await offlineRepo.syncNow();

        expect(api.calls, 0);
        expect(result.recordsApplied, 0);
        expect(result.conflicts, isEmpty);
      },
    );

    test('a local write stays dirty and triggers no server call', () async {
      await offlineRepo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      await Future<void>.delayed(Duration.zero);

      expect(api.calls, 0);
      final rows = await db.select(db.localVaultRecords).get();
      expect(rows, isNotEmpty);
      expect(rows.every((r) => r.dirty), isTrue);
    });

    test('force: true still syncs, for the attach-to-account flow', () async {
      await offlineRepo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      await offlineRepo.syncNow(force: true);

      expect(api.calls, greaterThan(0));
      final rows = await db.select(db.localVaultRecords).get();
      expect(rows.every((r) => !r.dirty), isTrue);
    });
  });

  group('backup', () {
    late domain.Asset eur;
    late MoneyContainer bank;
    late MoneyContainer budget;

    setUp(() async {
      eur = await repo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      bank = await repo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      budget = await repo.createContainer(
        name: 'Groceries',
        containerType: ContainerType.budget,
      );
      await repo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('100'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );
      await repo.setSetting(SettingIds.alphavantageApiKey, 'my-api-key');
    });

    test(
      'buildBackupPayload excludes the external sentinel containers',
      () async {
        final payload = await repo.buildBackupPayload();
        final containerIds = payload.entities
            .where((e) => e.type == VaultRecordTypes.container)
            .map((e) => e.id);
        expect(containerIds, isNot(contains(externalHolderContainerId)));
        expect(containerIds, isNot(contains(externalBudgetContainerId)));
        expect(containerIds, containsAll([bank.id, budget.id]));
      },
    );

    test('buildBackupPayload includes settings', () async {
      final payload = await repo.buildBackupPayload();
      final setting = payload.entities.singleWhere(
        (e) => e.type == VaultRecordTypes.setting,
      );
      expect(setting.id, equals(SettingIds.alphavantageApiKey));
      expect(setting.data['value'], equals('my-api-key'));
    });

    test('restoreBackup into a fresh vault recreates all entities with the '
        'same ids and valid cross-references', () async {
      final payload = await repo.buildBackupPayload();

      final freshDb = AppDatabase(NativeDatabase.memory());
      final freshCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final freshRepo = _buildRepository(
        freshDb,
        freshCacheDb,
        _OfflineVaultApi(),
        VaultCrypto.generateDek(),
      );
      await freshRepo.initializeAfterUnlock();

      var lastDone = 0;
      var lastTotal = 0;
      await freshRepo.restoreBackup(
        payload,
        onProgress: (done, total) {
          lastDone = done;
          lastTotal = total;
        },
      );
      expect(lastDone, equals(lastTotal));
      expect(lastTotal, equals(payload.entities.length));

      final restoredAssets = await freshCacheDb
          .select(freshCacheDb.assets)
          .get();
      expect(restoredAssets.map((a) => a.id), contains(eur.id));

      final restoredContainers = await (freshCacheDb.select(
        freshCacheDb.containers,
      )..where((t) => t.id.isIn([bank.id, budget.id]))).get();
      expect(restoredContainers, hasLength(2));

      final restoredTx = await freshCacheDb
          .select(freshCacheDb.transactions)
          .get();
      expect(restoredTx, hasLength(1));
      expect(restoredTx.single.legInContainerId, equals(bank.id));
      expect(restoredTx.single.legInAssetId, equals(eur.id));
      expect(restoredTx.single.budgetLegInContainerId, equals(budget.id));

      final restoredSetting = await freshRepo
          .watchSetting(SettingIds.alphavantageApiKey)
          .first;
      expect(restoredSetting?.value, equals('my-api-key'));

      await freshDb.close();
      await freshCacheDb.close();
    });

    test('a container icon survives backup export and restore', () async {
      final iconic = await repo.createContainer(
        name: 'Broker',
        containerType: ContainerType.holder,
        icon: 'fa:solidHouse',
      );
      final payload = await repo.buildBackupPayload();

      final freshDb = AppDatabase(NativeDatabase.memory());
      final freshCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final freshRepo = _buildRepository(
        freshDb,
        freshCacheDb,
        _OfflineVaultApi(),
        VaultCrypto.generateDek(),
      );
      await freshRepo.initializeAfterUnlock();
      await freshRepo.restoreBackup(payload);

      final restored = await (freshCacheDb.select(
        freshCacheDb.containers,
      )..where((t) => t.id.equals(iconic.id))).getSingle();
      expect(restored.icon, equals('fa:solidHouse'));
      final plain = await (freshCacheDb.select(
        freshCacheDb.containers,
      )..where((t) => t.id.equals(bank.id))).getSingle();
      expect(plain.icon, isNull);

      await freshDb.close();
      await freshCacheDb.close();
    });

    test('restoreBackup refuses (VaultNotEmptyException) when the vault '
        'already has real data, leaving it untouched', () async {
      final payload = await repo.buildBackupPayload();

      final otherDb = AppDatabase(NativeDatabase.memory());
      final otherCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final otherRepo = _buildRepository(
        otherDb,
        otherCacheDb,
        _OfflineVaultApi(),
        VaultCrypto.generateDek(),
      );
      await otherRepo.initializeAfterUnlock();
      await otherRepo.seedDefaultFiatAssetIfNeeded();
      await otherRepo.createAsset(
        kind: AssetKind.stock,
        symbol: 'AAPL',
        name: 'Apple',
      );

      await expectLater(
        () => otherRepo.restoreBackup(payload),
        throwsA(isA<VaultNotEmptyException>()),
      );

      final assetsAfter = await otherCacheDb.select(otherCacheDb.assets).get();
      expect(assetsAfter, hasLength(2));
      final containersAfter = await otherCacheDb
          .select(otherCacheDb.containers)
          .get();
      expect(containersAfter, hasLength(2));

      await otherDb.close();
      await otherCacheDb.close();
    });

    test('restoreBackup tolerates the single auto-seeded default asset (not '
        'user data) in an otherwise-empty vault', () async {
      final payload = await repo.buildBackupPayload();

      final freshDb = AppDatabase(NativeDatabase.memory());
      final freshCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final freshRepo = _buildRepository(
        freshDb,
        freshCacheDb,
        _OfflineVaultApi(),
        VaultCrypto.generateDek(),
      );
      await freshRepo.initializeAfterUnlock();
      await freshRepo.seedDefaultFiatAssetIfNeeded();

      await freshRepo.restoreBackup(payload);

      final restoredTx = await freshCacheDb
          .select(freshCacheDb.transactions)
          .get();
      expect(restoredTx, hasLength(1));

      await freshDb.close();
      await freshCacheDb.close();
    });

    test('a setting already present in an otherwise-empty vault does not '
        'block restoreBackup (settings are excluded from the emptiness '
        'check)', () async {
      final payload = await repo.buildBackupPayload();

      final freshDb = AppDatabase(NativeDatabase.memory());
      final freshCacheDb = DomainCacheDatabase(NativeDatabase.memory());
      final freshRepo = _buildRepository(
        freshDb,
        freshCacheDb,
        _OfflineVaultApi(),
        VaultCrypto.generateDek(),
      );
      await freshRepo.initializeAfterUnlock();
      await freshRepo.setSetting(SettingIds.alphavantageApiKey, 'pre-existing');

      await freshRepo.restoreBackup(payload);

      final restoredTx = await freshCacheDb
          .select(freshCacheDb.transactions)
          .get();
      expect(restoredTx, hasLength(1));

      await freshDb.close();
      await freshCacheDb.close();
    });
  });

  group('cold rebuild restages stale cached balanceAfter', () {
    test('a record whose synced balanceAfter disagrees with the recomputed '
        'value is re-staged; a second rebuild restages nothing', () async {
      final syncDb = AppDatabase(NativeDatabase.memory());
      final firstCache = DomainCacheDatabase(NativeDatabase.memory());
      final offlineRepo = _buildRepository(
        syncDb,
        firstCache,
        _OfflineVaultApi(),
        dek,
      );
      await offlineRepo.ensureExternalContainer();
      final eur = await offlineRepo.createAsset(
        kind: AssetKind.fiat,
        symbol: 'EUR',
        name: 'Euro',
      );
      final bank = await offlineRepo.createContainer(
        name: 'Bank',
        containerType: ContainerType.holder,
      );
      final budget = await offlineRepo.createContainer(
        name: 'Food',
        containerType: ContainerType.budget,
      );
      await offlineRepo.recordIncome(
        holderId: bank.id,
        budgetId: budget.id,
        assetId: eur.id,
        quantity: Decimal.parse('100'),
        effectiveDate: CalendarDate(2026, 1, 1),
      );

      final txRecord =
          (await (syncDb.select(syncDb.localVaultRecords)
                    ..where((r) => r.type.equals(VaultRecordTypes.transaction)))
                  .get())
              .single;
      final json =
          jsonDecode(
                utf8.decode(
                  await VaultCrypto.decryptRecord(
                    dek: dek,
                    recordId: txRecord.id,
                    type: txRecord.type,
                    ciphertext: txRecord.ciphertext,
                    nonce: txRecord.nonce,
                  ),
                ),
              )
              as Map<String, dynamic>;
      (json['legIn'] as Map<String, dynamic>)['balanceAfter'] = '999';
      final stale = await VaultCrypto.encryptRecord(
        dek: dek,
        recordId: txRecord.id,
        type: txRecord.type,
        plaintext: Uint8List.fromList(utf8.encode(jsonEncode(json))),
      );
      Future<void> markClean() =>
          (syncDb.update(
            syncDb.localVaultRecords,
          )..where((r) => r.id.equals(txRecord.id))).write(
            LocalVaultRecordsCompanion(
              ciphertext: Value(stale.ciphertext),
              nonce: Value(stale.nonce),
              dirty: const Value(false),
            ),
          );
      await markClean();

      Future<bool> dirtyAfterColdRebuild() async {
        final cache = DomainCacheDatabase(NativeDatabase.memory());
        final repo2 = _buildRepository(syncDb, cache, _OfflineVaultApi(), dek);
        await repo2.ensureExternalContainer();
        await repo2.applyAllLocalVaultRecords();
        await cache.close();
        return (await (syncDb.select(
          syncDb.localVaultRecords,
        )..where((r) => r.id.equals(txRecord.id))).getSingle()).dirty;
      }

      expect(
        await dirtyAfterColdRebuild(),
        isTrue,
        reason: 'stale cached balanceAfter must be re-pushed',
      );

      await (syncDb.update(syncDb.localVaultRecords)
            ..where((r) => r.id.equals(txRecord.id)))
          .write(const LocalVaultRecordsCompanion(dirty: Value(false)));
      expect(
        await dirtyAfterColdRebuild(),
        isFalse,
        reason: 'an up-to-date cache must not be re-pushed',
      );

      await firstCache.close();
      await syncDb.close();
    });
  });
}
