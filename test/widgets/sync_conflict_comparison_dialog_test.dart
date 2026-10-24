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
import 'package:moopro/widgets/sync_conflict_comparison_dialog.dart';

class _FakeDomainRepository extends DomainRepository {
  ConflictComparison comparison;
  final List<String> keepServerCalls = [];
  final List<String> keepLocalCalls = [];

  _FakeDomainRepository({
    required this.comparison,
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Future<ConflictComparison> loadConflictComparison(String id) async =>
      comparison;

  @override
  Future<void> keepServerVersion(String id) async {
    keepServerCalls.add(id);
  }

  @override
  Future<void> keepLocalVersion(String id) async {
    keepLocalCalls.add(id);
  }
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

  _FakeDomainRepository buildRepo(ConflictComparison comparison) {
    return _FakeDomainRepository(
      comparison: comparison,
      syncDb: syncDb,
      cacheDb: cacheDb,
      syncEngine: SyncEngine(db: syncDb, vaultApi: _VaultApiStub()),
      balanceEngine: BalanceEngine(cacheDb),
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
  }

  setUp(() {
    syncDb = AppDatabase(NativeDatabase.memory());
    cacheDb = ldb.DomainCacheDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  Future<void> pump(WidgetTester tester, _FakeDomainRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showSyncConflictComparison(context, recordId: 'r1'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both versions and resolves via "Keep server version"', (
    tester,
  ) async {
    final repo = buildRepo(
      const ConflictComparison(
        type: VaultRecordTypes.setting,
        local: Setting(id: 'r1', value: 'local-value'),
        server: Setting(id: 'r1', value: 'server-value'),
      ),
    );
    await pump(tester, repo);

    expect(find.text('Your edit'), findsOneWidget);
    expect(find.text('local-value'), findsOneWidget);
    expect(find.text('Current server version'), findsOneWidget);
    expect(find.text('server-value'), findsOneWidget);

    await tester.tap(find.text('Keep server version'));
    await tester.pumpAndSettle();

    expect(repo.keepServerCalls, equals(['r1']));
    expect(repo.keepLocalCalls, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('resolves via "Keep my edit"', (tester) async {
    final repo = buildRepo(
      const ConflictComparison(
        type: VaultRecordTypes.setting,
        local: Setting(id: 'r1', value: 'local-value'),
        server: Setting(id: 'r1', value: 'server-value'),
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Keep my edit'));
    await tester.pumpAndSettle();

    expect(repo.keepLocalCalls, equals(['r1']));
    expect(repo.keepServerCalls, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('"Close" resolves nothing and just dismisses', (tester) async {
    final repo = buildRepo(
      const ConflictComparison(
        type: VaultRecordTypes.setting,
        local: Setting(id: 'r1', value: 'local-value'),
        server: Setting(id: 'r1', value: 'server-value'),
      ),
    );
    await pump(tester, repo);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(repo.keepServerCalls, isEmpty);
    expect(repo.keepLocalCalls, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'falls back to server-only when the local snapshot is unavailable — '
    '"Keep my edit" is disabled',
    (tester) async {
      final repo = buildRepo(
        const ConflictComparison(
          type: VaultRecordTypes.setting,
          local: null,
          server: Setting(id: 'r1', value: 'server-value'),
        ),
      );
      await pump(tester, repo);

      expect(
        find.textContaining("Your previous edit isn't available"),
        findsOneWidget,
      );
      expect(find.text('Your edit'), findsNothing);

      final keepMyEdit = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Keep my edit'),
      );
      expect(keepMyEdit.onPressed, isNull);

      await tester.tap(find.text('Keep server version'));
      await tester.pumpAndSettle();
      expect(repo.keepServerCalls, equals(['r1']));
    },
  );
}
