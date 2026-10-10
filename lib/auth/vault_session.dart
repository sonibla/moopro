import 'dart:typed_data';

import '../api/auth_api.dart';
import '../crypto/kdf_params.dart';
import '../crypto/local_unlock_store.dart';
import '../crypto/local_vault_key_material_store.dart';
import '../crypto/vault_crypto.dart';

class InvalidMasterPasswordException implements Exception {
  const InvalidMasterPasswordException();
}

class VaultAlreadyInitializedException implements Exception {
  const VaultAlreadyInitializedException();
}

class VaultSessionManager {
  final AuthApi authApi;
  final LocalUnlockStore localUnlockStore;
  final LocalVaultKeyMaterialStore localVaultKeyMaterialStore;

  Uint8List? _dek;

  VaultSessionManager({
    required this.authApi,
    required this.localUnlockStore,
    required this.localVaultKeyMaterialStore,
  });

  Uint8List? get currentDek => _dek;
  bool get isUnlocked => _dek != null;

  Future<void> completeInitialVaultSetup({required String password}) async {
    final existing = await authApi.getVaultKeyMaterial();
    if (existing.hasVaultKeyMaterial) {
      throw const VaultAlreadyInitializedException();
    }
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.generateKdfSalt();
    final kek = await VaultCrypto.deriveKek(password: password, kdfSalt: salt);
    final wrapped = await VaultCrypto.wrapDek(dek: dek, kek: kek);
    await authApi.setVaultKeyMaterial(
      kdfSalt: salt,
      kdfParams: KdfParams.defaults.toJson(),
      wrappedDek: wrapped.wrappedDek,
      wrapNonce: wrapped.wrapNonce,
    );
    _dek = dek;
  }

  Future<void> unlock({required String password}) async {
    final material = await authApi.getVaultKeyMaterial();
    if (!material.hasVaultKeyMaterial ||
        material.kdfSalt == null ||
        material.kdfParams == null ||
        material.wrappedDek == null ||
        material.wrapNonce == null) {
      throw const VaultAlreadyInitializedException();
    }
    final params = KdfParams.fromJson(material.kdfParams!);
    final kek = await VaultCrypto.deriveKek(
      password: password,
      kdfSalt: material.kdfSalt!,
      params: params,
    );
    try {
      _dek = await VaultCrypto.unwrapDek(
        wrappedDek: material.wrappedDek!,
        wrapNonce: material.wrapNonce!,
        kek: kek,
      );
    } on VaultCryptoException {
      throw const InvalidMasterPasswordException();
    }
  }

  Future<bool> tryUnlockFromLocalCache({bool challenge = true}) async {
    final cached = await localUnlockStore.readDek(challenge: challenge);
    if (cached == null) return false;
    _dek = cached;
    return true;
  }

  Future<void> enableLocalUnlock() async {
    final dek = _dek;
    if (dek == null) {
      throw StateError('Cannot enable local unlock: vault is not unlocked');
    }
    await localUnlockStore.enableAndStore(dek);
  }

  Future<void> disableLocalUnlock() => localUnlockStore.clear();

  Future<void> rewrapDekAfterPasswordChange({
    required String newPassword,
  }) async {
    final dek = _dek;
    if (dek == null) {
      throw StateError('Cannot rewrap DEK: vault is not unlocked');
    }
    final salt = VaultCrypto.generateKdfSalt();
    final kek = await VaultCrypto.deriveKek(
      password: newPassword,
      kdfSalt: salt,
    );
    final wrapped = await VaultCrypto.wrapDek(dek: dek, kek: kek);
    await authApi.setVaultKeyMaterial(
      kdfSalt: salt,
      kdfParams: KdfParams.defaults.toJson(),
      wrappedDek: wrapped.wrappedDek,
      wrapNonce: wrapped.wrapNonce,
    );
  }

  void lock() {
    _dek = null;
  }

  Future<bool> hasLocalOfflineVault() => localVaultKeyMaterialStore.exists();

  Future<void> completeOfflineVaultSetup({required String password}) async {
    final dek = VaultCrypto.generateDek();
    final salt = VaultCrypto.generateKdfSalt();
    final kek = await VaultCrypto.deriveKek(password: password, kdfSalt: salt);
    final wrapped = await VaultCrypto.wrapDek(dek: dek, kek: kek);
    await localVaultKeyMaterialStore.write(
      kdfSalt: salt,
      kdfParams: KdfParams.defaults.toJson(),
      wrappedDek: wrapped.wrappedDek,
      wrapNonce: wrapped.wrapNonce,
    );
    _dek = dek;
  }

  Future<void> unlockOffline({required String password}) async {
    final material = await localVaultKeyMaterialStore.read();
    if (material == null) {
      throw const VaultAlreadyInitializedException();
    }
    final params = KdfParams.fromJson(material.kdfParams);
    final kek = await VaultCrypto.deriveKek(
      password: password,
      kdfSalt: material.kdfSalt,
      params: params,
    );
    try {
      _dek = await VaultCrypto.unwrapDek(
        wrappedDek: material.wrappedDek,
        wrapNonce: material.wrapNonce,
        kek: kek,
      );
    } on VaultCryptoException {
      throw const InvalidMasterPasswordException();
    }
  }

  Future<void> clearLocalOfflineVault() => localVaultKeyMaterialStore.clear();
}
