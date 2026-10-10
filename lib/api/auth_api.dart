import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'models.dart';

class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  Future<LoggedInApiResponse> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    final response = await _client.dio.post(
      '/login',
      data: {'email': email, 'password': password, 'totpCode': ?totpCode},
      options: dioOptionsSkipAuth,
    );
    final parsed = LoggedInApiResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _client.saveSession(
      accessToken: parsed.accessToken.accessToken,
      refreshToken: parsed.accessToken.refreshToken,
    );
    return parsed;
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/logout');
    } on DioException {
      // ignore: empty_catches
    }
    await _client.tokenStore.clear();
  }

  Future<RegistrationStatusResponse> checkRegistrationStatus() async {
    final response = await _client.dio.get(
      '/registration-status',
      options: dioOptionsSkipAuth,
    );
    return RegistrationStatusResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<LoggedInApiResponse> register({
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post(
      '/register',
      data: {'email': email, 'password': password},
      options: dioOptionsSkipAuth,
    );
    final parsed = LoggedInApiResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
    await _client.saveSession(
      accessToken: parsed.accessToken.accessToken,
      refreshToken: parsed.accessToken.refreshToken,
    );
    return parsed;
  }

  Future<void> requestAccount({required String email}) async {
    await _client.dio.post(
      '/account-requests',
      data: {'email': email},
      options: dioOptionsSkipAuth,
    );
  }

  Future<UserApiResponse> getCurrentUser() async {
    final response = await _client.dio.get('/users/me');
    return UserApiResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VaultKeyMaterialResponse> getVaultKeyMaterial() async {
    final response = await _client.dio.get('/users/me/vault-key-material');
    return VaultKeyMaterialResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<VaultKeyMaterialResponse> setVaultKeyMaterial({
    required Uint8List kdfSalt,
    required Map<String, dynamic> kdfParams,
    required Uint8List wrappedDek,
    required Uint8List wrapNonce,
  }) async {
    final response = await _client.dio.put(
      '/users/me/vault-key-material',
      data: {
        'kdfSalt': base64Encode(kdfSalt),
        'kdfParams': kdfParams,
        'wrappedDek': base64Encode(wrappedDek),
        'wrapNonce': base64Encode(wrapNonce),
      },
    );
    return VaultKeyMaterialResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<TotpSecretResponse> enableTotp() async {
    final response = await _client.dio.post('/users/me/totp');
    return TotpSecretResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> disableTotp() => _client.dio.delete('/users/me/totp');

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.dio.post(
      '/users/me/password-change',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
