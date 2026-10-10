import 'package:drift/drift.dart';

class LocalVaultRecords extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  BlobColumn get ciphertext => blob()();
  BlobColumn get nonce => blob()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  DateTimeColumn get conflictedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
