import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/crypto/vault_crypto.dart';
import 'package:moopro/db/database.dart';

class _CapturingAuthApi extends AuthApi {
  Uint8List? capturedKdfSalt;
  Map<String, dynamic>? capturedKdfParams;
  Uint8List? capturedWrappedDek;
  Uint8List? capturedWrapNonce;

  _CapturingAuthApi() : super(ApiClient());

  @override
  Future<VaultKeyMaterialResponse> setVaultKeyMaterial({
    required Uint8List kdfSalt,
    required Map<String, dynamic> kdfParams,
    required Uint8List wrappedDek,
    required Uint8List wrapNonce,
  }) async {
    capturedKdfSalt = kdfSalt;
    capturedKdfParams = kdfParams;
    capturedWrappedDek = wrappedDek;
    capturedWrapNonce = wrapNonce;
    return VaultKeyMaterialResponse(
      hasVaultKeyMaterial: true,
      kdfSalt: kdfSalt,
      kdfParams: kdfParams,
      wrappedDek: wrappedDek,
      wrapNonce: wrapNonce,
    );
  }
}

void main() {
  late AppDatabase db;
  late VaultSessionManager session;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    session = VaultSessionManager(
      authApi: AuthApi(ApiClient()),
      localUnlockStore: LocalUnlockStore(),
      localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(db),
    );
  });

  tearDown(() => db.close());

  const slowKdf = Timeout(Duration(minutes: 3));

  group('offline vault', () {
    test('hasLocalOfflineVault is false before any setup', () async {
      expect(await session.hasLocalOfflineVault(), isFalse);
    });

    test(
      'completeOfflineVaultSetup then unlockOffline with the same password '
      'recovers the same DEK',
      timeout: slowKdf,
      () async {
        await session.completeOfflineVaultSetup(password: 'hunter2');
        final dekAfterSetup = session.currentDek;
        expect(dekAfterSetup, isNotNull);
        expect(await session.hasLocalOfflineVault(), isTrue);

        session.lock();
        expect(session.currentDek, isNull);

        await session.unlockOffline(password: 'hunter2');

        expect(session.currentDek, equals(dekAfterSetup));
      },
    );

    test(
      'unlockOffline with the wrong password throws and leaves the vault locked',
      timeout: slowKdf,
      () async {
        await session.completeOfflineVaultSetup(password: 'hunter2');
        session.lock();

        await expectLater(
          () => session.unlockOffline(password: 'wrong'),
          throwsA(isA<InvalidMasterPasswordException>()),
        );
        expect(session.currentDek, isNull);
      },
    );

    test('unlockOffline throws VaultAlreadyInitializedException if no offline '
        'vault was ever set up', () async {
      await expectLater(
        () => session.unlockOffline(password: 'anything'),
        throwsA(isA<VaultAlreadyInitializedException>()),
      );
    });

    test(
      'clearLocalOfflineVault removes the local key material',
      timeout: slowKdf,
      () async {
        await session.completeOfflineVaultSetup(password: 'hunter2');
        expect(await session.hasLocalOfflineVault(), isTrue);

        await session.clearLocalOfflineVault();

        expect(await session.hasLocalOfflineVault(), isFalse);
      },
    );
  });

  group('attach simulation', () {
    test(
      'rewrapDekAfterPasswordChange re-wraps the same DEK under a new '
      'password-derived KEK — the "attach" operation reuses this '
      'unchanged, so the new material must unwrap to the identical DEK',
      timeout: slowKdf,
      () async {
        final authApi = _CapturingAuthApi();
        final attachSession = VaultSessionManager(
          authApi: authApi,
          localUnlockStore: LocalUnlockStore(),
          localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(db),
        );
        await attachSession.completeOfflineVaultSetup(
          password: 'offline-password',
        );
        final dekBeforeAttach = attachSession.currentDek;

        await attachSession.rewrapDekAfterPasswordChange(
          newPassword: 'real-account-password',
        );

        expect(attachSession.currentDek, equals(dekBeforeAttach));

        final newSalt = authApi.capturedKdfSalt;
        final newWrappedDek = authApi.capturedWrappedDek;
        final newWrapNonce = authApi.capturedWrapNonce;
        expect(newSalt, isNotNull);
        expect(newWrappedDek, isNotNull);
        expect(newWrapNonce, isNotNull);

        final kek = await VaultCrypto.deriveKek(
          password: 'real-account-password',
          kdfSalt: newSalt!,
        );
        final unwrapped = await VaultCrypto.unwrapDek(
          wrappedDek: newWrappedDek!,
          wrapNonce: newWrapNonce!,
          kek: kek,
        );
        expect(unwrapped, equals(dekBeforeAttach));
      },
    );
  });
}
