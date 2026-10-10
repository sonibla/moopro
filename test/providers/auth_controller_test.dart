import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/api/vault_api.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/db/vault_registry_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/vault/vault_registry.dart';
import 'package:moopro/providers/auth_controller.dart';

const _testUser = UserApiResponse(
  id: 'user-1',
  email: 'test@example.com',
  emailValidated: true,
  hasVaultKeyMaterial: true,
);

const _newAccountUser = UserApiResponse(
  id: 'user-2',
  email: 'new@example.com',
  emailValidated: true,
  hasVaultKeyMaterial: false,
);

const _existingVaultUser = UserApiResponse(
  id: 'user-3',
  email: 'existing@example.com',
  emailValidated: true,
  hasVaultKeyMaterial: true,
);

class _CloseTrackingAppDatabase extends AppDatabase {
  bool closeCalled = false;

  _CloseTrackingAppDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> close() {
    closeCalled = true;
    return super.close();
  }
}

class _FakeVaultSessionManager extends VaultSessionManager {
  bool failOfflineUnlock;

  bool cachedDekAvailable;

  bool rewrapCalled = false;
  bool clearLocalOfflineVaultCalled = false;
  Uint8List? _dek;

  _FakeVaultSessionManager({
    this.failOfflineUnlock = false,
    this.cachedDekAvailable = false,
  }) : super(
         authApi: AuthApi(ApiClient()),
         localUnlockStore: LocalUnlockStore(),
         localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
           AppDatabase(NativeDatabase.memory()),
         ),
       );

  @override
  Uint8List? get currentDek => _dek;

  @override
  Future<bool> tryUnlockFromLocalCache({bool challenge = true}) async {
    if (!cachedDekAvailable) return false;
    _dek = Uint8List.fromList(const [1, 2, 3]);
    return true;
  }

  @override
  Future<void> completeOfflineVaultSetup({required String password}) async {
    _dek = Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<void> unlockOffline({required String password}) async {
    if (failOfflineUnlock) throw const InvalidMasterPasswordException();
    _dek = Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<void> rewrapDekAfterPasswordChange({
    required String newPassword,
  }) async {
    rewrapCalled = true;
  }

  @override
  Future<void> clearLocalOfflineVault() async {
    clearLocalOfflineVaultCalled = true;
  }

  @override
  void lock() {
    _dek = null;
  }
}

class _FakeAuthApi extends AuthApi {
  bool logoutCalled = false;
  UserApiResponse loginResponseUser = _newAccountUser;
  bool registrationStatusEnabled = true;

  _FakeAuthApi() : super(ApiClient());

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<LoggedInApiResponse> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    return LoggedInApiResponse(
      userData: loginResponseUser,
      accessToken: const AccessTokenResponse(
        accessToken: 'fake-access',
        expiresIn: 3600,
        refreshToken: 'fake-refresh',
      ),
    );
  }

  @override
  Future<RegistrationStatusResponse> checkRegistrationStatus() async {
    return RegistrationStatusResponse(enabled: registrationStatusEnabled);
  }
}

class _FakeDomainRepositoryForAttach extends DomainRepository {
  bool syncCalled = false;

  _FakeDomainRepositoryForAttach()
    : super(
        syncDb: AppDatabase(NativeDatabase.memory()),
        cacheDb: DomainCacheDatabase(),
        syncEngine: SyncEngine(
          db: AppDatabase(NativeDatabase.memory()),
          vaultApi: VaultApi(ApiClient()),
        ),
        balanceEngine: BalanceEngine(DomainCacheDatabase()),
        vaultSession: _FakeVaultSessionManager(),
      );

  @override
  Future<PullResult> syncNow({bool force = false}) async {
    syncCalled = true;
    return const PullResult(recordsApplied: 0, rollbackWarnings: []);
  }
}

VaultRegistry _testRegistry(VaultRegistryDatabase db) => VaultRegistry(db);

void main() {
  group('AuthController cross-tab session sync', () {
    test(
      'follows a session clear signalled by another tab out of AuthReady',
      () async {
        final crossTabSignal = StreamController<void>();
        final container = ProviderContainer(
          overrides: [
            vaultSessionManagerProvider.overrideWithValue(
              _FakeVaultSessionManager(),
            ),
            authControllerProvider.overrideWith(
              (ref) => AuthController(
                ref,
                crossTabSessionChanges: crossTabSignal.stream,
                hasStoredSessionOverride: () async => false,
                knownVaultsOverride: () async => [],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(crossTabSignal.close);

        final controller = container.read(authControllerProvider.notifier);
        controller.state = const AuthReady(_testUser);

        crossTabSignal.add(null);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
      },
    );

    test(
      'ignores the signal when the session is still present elsewhere',
      () async {
        final crossTabSignal = StreamController<void>();
        final container = ProviderContainer(
          overrides: [
            vaultSessionManagerProvider.overrideWithValue(
              _FakeVaultSessionManager(),
            ),
            authControllerProvider.overrideWith(
              (ref) => AuthController(
                ref,
                crossTabSessionChanges: crossTabSignal.stream,
                hasStoredSessionOverride: () async => true,
                knownVaultsOverride: () async => [],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(crossTabSignal.close);

        final controller = container.read(authControllerProvider.notifier);
        controller.state = const AuthReady(_testUser);

        crossTabSignal.add(null);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(authControllerProvider), isA<AuthReady>());
      },
    );

    test('is a no-op when already logged out', () async {
      final crossTabSignal = StreamController<void>();
      final container = ProviderContainer(
        overrides: [
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: crossTabSignal.stream,
              hasStoredSessionOverride: () async => false,
              knownVaultsOverride: () async => [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(crossTabSignal.close);

      crossTabSignal.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });
  });

  group('AuthController offline vault + multi-vault', () {
    Future<ProviderContainer> buildContainer({
      required _FakeVaultSessionManager vaultSession,
      bool seedOfflineVault = false,
    }) async {
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      if (seedOfflineVault) {
        await registry.createOfflineVault(label: 'Offline vault');
      }
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'startup with a single offline vault shows the picker; selecting it lands '
      'on AuthOfflineNeedsUnlock',
      () async {
        final container = await buildContainer(
          vaultSession: _FakeVaultSessionManager(),
          seedOfflineVault: true,
        );
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final picker = container.read(authControllerProvider);
        expect(picker, isA<AuthNeedsVaultSelection>());
        await container
            .read(authControllerProvider.notifier)
            .selectVault((picker as AuthNeedsVaultSelection).vaults.single);

        expect(
          container.read(authControllerProvider),
          isA<AuthOfflineNeedsUnlock>(),
        );
      },
    );

    test('startup without a local offline vault stays AuthLoggedOut', () async {
      final container = await buildContainer(
        vaultSession: _FakeVaultSessionManager(),
      );
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });

    test(
      'selecting a single offline vault with a valid local-unlock cache '
      'goes straight to AuthOfflineReady, not AuthOfflineNeedsUnlock — '
      'regression test for the offline path never attempting the cache',
      () async {
        final container = await buildContainer(
          vaultSession: _FakeVaultSessionManager(cachedDekAvailable: true),
          seedOfflineVault: true,
        );
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await container
            .read(authControllerProvider.notifier)
            .selectVault(
              (container.read(authControllerProvider)
                      as AuthNeedsVaultSelection)
                  .vaults
                  .single,
            );

        expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
      },
    );

    test('startOfflineSetup transitions to AuthOfflineNeedsSetup', () async {
      final container = await buildContainer(
        vaultSession: _FakeVaultSessionManager(),
      );
      await Future<void>.delayed(Duration.zero);

      container.read(authControllerProvider.notifier).startOfflineSetup();

      expect(
        container.read(authControllerProvider),
        isA<AuthOfflineNeedsSetup>(),
      );
    });

    test('continueOffline goes straight to AuthOfflineNeedsSetup when no '
        'vaults are known yet', () async {
      final container = await buildContainer(
        vaultSession: _FakeVaultSessionManager(),
      );
      await Future<void>.delayed(Duration.zero);

      await container.read(authControllerProvider.notifier).continueOffline();

      expect(
        container.read(authControllerProvider),
        isA<AuthOfflineNeedsSetup>(),
      );
    });

    test('continueOffline shows the vault picker instead of creating a new '
        'vault when one already exists on this device — regression test for '
        'the "select online, then continue offline" dead end', () async {
      final container = await buildContainer(
        vaultSession: _FakeVaultSessionManager(),
        seedOfflineVault: true,
      );
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      container.read(authControllerProvider.notifier).returnToLoginScreen();

      await container.read(authControllerProvider.notifier).continueOffline();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthNeedsVaultSelection>());
      expect((state as AuthNeedsVaultSelection).vaults, hasLength(1));
    });

    test('completeOfflineVaultSetup lands on AuthOfflineReady', () async {
      final container = await buildContainer(
        vaultSession: _FakeVaultSessionManager(),
      );
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(authControllerProvider.notifier);
      controller.startOfflineSetup();

      await controller.completeOfflineVaultSetup(
        password: 'hunter2',
        label: 'My offline vault',
      );

      expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
    });

    test(
      'unlockOffline with the wrong password stays AuthOfflineNeedsUnlock and rethrows',
      () async {
        final vaultSession = _FakeVaultSessionManager(failOfflineUnlock: true);
        final container = await buildContainer(
          vaultSession: vaultSession,
          seedOfflineVault: true,
        );
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final controller = container.read(authControllerProvider.notifier);

        await expectLater(
          () => controller.unlockOffline(password: 'wrong'),
          throwsA(isA<InvalidMasterPasswordException>()),
        );

        expect(
          container.read(authControllerProvider),
          isA<AuthOfflineNeedsUnlock>(),
        );
      },
    );

    test(
      'unlockOffline with the right password lands on AuthOfflineReady',
      () async {
        final vaultSession = _FakeVaultSessionManager();
        final container = await buildContainer(
          vaultSession: vaultSession,
          seedOfflineVault: true,
        );
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final controller = container.read(authControllerProvider.notifier);

        await controller.unlockOffline(password: 'correct');

        expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
      },
    );

    test(
      'logout() from AuthOfflineReady locks, lands on AuthOfflineNeedsUnlock, '
      'and does not call authApi.logout',
      () async {
        final vaultSession = _FakeVaultSessionManager();
        final fakeAuthApi = _FakeAuthApi();
        final registry = _testRegistry(
          VaultRegistryDatabase(NativeDatabase.memory()),
        );
        await registry.createOfflineVault(label: 'Vault');
        final container = ProviderContainer(
          overrides: [
            vaultRegistryProvider.overrideWithValue(registry),
            vaultSessionManagerProvider.overrideWithValue(vaultSession),
            authApiProvider.overrideWithValue(fakeAuthApi),
            authControllerProvider.overrideWith(
              (ref) => AuthController(
                ref,
                crossTabSessionChanges: const Stream<void>.empty(),
                hasStoredSessionOverride: () async => false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final controller = container.read(authControllerProvider.notifier);
        await controller.unlockOffline(password: 'correct');
        expect(container.read(authControllerProvider), isA<AuthOfflineReady>());

        await controller.logout();

        expect(
          container.read(authControllerProvider),
          isA<AuthOfflineNeedsUnlock>(),
        );
        expect(vaultSession.currentDek, isNull);
        expect(fakeAuthApi.logoutCalled, isFalse);
      },
    );

    test('deleteVault refuses to delete the active, unlocked vault', () async {
      final vaultSession = _FakeVaultSessionManager();
      final container = await buildContainer(
        vaultSession: vaultSession,
        seedOfflineVault: true,
      );
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(authControllerProvider.notifier)
          .selectVault(
            (container.read(authControllerProvider) as AuthNeedsVaultSelection)
                .vaults
                .single,
          );
      final controller = container.read(authControllerProvider.notifier);
      await controller.unlockOffline(password: 'correct');
      final active = container.read(activeVaultProvider)!;

      await expectLater(
        () => controller.deleteVault(active),
        throwsA(isA<ActiveVaultCannotBeDeletedException>()),
      );
    });
  });

  group('AuthController vault picker releases the active vault', () {
    test('showVaultPicker locks, closes the vault database, clears the active '
        'vault, and lets the previously active vault be deleted', () async {
      final vaultSession = _FakeVaultSessionManager();
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      final vault = await registry.createOfflineVault(label: 'Offline vault');
      final db = _CloseTrackingAppDatabase();
      FlutterSecureStorage.setMockInitialValues({});
      final docsDir = Directory.systemTemp.createTempSync('moopro_vault');
      addTearDown(() => docsDir.deleteSync(recursive: true));
      final messenger =
          TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => docsDir.path,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          appDatabaseProvider.overrideWith((ref) {
            ref.watch(activeVaultProvider);
            return db;
          }),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(authControllerProvider.notifier)
          .selectVault(
            (container.read(authControllerProvider) as AuthNeedsVaultSelection)
                .vaults
                .single,
          );
      final controller = container.read(authControllerProvider.notifier);
      await controller.unlockOffline(password: 'correct');
      expect(container.read(activeVaultProvider)?.id, vault.id);

      VaultRegistryEntry? activeWhenPickerShown;
      container.listen<AuthFlowState>(authControllerProvider, (_, next) {
        if (next is AuthNeedsVaultSelection) {
          activeWhenPickerShown = container.read(activeVaultProvider);
        }
      });

      await controller.showVaultPicker();
      expect(activeWhenPickerShown?.id, vault.id);

      expect(
        container.read(authControllerProvider),
        isA<AuthNeedsVaultSelection>(),
      );
      expect(container.read(activeVaultProvider), isNull);
      expect(vaultSession.currentDek, isNull);
      expect(db.closeCalled, isTrue);

      await controller.deleteVault(vault);

      expect(await registry.list(), isEmpty);
    });

    test('showVaultPicker with no active vault just lists vaults', () async {
      final vaultSession = _FakeVaultSessionManager();
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      await registry.createOfflineVault(label: 'A');
      await registry.createOfflineVault(label: 'B');
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await controller.showVaultPicker();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthNeedsVaultSelection>());
      expect((state as AuthNeedsVaultSelection).vaults, hasLength(2));
    });
  });

  group('AuthController "last opened" tracking', () {
    test('selecting a vault without unlocking leaves lastOpenedAt alone; '
        'unlocking it updates it', () async {
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      final created = await registry.createOfflineVault(label: 'Vault');
      final vault = (await registry.get(created.id))!;
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
              knownVaultsOverride: () async => [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));

      await controller.selectVault(vault);

      expect(
        container.read(authControllerProvider),
        isA<AuthOfflineNeedsUnlock>(),
      );
      expect((await registry.get(vault.id))!.lastOpenedAt, vault.lastOpenedAt);

      await controller.unlockOffline(password: 'correct');

      expect(
        (await registry.get(
          vault.id,
        ))!.lastOpenedAt.isAfter(vault.lastOpenedAt),
        isTrue,
      );
    });
  });

  group('AuthController.backToVaultList', () {
    Future<(ProviderContainer, AuthController, _FakeAuthApi)> build({
      required int vaultCount,
      required AuthFlowState from,
    }) async {
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      for (var i = 0; i < vaultCount; i++) {
        await registry.createOfflineVault(label: 'Vault $i');
      }
      final authApi = _FakeAuthApi();
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authApiProvider.overrideWithValue(authApi),
          appDatabaseProvider.overrideWith((ref) {
            ref.watch(activeVaultProvider);
            return AppDatabase(NativeDatabase.memory());
          }),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
              knownVaultsOverride: () async => registry.list(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      // ignore: invalid_use_of_protected_member
      controller.state = from;
      return (container, controller, authApi);
    }

    test('offline setup with known vaults goes back to the picker', () async {
      final (container, controller, authApi) = await build(
        vaultCount: 2,
        from: const AuthOfflineNeedsSetup(),
      );

      await controller.backToVaultList();

      expect(
        container.read(authControllerProvider),
        isA<AuthNeedsVaultSelection>(),
      );
      expect(authApi.logoutCalled, isFalse);
    });

    test(
      'offline setup with no vaults goes back to the login screen',
      () async {
        final (container, controller, _) = await build(
          vaultCount: 0,
          from: const AuthOfflineNeedsSetup(),
        );

        await controller.backToVaultList();

        expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
      },
    );

    test('login screen with known vaults goes back to the picker', () async {
      final (container, controller, _) = await build(
        vaultCount: 1,
        from: const AuthLoggedOut(),
      );

      await controller.backToVaultList();

      expect(
        container.read(authControllerProvider),
        isA<AuthNeedsVaultSelection>(),
      );
    });

    test(
      'online first-time setup keeps the server session and shows the picker',
      () async {
        final (container, controller, authApi) = await build(
          vaultCount: 1,
          from: AuthNeedsVaultSetup(_newAccountUser),
        );

        await controller.backToVaultList();

        expect(authApi.logoutCalled, isFalse);
        expect(
          container.read(authControllerProvider),
          isA<AuthNeedsVaultSelection>(),
        );
      },
    );

    test('online unlock with no known vaults goes to the login screen without '
        'logging out', () async {
      final (container, controller, authApi) = await build(
        vaultCount: 0,
        from: AuthNeedsUnlock(_newAccountUser),
      );

      await controller.backToVaultList();

      expect(authApi.logoutCalled, isFalse);
      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });

    test('is ignored while an unlock is in flight', () async {
      final (container, controller, authApi) = await build(
        vaultCount: 1,
        from: const AuthOfflineUnlocking(),
      );

      await controller.backToVaultList();

      expect(
        container.read(authControllerProvider),
        isA<AuthOfflineUnlocking>(),
      );
      expect(authApi.logoutCalled, isFalse);
    });
  });

  group('AuthController online vault resolution', () {
    Future<ProviderContainer> buildContainer({
      required _FakeAuthApi authApi,
    }) async {
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authApiProvider.overrideWithValue(authApi),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('logging into a brand-new account allocates a new vault, tied to '
        'that email', () async {
      final authApi = _FakeAuthApi()..loginResponseUser = _testUser;
      final container = await buildContainer(authApi: authApi);
      final controller = container.read(authControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      await controller.login(email: _testUser.email, password: 'pw');

      final active = container.read(activeVaultProvider);
      expect(active, isNotNull);
      expect(active!.kind, VaultKind.online);
      expect(active.email, _testUser.email);
    });

    test(
      'logging into the same account twice reuses the same vault id',
      () async {
        final authApi = _FakeAuthApi()..loginResponseUser = _testUser;
        final container = await buildContainer(authApi: authApi);
        final controller = container.read(authControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);

        await controller.login(email: _testUser.email, password: 'pw');
        final firstId = container.read(activeVaultProvider)!.id;
        await controller.logout();
        await controller.login(email: _testUser.email, password: 'pw');
        final secondId = container.read(activeVaultProvider)!.id;

        expect(secondId, firstId);
      },
    );

    test(
      'logging into a different account allocates a different vault id',
      () async {
        final authApi = _FakeAuthApi()..loginResponseUser = _testUser;
        final container = await buildContainer(authApi: authApi);
        final controller = container.read(authControllerProvider.notifier);
        await Future<void>.delayed(Duration.zero);

        await controller.login(email: _testUser.email, password: 'pw');
        final firstId = container.read(activeVaultProvider)!.id;
        await controller.logout();

        authApi.loginResponseUser = _existingVaultUser;
        await controller.login(email: _existingVaultUser.email, password: 'pw');
        final secondId = container.read(activeVaultProvider)!.id;

        expect(secondId, isNot(firstId));
      },
    );
  });

  group('AuthController.checkRegistrationStatus', () {
    Future<ProviderContainer> buildContainer({
      required _FakeAuthApi authApi,
    }) async {
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authApiProvider.overrideWithValue(authApi),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('reports true when the instance has registration open', () async {
      final authApi = _FakeAuthApi()..registrationStatusEnabled = true;
      final container = await buildContainer(authApi: authApi);
      final controller = container.read(authControllerProvider.notifier);

      expect(await controller.checkRegistrationStatus(), isTrue);
    });

    test('reports false when the instance has registration closed', () async {
      final authApi = _FakeAuthApi()..registrationStatusEnabled = false;
      final container = await buildContainer(authApi: authApi);
      final controller = container.read(authControllerProvider.notifier);

      expect(await controller.checkRegistrationStatus(), isFalse);
    });
  });

  group('AuthController.attachOfflineVaultToAccount', () {
    Future<ProviderContainer> buildContainer({
      required _FakeVaultSessionManager vaultSession,
      required _FakeAuthApi authApi,
      required _FakeDomainRepositoryForAttach domainRepository,
    }) async {
      final registry = _testRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      await registry.createOfflineVault(label: 'Vault');
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(registry),
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          authApiProvider.overrideWithValue(authApi),
          domainRepositoryProvider.overrideWithValue(domainRepository),
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              ref,
              crossTabSessionChanges: const Stream<void>.empty(),
              hasStoredSessionOverride: () async => false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('succeeds against a brand-new account: syncs, converts the vault to '
        'online in place, lands on AuthReady', () async {
      final vaultSession = _FakeVaultSessionManager();
      final authApi = _FakeAuthApi()..loginResponseUser = _newAccountUser;
      final domainRepository = _FakeDomainRepositoryForAttach();
      final container = await buildContainer(
        vaultSession: vaultSession,
        authApi: authApi,
        domainRepository: domainRepository,
      );
      container.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await container
          .read(authControllerProvider.notifier)
          .selectVault(
            (container.read(authControllerProvider) as AuthNeedsVaultSelection)
                .vaults
                .single,
          );
      final controller = container.read(authControllerProvider.notifier);
      final vaultIdBeforeAttach = container.read(activeVaultProvider)!.id;
      await controller.unlockOffline(password: 'correct');

      await controller.attachOfflineVaultToAccount(
        email: 'new@example.com',
        password: 'newpassword',
      );

      expect(container.read(authControllerProvider), isA<AuthReady>());
      expect(vaultSession.rewrapCalled, isTrue);
      expect(domainRepository.syncCalled, isTrue);
      expect(vaultSession.clearLocalOfflineVaultCalled, isTrue);
      final active = container.read(activeVaultProvider)!;
      expect(active.id, vaultIdBeforeAttach);
      expect(active.kind, VaultKind.online);
      expect(active.email, 'new@example.com');
    });

    test(
      'against an account that already has a vault throws and stays AuthOfflineReady',
      () async {
        final vaultSession = _FakeVaultSessionManager();
        final authApi = _FakeAuthApi()..loginResponseUser = _existingVaultUser;
        final domainRepository = _FakeDomainRepositoryForAttach();
        final container = await buildContainer(
          vaultSession: vaultSession,
          authApi: authApi,
          domainRepository: domainRepository,
        );
        container.read(authControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        final controller = container.read(authControllerProvider.notifier);
        await controller.unlockOffline(password: 'correct');

        await expectLater(
          () => controller.attachOfflineVaultToAccount(
            email: 'existing@example.com',
            password: 'whatever',
          ),
          throwsA(isA<AccountAlreadyHasVaultException>()),
        );

        expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
        expect(vaultSession.rewrapCalled, isFalse);
        expect(domainRepository.syncCalled, isFalse);
        expect(vaultSession.clearLocalOfflineVaultCalled, isFalse);
      },
    );
  });
}
