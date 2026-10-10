import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:moopro/domain/calendar_date.dart';

void main() {
  late AppDatabase db;
  late DomainCacheDatabase cacheDb;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cacheDb = DomainCacheDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    await cacheDb.close();
  });

  test('SyncState defaults to version 0 when no row exists', () async {
    final row = await (db.select(
      db.syncState,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    expect(row, isNull);
  });

  test('LocalVaultRecords round-trips ciphertext/nonce blobs', () async {
    final ciphertext = Uint8List.fromList([1, 2, 3, 4, 5]);
    final nonce = Uint8List.fromList(List.generate(12, (i) => i));

    await db
        .into(db.localVaultRecords)
        .insert(
          LocalVaultRecordsCompanion.insert(
            id: 'rec1',
            type: 'transaction',
            ciphertext: ciphertext,
            nonce: nonce,
          ),
        );

    final stored = await (db.select(
      db.localVaultRecords,
    )..where((t) => t.id.equals('rec1'))).getSingle();

    expect(stored.ciphertext, equals(ciphertext));
    expect(stored.nonce, equals(nonce));
    expect(stored.dirty, isTrue);
    expect(stored.version, isNull);
    expect(stored.deleted, isFalse);
  });

  test('Assets/Containers/Transactions tables (DomainCacheDatabase) accept '
      'and return the documented data-model.md fields', () async {
    await cacheDb
        .into(cacheDb.assets)
        .insert(
          AssetsCompanion.insert(
            id: 'eur',
            kind: 'fiat',
            symbol: 'EUR',
            name: 'Euro',
          ),
        );
    await cacheDb
        .into(cacheDb.containers)
        .insert(
          ContainersCompanion.insert(
            id: 'bank1',
            name: 'Main bank',
            containerType: 'holder',
          ),
        );
    await cacheDb
        .into(cacheDb.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'tx1',
            postedAt: DateTime.utc(2026, 1, 1, 9, 30),
            effectiveDate: CalendarDate(2026, 1, 1),
            kind: 'holderTransfer',
            legOutContainerId: 'external',
            legOutAssetId: 'eur',
            legOutQuantity: '100.00',
            legInContainerId: 'bank1',
            legInAssetId: 'eur',
            legInQuantity: '100.00',
          ),
        );

    final asset = await cacheDb.select(cacheDb.assets).getSingle();
    final container = await cacheDb.select(cacheDb.containers).getSingle();
    final transaction = await cacheDb.select(cacheDb.transactions).getSingle();

    expect(asset.symbol, equals('EUR'));
    expect(container.containerType, equals('holder'));
    expect(transaction.legInQuantity, equals('100.00'));
  });

  test(
    'RecordVersionHighWaterMark tracks the highest version per id',
    () async {
      await db
          .into(db.recordVersionHighWaterMark)
          .insert(
            RecordVersionHighWaterMarkCompanion.insert(
              recordId: 'rec1',
              highestVersionSeen: 3,
            ),
          );
      await db
          .into(db.recordVersionHighWaterMark)
          .insertOnConflictUpdate(
            const RecordVersionHighWaterMarkCompanion(
              recordId: Value('rec1'),
              highestVersionSeen: Value(7),
            ),
          );

      final row = await (db.select(
        db.recordVersionHighWaterMark,
      )..where((t) => t.recordId.equals('rec1'))).getSingle();
      expect(row.highestVersionSeen, equals(7));
    },
  );

  test('LocalVaultKeyMaterial round-trips ciphertext/KDF metadata', () async {
    await db
        .into(db.localVaultKeyMaterial)
        .insert(
          LocalVaultKeyMaterialCompanion.insert(
            id: const Value(0),
            kdfSalt: Uint8List.fromList([1, 2, 3]),
            kdfParamsJson: '{"memory":65536,"iterations":3,"parallelism":4}',
            wrappedDek: Uint8List.fromList([4, 5, 6]),
            wrapNonce: Uint8List.fromList([7, 8, 9]),
          ),
        );

    final row = await db.select(db.localVaultKeyMaterial).getSingle();
    expect(row.kdfSalt, equals(Uint8List.fromList([1, 2, 3])));
    expect(row.wrappedDek, equals(Uint8List.fromList([4, 5, 6])));
  });

  test(
    'schema v5 migration adds LocalVaultKeyMaterial to a v4 database without '
    'touching existing LocalVaultRecords data',
    () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/moopro_db_migration_test_'
        '${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      final raw = sqlite3.sqlite3.open(tempFile.path);
      raw.execute('''
        CREATE TABLE sync_state (
          id INTEGER NOT NULL PRIMARY KEY,
          last_synced_version INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE local_vault_records (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          ciphertext BLOB NOT NULL,
          nonce BLOB NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0,
          version INTEGER NULL,
          updated_at INTEGER NULL,
          dirty INTEGER NOT NULL DEFAULT 1,
          conflicted_at INTEGER NULL
        );
        CREATE TABLE record_version_high_water_mark (
          record_id TEXT NOT NULL PRIMARY KEY,
          highest_version_seen INTEGER NOT NULL
        );
      ''');
      raw.execute('PRAGMA user_version = 4');
      raw.execute('''
        INSERT INTO local_vault_records (id, type, ciphertext, nonce)
        VALUES ('rec1', 'asset', x'0102', x'030405060708090a0b0c')
      ''');
      raw.close();

      final migrated = AppDatabase(NativeDatabase(tempFile));
      addTearDown(migrated.close);

      final existingRows = await migrated
          .select(migrated.localVaultRecords)
          .get();
      expect(existingRows, hasLength(1));
      expect(existingRows.single.id, equals('rec1'));

      final keyMaterialRows = await migrated
          .select(migrated.localVaultKeyMaterial)
          .get();
      expect(keyMaterialRows, isEmpty);

      await migrated
          .into(migrated.localVaultKeyMaterial)
          .insert(
            LocalVaultKeyMaterialCompanion.insert(
              id: const Value(0),
              kdfSalt: Uint8List.fromList([1]),
              kdfParamsJson: '{}',
              wrappedDek: Uint8List.fromList([2]),
              wrapNonce: Uint8List.fromList([3]),
            ),
          );
      expect(
        await migrated.select(migrated.localVaultKeyMaterial).get(),
        hasLength(1),
      );
    },
  );
}
