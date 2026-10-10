import 'package:drift/drift.dart';

import '../db/vault_registry_database.dart';
import '../domain/id_generator.dart';

enum VaultKind {
  online,
  offline;

  static VaultKind fromStorage(String value) => switch (value) {
    'online' => VaultKind.online,
    'offline' => VaultKind.offline,
    _ => throw ArgumentError('Unknown VaultKind: $value'),
  };
}

class VaultRegistryEntry {
  final String id;
  final String dbName;
  final VaultKind kind;
  final String label;
  final String? email;
  final DateTime createdAt;
  final DateTime lastOpenedAt;

  const VaultRegistryEntry({
    required this.id,
    required this.dbName,
    required this.kind,
    required this.label,
    required this.email,
    required this.createdAt,
    required this.lastOpenedAt,
  });

  VaultRegistryEntry.fromRow(VaultRegistryRow row)
    : id = row.id,
      dbName = row.dbName,
      kind = VaultKind.fromStorage(row.kind),
      label = row.label,
      email = row.email,
      createdAt = row.createdAt,
      lastOpenedAt = row.lastOpenedAt;
}

class VaultRegistry {
  final VaultRegistryDatabase db;

  VaultRegistry(this.db);

  Future<List<VaultRegistryEntry>> list() async {
    final rows =
        await (db.select(db.vaultRegistryEntries)..orderBy([
              (t) => OrderingTerm(
                expression: t.lastOpenedAt,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    return rows.map(VaultRegistryEntry.fromRow).toList();
  }

  Future<VaultRegistryEntry?> get(String id) async {
    final row = await (db.select(
      db.vaultRegistryEntries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : VaultRegistryEntry.fromRow(row);
  }

  Future<VaultRegistryEntry> createOfflineVault({required String label}) {
    return _create(kind: VaultKind.offline, label: label, email: null);
  }

  Future<VaultRegistryEntry> resolveOnlineVault({
    required String email,
    required String label,
  }) async {
    final existingForEmail =
        await (db.select(db.vaultRegistryEntries)..where(
              (t) =>
                  t.kind.equals(VaultKind.online.name) & t.email.equals(email),
            ))
            .getSingleOrNull();
    if (existingForEmail != null) {
      return VaultRegistryEntry.fromRow(existingForEmail);
    }

    return _create(kind: VaultKind.online, label: label, email: email);
  }

  Future<VaultRegistryEntry> _create({
    required VaultKind kind,
    required String label,
    required String? email,
  }) async {
    final id = generateRecordId();
    final dbName = 'moopro_vault_$id';
    final now = DateTime.now();
    await db
        .into(db.vaultRegistryEntries)
        .insert(
          VaultRegistryEntriesCompanion.insert(
            id: id,
            dbName: dbName,
            kind: kind.name,
            label: label,
            email: Value(email),
            createdAt: now,
            lastOpenedAt: now,
          ),
        );
    return VaultRegistryEntry(
      id: id,
      dbName: dbName,
      kind: kind,
      label: label,
      email: email,
      createdAt: now,
      lastOpenedAt: now,
    );
  }

  Future<VaultRegistryEntry> convertOfflineVaultToOnline({
    required String id,
    required String email,
  }) async {
    await (db.update(
      db.vaultRegistryEntries,
    )..where((t) => t.id.equals(id))).write(
      VaultRegistryEntriesCompanion(
        kind: Value(VaultKind.online.name),
        email: Value(email),
      ),
    );
    return (await get(id))!;
  }

  Future<void> touch(String id) async {
    await (db.update(
      db.vaultRegistryEntries,
    )..where((t) => t.id.equals(id))).write(
      VaultRegistryEntriesCompanion(lastOpenedAt: Value(DateTime.now())),
    );
  }

  Future<void> delete(String id) async {
    await (db.delete(
      db.vaultRegistryEntries,
    )..where((t) => t.id.equals(id))).go();
  }
}
