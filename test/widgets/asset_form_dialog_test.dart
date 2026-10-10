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
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/widgets/asset_form_dialog.dart';

class _FakeDomainRepository extends DomainRepository {
  ({
    String? id,
    AssetKind kind,
    String symbol,
    String name,
    String? displaySymbol,
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
  Future<Asset> createAsset({
    String? id,
    required AssetKind kind,
    required String symbol,
    required String name,
    String? displaySymbol,
  }) async {
    createCall = (
      id: id,
      kind: kind,
      symbol: symbol,
      name: name,
      displaySymbol: displaySymbol,
    );
    return Asset(
      id: id ?? 'new-asset',
      kind: kind,
      symbol: symbol,
      name: name,
      displaySymbol: displaySymbol,
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
      syncEngine: SyncEngine(db: syncDb, vaultApi: VaultApiStub()),
      balanceEngine: BalanceEngine(cacheDb),
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  Future<void> pump(WidgetTester tester, {ldb.Asset? existing}) async {
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
                    builder: (_) => AssetFormDialog(existing: existing),
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

  testWidgets('shows Kind/Symbol/Name fields, Kind defaulting to fiat', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Kind'), findsOneWidget);
    expect(find.text('Symbol'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Fiat currency'), findsOneWidget);
  });

  testWidgets('Save is a no-op when symbol/name are empty', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repo.createCall, isNull);
    expect(find.byType(AssetFormDialog), findsOneWidget);
  });

  testWidgets('filling the form and saving calls createAsset with the '
      'selected kind/symbol/name, then closes', (tester) async {
    await pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'BTC');
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Bitcoin');
    await tester.tap(find.byType(DropdownButtonFormField<AssetKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crypto').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.createCall?.kind, equals(AssetKind.crypto));
    expect(repo.createCall?.symbol, equals('BTC'));
    expect(repo.createCall?.name, equals('Bitcoin'));
    expect(find.byType(AssetFormDialog), findsNothing);
  });

  group('edit mode', () {
    const existing = ldb.Asset(
      id: 'eur-id',
      kind: 'fiat',
      symbol: 'EUR',
      name: 'Euro',
      deleted: false,
    );

    testWidgets('title is "Edit asset" and fields are prefilled, kind shown '
        'read-only', (tester) async {
      await pump(tester, existing: existing);
      expect(find.text('Edit asset'), findsOneWidget);
      expect(find.text('Fiat currency'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<AssetKind>), findsNothing);
      expect(find.widgetWithText(TextField, 'Symbol'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('Euro'), findsOneWidget);
    });

    testWidgets('saving passes the existing id through, kind unchanged', (
      tester,
    ) async {
      await pump(tester, existing: existing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Euro (renamed)',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.createCall?.id, equals('eur-id'));
      expect(repo.createCall?.kind, equals(AssetKind.fiat));
      expect(repo.createCall?.symbol, equals('EUR'));
      expect(repo.createCall?.name, equals('Euro (renamed)'));
    });
  });

  group('display glyph', () {
    testWidgets('suggests € for a fiat asset symbol EUR, applied on tap', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'EUR');
      await tester.pump();
      expect(find.text('€'), findsOneWidget);

      await tester.tap(find.byTooltip('Use "€"'));
      await tester.pump();
      expect(find.widgetWithText(TextField, '€'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Euro');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.createCall?.displaySymbol, equals('€'));
    });

    testWidgets('no suggestion for a non-fiat kind', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(DropdownButtonFormField<AssetKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crypto').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'EUR');
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message?.startsWith('Use "') ?? false),
        ),
        findsNothing,
      );
    });

    testWidgets('an empty glyph field saves as null', (tester) async {
      await pump(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'AAA');
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Test asset',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.createCall?.displaySymbol, isNull);
    });
  });

  group('unsaved changes confirmation', () {
    testWidgets(
      'tapping outside the dialog barrier with unsaved changes prompts '
      'instead of closing immediately',
      (tester) async {
        await pump(tester);

        await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'BTC');
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('New asset'), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
      },
    );

    testWidgets(
      "'Keep editing' dismisses the prompt and leaves the form open with "
      'the typed text intact',
      (tester) async {
        await pump(tester);
        await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'BTC');
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        expect(find.text('Discard changes?'), findsNothing);
        expect(find.widgetWithText(TextField, 'BTC'), findsOneWidget);
      },
    );

    testWidgets("'Discard' closes both the prompt and the form", (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'BTC');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New asset'), findsNothing);
    });

    testWidgets(
      "the Cancel button also prompts (an explicit button's onPressed isn't "
      'gated by PopScope the way a barrier tap/Escape is)',
      (tester) async {
        await pump(tester);
        await tester.enterText(find.widgetWithText(TextField, 'Symbol'), 'BTC');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('New asset'), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
      },
    );

    testWidgets('closes immediately with no unsaved changes', (tester) async {
      await pump(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New asset'), findsNothing);
    });
  });
}

class VaultApiStub extends VaultApi {
  VaultApiStub() : super(ApiClient());

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async =>
      const [];

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async => const [];
}
