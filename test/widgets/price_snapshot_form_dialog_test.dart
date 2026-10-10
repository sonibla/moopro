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
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/widgets/price_snapshot_form_dialog.dart';

class _FakeDomainRepository extends DomainRepository {
  ({
    String? id,
    String assetId,
    DateTime date,
    Decimal price,
    String currencyAssetId,
    PriceSnapshotSource source,
  })?
  createCall;

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(null);

  @override
  Future<PriceSnapshot> createPriceSnapshot({
    String? id,
    required String assetId,
    required DateTime date,
    required Decimal price,
    required String currencyAssetId,
    PriceSnapshotSource source = PriceSnapshotSource.manual,
  }) async {
    createCall = (
      id: id,
      assetId: assetId,
      date: date,
      price: price,
      currencyAssetId: currencyAssetId,
      source: source,
    );
    return PriceSnapshot(
      id: id ?? 'new-snapshot',
      assetId: assetId,
      date: date,
      price: price,
      currencyAssetId: currencyAssetId,
      source: source,
    );
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

const _aaplId = 'aapl0000000000';
const _eurId = 'eur00000000000';
const _usdId = 'usd00000000000';

void main() {
  late AppDatabase syncDb;
  late ldb.DomainCacheDatabase cacheDb;
  late _FakeDomainRepository repo;

  const aapl = ldb.Asset(
    id: _aaplId,
    kind: 'stock',
    symbol: 'AAPL',
    name: 'Apple',
    deleted: false,
  );
  const eur = ldb.Asset(
    id: _eurId,
    kind: 'fiat',
    symbol: 'EUR',
    name: 'Euro',
    deleted: false,
  );
  const usd = ldb.Asset(
    id: _usdId,
    kind: 'fiat',
    symbol: 'USD',
    name: 'US Dollar',
    deleted: false,
  );

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

  Future<void> pump(
    WidgetTester tester, {
    required List<ldb.Asset> otherAssets,
    ldb.PriceSnapshot? existing,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => PriceSnapshotFormDialog(
                      asset: aapl,
                      otherAssets: otherAssets,
                      existing: existing,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Date/Price/"Priced in" fields, defaulting to the first '
      'other asset', (tester) async {
    await pump(tester, otherAssets: [eur, usd]);
    expect(find.text('New price for AAPL'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
    expect(find.text('Priced in'), findsOneWidget);
    expect(find.text('EUR — Euro'), findsOneWidget);
  });

  testWidgets('Save is a no-op with an unparseable price', (tester) async {
    await pump(tester, otherAssets: [eur]);
    await tester.enterText(
      find.widgetWithText(TextField, 'Price'),
      'not a number',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repo.createCall, isNull);
    expect(find.byType(PriceSnapshotFormDialog), findsOneWidget);
  });

  testWidgets('filling in a price and saving calls createPriceSnapshot with '
      'the entered price/date and the selected currency, then closes', (
    tester,
  ) async {
    await pump(tester, otherAssets: [eur, usd]);

    await tester.enterText(find.widgetWithText(TextField, 'Price'), '172.34');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD — US Dollar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.createCall?.assetId, equals(_aaplId));
    expect(repo.createCall?.price, equals(Decimal.parse('172.34')));
    expect(repo.createCall?.currencyAssetId, equals(_usdId));
    expect(find.byType(PriceSnapshotFormDialog), findsNothing);
  });

  group('edit mode', () {
    final existingManual = ldb.PriceSnapshot(
      id: 'snap-1',
      assetId: _aaplId,
      date: DateTime.utc(2026, 1, 1),
      price: '170.00',
      currencyAssetId: _eurId,
      source: 'manual',
      deleted: false,
    );
    final existingFetched = ldb.PriceSnapshot(
      id: 'snap-2',
      assetId: _aaplId,
      date: DateTime.utc(2026, 1, 1),
      price: '170.00',
      currencyAssetId: _eurId,
      source: 'fetched',
      deleted: false,
    );

    testWidgets('title is "Edit price for AAPL" and fields are prefilled', (
      tester,
    ) async {
      await pump(tester, otherAssets: [eur, usd], existing: existingManual);
      expect(find.text('Edit price for AAPL'), findsOneWidget);
      expect(find.widgetWithText(TextField, '170.00'), findsOneWidget);
      expect(find.text('EUR — Euro'), findsOneWidget);
    });

    testWidgets('saving passes the existing id through', (tester) async {
      await pump(tester, otherAssets: [eur, usd], existing: existingManual);
      await tester.enterText(
        find.widgetWithText(TextField, '170.00'),
        '175.00',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.createCall?.id, equals('snap-1'));
      expect(repo.createCall?.price, equals(Decimal.parse('175.00')));
    });

    testWidgets('editing a fetched snapshot does not downgrade its source '
        'to manual', (tester) async {
      await pump(tester, otherAssets: [eur, usd], existing: existingFetched);
      await tester.enterText(
        find.widgetWithText(TextField, '170.00'),
        '175.00',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.createCall?.source, equals(PriceSnapshotSource.fetched));
    });
  });

  group('unsaved changes confirmation', () {
    testWidgets(
      'tapping outside the dialog barrier with unsaved changes prompts '
      'instead of closing immediately',
      (tester) async {
        await pump(tester, otherAssets: [eur, usd]);

        await tester.enterText(
          find.widgetWithText(TextField, 'Price'),
          '172.34',
        );
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('New price for AAPL'), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
      },
    );

    testWidgets(
      "'Keep editing' dismisses the prompt and leaves the form open with "
      'the typed price intact',
      (tester) async {
        await pump(tester, otherAssets: [eur, usd]);
        await tester.enterText(
          find.widgetWithText(TextField, 'Price'),
          '172.34',
        );
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        expect(find.text('Discard changes?'), findsNothing);
        expect(find.widgetWithText(TextField, '172.34'), findsOneWidget);
      },
    );

    testWidgets("'Discard' closes both the prompt and the form", (
      tester,
    ) async {
      await pump(tester, otherAssets: [eur, usd]);
      await tester.enterText(find.widgetWithText(TextField, 'Price'), '172.34');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New price for AAPL'), findsNothing);
    });

    testWidgets(
      "the Cancel button also prompts (an explicit button's onPressed isn't "
      'gated by PopScope the way a barrier tap/Escape is)',
      (tester) async {
        await pump(tester, otherAssets: [eur, usd]);
        await tester.enterText(
          find.widgetWithText(TextField, 'Price'),
          '172.34',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('New price for AAPL'), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
      },
    );

    testWidgets('closes immediately with no unsaved changes', (tester) async {
      await pump(tester, otherAssets: [eur, usd]);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New price for AAPL'), findsNothing);
    });
  });
}
