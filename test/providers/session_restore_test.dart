import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/api/token_store.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/vault_registry_database.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/vault/vault_registry.dart';

const _user = UserApiResponse(
  id: 'u1',
  email: 'test@example.com',
  emailValidated: true,
  hasVaultKeyMaterial: true,
);

class _FakeAuthApi extends AuthApi {
  bool currentUserFails = false;
  int getCurrentUserCalls = 0;
  bool logoutCalled = false;

  _FakeAuthApi(super.client);

  @override
  Future<UserApiResponse> getCurrentUser() async {
    getCurrentUserCalls++;
    if (currentUserFails) {
      throw DioException(requestOptions: RequestOptions(path: '/users/me'));
    }
    return _user;
  }

  @override
  Future<LoggedInApiResponse> login({
    required String email,
    required String password,
    String? totpCode,
  }) async => const LoggedInApiResponse(
    userData: _user,
    accessToken: AccessTokenResponse(
      accessToken: 'new-access',
      expiresIn: 3600,
      refreshToken: 'new-refresh',
    ),
  );

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await super.logout();
  }
}

class _FakeVaultSession extends VaultSessionManager {
  _FakeVaultSession()
    : super(
        authApi: AuthApi(ApiClient()),
        localUnlockStore: LocalUnlockStore(),
        localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
          AppDatabase(NativeDatabase.memory()),
        ),
      );

  @override
  Uint8List? get currentDek => null;

  bool hasCachedKey = false;
  final challengeArgs = <bool>[];

  @override
  Future<bool> tryUnlockFromLocalCache({bool challenge = true}) async {
    challengeArgs.add(challenge);
    return hasCachedKey;
  }

  @override
  void lock() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStore tokenStore;
  late _FakeAuthApi authApi;
  late VaultRegistry registry;
  late _FakeVaultSession vaultSession;
  late List<String> prompts;
  bool promptResult = true;

  String key(String base) => '$base:${_user.email}';

  Future<(ProviderContainer, VaultRegistryEntry)> build({
    bool currentUserFails = false,
  }) async {
    final client = ApiClient(tokenStore: tokenStore);
    authApi = _FakeAuthApi(client)..currentUserFails = currentUserFails;
    registry = VaultRegistry(VaultRegistryDatabase(NativeDatabase.memory()));
    final vault = await registry.resolveOnlineVault(
      email: _user.email,
      label: _user.email,
    );
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authApiProvider.overrideWithValue(authApi),
        vaultSessionManagerProvider.overrideWithValue(vaultSession),
        vaultRegistryProvider.overrideWithValue(registry),
        appDatabaseProvider.overrideWith((ref) {
          ref.watch(activeVaultProvider);
          return AppDatabase(NativeDatabase.memory());
        }),
        authControllerProvider.overrideWith(
          (ref) => AuthController(
            ref,
            crossTabSessionChanges: const Stream<void>.empty(),
            authenticate: ({required String reason}) async {
              prompts.add(reason);
              return promptResult;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return (container, vault);
  }

  void seedDisk() => FlutterSecureStorage.setMockInitialValues({
    key(TokenStore.accessTokenKey): 'stored-access',
    key(TokenStore.refreshTokenKey): 'stored-refresh',
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tokenStore = TokenStore();
    vaultSession = _FakeVaultSession();
    prompts = [];
    promptResult = true;
  });

  group('vault list at startup', () {
    test('lists the known vault and marks the stay-signed-in account as '
        'connected', () async {
      seedDisk();
      final (container, _) = await build();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthNeedsVaultSelection>());
      expect((state as AuthNeedsVaultSelection).connectedEmails, {_user.email});
      expect(authApi.getCurrentUserCalls, 0);
    });

    test(
      'an account without a stored session is not marked connected',
      () async {
        final (container, _) = await build();

        final state = container.read(authControllerProvider);
        expect((state as AuthNeedsVaultSelection).connectedEmails, isEmpty);
      },
    );
  });

  group('selecting an online vault', () {
    test('with a stored session it skips the login screen and asks for the '
        'vault unlock', () async {
      seedDisk();
      final (container, vault) = await build();
      final seen = <AuthFlowState>[];
      container.listen<AuthFlowState>(
        authControllerProvider,
        (_, next) => seen.add(next),
      );

      await container.read(authControllerProvider.notifier).selectVault(vault);

      expect(seen.first, isA<AuthResumingSession>());
      expect(seen.whereType<AuthLoggingIn>(), isEmpty);
      expect(container.read(authControllerProvider), isA<AuthNeedsUnlock>());
      expect(authApi.getCurrentUserCalls, 1);
      expect(await tokenStore.readRefreshToken(), 'stored-refresh');
    });

    test('a disk-stored session shows ONE prompt, which also covers the cached '
        'vault key', () async {
      seedDisk();
      vaultSession.hasCachedKey = true;
      final (container, vault) = await build();

      await container.read(authControllerProvider.notifier).selectVault(vault);

      expect(container.read(authControllerProvider), isA<AuthReady>());
      expect(prompts, ['Sign in to moopro']);
      expect(vaultSession.challengeArgs, [false]);
    });

    test('a session already in memory ran no prompt, so the cached key read '
        'still challenges', () async {
      seedDisk();
      vaultSession.hasCachedKey = true;
      final (container, vault) = await build();
      final controller = container.read(authControllerProvider.notifier);
      await controller.selectVault(vault);
      await controller.backToVaultList();
      prompts.clear();
      vaultSession.challengeArgs.clear();

      await controller.selectVault(vault);

      expect(prompts, isEmpty);
      expect(vaultSession.challengeArgs, [true]);
    });

    test(
      'a cancelled prompt opens login and never reads the cached key',
      () async {
        seedDisk();
        vaultSession.hasCachedKey = true;
        promptResult = false;
        final (container, vault) = await build();

        await container
            .read(authControllerProvider.notifier)
            .selectVault(vault);

        expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
        expect(prompts, hasLength(1));
        expect(vaultSession.challengeArgs, isEmpty);
      },
    );

    test('a password login (no earlier prompt) still challenges for the '
        'cached key', () async {
      vaultSession.hasCachedKey = true;
      final (container, _) = await build();

      await container
          .read(authControllerProvider.notifier)
          .login(email: _user.email, password: 'pw');

      expect(prompts, isEmpty);
      expect(vaultSession.challengeArgs, [true]);
    });

    test('without a stored session it opens login with the email '
        'pre-filled', () async {
      final (container, vault) = await build();

      await container.read(authControllerProvider.notifier).selectVault(vault);

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthLoggedOut>());
      expect((state as AuthLoggedOut).prefillEmail, _user.email);
      expect(authApi.getCurrentUserCalls, 0);
    });

    test('an unreachable/rejecting server falls back to login but keeps the '
        'stored tokens for next time', () async {
      seedDisk();
      final (container, vault) = await build(currentUserFails: true);

      await container.read(authControllerProvider.notifier).selectVault(vault);

      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
      expect(await const FlutterSecureStorage().readAll(), isNotEmpty);
    });

    test('going back to the list keeps the account connected', () async {
      seedDisk();
      final (container, vault) = await build();
      final controller = container.read(authControllerProvider.notifier);
      await controller.selectVault(vault);

      await controller.backToVaultList();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthNeedsVaultSelection>());
      expect((state as AuthNeedsVaultSelection).connectedEmails, {_user.email});
      expect(authApi.logoutCalled, isFalse);
    });
  });

  group('stay signed in', () {
    test('unticked: nothing reaches secure storage', () async {
      final (container, _) = await build();
      await container
          .read(authControllerProvider.notifier)
          .login(email: _user.email, password: 'pw');
      expect(tokenStore.persist, isFalse);
      await tokenStore.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });

    test('ticked: tokens are persisted under the account', () async {
      final (container, _) = await build();
      await container
          .read(authControllerProvider.notifier)
          .login(email: _user.email, password: 'pw', stayLoggedIn: true);
      expect(tokenStore.persist, isTrue);
      await tokenStore.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(
        (await const FlutterSecureStorage().readAll())[key(
          TokenStore.refreshTokenKey,
        )],
        'r',
      );
    });

    test('logout removes persisted tokens and calls the server', () async {
      seedDisk();
      final (container, vault) = await build();
      final controller = container.read(authControllerProvider.notifier);
      await controller.selectVault(vault);

      await controller.logout();

      expect(authApi.logoutCalled, isTrue);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });
  });
}
