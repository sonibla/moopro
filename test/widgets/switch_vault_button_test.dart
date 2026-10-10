import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/widgets/switch_vault_button.dart';

class _RecordingAuthController extends AuthController {
  int showVaultPickerCalls = 0;

  _RecordingAuthController(super.ref)
    : super(knownVaultsOverride: () async => []);

  @override
  Future<void> showVaultPicker() async => showVaultPickerCalls++;

  @override
  Future<void> logout() async => fail('switching vaults must not log out');
}

void main() {
  testWidgets('tapping it opens the vault list without logging out', (
    tester,
  ) async {
    late _RecordingAuthController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => controller = _RecordingAuthController(ref),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: SwitchVaultButton())),
        ),
      ),
    );

    expect(find.byTooltip('Switch vault'), findsOneWidget);
    await tester.tap(find.byTooltip('Switch vault'));

    expect(controller.showVaultPickerCalls, 1);
  });
}
