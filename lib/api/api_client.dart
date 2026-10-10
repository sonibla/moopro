import 'package:dio/dio.dart';

import 'api_config.dart';
import 'cookie_support.dart';
import 'token_store.dart';

final Options dioOptionsSkipAuth = Options(extra: {'skipAuth': true});

class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;

  Future<String?>? _pendingRefresh;

  ApiClient({Dio? dio, TokenStore? tokenStore, String? baseUrl})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl ?? ApiConfig.baseUrl,
              contentType: 'application/json',
            ),
          ),
      tokenStore = tokenStore ?? TokenStore() {
    configureCookieHandling(this.dio);
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.extra.containsKey('skipAuth')) {
            final token = await this.tokenStore.readAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final skipAuth = error.requestOptions.extra['skipAuth'] == true;
          if (isUnauthorized && !alreadyRetried && !skipAuth) {
            final newToken = await _refreshAccessToken();
            if (newToken != null) {
              final retryOptions = error.requestOptions;
              retryOptions.extra['retried'] = true;
              retryOptions.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await this.dio.fetch(retryOptions);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> activateSession(String account) async {
    if (!await tokenStore.activate(account)) return false;
    final cookies = tokenStore.readSessionCookies();
    if (cookies != null) await seedSessionCookies(dio, cookies);
    return true;
  }

  Future<void> saveSession({
    required String accessToken,
    required String? refreshToken,
  }) async {
    final cookies = await readSessionCookies(dio);
    await tokenStore.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessCookie: cookies?.access,
      refreshCookie: cookies?.refresh,
    );
  }

  Future<String?> _refreshAccessToken() {
    return _pendingRefresh ??= _doRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await dio.post(
        '/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final accessToken =
          response.data['accessToken']['access_token'] as String;
      final newRefreshToken =
          response.data['accessToken']['refresh_token'] as String?;
      await saveSession(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
      return accessToken;
    } on DioException {
      final currentRefreshToken = await tokenStore.readRefreshToken();
      if (currentRefreshToken != null && currentRefreshToken != refreshToken) {
        return tokenStore.readAccessToken();
      }
      await tokenStore.clear();
      return null;
    }
  }
}
