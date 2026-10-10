import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/token_store.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

class FakeTokenStore extends TokenStore {
  String? _accessToken;
  String? _refreshToken;

  FakeTokenStore({String? accessToken, String? refreshToken})
    : _accessToken = accessToken,
      _refreshToken = refreshToken;

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String? refreshToken,
    String? accessCookie,
    String? refreshCookie,
  }) async {
    _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

ApiClient _buildClient(
  FakeTokenStore tokenStore,
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return ApiClient(dio: dio, tokenStore: tokenStore);
}

void main() {
  group('ApiClient 401-refresh-retry', () {
    test('a refresh failure with no other tab racing clears tokens and '
        'propagates the error', () async {
      final tokenStore = FakeTokenStore(
        accessToken: 'expired-access',
        refreshToken: 'stale-refresh',
      );
      final apiClient = _buildClient(tokenStore, (options) async {
        if (options.path == '/protected') {
          return ResponseBody.fromString('{}', 401);
        }
        if (options.path == '/refresh') {
          return ResponseBody.fromString('{"detail":"invalid"}', 401);
        }
        throw StateError('unexpected path ${options.path}');
      });

      await expectLater(
        apiClient.dio.get<void>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
    });

    test('a refresh failure caused by another tab already rotating the '
        "token recovers using that tab's tokens instead of clearing", () async {
      final tokenStore = FakeTokenStore(
        accessToken: 'expired-access',
        refreshToken: 'stale-refresh',
      );
      final apiClient = _buildClient(tokenStore, (options) async {
        if (options.path == '/protected') {
          final auth = options.headers['Authorization'];
          if (auth == 'Bearer new-access-from-other-tab') {
            return ResponseBody.fromString('{"ok":true}', 200);
          }
          return ResponseBody.fromString('{}', 401);
        }
        if (options.path == '/refresh') {
          await tokenStore.saveTokens(
            accessToken: 'new-access-from-other-tab',
            refreshToken: 'new-refresh-from-other-tab',
          );
          return ResponseBody.fromString('{"detail":"stale token"}', 401);
        }
        throw StateError('unexpected path ${options.path}');
      });

      final response = await apiClient.dio.get<void>('/protected');

      expect(response.statusCode, equals(200));
      expect(
        await tokenStore.readAccessToken(),
        equals('new-access-from-other-tab'),
      );
      expect(
        await tokenStore.readRefreshToken(),
        equals('new-refresh-from-other-tab'),
      );
    });

    test('a genuinely dead session (refresh token unchanged) still forces '
        'logout — the recovery path does not mask a real failure', () async {
      final tokenStore = FakeTokenStore(
        accessToken: 'expired-access',
        refreshToken: 'dead-refresh',
      );
      final apiClient = _buildClient(tokenStore, (options) async {
        if (options.path == '/protected') {
          return ResponseBody.fromString('{}', 401);
        }
        if (options.path == '/refresh') {
          return ResponseBody.fromString('{"detail":"invalid"}', 401);
        }
        throw StateError('unexpected path ${options.path}');
      });

      await expectLater(
        apiClient.dio.get<void>('/protected'),
        throwsA(isA<DioException>()),
      );

      expect(await tokenStore.readAccessToken(), isNull);
      expect(await tokenStore.readRefreshToken(), isNull);
    });
  });
}
