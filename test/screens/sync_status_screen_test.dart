import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/domain/models.dart' show SettingIds;
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/screens/sync_status_screen.dart';
import 'package:moopro/sync/sync_engine.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ConflictedRecordRef> conflicted = const [];
  List<PendingRecordRef> pending = const [];
  SyncCounts counts = const SyncCounts(pending: 0, conflicted: 0);
  List<ldb.Asset> assets = const [];
  List<ldb.Container> containers = const [];
  List<ldb.Transaction> transactions = const [];
  List<ldb.PriceSnapshot> priceSnapshots = const [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Stream<List<ConflictedRecordRef>> watchConflictedRecords() =>
      Stream.value(conflicted);

  @override
  Stream<List<PendingRecordRef>> watchPendingRecords() => Stream.value(pending);

  @override
  Stream<SyncCounts> watchSyncCounts() => Stream.value(counts);

  @override
  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      Stream.value(const {});

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Transaction>> watchTransactions() =>
      Stream.value(transactions);

  @override
  Stream<List<ldb.PriceSnapshot>> watchPriceSnapshots() =>
      Stream.value(priceSnapshots);

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(null);
}

class _VaultApiStub extends VaultApi {
  _VaultApiStub() : super(ApiClient());

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async =>
      const [];

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async => const [];
}

class _FixedDekVaultSession extends VaultSessionManager {
  final Uint8List _dek;
  _FixedDekVaultSession(this._dek)
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

void main() {
  late AppDatabase syncDb;
  late ldb.DomainCacheDatabase cacheDb;
  late _FakeDomainRepository repo;

  setUp(() {
    syncDb = AppDatabase(NativeDatabase.memory());
    cacheDb = ldb.DomainCacheDatabase(NativeDatabase.memory());
    repo = _FakeDomainRepository(
      syncDb: syncDb,
      cacheDb: cacheDb,
      syncEngine: SyncEngine(db: syncDb, vaultApi: _VaultApiStub()),
      balanceEngine: BalanceEngine(cacheDb),
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          domainRepositoryProvider.overrideWithValue(repo),
          serverAvailableProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: const MaterialApp(home: SyncStatusScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows "All changes saved." when nothing is pending or '
      'conflicted', (tester) async {
    await pump(tester);

    expect(find.text('All changes saved.'), findsWidgets);
    expect(find.textContaining('Needs your attention'), findsNothing);
    expect(find.textContaining('Pending'), findsNothing);
  });

  testWidgets('lists conflicted records with a working "Review" action', (
    tester,
  ) async {
    repo.conflicted = const [ConflictedRecordRef(id: 's1', type: 'setting')];
    repo.counts = const SyncCounts(pending: 0, conflicted: 1);

    await pump(tester);

    expect(find.textContaining('Needs your attention (1)'), findsOneWidget);
    expect(find.text('Setting'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Sync conflict'), findsOneWidget);
  });

  testWidgets('lists pending records with a human label', (tester) async {
    repo.pending = const [PendingRecordRef(id: 'a1', type: 'asset')];
    repo.counts = const SyncCounts(pending: 1, conflicted: 0);
    repo.assets = [
      const ldb.Asset(
        id: 'a1',
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
    ];

    await pump(tester);

    expect(find.textContaining('Pending (1)'), findsOneWidget);
    expect(find.text('Euro (EUR)'), findsOneWidget);
  });

  testWidgets('a known setting id resolves to its human label, using the '
      'fixed SettingIds map', (tester) async {
    repo.pending = const [
      PendingRecordRef(id: SettingIds.hideAmounts, type: 'setting'),
    ];
    repo.counts = const SyncCounts(pending: 1, conflicted: 0);

    await pump(tester);

    expect(find.text('Hide amounts'), findsOneWidget);
  });
}
