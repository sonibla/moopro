import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/zip_file_helper.dart';

Uint8List _buildZip(Map<String, String> filesByPath, {String? password}) {
  final archive = Archive();
  for (final entry in filesByPath.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder(password: password).encodeBytes(archive);
}

Uint8List _buildZeroCrcZip(
  Map<String, String> filesByPath, {
  required String password,
}) {
  final archive = Archive();
  for (final entry in filesByPath.entries) {
    final file = ArchiveFile.string(entry.key, entry.value)..crc32 = 0;
    archive.addFile(file);
  }
  return ZipEncoder(password: password).encodeBytes(archive);
}

const _legacyZipCryptoBase64 =
    'UEsDBAoACQAAAIKLOV1hwJEcFgAAAAoAAAARABwAcGVyc29uYWxiYW5rLmpzb25VVAkAAwOTtmoDk7ZqdXgLAAEE6AMAAAToAwAAipd2hwAqTdwjQn4VXJkGM3gs8KhFelBLBwhhwJEcFgAAAAoAAABQSwECHgMKAAkAAACCizldYcCRHBYAAAAKAAAAEQAYAAAAAAABAAAApIEAAAAAcGVyc29uYWxiYW5rLmpzb25VVAUAAwOTtmp1eAsAAQToAwAABOgDAABQSwUGAAAAAAEAAQBXAAAAcQAAAAAA';
const _aes256Base64 =
    'UEsDBDMDAQBjAIKLOV0AAAAAJgAAAAoAAAARAAsAcGVyc29uYWxiYW5rLmpzb24BmQcAAgBBRQMAANnCG6IG2W+m2upUWBfoOl6UAWh/4U+mT5IMou14qfmnpQ1WzPV/UEsBAj8DMwMBAGMAgos5XQAAAAAmAAAACgAAABEALwAAAAAAAAAggKSBAAAAAHBlcnNvbmFsYmFuay5qc29uCgAgAAAAAAABABgAgMNzdAJN3QGASgd4Ak3dAYDDc3QCTd0BAZkHAAIAQUUDAABQSwUGAAAAAAEAAQBuAAAAYAAAAAAA';

const _unixExtraFieldAheadOfAesBase64 =
    'UEsDBBQACQBjAP2MOV0AAAAAAAAAAAAAAAAEACsAdGVzdHV4CwABBOgDAAAE6AMAAAGZBwACAEFFAwgAVVQNAAfPlbZqz5W2as+VtmoLHQqhKHKsZI9UFOp2dWth2xFR8Mao7lHuPbhHBHrvfkcY345QSwcIAAAAACQAAAAGAAAAUEsBAhQDFAAJAGMA/Yw5XQAAAAAkAAAABgAAAAQAIwAAAAAAAAAAAKSBAAAAAHRlc3R1eAsAAQToAwAABOgDAAABmQcAAgBBRQMIAFVUBQABz5W2alBLBQYAAAAAAQABAFUAAACBAAAAAAA=';

void main() {
  group('looksLikeZip', () {
    test('matches only the .zip extension, case-insensitively', () {
      expect(looksLikeZip('statements.zip'), isTrue);
      expect(looksLikeZip('STATEMENTS.ZIP'), isTrue);
      expect(looksLikeZip('statement.pdf'), isFalse);
    });
  });

  group('extractZip', () {
    test('extracts every entry, preserving nested subfolder paths', () {
      final bytes = _buildZip({
        'root.csv': 'a,b,c',
        '2024/boursorama/releve_janvier.pdf': 'fake pdf bytes',
        '2024/fortuneo/export.csv': 'x,y,z',
      });

      final entries = extractZip(bytes);

      final byPath = {for (final e in entries) e.path: utf8.decode(e.bytes)};
      expect(byPath, {
        'root.csv': 'a,b,c',
        '2024/boursorama/releve_janvier.pdf': 'fake pdf bytes',
        '2024/fortuneo/export.csv': 'x,y,z',
      });
    });

    test('extracts a password-protected zip given the correct password', () {
      final bytes = _buildZip({
        'statement.csv': '[{}]',
      }, password: 'correct horse');

      final entries = extractZip(bytes, password: 'correct horse');

      expect(entries, hasLength(1));
      expect(utf8.decode(entries.single.bytes), '[{}]');
    });

    test('throws ZipPasswordRequiredException when no password is given for an '
        'encrypted archive', () {
      final bytes = _buildZip({
        'statement.csv': '[{}]',
      }, password: 'correct horse');

      expect(
        () => extractZip(bytes),
        throwsA(isA<ZipPasswordRequiredException>()),
      );
    });

    test(
      'throws ZipWrongPasswordException when the given password is wrong',
      () {
        final bytes = _buildZip({
          'statement.csv': '[{}]',
        }, password: 'correct horse');

        expect(
          () => extractZip(bytes, password: 'wrong password'),
          throwsA(isA<ZipWrongPasswordException>()),
        );
      },
    );

    test(
      'extracts an archive with thousands of small entries without a size-based '
      'rejection',
      () {
        final bytes = _buildZip({
          for (var i = 0; i < 2000; i++) 'file$i.txt': 'x',
        });

        final entries = extractZip(bytes);

        expect(entries, hasLength(2000));
      },
    );

    group(
      'AE-2-shaped archive (stored CRC-32 of 0, as real AES tools produce)',
      () {
        test(
          'extracts successfully with the correct password despite the zero CRC',
          () {
            final bytes = _buildZeroCrcZip({
              'statement.csv': '[{}]',
            }, password: 'correct horse');

            final entries = extractZip(bytes, password: 'correct horse');

            expect(entries, hasLength(1));
            expect(utf8.decode(entries.single.bytes), '[{}]');
          },
        );

        test(
          'still throws ZipWrongPasswordException for an actually wrong password',
          () {
            final bytes = _buildZeroCrcZip({
              'statement.csv': '[{}]',
            }, password: 'correct horse');

            expect(
              () => extractZip(bytes, password: 'wrong password'),
              throwsA(isA<ZipWrongPasswordException>()),
            );
          },
        );
      },
    );

    group('real-world fixtures (built with independent, non-Dart tools)', () {
      test(
        'legacy ZipCrypto zip (system `zip -P`) with the correct ASCII password',
        () {
          final bytes = base64Decode(_legacyZipCryptoBase64);

          final entries = extractZip(bytes, password: 'correct horse');

          expect(entries, hasLength(1));
          expect(utf8.decode(entries.single.bytes).trim(), '[{"a":1}]');
        },
      );

      test('legacy ZipCrypto zip rejects a wrong password', () {
        final bytes = base64Decode(_legacyZipCryptoBase64);

        expect(
          () => extractZip(bytes, password: 'wrong password'),
          throwsA(isA<ZipWrongPasswordException>()),
        );
      });

      test(
        'AES-256 zip (system `7z -mem=AES256`) with the correct ASCII password',
        () {
          final bytes = base64Decode(_aes256Base64);

          final entries = extractZip(bytes, password: 'correct horse');

          expect(entries, hasLength(1));
          expect(utf8.decode(entries.single.bytes).trim(), '[{"a":1}]');
        },
      );

      test('AES-256 zip rejects a wrong password', () {
        final bytes = base64Decode(_aes256Base64);

        expect(
          () => extractZip(bytes, password: 'wrong password'),
          throwsA(isA<ZipWrongPasswordException>()),
        );
      });

      test(
        'a Unix-UID/GID-then-AES-extra-field zip extracts with the correct password',
        () {
          final bytes = base64Decode(_unixExtraFieldAheadOfAesBase64);

          final entries = extractZip(bytes, password: 'pass');

          expect(entries, hasLength(1));
          expect(utf8.decode(entries.single.bytes).trim(), 'hehe');
        },
      );

      test(
        'a Unix-UID/GID-then-AES-extra-field zip still rejects a wrong password',
        () {
          final bytes = base64Decode(_unixExtraFieldAheadOfAesBase64);

          expect(
            () => extractZip(bytes, password: 'wrong'),
            throwsA(isA<ZipWrongPasswordException>()),
          );
        },
      );
    });
  });
}
