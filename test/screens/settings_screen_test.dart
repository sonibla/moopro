import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
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
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/screens/settings_screen.dart';
import 'package:moopro/sync/sync_engine.dart';

class _FakeDomainRepository extends DomainRepository {
  final _controller = StreamController<ldb.Setting?>.broadcast();
  ldb.Setting? _current;
  final List<String> setCalls = [];
  final List<String> clearCalls = [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  void seed(String? value) {
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
  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      Stream.value(const {});

  List<ldb.Asset> assets = [];

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Future<void> setSetting(String id, String value) async {
    setCalls.add(value);
    _current = ldb.Setting(id: id, value: value, deleted: false);
    _controller.add(_current);
  }

  @override
  Future<void> clearSetting(String id) async {
    clearCalls.add(id);
    _current = null;
    _controller.add(null);
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(ApiClient());
  int enableCalls = 0;
  int disableCalls = 0;
  bool failToggle = false;

  @override
  Future<TotpSecretResponse> enableTotp() async {
    if (failToggle) {
      throw DioException(
        requestOptions: RequestOptions(path: '/users/me/totp'),
      );
    }
    enableCalls++;
    return const TotpSecretResponse(
      secret: 'JBSWY3DPEHPK3PXP',
      otpauthUri: 'otpauth://totp/moopro:test?secret=JBSWY3DPEHPK3PXP',
    );
  }

  @override
  Future<void> disableTotp() async {
    if (failToggle) {
      throw DioException(
        requestOptions: RequestOptions(path: '/users/me/totp'),
      );
    }
    disableCalls++;
  }
}

class _FakeLocalUnlockStore extends LocalUnlockStore {
  @override
  Future<bool> isOptedIn() async => false;
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

const _testUser = UserApiResponse(
  id: 'u1',
  email: 'test@example.com',
  emailValidated: true,
  hasVaultKeyMaterial: true,
);

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

  Future<void> pump(
    WidgetTester tester, {
    UserApiResponse user = _testUser,
    AuthApi? authApi,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (authApi != null) authApiProvider.overrideWithValue(authApi),
          domainRepositoryProvider.overrideWithValue(repo),
          localUnlockStoreProvider.overrideWithValue(_FakeLocalUnlockStore()),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = AuthReady(user);
            return controller;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows "Not set" when no API key has been saved yet', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text('Not set — needed for automatic price fetching'),
      findsOneWidget,
    );
    expect(find.text('••••••••'), findsNothing);
  });

  testWidgets('the "Hide amounts" switch writes the account-level setting', (
    tester,
  ) async {
    await pump(tester);

    final tile = find.widgetWithText(SwitchListTile, 'Hide amounts');
    await tester.ensureVisible(tile);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pump();

    expect(repo.setCalls, equals(['1']));
  });

  testWidgets('"Open-source licenses" opens Flutter\'s license page listing '
      'registered packages', (tester) async {
    LicenseRegistry.addLicense(
      () => Stream.value(
        const LicenseEntryWithLineBreaks(['fake_pkg'], 'MIT License'),
      ),
    );
    await pump(tester);

    final tile = find.widgetWithText(ListTile, 'Open-source licenses');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Moopro'), findsWidgets);
    expect(find.text('fake_pkg'), findsOneWidget);
  });

  testWidgets('shows a masked value once an API key is set', (tester) async {
    repo.seed('super-secret-key');
    await pump(tester);

    expect(find.text('••••••••'), findsOneWidget);
    expect(
      find.text('Not set — needed for automatic price fetching'),
      findsNothing,
    );
  });

  testWidgets(
    'tapping the tile, entering a key, and saving calls setSetting and '
    'updates the tile to masked',
    (tester) async {
      await pump(tester);

      await tester.tap(find.text('AlphaVantage API key'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'my-new-key');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.setCalls, equals(['my-new-key']));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('••••••••'), findsOneWidget);
    },
  );

  testWidgets('clearing a previously-set key calls clearSetting and the '
      'tile reverts to "Not set"', (tester) async {
    repo.seed('existing-key');
    await pump(tester);

    await tester.tap(find.text('••••••••'));
    await tester.pumpAndSettle();

    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(repo.clearCalls, equals([SettingIds.alphavantageApiKey]));
    expect(
      find.text('Not set — needed for automatic price fetching'),
      findsOneWidget,
    );
  });

  testWidgets('the dialog has no Clear button when nothing is set yet', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('AlphaVantage API key'));
    await tester.pumpAndSettle();

    expect(find.text('Clear'), findsNothing);
  });

  group('two-factor authentication', () {
    const totpUser = UserApiResponse(
      id: 'u1',
      email: 'test@example.com',
      emailValidated: true,
      hasVaultKeyMaterial: true,
      totpEnabled: true,
    );
    final tile = find.widgetWithText(
      SwitchListTile,
      'Two-factor authentication (TOTP)',
    );

    bool tileValue(WidgetTester tester) =>
        tester.widget<SwitchListTile>(tile).value;

    testWidgets('enabling shows the server-generated secret', (tester) async {
      final api = _FakeAuthApi();
      await pump(tester, authApi: api);
      await tester.scrollUntilVisible(tile, 200);
      expect(tileValue(tester), isFalse);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(api.enableCalls, 1);
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(tileValue(tester), isTrue);
    });

    testWidgets('disabling calls the server and flips the switch', (
      tester,
    ) async {
      final api = _FakeAuthApi();
      await pump(tester, user: totpUser, authApi: api);
      await tester.scrollUntilVisible(tile, 200);
      expect(tileValue(tester), isTrue);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(api.disableCalls, 1);
      expect(tileValue(tester), isFalse);
    });

    testWidgets('a server error leaves the switch unchanged and says so', (
      tester,
    ) async {
      final api = _FakeAuthApi()..failToggle = true;
      await pump(tester, authApi: api);
      await tester.scrollUntilVisible(tile, 200);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(tileValue(tester), isFalse);
      expect(
        find.textContaining('Could not update two-factor'),
        findsOneWidget,
      );
    });
  });

  group('default currency', () {
    const eurId = 'eur00000000000';
    const usdId = 'usd00000000000';
    const eur = ldb.Asset(
      id: eurId,
      kind: 'fiat',
      symbol: 'EUR',
      name: 'Euro',
      deleted: false,
    );
    const usd = ldb.Asset(
      id: usdId,
      kind: 'fiat',
      symbol: 'USD',
      name: 'US Dollar',
      deleted: false,
    );

    testWidgets('is omitted when there is no fiat asset to pick from', (
      tester,
    ) async {
      repo.assets = const [
        ldb.Asset(
          id: 'aapl',
          kind: 'stock',
          symbol: 'AAPL',
          name: 'Apple',
          deleted: false,
        ),
      ];
      await pump(tester);
      expect(find.text('Default currency'), findsNothing);
    });

    testWidgets('defaults to the first fiat asset when nothing is set yet', (
      tester,
    ) async {
      repo.assets = const [eur, usd];
      await pump(tester);

      expect(find.text('Default currency'), findsOneWidget);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.value, equals(eurId));
    });

    testWidgets('reflects an already-persisted default currency', (
      tester,
    ) async {
      repo.assets = const [eur, usd];
      await repo.setSetting(SettingIds.defaultCurrencyAssetId, usdId);
      await pump(tester);
      await tester.pump();

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.value, equals(usdId));
    });

    testWidgets('picking a currency calls setSetting with its asset id', (
      tester,
    ) async {
      repo.assets = const [eur, usd];
      await pump(tester);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD').last);
      await tester.pumpAndSettle();

      expect(repo.setCalls, contains(usdId));
    });
  });

  group('theme', () {
    testWidgets('defaults to System when no theme setting is stored', (
      tester,
    ) async {
      await pump(tester);

      final segmented = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(segmented.selected, equals({ThemeMode.system}));
    });

    testWidgets('reflects an already-persisted theme choice', (tester) async {
      await repo.setSetting(SettingIds.themeMode, 'dark');
      await pump(tester);
      await tester.pump();

      final segmented = tester.widget<SegmentedButton<ThemeMode>>(
        find.byType(SegmentedButton<ThemeMode>),
      );
      expect(segmented.selected, equals({ThemeMode.dark}));
    });

    testWidgets('tapping a segment calls setSetting with its storage value', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Dark'));
      await tester.pumpAndSettle();

      expect(repo.setCalls, contains('dark'));
    });
  });
}
