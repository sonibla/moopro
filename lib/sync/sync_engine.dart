import 'package:drift/drift.dart';

import '../api/models.dart';
import '../api/vault_api.dart';
import '../db/database.dart';

class RollbackWarning {
  final String recordId;
  final int highestVersionSeen;
  final int pulledVersion;

  const RollbackWarning({
    required this.recordId,
    required this.highestVersionSeen,
    required this.pulledVersion,
  });

  @override
  String toString() =>
      'RollbackWarning(recordId: $recordId, highestVersionSeen: '
      '$highestVersionSeen, pulledVersion: $pulledVersion)';
}

class PullResult {
  final int recordsApplied;
  final List<RollbackWarning> rollbackWarnings;

  final List<VaultRecordResponse> appliedRecords;

  final List<VaultRecordConflict> conflicts;

  const PullResult({
    required this.recordsApplied,
    required this.rollbackWarnings,
    this.appliedRecords = const [],
    this.conflicts = const [],
  });
}

const int maxRecordsPerPushRequest = 500;

enum RecordSyncStatus { synced, pending, conflicted }

class SyncCounts {
  final int pending;
  final int conflicted;

  const SyncCounts({required this.pending, required this.conflicted});
}

class SyncEngine {
  final AppDatabase db;
  final VaultApi vaultApi;

  SyncEngine({required this.db, required this.vaultApi});

  Future<int> _readCursor() async {
    final row = await (db.select(
      db.syncState,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    return row?.lastSyncedVersion ?? 0;
  }

  Future<void> _writeCursor(int version) async {
    await db
        .into(db.syncState)
        .insertOnConflictUpdate(
          SyncStateCompanion(
            id: const Value(0),
            lastSyncedVersion: Value(version),
          ),
        );
  }

  Future<bool> hasNewRemoteData() async {
    final remoteLatest = await vaultApi.latestVersion();
    final localCursor = await _readCursor();
    return remoteLatest > localCursor;
  }

  Future<int> _highWaterMark(String recordId) async {
    final row = await (db.select(
      db.recordVersionHighWaterMark,
    )..where((t) => t.recordId.equals(recordId))).getSingleOrNull();
    return row?.highestVersionSeen ?? -1;
  }

  Future<void> _bumpHighWaterMark(String recordId, int version) async {
    final current = await _highWaterMark(recordId);
    if (version > current) {
      await db
          .into(db.recordVersionHighWaterMark)
          .insertOnConflictUpdate(
            RecordVersionHighWaterMarkCompanion(
              recordId: Value(recordId),
              highestVersionSeen: Value(version),
            ),
          );
    }
  }

  Future<PullResult> pull() async {
    final cursor = await _readCursor();
    final remoteRecords = await vaultApi.pull(sinceVersion: cursor);
    if (remoteRecords.isEmpty) {
      return const PullResult(recordsApplied: 0, rollbackWarnings: []);
    }

    final warnings = <RollbackWarning>[];
    final appliedRecords = <VaultRecordResponse>[];
    var applied = 0;
    var maxVersionSeen = cursor;
    int? cursorCeiling;

    await db.transaction(() async {
      for (final record in remoteRecords) {
        final localRow = await (db.select(
          db.localVaultRecords,
        )..where((t) => t.id.equals(record.id))).getSingleOrNull();
        if (localRow != null && localRow.dirty) {
          final ceiling = record.version - 1;
          cursorCeiling = cursorCeiling == null
              ? ceiling
              : (ceiling < cursorCeiling! ? ceiling : cursorCeiling);
          continue;
        }

        maxVersionSeen = record.version > maxVersionSeen
            ? record.version
            : maxVersionSeen;

        final seenHighWaterMark = await _highWaterMark(record.id);
        if (record.version < seenHighWaterMark) {
          warnings.add(
            RollbackWarning(
              recordId: record.id,
              highestVersionSeen: seenHighWaterMark,
              pulledVersion: record.version,
            ),
          );
          continue;
        }

        await db
            .into(db.localVaultRecords)
            .insertOnConflictUpdate(
              LocalVaultRecordsCompanion(
                id: Value(record.id),
                type: Value(record.type),
                ciphertext: Value(record.ciphertext),
                nonce: Value(record.nonce),
                deleted: Value(record.deleted),
                version: Value(record.version),
                updatedAt: Value(record.updatedAt),
                dirty: const Value(false),
              ),
            );
        await _bumpHighWaterMark(record.id, record.version);
        appliedRecords.add(record);
        applied++;
      }
    });

    final ceiling = cursorCeiling;
    final newCursor = ceiling != null
        ? (maxVersionSeen < ceiling ? maxVersionSeen : ceiling)
        : maxVersionSeen;
    await _writeCursor(newCursor);
    return PullResult(
      recordsApplied: applied,
      rollbackWarnings: warnings,
      appliedRecords: appliedRecords,
    );
  }

  Future<int> push() async {
    final dirtyRows = await (db.select(
      db.localVaultRecords,
    )..where((t) => t.dirty.equals(true))).get();
    if (dirtyRows.isEmpty) return 0;

    var pushed = 0;
    final allConflicts = <VaultRecordConflict>[];
    for (var i = 0; i < dirtyRows.length; i += maxRecordsPerPushRequest) {
      final chunk = dirtyRows.sublist(
        i,
        (i + maxRecordsPerPushRequest > dirtyRows.length)
            ? dirtyRows.length
            : i + maxRecordsPerPushRequest,
      );
      final upserts = chunk
          .map(
            (row) => VaultRecordUpsert(
              id: row.id,
              type: row.type,
              ciphertext: row.ciphertext,
              nonce: row.nonce,
              deleted: row.deleted,
              baseVersion: row.version,
            ),
          )
          .toList();
      List<VaultRecordResponse> results;
      try {
        results = await vaultApi.push(upserts);
      } on VaultConflictException catch (e) {
        allConflicts.addAll(e.conflicts);
        await (db.update(
          db.localVaultRecords,
        )..where((t) => t.id.isIn(e.conflicts.map((c) => c.id)))).write(
          LocalVaultRecordsCompanion(
            dirty: const Value(false),
            conflictedAt: Value(DateTime.now()),
          ),
        );
        continue;
      }
      await db.transaction(() async {
        for (final result in results) {
          await db
              .into(db.localVaultRecords)
              .insertOnConflictUpdate(
                LocalVaultRecordsCompanion(
                  id: Value(result.id),
                  type: Value(result.type),
                  ciphertext: Value(result.ciphertext),
                  nonce: Value(result.nonce),
                  deleted: Value(result.deleted),
                  version: Value(result.version),
                  updatedAt: Value(result.updatedAt),
                  dirty: const Value(false),
                  conflictedAt: const Value(null),
                ),
              );
          await _bumpHighWaterMark(result.id, result.version);
          pushed++;
        }
      });
    }
    if (allConflicts.isNotEmpty) {
      throw VaultConflictException(allConflicts);
    }
    return pushed;
  }

  Future<PullResult> sync() async {
    List<VaultRecordConflict> conflicts = const [];
    try {
      await push();
    } on VaultConflictException catch (e) {
      conflicts = e.conflicts;
    }
    final result = await pull();
    return conflicts.isEmpty
        ? result
        : PullResult(
            recordsApplied: result.recordsApplied,
            rollbackWarnings: result.rollbackWarnings,
            appliedRecords: result.appliedRecords,
            conflicts: conflicts,
          );
  }

  Future<void> stageLocalChange({
    required String id,
    required String type,
    required Uint8List ciphertext,
    required Uint8List nonce,
    bool deleted = false,
  }) async {
    await db
        .into(db.localVaultRecords)
        .insertOnConflictUpdate(
          LocalVaultRecordsCompanion(
            id: Value(id),
            type: Value(type),
            ciphertext: Value(ciphertext),
            nonce: Value(nonce),
            deleted: Value(deleted),
            dirty: const Value(true),
          ),
        );
  }

  RecordSyncStatus statusOf(LocalVaultRecord row) {
    if (row.conflictedAt != null) return RecordSyncStatus.conflicted;
    if (row.dirty) return RecordSyncStatus.pending;
    return RecordSyncStatus.synced;
  }

  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() {
    return db
        .select(db.localVaultRecords)
        .watch()
        .map((rows) => {for (final row in rows) row.id: statusOf(row)});
  }

  Stream<SyncCounts> watchSyncCounts() {
    final pendingExpr = db.localVaultRecords.id.count(
      filter:
          db.localVaultRecords.dirty.equals(true) &
          db.localVaultRecords.conflictedAt.isNull(),
    );
    final conflictedExpr = db.localVaultRecords.id.count(
      filter: db.localVaultRecords.conflictedAt.isNotNull(),
    );
    final query = db.selectOnly(db.localVaultRecords)
      ..addColumns([pendingExpr, conflictedExpr]);
    return query.watchSingle().map(
      (row) => SyncCounts(
        pending: row.read(pendingExpr) ?? 0,
        conflicted: row.read(conflictedExpr) ?? 0,
      ),
    );
  }

  Future<void> acknowledgeConflict(String id) async {
    await (db.update(db.localVaultRecords)..where((t) => t.id.equals(id)))
        .write(const LocalVaultRecordsCompanion(conflictedAt: Value(null)));
  }
}
