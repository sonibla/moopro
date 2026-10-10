import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/crypto/kdf_params.dart';
import 'package:moopro/crypto/vault_crypto.dart';

const _testKdfParams = KdfParams(memory: 8, iterations: 1, parallelism: 1);

void main() {
  group('KEK derivation + DEK wrap/unwrap', () {
    test('derives a deterministic KEK from the same password+salt', () async {
      final salt = VaultCrypto.generateKdfSalt();
      final kek1 = await VaultCrypto.deriveKek(
        password: 'correct horse',
        kdfSalt: salt,
        params: _testKdfParams,
      );
      final kek2 = await VaultCrypto.deriveKek(
        password: 'correct horse',
        kdfSalt: salt,
        params: _testKdfParams,
      );
      expect(await kek1.extractBytes(), equals(await kek2.extractBytes()));
    });

    test('different passwords derive different KEKs', () async {
      final salt = VaultCrypto.generateKdfSalt();
      final kek1 = await VaultCrypto.deriveKek(
        password: 'password one',
        kdfSalt: salt,
        params: _testKdfParams,
      );
      final kek2 = await VaultCrypto.deriveKek(
        password: 'password two',
        kdfSalt: salt,
        params: _testKdfParams,
      );
      expect(
        await kek1.extractBytes(),
        isNot(equals(await kek2.extractBytes())),
      );
    });

    test('wrap then unwrap recovers the original DEK', () async {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.generateKdfSalt();
      final kek = await VaultCrypto.deriveKek(
        password: 'hunter2',
        kdfSalt: salt,
        params: _testKdfParams,
      );

      final wrapped = await VaultCrypto.wrapDek(dek: dek, kek: kek);
      final unwrapped = await VaultCrypto.unwrapDek(
        wrappedDek: wrapped.wrappedDek,
        wrapNonce: wrapped.wrapNonce,
        kek: kek,
      );

      expect(unwrapped, equals(dek));
    });

    test('unwrap with the wrong password throws', () async {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.generateKdfSalt();
      final correctKek = await VaultCrypto.deriveKek(
        password: 'right password',
        kdfSalt: salt,
        params: _testKdfParams,
      );
      final wrongKek = await VaultCrypto.deriveKek(
        password: 'wrong password',
        kdfSalt: salt,
        params: _testKdfParams,
      );

      final wrapped = await VaultCrypto.wrapDek(dek: dek, kek: correctKek);

      expect(
        () => VaultCrypto.unwrapDek(
          wrappedDek: wrapped.wrappedDek,
          wrapNonce: wrapped.wrapNonce,
          kek: wrongKek,
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('wrapped DEK fits within the backend\'s size bounds', () async {
      final dek = VaultCrypto.generateDek();
      final salt = VaultCrypto.generateKdfSalt();
      final kek = await VaultCrypto.deriveKek(
        password: 'x',
        kdfSalt: salt,
        params: _testKdfParams,
      );
      final wrapped = await VaultCrypto.wrapDek(dek: dek, kek: kek);

      expect(wrapped.wrappedDek.length, greaterThanOrEqualTo(32));
      expect(wrapped.wrappedDek.length, lessThanOrEqualTo(128));
      expect(wrapped.wrapNonce.length, equals(12));
    });
  });

  group('Record encryption', () {
    final dek = VaultCrypto.generateDek();

    test('encrypt then decrypt recovers the original plaintext', () async {
      final plaintext = Uint8List.fromList(utf8.encode('{"amount": "42.00"}'));
      final encrypted = await VaultCrypto.encryptRecord(
        dek: dek,
        recordId: 'deadbeef',
        type: 'transaction',
        plaintext: plaintext,
      );
      final decrypted = await VaultCrypto.decryptRecord(
        dek: dek,
        recordId: 'deadbeef',
        type: 'transaction',
        ciphertext: encrypted.ciphertext,
        nonce: encrypted.nonce,
      );
      expect(decrypted, equals(plaintext));
    });

    test('decrypting with the wrong DEK throws', () async {
      final otherDek = VaultCrypto.generateDek();
      final plaintext = Uint8List.fromList(utf8.encode('secret'));
      final encrypted = await VaultCrypto.encryptRecord(
        dek: dek,
        recordId: 'id1',
        type: 'asset',
        plaintext: plaintext,
      );
      expect(
        () => VaultCrypto.decryptRecord(
          dek: otherDek,
          recordId: 'id1',
          type: 'asset',
          ciphertext: encrypted.ciphertext,
          nonce: encrypted.nonce,
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test(
      'AAD binds the ciphertext to its record id — id swap is detected',
      () async {
        final plaintext = Uint8List.fromList(utf8.encode('secret'));
        final encrypted = await VaultCrypto.encryptRecord(
          dek: dek,
          recordId: 'record-a',
          type: 'container',
          plaintext: plaintext,
        );
        expect(
          () => VaultCrypto.decryptRecord(
            dek: dek,
            recordId: 'record-b',
            type: 'container',
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
          ),
          throwsA(isA<VaultCryptoException>()),
        );
      },
    );

    test(
      'AAD binds the ciphertext to its type — type relabel is detected',
      () async {
        final plaintext = Uint8List.fromList(utf8.encode('secret'));
        final encrypted = await VaultCrypto.encryptRecord(
          dek: dek,
          recordId: 'record-a',
          type: 'container',
          plaintext: plaintext,
        );
        expect(
          () => VaultCrypto.decryptRecord(
            dek: dek,
            recordId: 'record-a',
            type: 'asset',
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
          ),
          throwsA(isA<VaultCryptoException>()),
        );
      },
    );

    test('tampering with a single ciphertext byte is detected', () async {
      final plaintext = Uint8List.fromList(utf8.encode('secret'));
      final encrypted = await VaultCrypto.encryptRecord(
        dek: dek,
        recordId: 'id1',
        type: 'asset',
        plaintext: plaintext,
      );
      final tampered = Uint8List.fromList(encrypted.ciphertext);
      tampered[0] ^= 0xFF;
      expect(
        () => VaultCrypto.decryptRecord(
          dek: dek,
          recordId: 'id1',
          type: 'asset',
          ciphertext: tampered,
          nonce: encrypted.nonce,
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('two encryptions of the same plaintext use different nonces and '
        'ciphertexts', () async {
      final plaintext = Uint8List.fromList(utf8.encode('same content'));
      final first = await VaultCrypto.encryptRecord(
        dek: dek,
        recordId: 'id1',
        type: 'asset',
        plaintext: plaintext,
      );
      final second = await VaultCrypto.encryptRecord(
        dek: dek,
        recordId: 'id1',
        type: 'asset',
        plaintext: plaintext,
      );
      expect(first.nonce, isNot(equals(second.nonce)));
      expect(first.ciphertext, isNot(equals(second.ciphertext)));
    });
  });
}
