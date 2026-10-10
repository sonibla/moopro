import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/vault_registry_database.dart';
import 'package:moopro/vault/vault_registry.dart';

void main() {
  late VaultRegistryDatabase db;
  late VaultRegistry registry;

  setUp(() {
    db = VaultRegistryDatabase(NativeDatabase.memory());
    registry = VaultRegistry(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('a fresh registry starts empty', () async {
    expect(await registry.list(), isEmpty);
  });

  test('createOfflineVault allocates a unique id and dbName', () async {
    final a = await registry.createOfflineVault(label: 'A');
    final b = await registry.createOfflineVault(label: 'B');

    expect(a.id, isNot(b.id));
    expect(a.dbName, isNot(b.dbName));
    expect(a.kind, VaultKind.offline);
    expect(a.email, isNull);
  });

  test('list() sorts by lastOpenedAt, most recent first', () async {
    final older = await registry.createOfflineVault(label: 'Older');
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));
    final newer = await registry.createOfflineVault(label: 'Newer');

    final list = await registry.list();
    expect(list.map((e) => e.id), [newer.id, older.id]);

    await registry.touch(older.id);
    final afterTouch = await registry.list();
    expect(afterTouch.first.id, older.id);
  });

  test('delete removes the entry', () async {
    final vault = await registry.createOfflineVault(label: 'Gone soon');
    await registry.delete(vault.id);

    expect(await registry.list(), isEmpty);
    expect(await registry.get(vault.id), isNull);
  });

  group('resolveOnlineVault', () {
    test('allocates a new vault for a never-seen email', () async {
      final vault = await registry.resolveOnlineVault(
        email: 'a@example.com',
        label: 'a@example.com',
      );

      expect(vault.kind, VaultKind.online);
      expect(vault.email, 'a@example.com');
      expect(await registry.list(), hasLength(1));
    });

    test('reuses the existing vault for an already-known email', () async {
      final first = await registry.resolveOnlineVault(
        email: 'a@example.com',
        label: 'a@example.com',
      );
      final second = await registry.resolveOnlineVault(
        email: 'a@example.com',
        label: 'a@example.com',
      );

      expect(second.id, first.id);
      expect(second.dbName, first.dbName);
      expect(await registry.list(), hasLength(1));
    });

    test('allocates a different vault for a different email', () async {
      final first = await registry.resolveOnlineVault(
        email: 'a@example.com',
        label: 'a@example.com',
      );
      final second = await registry.resolveOnlineVault(
        email: 'b@example.com',
        label: 'b@example.com',
      );

      expect(second.id, isNot(first.id));
      expect(await registry.list(), hasLength(2));
    });
  });

  test(
    'convertOfflineVaultToOnline keeps the same id/dbName but changes kind/email',
    () async {
      final vault = await registry.createOfflineVault(label: 'Was offline');

      final converted = await registry.convertOfflineVaultToOnline(
        id: vault.id,
        email: 'now-online@example.com',
      );

      expect(converted.id, vault.id);
      expect(converted.dbName, vault.dbName);
      expect(converted.kind, VaultKind.online);
      expect(converted.email, 'now-online@example.com');
    },
  );
}
