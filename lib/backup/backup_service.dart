import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_pg/dart_pg.dart';
import 'package:flutter/foundation.dart' show compute;

import 'backup_models.dart';

class BackupDecryptException implements Exception {
  final String message;
  const BackupDecryptException(this.message);

  @override
  String toString() => 'BackupDecryptException: $message';
}

typedef EncryptArgs = ({String json, String password});
typedef DecryptArgs = ({String armored, String password});

String encryptIsolateEntry(EncryptArgs args) {
  final bytes = Uint8List.fromList(utf8.encode(args.json));
  return OpenPGP.encryptBinaryData(bytes, passwords: [args.password]).armor();
}

String decryptIsolateEntry(DecryptArgs args) {
  final message = OpenPGP.decrypt(args.armored, passwords: [args.password]);
  return utf8.decode(message.literalData.binary);
}

class BackupService {
  final Future<String> Function(EncryptArgs) _runEncrypt;
  final Future<String> Function(DecryptArgs) _runDecrypt;

  BackupService({
    Future<String> Function(EncryptArgs)? runEncrypt,
    Future<String> Function(DecryptArgs)? runDecrypt,
  }) : _runEncrypt =
           runEncrypt ?? ((args) => compute(encryptIsolateEntry, args)),
       _runDecrypt =
           runDecrypt ?? ((args) => compute(decryptIsolateEntry, args));

  Future<String> exportBackup({
    required BackupPayload payload,
    required String password,
  }) async {
    final json = jsonEncode(payload.toJson());
    return _runEncrypt((json: json, password: password));
  }

  Future<BackupPayload> decryptBackup({
    required String armored,
    required String password,
  }) async {
    final String json;
    try {
      json = await _runDecrypt((armored: armored, password: password));
    } catch (e) {
      throw BackupDecryptException('Failed to decrypt: $e');
    }
    try {
      return BackupPayload.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on FormatException catch (e) {
      throw BackupDecryptException('Not a valid backup file: $e');
    }
  }
}
