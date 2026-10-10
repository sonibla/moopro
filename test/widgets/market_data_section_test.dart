import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
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
import 'package:moopro/domain/models.dart';
import 'package:moopro/market_data/alphavantage_client.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/widgets/market_data_section.dart';

class _FakeDomainRepository extends DomainRepository {
  final _controller = StreamController<ldb.Setting?>.broadcast();
  ldb.Setting? _current;
  String? lastLinkedAssetId;
  String? lastLinkedSymbol;
  final List<Map<String, Object?>> priceSnapshotCalls = [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  void seedApiKey(String? value) {
    _current = value == null
        ? null
        : ldb.Setting(
            id: SettingIds.alphavantageApiKey,
            value: value,
            deleted: false,
          );
  }

  @override
  Stream<ldb.Setting?> watchSetting(String id) async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> setAssetAlphaVantageSymbol(
    String assetId,
    String? symbol,
  ) async {
    lastLinkedAssetId = assetId;
    lastLinkedSymbol = symbol;
  }

  @override
  Future<PriceSnapshot> createPriceSnapshot({
    String? id,
    required String assetId,
    required DateTime date,
    required Decimal price,
    required String currencyAssetId,
    PriceSnapshotSource source = PriceSnapshotSource.manual,
  }) async {
    priceSnapshotCalls.add({
      'assetId': assetId,
      'date': date,
      'price': price,
      'currencyAssetId': currencyAssetId,
      'source': source,
    });
    return PriceSnapshot(
      id: id ?? 'generated',
      assetId: assetId,
      date: date,
      price: price,
      currencyAssetId: currencyAssetId,
      source: source,
    );
  }
}

class _FakeAlphaVantageClient extends AlphaVantageClient {
  AlphaVantageQuote? quote;
  AlphaVantageException? exception;
  Future<void>? gate;
  String? lastEquitySymbol;
  String? lastCryptoFrom;
  String? lastCryptoTo;

  Future<AlphaVantageQuote> _resolve() async {
    if (gate != null) await gate;
    if (exception != null) throw exception!;
    return quote!;
  }

  @override
  Future<AlphaVantageQuote> fetchEquityQuote({
    required String apiKey,
    required String symbol,
  }) {
    lastEquitySymbol = symbol;
    return _resolve();
  }

  @override
  Future<AlphaVantageQuote> fetchCryptoExchangeRate({
    required String apiKey,
    required String fromCurrency,
    required String toCurrency,
  }) {
    lastCryptoFrom = fromCurrency;
    lastCryptoTo = toCurrency;
    return _resolve();
  }
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

const _tscoId = 'tsco000000000000';
const _eurId = 'eur00000000000000';
const _btcId = 'btc00000000000000';

const _tscoLinked = ldb.Asset(
  id: _tscoId,
  kind: 'stock',
  symbol: 'TSCO',
  name: 'Tesco',
  alphaVantageSymbol: 'TSCO.LON',
  deleted: false,
);
const _tscoUnlinked = ldb.Asset(
  id: _tscoId,
  kind: 'stock',
  symbol: 'TSCO',
  name: 'Tesco',
  deleted: false,
);
const _btcUnlinked = ldb.Asset(
  id: _btcId,
  kind: 'crypto',
  symbol: 'BTC',
  name: 'Bitcoin',
  deleted: false,
);
const _eur = ldb.Asset(
  id: _eurId,
  kind: 'fiat',
  symbol: 'EUR',
  name: 'Euro',
  deleted: false,
);

void main() {
  late AppDatabase syncDb;
  late ldb.DomainCacheDatabase cacheDb;
  late _FakeDomainRepository repo;
  late _FakeAlphaVantageClient client;

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
    client = _FakeAlphaVantageClient();
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required ldb.Asset asset,
    List<ldb.Asset> otherAssets = const [_eur],
    List<ldb.PriceSnapshot> existingSnapshots = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          domainRepositoryProvider.overrideWithValue(repo),
          alphaVantageClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarketDataSection(
              asset: asset,
              otherAssets: otherAssets,
              existingSnapshots: existingSnapshots,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing for a fiat asset', (tester) async {
    await pump(tester, asset: _eur, otherAssets: const []);
    expect(find.text('AlphaVantage symbol'), findsNothing);
  });

  testWidgets('not-linked state shows "Not linked" and a Link button', (
    tester,
  ) async {
    await pump(tester, asset: _tscoUnlinked);
    expect(find.text('Not linked'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Link'), findsOneWidget);
    expect(find.text('Fetch latest price'), findsNothing);
  });

  testWidgets('linking a crypto asset via the manual-entry dialog calls '
      'setAssetAlphaVantageSymbol', (tester) async {
    await pump(tester, asset: _btcUnlinked);

    await tester.tap(find.widgetWithText(TextButton, 'Link'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'BTC');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repo.lastLinkedAssetId, equals(_btcId));
    expect(repo.lastLinkedSymbol, equals('BTC'));
  });

  testWidgets(
    'linked-but-no-api-key: fetch tile is disabled with an explanatory '
    'message',
    (tester) async {
      repo.seedApiKey(null);
      await pump(tester, asset: _tscoLinked);

      expect(find.text('TSCO.LON'), findsOneWidget);
      expect(find.text('Fetch latest price'), findsOneWidget);
      expect(
        find.text('Set your AlphaVantage API key in Settings first.'),
        findsOneWidget,
      );

      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Fetch latest price'),
      );
      expect(tile.enabled, isFalse);
    },
  );

  testWidgets('no other assets: fetch tile is disabled with a message', (
    tester,
  ) async {
    repo.seedApiKey('a-key');
    await pump(tester, asset: _tscoLinked, otherAssets: const []);

    expect(
      find.text('Create another asset to price this against first.'),
      findsOneWidget,
    );
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Fetch latest price'),
    );
    expect(tile.enabled, isFalse);
  });

  Future<void> tapFetchAndConfirmCurrency(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ListTile, 'Fetch latest price'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Fetch'));
    await tester.pump();
  }

  testWidgets('shows a loading spinner while the fetch is in flight', (
    tester,
  ) async {
    repo.seedApiKey('a-key');
    final gate = Completer<void>();
    client.gate = gate.future;
    client.quote = AlphaVantageQuote(
      symbol: 'TSCO.LON',
      price: Decimal.parse('310.5'),
      asOf: DateTime.utc(2026, 7, 24),
    );
    await pump(tester, asset: _tscoLinked);

    await tapFetchAndConfirmCurrency(tester);
    expect(find.text('Fetching…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a successful fetch creates a fetched PriceSnapshot and shows a '
      'confirmation SnackBar', (tester) async {
    repo.seedApiKey('a-key');
    client.quote = AlphaVantageQuote(
      symbol: 'TSCO.LON',
      price: Decimal.parse('310.5'),
      asOf: DateTime.utc(2026, 7, 24),
    );
    await pump(tester, asset: _tscoLinked);

    await tapFetchAndConfirmCurrency(tester);
    await tester.pumpAndSettle();

    expect(repo.priceSnapshotCalls, hasLength(1));
    final call = repo.priceSnapshotCalls.single;
    expect(call['assetId'], equals(_tscoId));
    expect(call['currencyAssetId'], equals(_eurId));
    expect(call['price'], equals(Decimal.parse('310.5')));
    expect(call['source'], equals(PriceSnapshotSource.fetched));
    expect(client.lastEquitySymbol, equals('TSCO.LON'));
    expect(find.textContaining('Fetched'), findsOneWidget);
  });

  testWidgets('a crypto fetch passes the chosen currency as to_currency', (
    tester,
  ) async {
    repo.seedApiKey('a-key');
    client.quote = AlphaVantageQuote(
      symbol: 'BTC',
      price: Decimal.parse('65000'),
      asOf: DateTime.utc(2026, 7, 24),
    );
    await pump(
      tester,
      asset: const ldb.Asset(
        id: _btcId,
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        alphaVantageSymbol: 'BTC',
        deleted: false,
      ),
    );

    await tapFetchAndConfirmCurrency(tester);
    await tester.pumpAndSettle();

    expect(client.lastCryptoFrom, equals('BTC'));
    expect(client.lastCryptoTo, equals('EUR'));
    expect(repo.priceSnapshotCalls.single['currencyAssetId'], equals(_eurId));
  });

  testWidgets('a generic (non-rate-limited) fetch error is shown inline', (
    tester,
  ) async {
    repo.seedApiKey('a-key');
    client.exception = const AlphaVantageException('Invalid API call.');
    await pump(tester, asset: _tscoLinked);

    await tapFetchAndConfirmCurrency(tester);
    await tester.pumpAndSettle();

    expect(find.text('Invalid API call.'), findsOneWidget);
    expect(repo.priceSnapshotCalls, isEmpty);
  });

  testWidgets('a rate-limited fetch error shows a distinct message', (
    tester,
  ) async {
    repo.seedApiKey('a-key');
    client.exception = const AlphaVantageException(
      'Standard API rate limit is 25 requests per day.',
      rateLimited: true,
    );
    await pump(tester, asset: _tscoLinked);

    await tapFetchAndConfirmCurrency(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('AlphaVantage daily limit reached — try again tomorrow.'),
      findsOneWidget,
    );
    expect(repo.priceSnapshotCalls, isEmpty);
  });
}
