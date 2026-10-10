import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';

import 'package:moopro/main.dart';

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(ApiClient());

  @override
  Future<RegistrationStatusResponse> checkRegistrationStatus() async =>
      const RegistrationStatusResponse(enabled: true);
}

void main() {
  testWidgets('App boots to the login screen when logged out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWithValue(_FakeAuthApi()),
          authControllerProvider.overrideWith(
            (ref) => AuthController(ref, knownVaultsOverride: () async => []),
          ),
        ],
        child: const MooproApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Log in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Continue offline'), findsOneWidget);
  });

  testWidgets(
    'always uses system theme before the vault is unlocked, regardless '
    'of the persisted theme-mode setting — the login/vault-unlock screens '
    "shouldn't depend on vault-derived state",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWithValue(_FakeAuthApi()),
            authControllerProvider.overrideWith(
              (ref) => AuthController(ref, knownVaultsOverride: () async => []),
            ),
            themeModeProvider.overrideWithValue(ThemeMode.dark),
          ],
          child: const MooproApp(),
        ),
      );
      await tester.pump();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
    },
  );
}
