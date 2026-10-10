import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const accessTokenKey = 'auth_access_token';
  static const refreshTokenKey = 'auth_refresh_token';

  static const accessCookieKey = 'auth_access_cookie';
  static const refreshCookieKey = 'auth_refresh_cookie';

  final FlutterSecureStorage _storage;
  String? _accessToken;
  String? _refreshToken;
  String? _accessCookie;
  String? _refreshCookie;

  bool persist = false;

  bool _onDisk = false;

  String? _account;

  final Map<String, _Stashed> _stashed = {};

  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  String _key(String base) => _account == null ? base : '$base:$_account';

  void useAccount(String? account) {
    if (account == _account) return;
    final current = _account;
    if (current != null && _refreshToken != null) {
      _stashed[current] = _Stashed(
        _accessToken,
        _refreshToken,
        _accessCookie,
        _refreshCookie,
        persist: persist,
        onDisk: _onDisk,
      );
    }
    final restored = account == null ? null : _stashed.remove(account);
    _account = account;
    _accessToken = restored?.accessToken;
    _refreshToken = restored?.refreshToken;
    _accessCookie = restored?.accessCookie;
    _refreshCookie = restored?.refreshCookie;
    persist = restored?.persist ?? false;
    _onDisk = restored?.onDisk ?? false;
  }

  bool hasInMemory(String account) =>
      (_account == account && _refreshToken != null) ||
      _stashed.containsKey(account);

  Future<bool> activate(String account) async {
    useAccount(account);
    if (_refreshToken != null) return true;
    return loadPersisted();
  }

  Future<Set<String>> connectedAccounts() async {
    final accounts = <String>{
      for (final e in _stashed.entries)
        if (e.value.refreshToken != null) e.key,
      if (_account != null && _refreshToken != null) _account!,
    };
    try {
      const prefix = '$refreshTokenKey:';
      for (final key in (await _storage.readAll()).keys) {
        if (key.startsWith(prefix)) accounts.add(key.substring(prefix.length));
      }
    } catch (_) {}
    return accounts;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String? refreshToken,
    String? accessCookie,
    String? refreshCookie,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
    if (accessCookie != null) _accessCookie = accessCookie;
    if (refreshCookie != null) _refreshCookie = refreshCookie;
    if (!persist) {
      if (_onDisk) await _deletePersisted();
      return;
    }
    _onDisk = true;
    await _storage.write(key: _key(accessTokenKey), value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _key(refreshTokenKey), value: refreshToken);
    }
    if (accessCookie != null) {
      await _storage.write(key: _key(accessCookieKey), value: accessCookie);
    }
    if (refreshCookie != null) {
      await _storage.write(key: _key(refreshCookieKey), value: refreshCookie);
    }
  }

  ({String access, String refresh})? readSessionCookies() {
    final access = _accessCookie;
    final refresh = _refreshCookie;
    return access == null || refresh == null
        ? null
        : (access: access, refresh: refresh);
  }

  Future<String?> readAccessToken() async => _accessToken;
  Future<String?> readRefreshToken() async => _refreshToken;

  Future<bool> hasPersistedTokens() async =>
      await _storage.containsKey(key: _key(refreshTokenKey));

  Future<bool> hasSession() async => persist
      ? await hasPersistedTokens()
      : (_accessToken != null || _refreshToken != null);

  Future<bool> loadPersisted() async {
    final refresh = await _storage.read(key: _key(refreshTokenKey));
    if (refresh == null) return false;
    _refreshToken = refresh;
    _accessToken = await _storage.read(key: _key(accessTokenKey));
    _accessCookie = await _storage.read(key: _key(accessCookieKey));
    _refreshCookie = await _storage.read(key: _key(refreshCookieKey));
    persist = true;
    _onDisk = true;
    return true;
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _accessCookie = null;
    _refreshCookie = null;
    persist = false;
    await _deletePersisted();
  }

  Future<void> _deletePersisted() async {
    _onDisk = false;
    await _storage.delete(key: _key(accessTokenKey));
    await _storage.delete(key: _key(refreshTokenKey));
    await _storage.delete(key: _key(accessCookieKey));
    await _storage.delete(key: _key(refreshCookieKey));
  }
}

class _Stashed {
  final String? accessToken;
  final String? refreshToken;
  final String? accessCookie;
  final String? refreshCookie;
  final bool persist;
  final bool onDisk;

  const _Stashed(
    this.accessToken,
    this.refreshToken,
    this.accessCookie,
    this.refreshCookie, {
    required this.persist,
    required this.onDisk,
  });
}
