import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'local_vault_records.dart';
import 'tables.dart'
    show SyncState, RecordVersionHighWaterMark, LocalVaultKeyMaterial;

part 'database.g.dart';

@DriftDatabase(
  tables: [
    LocalVaultRecords,
    SyncState,
    RecordVersionHighWaterMark,
    LocalVaultKeyMaterial,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection('moopro_vault'));

  AppDatabase.withName(String dbName) : super(_openConnection(dbName));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 5) {
        await m.createTable(localVaultKeyMaterial);
      }
      if (from < 4) {
        await m.addColumn(localVaultRecords, localVaultRecords.conflictedAt);
      }
      if (from < 3) {
        for (final name in [
          'assets',
          'containers',
          'transactions',
          'price_snapshots',
          'balance_checkpoints',
        ]) {
          await m.deleteTable(name);
        }
      }
    },
  );

  static QueryExecutor _openConnection(String dbName) {
    return driftDatabase(
      name: dbName,
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
