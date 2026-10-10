import 'dart:convert';
import 'dart:typed_data';

class RegistrationStatusResponse {
  final bool enabled;

  const RegistrationStatusResponse({required this.enabled});

  factory RegistrationStatusResponse.fromJson(Map<String, dynamic> json) =>
      RegistrationStatusResponse(enabled: json['enabled'] as bool);
}

class UserApiResponse {
  final String id;
  final String email;
  final bool emailValidated;
  final bool hasVaultKeyMaterial;
  final bool totpEnabled;

  const UserApiResponse({
    required this.id,
    required this.email,
    required this.emailValidated,
    required this.hasVaultKeyMaterial,
    this.totpEnabled = false,
  });

  factory UserApiResponse.fromJson(Map<String, dynamic> json) =>
      UserApiResponse(
        id: json['id'] as String,
        email: json['email'] as String,
        emailValidated: json['emailValidated'] as bool,
        hasVaultKeyMaterial: json['hasVaultKeyMaterial'] as bool,
        totpEnabled: json['totpEnabled'] as bool,
      );
}

class TotpSecretResponse {
  final String secret;
  final String otpauthUri;

  const TotpSecretResponse({required this.secret, required this.otpauthUri});

  factory TotpSecretResponse.fromJson(Map<String, dynamic> json) =>
      TotpSecretResponse(
        secret: json['secret'] as String,
        otpauthUri: json['otpauthUri'] as String,
      );
}

class AccessTokenResponse {
  final String accessToken;
  final int expiresIn;
  final String? refreshToken;
  final int? refreshTokenExpiresIn;

  const AccessTokenResponse({
    required this.accessToken,
    required this.expiresIn,
    this.refreshToken,
    this.refreshTokenExpiresIn,
  });

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) =>
      AccessTokenResponse(
        accessToken: json['access_token'] as String,
        expiresIn: json['expires_in'] as int,
        refreshToken: json['refresh_token'] as String?,
        refreshTokenExpiresIn: json['refresh_token_expires_in'] as int?,
      );
}

class LoggedInApiResponse {
  final UserApiResponse userData;
  final AccessTokenResponse accessToken;

  const LoggedInApiResponse({
    required this.userData,
    required this.accessToken,
  });

  factory LoggedInApiResponse.fromJson(Map<String, dynamic> json) =>
      LoggedInApiResponse(
        userData: UserApiResponse.fromJson(
          json['userData'] as Map<String, dynamic>,
        ),
        accessToken: AccessTokenResponse.fromJson(
          json['accessToken'] as Map<String, dynamic>,
        ),
      );
}

class VaultKeyMaterialResponse {
  final bool hasVaultKeyMaterial;
  final Uint8List? kdfSalt;
  final Map<String, dynamic>? kdfParams;
  final Uint8List? wrappedDek;
  final Uint8List? wrapNonce;

  const VaultKeyMaterialResponse({
    required this.hasVaultKeyMaterial,
    this.kdfSalt,
    this.kdfParams,
    this.wrappedDek,
    this.wrapNonce,
  });

  factory VaultKeyMaterialResponse.fromJson(Map<String, dynamic> json) =>
      VaultKeyMaterialResponse(
        hasVaultKeyMaterial: json['hasVaultKeyMaterial'] as bool,
        kdfSalt: json['kdfSalt'] != null
            ? base64Decode(json['kdfSalt'] as String)
            : null,
        kdfParams: json['kdfParams'] as Map<String, dynamic>?,
        wrappedDek: json['wrappedDek'] != null
            ? base64Decode(json['wrappedDek'] as String)
            : null,
        wrapNonce: json['wrapNonce'] != null
            ? base64Decode(json['wrapNonce'] as String)
            : null,
      );
}

class VaultRecordUpsert {
  final String id;
  final String type;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final bool deleted;

  final int? baseVersion;

  const VaultRecordUpsert({
    required this.id,
    required this.type,
    required this.ciphertext,
    required this.nonce,
    this.deleted = false,
    this.baseVersion,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'ciphertext': base64Encode(ciphertext),
    'nonce': base64Encode(nonce),
    'deleted': deleted,
    'baseVersion': baseVersion,
  };
}

class VaultRecordResponse {
  final String id;
  final String type;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final int version;
  final DateTime updatedAt;
  final bool deleted;

  const VaultRecordResponse({
    required this.id,
    required this.type,
    required this.ciphertext,
    required this.nonce,
    required this.version,
    required this.updatedAt,
    required this.deleted,
  });

  factory VaultRecordResponse.fromJson(Map<String, dynamic> json) =>
      VaultRecordResponse(
        id: json['id'] as String,
        type: json['type'] as String,
        ciphertext: base64Decode(json['ciphertext'] as String),
        nonce: base64Decode(json['nonce'] as String),
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deleted: json['deleted'] as bool,
      );
}

class VaultRecordConflict {
  final String id;
  final int? currentVersion;

  const VaultRecordConflict({required this.id, required this.currentVersion});

  factory VaultRecordConflict.fromJson(Map<String, dynamic> json) =>
      VaultRecordConflict(
        id: json['id'] as String,
        currentVersion: json['currentVersion'] as int?,
      );
}

class VaultConflictException implements Exception {
  final List<VaultRecordConflict> conflicts;

  const VaultConflictException(this.conflicts);

  factory VaultConflictException.fromResponseBody(Map<String, dynamic> body) {
    final detail = body['detail'] as Map<String, dynamic>;
    final conflicts = (detail['conflicts'] as List<dynamic>)
        .map((e) => VaultRecordConflict.fromJson(e as Map<String, dynamic>))
        .toList();
    return VaultConflictException(conflicts);
  }

  @override
  String toString() =>
      'One or more changes conflicted with a newer version from another '
      'device (${conflicts.map((c) => c.id).join(', ')}); please review '
      'the latest version before retrying.';
}
