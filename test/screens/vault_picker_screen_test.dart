import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/screens/vault_picker_screen.dart';
import 'package:moopro/vault/vault_registry.dart';

final _onlineVault = VaultRegistryEntry(
  id: 'online-1',
  dbName: 'moopro_vault_online-1',
  kind: VaultKind.online,
  label: 'alice@example.com',
  email: 'alice@example.com',
  createdAt: DateTime(2026, 1, 1),
  lastOpenedAt: DateTime(2026, 1, 1),
);

final _offlineVault = VaultRegistryEntry(
  id: 'offline-1',
  dbName: 'moopro_vault_offline-1',
  kind: VaultKind.offline,
  label: 'Home vault',
  email: null,
  createdAt: DateTime(2026, 1, 2),
  lastOpenedAt: DateTime(2026, 1, 2),
);

class _RecordingAuthController extends AuthController {
  String? lastAction;
  VaultRegistryEntry? lastVault;
  Object? deleteVaultError;

  _RecordingAuthController(super.ref)
    : super(knownVaultsOverride: () async => []);

  @override
  Future<void> selectVault(VaultRegistryEntry vault) async {
    lastAction = 'selectVault';
    lastVault = vault;
  }

  @override
  void startOfflineSetup() {
    lastAction = 'startOfflineSetup';
    state = const AuthOfflineNeedsSetup();
  }

  @override
  void returnToLoginScreen() {
    lastAction = 'returnToLoginScreen';
    state = const AuthLoggedOut();
  }

  @override
  Future<void> deleteVault(VaultRegistryEntry entry) async {
    lastAction = 'deleteVault';
    lastVault = entry;
    if (deleteVaultError != null) throw deleteVaultError!;
  }
}

void main() {
  late _RecordingAuthController controller;

  Future<void> pump(
    WidgetTester tester, {
    required List<VaultRegistryEntry> vaults,
    VaultRegistryEntry? active,
    Set<String> connectedEmails = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (active != null) activeVaultProvider.overrideWith((ref) => active),
          authControllerProvider.overrideWith((ref) {
            controller = _RecordingAuthController(ref);
            controller.state = AuthNeedsVaultSelection(
              vaults,
              connectedEmails: connectedEmails,
            );
            return controller;
          }),
        ],
        child: const MaterialApp(home: VaultPickerScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists every known vault with its kind/email', (tester) async {
    await pump(tester, vaults: [_onlineVault, _offlineVault]);

    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('Home vault'), findsOneWidget);
    expect(find.textContaining('Offline vault'), findsOneWidget);
  });

  testWidgets('marks online accounts that still have a session as '
      'Connected, the others as Sign-in required', (tester) async {
    final other = VaultRegistryEntry(
      id: 'online-2',
      dbName: 'moopro_vault_online-2',
      kind: VaultKind.online,
      label: 'bob@example.com',
      email: 'bob@example.com',
      createdAt: DateTime(2026, 1, 3),
      lastOpenedAt: DateTime(2026, 1, 3),
    );
    await pump(
      tester,
      vaults: [_onlineVault, other, _offlineVault],
      connectedEmails: {'alice@example.com'},
    );

    expect(find.textContaining('Connected'), findsOneWidget);
    expect(find.textContaining('Sign-in required'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('shows the empty state plus both add actions with 0 vaults', (
    tester,
  ) async {
    await pump(tester, vaults: const []);

    expect(find.text('No vaults on this device yet.'), findsOneWidget);
    expect(find.text('Log into an account'), findsOneWidget);
    expect(find.text('Create a new offline vault'), findsOneWidget);
  });

  testWidgets('tapping a vault calls selectVault with that entry', (
    tester,
  ) async {
    await pump(tester, vaults: [_offlineVault]);

    await tester.tap(find.text('Home vault'));

    expect(controller.lastAction, 'selectVault');
    expect(controller.lastVault, _offlineVault);
  });

  testWidgets('"Log into an account" returns to the login screen', (
    tester,
  ) async {
    await pump(tester, vaults: [_offlineVault]);

    await tester.tap(find.text('Log into an account'));

    expect(controller.lastAction, 'returnToLoginScreen');
  });

  testWidgets('"Create a new offline vault" starts offline setup', (
    tester,
  ) async {
    await pump(tester, vaults: [_offlineVault]);

    await tester.tap(find.text('Create a new offline vault'));

    expect(controller.lastAction, 'startOfflineSetup');
  });

  testWidgets(
    'delete is enabled for every vault, even if one is still marked active',
    (tester) async {
      await pump(tester, vaults: [_offlineVault], active: _offlineVault);

      final deleteButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(deleteButton.onPressed, isNotNull);
    },
  );

  testWidgets('confirming delete on a non-active vault calls deleteVault', (
    tester,
  ) async {
    await pump(tester, vaults: [_offlineVault]);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Home vault"?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(controller.lastAction, 'deleteVault');
    expect(controller.lastVault, _offlineVault);
  });

  testWidgets(
    'a refused delete (active+unlocked, raced) shows a snackbar instead of crashing',
    (tester) async {
      await pump(tester, vaults: [_offlineVault]);
      controller.deleteVaultError = const ActiveVaultCannotBeDeletedException();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Switch to a different vault before deleting this one.'),
        findsOneWidget,
      );
    },
  );
}
