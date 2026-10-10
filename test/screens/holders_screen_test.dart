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
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/date_time_format_prefs.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/screens/holders_screen.dart';
import 'package:moopro/sync/sync_engine.dart';

import '../domain/balance_chart_rows.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ldb.Container> containers = [];
  List<ldb.Asset> assets = [];
  List<ldb.Transaction> transactions = [];
  List<ldb.PriceSnapshot> priceSnapshots = [];
  List<ldb.RecurringTransactionTemplate> templates = [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Stream<List<ldb.Transaction>> watchTransactions() =>
      Stream.value(transactions);

  @override
  Stream<List<ldb.PriceSnapshot>> watchPriceSnapshots() =>
      Stream.value(priceSnapshots);

  @override
  Stream<List<ldb.RecurringTransactionTemplate>> watchRecurringTemplates() =>
      Stream.value(templates);

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      Stream.value(const {});

  @override
  Stream<SyncCounts> watchSyncCounts() =>
      Stream.value(const SyncCounts(pending: 0, conflicted: 0));

  String? defaultCurrencyAssetId;

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(
    defaultCurrencyAssetId == null
        ? null
        : ldb.Setting(id: id, value: defaultCurrencyAssetId!, deleted: false),
  );
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

const _eurId = 'eur00000000000';
const _btcId = 'btc00000000000';

void main() {
  late AppDatabase syncDb;
  late ldb.DomainCacheDatabase cacheDb;
  late _FakeDomainRepository repo;
  late BalanceEngine balanceEngine;

  setUp(() {
    syncDb = AppDatabase(NativeDatabase.memory());
    cacheDb = ldb.DomainCacheDatabase(NativeDatabase.memory());
    balanceEngine = BalanceEngine(cacheDb);
    repo = _FakeDomainRepository(
      syncDb: syncDb,
      cacheDb: cacheDb,
      syncEngine: SyncEngine(db: syncDb, vaultApi: _VaultApiStub()),
      balanceEngine: balanceEngine,
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  final day = CalendarDate(2025, 1, 1);
  var seq = 0;
  void hold(String container, String asset, String qty) {
    repo.transactions = [
      ...repo.transactions,
      incomeRow(
        'tx${seq++}',
        day,
        holder: container,
        asset: asset,
        amount: qty,
        holderAfter: qty,
      ),
    ];
  }

  void price(String asset, String value) {
    repo.priceSnapshots = [
      ...repo.priceSnapshots,
      for (final a in repo.assets)
        if (a.id != asset) priceRow(asset, day, value, currency: a.id),
    ];
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: HoldersScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the net-worth hero sums every holder\'s multi-asset '
      'converted total, not just one asset', (tester) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: _btcId,
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'bank',
        name: 'Bank',
        containerType: 'holder',
        deleted: false,
      ),
      ldb.Container(
        id: 'wallet',
        name: 'Wallet',
        containerType: 'holder',
        deleted: false,
      ),
    ];
    hold('bank', _eurId, '1000');
    hold('wallet', _btcId, '0.1');
    price(_btcId, '60000');

    await pump(tester);

    expect(find.textContaining('6000.00'), findsWidgets);
  });

  testWidgets(
    'the persisted default-currency setting wins over "first asset in '
    'the vault" when set',
    (tester) async {
      repo.assets = const [
        ldb.Asset(
          id: _btcId,
          kind: 'crypto',
          symbol: 'BTC',
          name: 'Bitcoin',
          deleted: false,
        ),
        ldb.Asset(
          id: _eurId,
          kind: 'fiat',
          symbol: 'EUR',
          name: 'Euro',
          deleted: false,
        ),
      ];
      repo.containers = const [
        ldb.Container(
          id: 'wallet',
          name: 'Wallet',
          containerType: 'holder',
          deleted: false,
        ),
      ];
      hold('wallet', _btcId, '0.1');
      price(_btcId, '60000');
      repo.defaultCurrencyAssetId = _eurId;

      await pump(tester);

      expect(find.textContaining('6000.00'), findsWidgets);
      expect(find.textContaining('Convert to BTC'), findsNothing);
    },
  );

  testWidgets('filtering to an asset kind sums converted values of every '
      'matching asset, excluding holders with none of that kind', (
    tester,
  ) async {
    const aaplId = 'aapl0000000000';
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: aaplId,
        kind: 'stock',
        symbol: 'AAPL',
        name: 'Apple',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'broker',
        name: 'Broker',
        containerType: 'holder',
        deleted: false,
      ),
      ldb.Container(
        id: 'bank',
        name: 'Bank',
        containerType: 'holder',
        deleted: false,
      ),
    ];
    hold('broker', aaplId, '10');
    hold('bank', _eurId, '500');
    price(aaplId, '170');

    await pump(tester);

    await tester.tap(find.text('All assets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Type: Stock'));
    await tester.pumpAndSettle();

    expect(find.text('Type: Stock'), findsOneWidget);
    expect(find.textContaining('1700.00'), findsWidgets);
  });

  testWidgets('an asset with no known price is surfaced in the "Actual '
      'assets held" panel rather than silently excluded from net worth', (
    tester,
  ) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: _btcId,
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'wallet',
        name: 'Wallet',
        containerType: 'holder',
        deleted: false,
      ),
    ];
    hold('wallet', _btcId, '0.5');

    await pump(tester);

    expect(find.text('ACTUAL ASSETS HELD'), findsOneWidget);
    expect(find.text('no known price'), findsOneWidget);
  });

  testWidgets('selecting a holder focuses the page on it without collapsing '
      'the flat pie', (tester) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'bank',
        name: 'Bank',
        containerType: 'holder',
        deleted: false,
      ),
      ldb.Container(
        id: 'cash',
        name: 'Cash',
        containerType: 'holder',
        deleted: false,
      ),
    ];
    hold('bank', _eurId, '900');
    hold('cash', _eurId, '100');
    await pump(tester);

    expect(find.text('Total on ${_todayText()}'), findsOneWidget);

    final card = find.textContaining('Cash ·');
    await tester.ensureVisible(card.first);
    await tester.pump();
    await tester.tap(card.first);
    await tester.pumpAndSettle();

    expect(find.text('Balance over time · Cash'), findsNothing);
    expect(find.text('Total on ${_todayText()}'), findsOneWidget);
    expect(find.byKey(const ValueKey('focusBack')), findsOneWidget);
    expect(find.byKey(const ValueKey('editFocusedContainer')), findsOneWidget);
    expect(find.textContaining('Total:'), findsOneWidget);
    expect(find.textContaining('Bank'), findsWidgets);
    expect(find.text('ACTUAL ASSETS HELD'), findsOneWidget);
    expect(find.textContaining('EUR — 100.00'), findsOneWidget);
  });
}

String _todayText() =>
    DateTimeFormatPrefs.defaults.formatCalendarDate(CalendarDate.today());
