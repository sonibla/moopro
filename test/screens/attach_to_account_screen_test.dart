import 'dart:typed_data';

import 'package:dio/dio.dart';
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
import 'package:moopro/db/database.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/screens/attach_to_account_screen.dart';
import 'package:moopro/sync/sync_engine.dart';

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

class _FakeVaultSessionManager extends VaultSessionManager {
  final Uint8List _dek = Uint8List.fromList(const [1, 2, 3]);

  _FakeVaultSessionManager()
    : super(
        authApi: AuthApi(ApiClient()),
        localUnlockStore: LocalUnlockStore(),
        localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
          AppDatabase(NativeDatabase.memory()),
        ),
      );

  @override
  Uint8List? get currentDek => _dek;

  @override
  Future<void> rewrapDekAfterPasswordChange({
    required String newPassword,
  }) async {}

  @override
  Future<void> clearLocalOfflineVault() async {}
}

class _FakeAuthApi extends AuthApi {
  bool rejectLogin = false;
  UserApiResponse loginResponseUser = _newAccountUser;

  _FakeAuthApi() : super(ApiClient());

  @override
  Future<LoggedInApiResponse> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    if (rejectLogin) {
      throw DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 401,
        ),
      );
    }
    return LoggedInApiResponse(
      userData: loginResponseUser,
      accessToken: const AccessTokenResponse(
        accessToken: 'fake-access',
        expiresIn: 3600,
        refreshToken: 'fake-refresh',
      ),
    );
  }
}

class _FakeDomainRepositoryForAttach extends DomainRepository {
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
  Future<PullResult> syncNow() async =>
      const PullResult(recordsApplied: 0, rollbackWarnings: []);
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _FakeAuthApi authApi,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          domainRepositoryProvider.overrideWithValue(
            _FakeDomainRepositoryForAttach(),
          ),
          authControllerProvider.overrideWith((ref) => AuthController(ref)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AttachToAccountScreen(),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('successful attach pops back to the caller', (tester) async {
    final authApi = _FakeAuthApi()..loginResponseUser = _newAccountUser;
    await pump(tester, authApi: authApi);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'newpassword',
    );
    await tester.tap(find.text('Attach and sync'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachToAccountScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'attaching to an account that already has a vault shows a clear error '
    'and stays on the screen',
    (tester) async {
      final authApi = _FakeAuthApi()..loginResponseUser = _existingVaultUser;
      await pump(tester, authApi: authApi);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'existing@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'whatever',
      );
      await tester.tap(find.text('Attach and sync'));
      await tester.pumpAndSettle();

      expect(find.byType(AttachToAccountScreen), findsOneWidget);
      expect(find.textContaining('already has a vault'), findsOneWidget);
    },
  );

  testWidgets('bad credentials shows "Incorrect email or password"', (
    tester,
  ) async {
    final authApi = _FakeAuthApi()..rejectLogin = true;
    await pump(tester, authApi: authApi);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'someone@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrong',
    );
    await tester.tap(find.text('Attach and sync'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachToAccountScreen), findsOneWidget);
    expect(find.text('Incorrect email or password'), findsOneWidget);
  });
}
