import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_unlock_gate.dart';

class LocalUnlockStore {
  final String vaultId;
  final FlutterSecureStorage _storage;
  final Future<bool> Function({required String reason}) _authenticate;

  LocalUnlockStore({
    this.vaultId = 'default',
    FlutterSecureStorage? storage,
    Future<bool> Function({required String reason})? authenticate,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _authenticate = authenticate ?? authenticateForLocalUnlock;

  String get _dekKey => 'vault_dek_local_unlock_$vaultId';
  String get _optedInKey => 'vault_local_unlock_opted_in_$vaultId';

  Future<bool> isOptedIn() async {
    final value = await _storage.read(key: _optedInKey);
    return value == 'true';
  }

  Future<void> enableAndStore(Uint8List dek) async {
    await _storage.write(key: _optedInKey, value: 'true');
    await _storage.write(key: _dekKey, value: base64Encode(dek));
  }

  Future<Uint8List?> readDek({bool challenge = true}) async {
    if (!await isOptedIn()) return null;
    final value = await _storage.read(key: _dekKey);
    if (value == null) return null;
    if (challenge && !await _authenticate(reason: 'Unlock your moopro vault')) {
      return null;
    }
    return base64Decode(value);
  }

  Future<void> clear() async {
    await _storage.delete(key: _dekKey);
    await _storage.delete(key: _optedInKey);
  }
}
