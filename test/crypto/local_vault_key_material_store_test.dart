import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/db/database.dart';

void main() {
  late AppDatabase db;
  late LocalVaultKeyMaterialStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalVaultKeyMaterialStore(db);
  });

  tearDown(() => db.close());

  test(
    'exists() is false and read() is null before anything is written',
    () async {
      expect(await store.exists(), isFalse);
      expect(await store.read(), isNull);
    },
  );

  test('write/read round-trips all fields', () async {
    final salt = Uint8List.fromList(List.generate(32, (i) => i));
    final wrappedDek = Uint8List.fromList(List.generate(48, (i) => 255 - i));
    final wrapNonce = Uint8List.fromList(List.generate(12, (i) => i * 2));
    const kdfParams = {'memory': 65536, 'iterations': 3, 'parallelism': 4};

    await store.write(
      kdfSalt: salt,
      kdfParams: kdfParams,
      wrappedDek: wrappedDek,
      wrapNonce: wrapNonce,
    );

    expect(await store.exists(), isTrue);
    final read = await store.read();
    expect(read, isNotNull);
    expect(read!.kdfSalt, equals(salt));
    expect(read.kdfParams, equals(kdfParams));
    expect(read.wrappedDek, equals(wrappedDek));
    expect(read.wrapNonce, equals(wrapNonce));
  });

  test(
    'write() overwrites the single row rather than inserting a second one',
    () async {
      final saltA = Uint8List.fromList([1, 2, 3]);
      final saltB = Uint8List.fromList([4, 5, 6]);
      final wrapped = Uint8List.fromList([9, 9, 9]);
      final nonce = Uint8List.fromList([7, 7, 7]);
      const params = {'memory': 1, 'iterations': 1, 'parallelism': 1};

      await store.write(
        kdfSalt: saltA,
        kdfParams: params,
        wrappedDek: wrapped,
        wrapNonce: nonce,
      );
      await store.write(
        kdfSalt: saltB,
        kdfParams: params,
        wrappedDek: wrapped,
        wrapNonce: nonce,
      );

      final rows = await db.select(db.localVaultKeyMaterial).get();
      expect(rows, hasLength(1));
      expect((await store.read())!.kdfSalt, equals(saltB));
    },
  );

  test('clear() removes the row', () async {
    await store.write(
      kdfSalt: Uint8List.fromList([1]),
      kdfParams: const {'memory': 1, 'iterations': 1, 'parallelism': 1},
      wrappedDek: Uint8List.fromList([2]),
      wrapNonce: Uint8List.fromList([3]),
    );
    expect(await store.exists(), isTrue);

    await store.clear();

    expect(await store.exists(), isFalse);
    expect(await store.read(), isNull);
  });

  test('clear() is a no-op when nothing was ever written', () async {
    await store.clear();
    expect(await store.exists(), isFalse);
  });
}
