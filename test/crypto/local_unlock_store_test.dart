import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/crypto/local_unlock_store.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values.remove(key);
}

void main() {
  test('a fresh store is not opted in and has no cached DEK', () async {
    final store = LocalUnlockStore(
      vaultId: 'vault-a',
      storage: _FakeSecureStorage(),
    );

    expect(await store.isOptedIn(), isFalse);
    expect(await store.readDek(), isNull);
  });

  test('enableAndStore then readDek round-trips the DEK', () async {
    final store = LocalUnlockStore(
      vaultId: 'vault-a',
      storage: _FakeSecureStorage(),
    );
    final dek = Uint8List.fromList([1, 2, 3, 4]);

    await store.enableAndStore(dek);

    expect(await store.isOptedIn(), isTrue);
    expect(await store.readDek(), dek);
  });

  test('clear revokes local unlock', () async {
    final store = LocalUnlockStore(
      vaultId: 'vault-a',
      storage: _FakeSecureStorage(),
    );
    await store.enableAndStore(Uint8List.fromList([1, 2, 3]));

    await store.clear();

    expect(await store.isOptedIn(), isFalse);
    expect(await store.readDek(), isNull);
  });

  test('two vaults on the same underlying storage keep independent DEKs — '
      'the fix for local-unlock being a single device-global cache', () async {
    final storage = _FakeSecureStorage();
    final vaultA = LocalUnlockStore(vaultId: 'vault-a', storage: storage);
    final vaultB = LocalUnlockStore(vaultId: 'vault-b', storage: storage);

    await vaultA.enableAndStore(Uint8List.fromList([1, 1, 1]));

    expect(await vaultA.readDek(), Uint8List.fromList([1, 1, 1]));
    expect(await vaultB.isOptedIn(), isFalse);
    expect(await vaultB.readDek(), isNull);
  });

  test(
    'clearing one vault does not revoke another vault\'s cached DEK',
    () async {
      final storage = _FakeSecureStorage();
      final vaultA = LocalUnlockStore(vaultId: 'vault-a', storage: storage);
      final vaultB = LocalUnlockStore(vaultId: 'vault-b', storage: storage);
      await vaultA.enableAndStore(Uint8List.fromList([1, 1, 1]));
      await vaultB.enableAndStore(Uint8List.fromList([2, 2, 2]));

      await vaultA.clear();

      expect(await vaultA.readDek(), isNull);
      expect(await vaultB.readDek(), Uint8List.fromList([2, 2, 2]));
    },
  );

  group('biometric challenge', () {
    Future<(LocalUnlockStore, List<String>)> store({bool allow = true}) async {
      final reasons = <String>[];
      final s = LocalUnlockStore(
        vaultId: 'vault-a',
        storage: _FakeSecureStorage(),
        authenticate: ({required String reason}) async {
          reasons.add(reason);
          return allow;
        },
      );
      await s.enableAndStore(Uint8List.fromList([9, 9]));
      return (s, reasons);
    }

    test('readDek challenges by default', () async {
      final (s, reasons) = await store();
      expect(await s.readDek(), Uint8List.fromList([9, 9]));
      expect(reasons, hasLength(1));
    });

    test('a denied challenge returns null', () async {
      final (s, reasons) = await store(allow: false);
      expect(await s.readDek(), isNull);
      expect(reasons, hasLength(1));
    });

    test('readDek(challenge: false) skips the challenge', () async {
      final (s, reasons) = await store(allow: false);
      expect(await s.readDek(challenge: false), Uint8List.fromList([9, 9]));
      expect(reasons, isEmpty);
    });

    test('challenge: false still requires opt-in', () async {
      final s = LocalUnlockStore(
        storage: _FakeSecureStorage(),
        authenticate: ({required String reason}) async => true,
      );
      expect(await s.readDek(challenge: false), isNull);
    });
  });
}
