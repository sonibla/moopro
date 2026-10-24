import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/api/vault_api.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/sync/sync_engine.dart';

class FakeVaultApi extends VaultApi {
  final List<VaultRecordResponse> serverRecords = [];
  int _nextVersion = 1;
  int pushCallCount = 0;
  int pullCallCount = 0;

  FakeVaultApi() : super(ApiClient());

  void seedServerRecord(VaultRecordResponse record) {
    serverRecords.add(record);
    if (record.version >= _nextVersion) _nextVersion = record.version + 1;
  }

  @override
  Future<int> latestVersion() async => _nextVersion - 1;

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async {
    pullCallCount++;
    return serverRecords.where((r) => r.version > sinceVersion).toList();
  }

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async {
    pushCallCount++;
    final conflicts = <VaultRecordConflict>[];
    for (final upsert in records) {
      final current = serverRecords
          .where((r) => r.id == upsert.id)
          .firstOrNull
          ?.version;
      if (upsert.baseVersion != current) {
        conflicts.add(
          VaultRecordConflict(id: upsert.id, currentVersion: current),
        );
      }
    }
    if (conflicts.isNotEmpty) {
      throw VaultConflictException(conflicts);
    }

    final results = <VaultRecordResponse>[];
    for (final upsert in records) {
      final assigned = VaultRecordResponse(
        id: upsert.id,
        type: upsert.type,
        ciphertext: upsert.ciphertext,
        nonce: upsert.nonce,
        version: _nextVersion++,
        updatedAt: DateTime.utc(2026, 1, 1),
        deleted: upsert.deleted,
      );
      serverRecords.removeWhere((r) => r.id == upsert.id);
      serverRecords.add(assigned);
      results.add(assigned);
    }
    return results;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => this.isEmpty ? null : first;
}

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  late AppDatabase db;
  late FakeVaultApi fakeApi;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeApi = FakeVaultApi();
    engine = SyncEngine(db: db, vaultApi: fakeApi);
  });

  tearDown(() async {
    await db.close();
  });

  group('pull', () {
    test('applies remote records and advances the local cursor', () async {
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'a1',
          type: 'asset',
          ciphertext: _bytes('cipher-a1'),
          nonce: _bytes('nonce-a1-12b'),
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );

      final result = await engine.pull();

      expect(result.recordsApplied, equals(1));
      expect(result.rollbackWarnings, isEmpty);

      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('a1'))).getSingle();
      expect(stored.type, equals('asset'));
      expect(stored.version, equals(1));
      expect(stored.dirty, isFalse);
    });

    test('a second pull only fetches records past the saved cursor', () async {
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'a1',
          type: 'asset',
          ciphertext: _bytes('c1'),
          nonce: _bytes('nonce-a1-12b'),
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      await engine.pull();

      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'a2',
          type: 'asset',
          ciphertext: _bytes('c2'),
          nonce: _bytes('nonce-a2-12b'),
          version: 2,
          updatedAt: DateTime.utc(2026, 1, 2),
          deleted: false,
        ),
      );
      final secondResult = await engine.pull();

      expect(secondResult.recordsApplied, equals(1));
      final all = await db.select(db.localVaultRecords).get();
      expect(all.length, equals(2));
    });

    test('rejects a record whose version regresses below the local '
        'high-water-mark', () async {
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'a1',
          type: 'asset',
          ciphertext: _bytes('c-v5'),
          nonce: _bytes('nonce-a1-12b'),
          version: 5,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      await engine.pull();

      fakeApi.serverRecords.removeWhere((r) => r.id == 'a1');
      fakeApi.serverRecords.add(
        VaultRecordResponse(
          id: 'a1',
          type: 'asset',
          ciphertext: _bytes('c-v3-stale'),
          nonce: _bytes('nonce-a1-12b'),
          version: 3,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      await db
          .into(db.syncState)
          .insertOnConflictUpdate(
            const SyncStateCompanion(id: Value(0), lastSyncedVersion: Value(0)),
          );

      final result = await engine.pull();

      expect(result.rollbackWarnings, hasLength(1));
      expect(result.rollbackWarnings.first.recordId, equals('a1'));
      expect(result.rollbackWarnings.first.highestVersionSeen, equals(5));
      expect(result.rollbackWarnings.first.pulledVersion, equals(3));

      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('a1'))).getSingle();
      expect(stored.version, equals(5));
    });
  });

  group('push', () {
    test(
      'pushes dirty records and marks them clean with a server version',
      () async {
        await engine.stageLocalChange(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('local-cipher'),
          nonce: _bytes('local-nonce1'),
        );

        final pushedCount = await engine.push();

        expect(pushedCount, equals(1));
        expect(fakeApi.serverRecords, hasLength(1));
        final stored = await (db.select(
          db.localVaultRecords,
        )..where((t) => t.id.equals('local1'))).getSingle();
        expect(stored.dirty, isFalse);
        expect(stored.version, isNotNull);
      },
    );

    test('records with no local changes are not pushed again', () async {
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('local-cipher'),
        nonce: _bytes('local-nonce1'),
      );
      await engine.push();
      final secondPushCount = await engine.push();

      expect(secondPushCount, equals(0));
      expect(fakeApi.pushCallCount, equals(1));
    });

    test(
      'sends the last-confirmed version as baseVersion on an edit',
      () async {
        await engine.stageLocalChange(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('v1'),
          nonce: _bytes('local-nonce1'),
        );
        await engine.push();
        final firstVersion = fakeApi.serverRecords.single.version;

        await engine.stageLocalChange(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('v2'),
          nonce: _bytes('local-nonce1'),
        );
        await engine.push();

        expect(fakeApi.serverRecords.single.version, greaterThan(firstVersion));
      },
    );

    test('a stale baseVersion abandons the dirty edit (clears dirty without '
        'applying it) rather than looping forever', () async {
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('v1'),
        nonce: _bytes('local-nonce1'),
      );
      await engine.push();

      fakeApi.serverRecords.removeWhere((r) => r.id == 'local1');
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('someone-elses-edit'),
          nonce: _bytes('local-nonce1'),
          version: 99,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );

      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('my-stale-edit'),
        nonce: _bytes('local-nonce1'),
      );
      await expectLater(engine.push(), throwsA(isA<VaultConflictException>()));

      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(stored.dirty, isFalse);
    });
  });

  group('sync', () {
    test('push then pull round-trips a locally-staged change', () async {
      await engine.stageLocalChange(
        id: 'roundtrip1',
        type: 'container',
        ciphertext: _bytes('data'),
        nonce: _bytes('nonce-rt-12b'),
      );

      await engine.sync();

      expect(fakeApi.pushCallCount, equals(1));
      expect(fakeApi.pullCallCount, equals(1));
      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('roundtrip1'))).getSingle();
      expect(stored.dirty, isFalse);
    });

    test('a push conflict is folded into the result, not thrown, and the '
        'winning server version is still pulled in', () async {
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('v1'),
        nonce: _bytes('local-nonce1'),
      );
      await engine.sync();

      fakeApi.serverRecords.removeWhere((r) => r.id == 'local1');
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('someone-elses-edit'),
          nonce: _bytes('local-nonce1'),
          version: 99,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('my-stale-edit'),
        nonce: _bytes('local-nonce1'),
      );

      final result = await engine.sync();

      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.id, equals('local1'));
      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(stored.dirty, isFalse);
      expect(stored.ciphertext, equals(_bytes('someone-elses-edit')));
    });
  });

  group('pull vs. a pending local edit', () {
    test('does not clobber a currently-dirty row, and keeps the cursor '
        'from skipping past it', () async {
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('my-pending-edit'),
        nonce: _bytes('local-nonce1'),
      );
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('remote-edit'),
          nonce: _bytes('local-nonce1'),
          version: 5,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'other',
          type: 'asset',
          ciphertext: _bytes('other'),
          nonce: _bytes('other-nonce1'),
          version: 6,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );

      await engine.pull();

      final local1Row = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(local1Row.dirty, isTrue);
      expect(local1Row.ciphertext, equals(_bytes('my-pending-edit')));

      await (db.update(db.localVaultRecords)
            ..where((t) => t.id.equals('local1')))
          .write(const LocalVaultRecordsCompanion(dirty: Value(false)));
      final secondPull = await engine.pull();
      expect(secondPull.recordsApplied, equals(2));
      final resolved = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(resolved.ciphertext, equals(_bytes('remote-edit')));
    });
  });

  group('conflictedAt / RecordSyncStatus', () {
    Future<void> forceConflict() async {
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('v1'),
        nonce: _bytes('local-nonce1'),
      );
      await engine.push();
      fakeApi.serverRecords.removeWhere((r) => r.id == 'local1');
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('someone-elses-edit'),
          nonce: _bytes('local-nonce1'),
          version: 99,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('my-stale-edit'),
        nonce: _bytes('local-nonce1'),
      );
    }

    test('a 409 sets conflictedAt', () async {
      await forceConflict();
      await expectLater(engine.push(), throwsA(isA<VaultConflictException>()));

      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(stored.conflictedAt, isNotNull);
      expect(engine.statusOf(stored), equals(RecordSyncStatus.conflicted));
    });

    test('a successful push clears a prior conflictedAt', () async {
      await forceConflict();
      await expectLater(engine.push(), throwsA(isA<VaultConflictException>()));

      await engine.pull();
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('my-fresh-edit'),
        nonce: _bytes('local-nonce1'),
      );
      await engine.push();

      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(stored.conflictedAt, isNull);
      expect(engine.statusOf(stored), equals(RecordSyncStatus.synced));
    });

    test('pull() applying the winning version after a conflict does NOT '
        'clear conflictedAt — sync() always pulls right after a '
        'conflicting push, so clearing it here would make "conflicted" '
        'unobservable', () async {
      await forceConflict();
      await expectLater(engine.push(), throwsA(isA<VaultConflictException>()));

      await engine.pull();

      final stored = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(stored.conflictedAt, isNotNull);
      expect(stored.ciphertext, equals(_bytes('someone-elses-edit')));
      expect(engine.statusOf(stored), equals(RecordSyncStatus.conflicted));
    });

    test('acknowledgeConflict clears conflictedAt without touching '
        'ciphertext or version', () async {
      await forceConflict();
      await expectLater(engine.push(), throwsA(isA<VaultConflictException>()));
      await engine.pull();

      final before = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(before.conflictedAt, isNotNull);

      await engine.acknowledgeConflict('local1');

      final after = await (db.select(
        db.localVaultRecords,
      )..where((t) => t.id.equals('local1'))).getSingle();
      expect(after.conflictedAt, isNull);
      expect(after.ciphertext, equals(before.ciphertext));
      expect(after.version, equals(before.version));
      expect(engine.statusOf(after), equals(RecordSyncStatus.synced));
    });

    test(
      'watchRecordStatuses reflects pending, synced, and conflicted',
      () async {
        final statusesFuture = engine.watchRecordStatuses().first;

        await engine.stageLocalChange(
          id: 'local1',
          type: 'transaction',
          ciphertext: _bytes('v1'),
          nonce: _bytes('local-nonce1'),
        );

        final firstSnapshot = await statusesFuture;
        expect(firstSnapshot['local1'], equals(RecordSyncStatus.pending));

        await engine.push();
        final afterPush = await engine.watchRecordStatuses().first;
        expect(afterPush['local1'], equals(RecordSyncStatus.synced));

        await forceConflict();
        await expectLater(
          engine.push(),
          throwsA(isA<VaultConflictException>()),
        );
        final afterConflict = await engine.watchRecordStatuses().first;
        expect(afterConflict['local1'], equals(RecordSyncStatus.conflicted));
      },
    );

    test('watchConflictedRecords/watchPendingRecords list ids/types for '
        'the Sync Status screen', () async {
      await engine.stageLocalChange(
        id: 'local2',
        type: 'asset',
        ciphertext: _bytes('v1'),
        nonce: _bytes('local-nonce2'),
      );

      final pendingBefore = await engine.watchPendingRecords().first;
      expect(pendingBefore.map((r) => r.id), contains('local2'));
      expect(
        pendingBefore.firstWhere((r) => r.id == 'local2').type,
        equals('asset'),
      );
      expect(await engine.watchConflictedRecords().first, isEmpty);

      await forceConflict();
      await expectLater(engine.push(), throwsA(isA<VaultConflictException>()));

      final conflicted = await engine.watchConflictedRecords().first;
      expect(conflicted.map((r) => r.id), contains('local1'));
      expect(
        conflicted.firstWhere((r) => r.id == 'local1').type,
        equals('transaction'),
      );
      final pendingAfter = await engine.watchPendingRecords().first;
      expect(pendingAfter.map((r) => r.id), isNot(contains('local1')));
    });
  });

  group('write coalescing (perf regression)', () {
    test('push() of several dirty records emits watchRecordStatuses/'
        'watchSyncCounts once per call, not once per record — pushing '
        'thousands of records must not mean thousands of full-table UI '
        'notifications', () async {
      for (var i = 0; i < 5; i++) {
        await engine.stageLocalChange(
          id: 'r$i',
          type: 'transaction',
          ciphertext: _bytes('v$i'),
          nonce: _bytes('nonce-r$i-123'),
        );
      }

      final statusEmissions = <Map<String, RecordSyncStatus>>[];
      final countEmissions = <SyncCounts>[];
      final statusSub = engine.watchRecordStatuses().listen(
        statusEmissions.add,
      );
      final countSub = engine.watchSyncCounts().listen(countEmissions.add);
      await pumpEventQueue();

      final statusCountBeforePush = statusEmissions.length;
      final syncCountBeforePush = countEmissions.length;

      await engine.push();
      await pumpEventQueue();

      await statusSub.cancel();
      await countSub.cancel();

      expect(statusEmissions.length - statusCountBeforePush, equals(1));
      expect(countEmissions.length - syncCountBeforePush, equals(1));
      expect(countEmissions.last.pending, equals(0));
    });

    test('pull() of several remote records emits watchRecordStatuses once '
        'per call, not once per record', () async {
      for (var i = 0; i < 5; i++) {
        fakeApi.seedServerRecord(
          VaultRecordResponse(
            id: 'p$i',
            type: 'transaction',
            ciphertext: _bytes('v$i'),
            nonce: _bytes('nonce-p$i-123'),
            version: i + 1,
            updatedAt: DateTime.utc(2026, 1, 1),
            deleted: false,
          ),
        );
      }

      final statusEmissions = <Map<String, RecordSyncStatus>>[];
      final statusSub = engine.watchRecordStatuses().listen(
        statusEmissions.add,
      );
      await pumpEventQueue();
      final statusCountBeforePull = statusEmissions.length;

      await engine.pull();
      await pumpEventQueue();

      await statusSub.cancel();
      expect(statusEmissions.length - statusCountBeforePull, equals(1));
    });
  });

  group('hasNewRemoteData', () {
    test('false on a fresh engine talking to a fresh server', () async {
      expect(await engine.hasNewRemoteData(), isFalse);
    });

    test('false after this engine pushes its own change (cursor catches '
        'up)', () async {
      await engine.stageLocalChange(
        id: 'local1',
        type: 'transaction',
        ciphertext: _bytes('v1'),
        nonce: _bytes('local-nonce1'),
      );
      await engine.sync();

      expect(await engine.hasNewRemoteData(), isFalse);
    });

    test('true once another device has pushed something this engine '
        "hasn't pulled", () async {
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'other-device-1',
          type: 'transaction',
          ciphertext: _bytes('someone-elses-data'),
          nonce: _bytes('other-nonce1'),
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );

      expect(await engine.hasNewRemoteData(), isTrue);
    });

    test('false again after pulling the other device\'s change', () async {
      fakeApi.seedServerRecord(
        VaultRecordResponse(
          id: 'other-device-1',
          type: 'transaction',
          ciphertext: _bytes('someone-elses-data'),
          nonce: _bytes('other-nonce1'),
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 1),
          deleted: false,
        ),
      );
      expect(await engine.hasNewRemoteData(), isTrue);

      await engine.pull();

      expect(await engine.hasNewRemoteData(), isFalse);
    });
  });
}
