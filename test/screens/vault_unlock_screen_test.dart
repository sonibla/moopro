import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/vault_registry_database.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/screens/vault_unlock_screen.dart';
import 'package:moopro/vault/vault_registry.dart';

class _FakeVaultSessionManager extends VaultSessionManager {
  bool failOfflineUnlock;

  Completer<void>? setupGate;
  Uint8List? _dek;
  int enableLocalUnlockCalls = 0;

  _FakeVaultSessionManager({this.failOfflineUnlock = false, this.setupGate})
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
  Future<void> enableLocalUnlock() async => enableLocalUnlockCalls++;

  @override
  Future<void> completeOfflineVaultSetup({required String password}) async {
    if (setupGate != null) await setupGate!.future;
    _dek = Uint8List.fromList(const [1, 2, 3]);
  }

  @override
  Future<void> unlockOffline({required String password}) async {
    if (failOfflineUnlock) throw const InvalidMasterPasswordException();
    _dek = Uint8List.fromList(const [1, 2, 3]);
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('offline setup state shows "Create local vault" copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = const AuthOfflineNeedsSetup();
            return controller;
          }),
        ],
        child: const MaterialApp(home: VaultUnlockScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Create local vault'), findsOneWidget);
    expect(find.text('Create vault'), findsOneWidget);
    expect(find.textContaining('There is no server involved'), findsOneWidget);
  });

  testWidgets(
    'submitting offline setup unlocks and the controller lands on AuthOfflineReady',
    (tester) async {
      final vaultSession = _FakeVaultSessionManager();
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(
            VaultRegistry(VaultRegistryDatabase(NativeDatabase.memory())),
          ),
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = const AuthOfflineNeedsSetup();
            return controller;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultUnlockScreen()),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'),
        'hunter2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm master password'),
        'hunter2',
      );
      await tester.ensureVisible(find.text('Create vault'));
      await tester.tap(find.text('Create vault'));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
    },
  );

  testWidgets('setup is blocked and shows an error when the passwords differ', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        vaultSessionManagerProvider.overrideWithValue(
          _FakeVaultSessionManager(),
        ),
        authControllerProvider.overrideWith((ref) {
          final controller = AuthController(
            ref,
            knownVaultsOverride: () async => [],
          );
          controller.state = const AuthOfflineNeedsSetup();
          return controller;
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultUnlockScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Master password'),
      'hunter2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm master password'),
      'hunter3',
    );
    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(
      container.read(authControllerProvider),
      isA<AuthOfflineNeedsSetup>(),
    );
  });

  testWidgets('unlock (not setup) has no confirm field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = const AuthOfflineNeedsUnlock();
            return controller;
          }),
        ],
        child: const MaterialApp(home: VaultUnlockScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Confirm master password'), findsNothing);
  });

  testWidgets('offline unlock state shows "Unlock local vault" copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = const AuthOfflineNeedsUnlock();
            return controller;
          }),
        ],
        child: const MaterialApp(home: VaultUnlockScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Unlock local vault'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('offline unlock with the wrong password shows an error and '
      'stays on the unlock screen', (tester) async {
    final vaultSession = _FakeVaultSessionManager(failOfflineUnlock: true);
    final container = ProviderContainer(
      overrides: [
        vaultSessionManagerProvider.overrideWithValue(vaultSession),
        authControllerProvider.overrideWith((ref) {
          final controller = AuthController(
            ref,
            knownVaultsOverride: () async => [],
          );
          controller.state = const AuthOfflineNeedsUnlock();
          return controller;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VaultUnlockScreen()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password.'), findsOneWidget);
    expect(
      container.read(authControllerProvider),
      isA<AuthOfflineNeedsUnlock>(),
    );
  });

  testWidgets(
    'stays on "Create local vault" copy (not "Unlock local vault") while '
    'the setup call is still in flight — regression test for a caught '
    'flicker: AuthOfflineUnlocking carries no setup-vs-unlock flag, so '
    'deriving the title purely from authState briefly showed the wrong '
    'copy between tapping "Create vault" and the call resolving',
    (tester) async {
      final setupGate = Completer<void>();
      final vaultSession = _FakeVaultSessionManager(setupGate: setupGate);
      final container = ProviderContainer(
        overrides: [
          vaultRegistryProvider.overrideWithValue(
            VaultRegistry(VaultRegistryDatabase(NativeDatabase.memory())),
          ),
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = const AuthOfflineNeedsSetup();
            return controller;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultUnlockScreen()),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Master password'),
        'hunter2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm master password'),
        'hunter2',
      );
      await tester.ensureVisible(find.text('Create vault'));
      await tester.tap(find.text('Create vault'));
      await tester.pump();

      expect(
        container.read(authControllerProvider),
        isA<AuthOfflineUnlocking>(),
      );
      expect(find.text('Create local vault'), findsOneWidget);
      expect(find.text('Unlock local vault'), findsNothing);

      setupGate.complete();
      await tester.pumpAndSettle();
      expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
    },
  );

  group('back navigation', () {
    Future<ProviderContainer> pumpAt(
      WidgetTester tester,
      AuthFlowState from, {
      required int vaultCount,
    }) async {
      final registry = VaultRegistry(
        VaultRegistryDatabase(NativeDatabase.memory()),
      );
      await tester.runAsync(() async {
        for (var i = 0; i < vaultCount; i++) {
          await registry.createOfflineVault(label: 'Vault $i');
        }
      });
      final container = ProviderContainer(
        overrides: [
          vaultSessionManagerProvider.overrideWithValue(
            _FakeVaultSessionManager(),
          ),
          vaultRegistryProvider.overrideWithValue(registry),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: registry.list,
            );
            controller.state = from;
            return controller;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultUnlockScreen()),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets(
      'offline first-setup screen has a back button to the vault picker '
      '(regression: it used to be a dead end)',
      (tester) async {
        final container = await pumpAt(
          tester,
          const AuthOfflineNeedsSetup(),
          vaultCount: 1,
        );

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(
          container.read(authControllerProvider),
          isA<AuthNeedsVaultSelection>(),
        );
      },
    );

    testWidgets('back with no known vaults lands on the login screen', (
      tester,
    ) async {
      final container = await pumpAt(
        tester,
        const AuthOfflineNeedsSetup(),
        vaultCount: 0,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });

    testWidgets('system back follows the same path as the back button', (
      tester,
    ) async {
      final container = await pumpAt(
        tester,
        const AuthOfflineNeedsUnlock(),
        vaultCount: 1,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        container.read(authControllerProvider),
        isA<AuthNeedsVaultSelection>(),
      );
    });

    testWidgets('back is hidden and system back ignored while unlocking', (
      tester,
    ) async {
      final container = await pumpAt(
        tester,
        const AuthOfflineUnlocking(),
        vaultCount: 1,
      );

      expect(find.byType(BackButton), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(
        container.read(authControllerProvider),
        isA<AuthOfflineUnlocking>(),
      );
    });
  });

  group('save master key checkbox', () {
    Future<ProviderContainer> pumpUnlock(
      WidgetTester tester,
      _FakeVaultSessionManager vaultSession,
    ) async {
      final container = ProviderContainer(
        overrides: [
          vaultSessionManagerProvider.overrideWithValue(vaultSession),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            controller.state = const AuthOfflineNeedsUnlock();
            return controller;
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultUnlockScreen()),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('is unticked by default and nothing is saved on unlock', (
      tester,
    ) async {
      final vaultSession = _FakeVaultSessionManager();
      final container = await pumpUnlock(tester, vaultSession);

      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.enterText(find.byType(TextFormField), 'pw');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
      expect(vaultSession.enableLocalUnlockCalls, 0);
    });

    testWidgets('ticked: the key is saved after a successful unlock', (
      tester,
    ) async {
      final vaultSession = _FakeVaultSessionManager();
      final container = await pumpUnlock(tester, vaultSession);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(find.byType(TextFormField), 'pw');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(container.read(authControllerProvider), isA<AuthOfflineReady>());
      expect(vaultSession.enableLocalUnlockCalls, 1);
    });

    testWidgets('ticked but wrong password: nothing is saved', (tester) async {
      final vaultSession = _FakeVaultSessionManager(failOfflineUnlock: true);
      await pumpUnlock(tester, vaultSession);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.enterText(find.byType(TextFormField), 'wrong');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect password.'), findsOneWidget);
      expect(vaultSession.enableLocalUnlockCalls, 0);
    });
  });
}
