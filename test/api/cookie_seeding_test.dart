import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/token_store.dart';

class _BackendAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isAuth = options.path == '/login' || options.path == '/refresh';
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        if (isAuth)
          HttpHeaders.setCookieHeader: [
            'access_token=COOKIE-ACCESS; Path=/; HttpOnly',
            'refresh_token=COOKIE-REFRESH; Path=/refresh; HttpOnly',
          ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_BackendAdapter adapter) => ApiClient(
  dio: Dio(BaseOptions(baseUrl: 'http://localhost:8000'))
    ..httpClientAdapter = adapter,
  tokenStore: TokenStore(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final onIo = Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  test('a restored session sends the server\'s cookie tokens — not the body '
      'tokens, which the backend rejects as cookies', () async {
    if (!onIo) return;
    FlutterSecureStorage.setMockInitialValues({});

    final first = _client(_BackendAdapter());
    first.tokenStore
      ..useAccount('a@x.com')
      ..persist = true;
    await first.dio.post('/login', options: dioOptionsSkipAuth);
    await first.saveSession(
      accessToken: 'BODY-ACCESS',
      refreshToken: 'BODY-REFRESH',
    );

    final adapter = _BackendAdapter();
    final second = _client(adapter);
    expect(await second.activateSession('a@x.com'), isTrue);
    await second.dio.get('/users/me');
    await second.dio.post('/refresh', data: {'refresh_token': 'BODY-REFRESH'});

    final me = adapter.requests[0];
    expect(me.headers['Authorization'], 'Bearer BODY-ACCESS');
    expect(me.headers['cookie'], contains('access_token=COOKIE-ACCESS'));
    expect(me.headers['cookie'], isNot(contains('BODY-')));
    expect(
      adapter.requests[1].headers['cookie'],
      contains('refresh_token=COOKIE-REFRESH'),
    );
  });

  test('without "stay signed in" the cookie tokens never reach secure '
      'storage', () async {
    if (!onIo) return;
    FlutterSecureStorage.setMockInitialValues({});
    final client = _client(_BackendAdapter());
    client.tokenStore.useAccount('a@x.com');

    await client.dio.post('/login', options: dioOptionsSkipAuth);
    await client.saveSession(accessToken: 'a', refreshToken: 'r');

    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    expect(client.tokenStore.readSessionCookies()?.access, 'COOKIE-ACCESS');
  });

  test('activating an account with no session changes nothing', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = _client(_BackendAdapter());

    expect(await client.activateSession('nobody@x.com'), isFalse);
  });
}
