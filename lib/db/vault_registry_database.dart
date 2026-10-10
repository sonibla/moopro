import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'vault_registry_database.g.dart';

@DataClassName('VaultRegistryRow')
class VaultRegistryEntries extends Table {
  TextColumn get id => text()();

  TextColumn get dbName => text()();

  TextColumn get kind => text()();

  TextColumn get label => text()();

  TextColumn get email => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get lastOpenedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [VaultRegistryEntries])
class VaultRegistryDatabase extends _$VaultRegistryDatabase {
  VaultRegistryDatabase([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'vault_registry',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
