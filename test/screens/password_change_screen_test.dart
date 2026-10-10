import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/screens/password_change_screen.dart';

class _FakeAuthApi extends AuthApi {
  final List<String> changedTo = [];

  _FakeAuthApi() : super(ApiClient());

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changedTo.add(newPassword);
  }
}

class _FakeVaultSessionManager extends VaultSessionManager {
  _FakeVaultSessionManager()
    : super(
        authApi: AuthApi(ApiClient()),
        localUnlockStore: LocalUnlockStore(),
        localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
          AppDatabase(NativeDatabase.memory()),
        ),
      );

  @override
  Future<void> rewrapDekAfterPasswordChange({
    required String newPassword,
  }) async {}
}

void main() {
  Future<_FakeAuthApi> pump(WidgetTester tester) async {
    final authApi = _FakeAuthApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(authApi),
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
        ],
        child: const MaterialApp(home: PasswordChangeScreen()),
      ),
    );
    return authApi;
  }

  Future<void> fill(WidgetTester tester, String newPw, String confirm) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'old-pass',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      newPw,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      confirm,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
    await tester.pumpAndSettle();
  }

  testWidgets('mismatched confirmation blocks the change', (tester) async {
    final authApi = await pump(tester);
    await fill(tester, 'new-pass-1', 'new-pass-2');

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(authApi.changedTo, isEmpty);
  });

  testWidgets('matching confirmation changes the password', (tester) async {
    final authApi = await pump(tester);
    await fill(tester, 'new-pass-1', 'new-pass-1');

    expect(authApi.changedTo, ['new-pass-1']);
    expect(find.text('Password changed successfully.'), findsOneWidget);
  });
}
