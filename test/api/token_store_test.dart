import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, String>> disk() => const FlutterSecureStorage().readAll();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'by default tokens are kept in memory and never written to disk',
    () async {
      final store = TokenStore();
      await store.saveTokens(accessToken: 'a1', refreshToken: 'r1');

      expect(await store.readAccessToken(), 'a1');
      expect(await store.readRefreshToken(), 'r1');
      expect(await disk(), isEmpty);
      expect(await store.hasPersistedTokens(), isFalse);
      expect(await store.hasSession(), isTrue);
    },
  );

  test(
    'with persist on, tokens (and rotated refresh tokens) reach disk',
    () async {
      final store = TokenStore()..persist = true;
      await store.saveTokens(accessToken: 'a1', refreshToken: 'r1');
      await store.saveTokens(accessToken: 'a2', refreshToken: 'r2');

      expect(await disk(), {
        TokenStore.accessTokenKey: 'a2',
        TokenStore.refreshTokenKey: 'r2',
      });
      expect(await store.hasPersistedTokens(), isTrue);
    },
  );

  test(
    'a new run restores persisted tokens, and keeps persisting them',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        TokenStore.accessTokenKey: 'a1',
        TokenStore.refreshTokenKey: 'r1',
      });
      final store = TokenStore();
      expect(await store.readRefreshToken(), isNull);

      expect(await store.loadPersisted(), isTrue);
      expect(await store.readAccessToken(), 'a1');
      expect(await store.readRefreshToken(), 'r1');

      await store.saveTokens(accessToken: 'a2', refreshToken: 'r2');
      expect((await disk())[TokenStore.refreshTokenKey], 'r2');
    },
  );

  test('loadPersisted reports false when nothing was stored', () async {
    expect(await TokenStore().loadPersisted(), isFalse);
  });

  test('clear wipes memory and disk (logout)', () async {
    final store = TokenStore()..persist = true;
    await store.saveTokens(accessToken: 'a1', refreshToken: 'r1');

    await store.clear();

    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
    expect(await disk(), isEmpty);
    expect(await store.hasSession(), isFalse);
    expect(store.persist, isFalse);
  });

  test(
    'a later login without "stay signed in" erases tokens left on disk',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        TokenStore.accessTokenKey: 'old-a',
        TokenStore.refreshTokenKey: 'old-r',
      });
      final store = TokenStore();
      await store.loadPersisted();

      store.persist = false;
      await store.saveTokens(accessToken: 'new-a', refreshToken: 'new-r');

      expect(await disk(), isEmpty);
      expect(await store.readRefreshToken(), 'new-r');
    },
  );

  group('per-account sessions', () {
    String key(String base, String account) => '$base:$account';

    test('persisted tokens are stored under the account and listed as '
        'connected', () async {
      final store = TokenStore()
        ..useAccount('a@x.com')
        ..persist = true;
      await store.saveTokens(accessToken: 'a1', refreshToken: 'r1');

      expect(await disk(), {
        key(TokenStore.accessTokenKey, 'a@x.com'): 'a1',
        key(TokenStore.refreshTokenKey, 'a@x.com'): 'r1',
      });
      expect(await store.connectedAccounts(), {'a@x.com'});
    });

    test(
      'switching accounts keeps the previous one connected in memory',
      () async {
        final store = TokenStore()..useAccount('a@x.com');
        await store.saveTokens(accessToken: 'a1', refreshToken: 'r1');
        store.useAccount('b@x.com');
        await store.saveTokens(accessToken: 'a2', refreshToken: 'r2');

        expect(await store.readRefreshToken(), 'r2');
        expect(await store.connectedAccounts(), {'a@x.com', 'b@x.com'});
        expect(store.hasInMemory('a@x.com'), isTrue);

        expect(await store.activate('a@x.com'), isTrue);
        expect(await store.readRefreshToken(), 'r1');
        expect(await disk(), isEmpty);
      },
    );

    test('a fresh run activates an account from disk, and persists its '
        'rotated tokens', () async {
      FlutterSecureStorage.setMockInitialValues({
        key(TokenStore.accessTokenKey, 'a@x.com'): 'a1',
        key(TokenStore.refreshTokenKey, 'a@x.com'): 'r1',
        key(TokenStore.refreshTokenKey, 'b@x.com'): 'rb',
      });
      final store = TokenStore();

      expect(await store.connectedAccounts(), {'a@x.com', 'b@x.com'});
      expect(store.hasInMemory('a@x.com'), isFalse);
      expect(await store.activate('a@x.com'), isTrue);
      expect(await store.readRefreshToken(), 'r1');

      await store.saveTokens(accessToken: 'a2', refreshToken: 'r2');
      expect((await disk())[key(TokenStore.refreshTokenKey, 'a@x.com')], 'r2');
    });

    test('activating an account with no session reports false', () async {
      expect(await TokenStore().activate('nobody@x.com'), isFalse);
    });

    test('clear ends only the active account', () async {
      FlutterSecureStorage.setMockInitialValues({
        key(TokenStore.refreshTokenKey, 'a@x.com'): 'ra',
        key(TokenStore.refreshTokenKey, 'b@x.com'): 'rb',
      });
      final store = TokenStore();
      await store.activate('a@x.com');

      await store.clear();

      expect(await store.connectedAccounts(), {'b@x.com'});
    });
  });
}
