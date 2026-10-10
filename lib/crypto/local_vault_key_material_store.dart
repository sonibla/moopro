import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../db/database.dart';

class LocalKeyMaterial {
  final Uint8List kdfSalt;
  final Map<String, dynamic> kdfParams;
  final Uint8List wrappedDek;
  final Uint8List wrapNonce;

  const LocalKeyMaterial({
    required this.kdfSalt,
    required this.kdfParams,
    required this.wrappedDek,
    required this.wrapNonce,
  });
}

class LocalVaultKeyMaterialStore {
  static const _rowId = 0;

  final AppDatabase db;

  LocalVaultKeyMaterialStore(this.db);

  Future<bool> exists() async {
    final row = await _readRow();
    return row != null;
  }

  Future<LocalKeyMaterial?> read() async {
    final row = await _readRow();
    if (row == null) return null;
    return LocalKeyMaterial(
      kdfSalt: Uint8List.fromList(row.kdfSalt),
      kdfParams: jsonDecode(row.kdfParamsJson) as Map<String, dynamic>,
      wrappedDek: Uint8List.fromList(row.wrappedDek),
      wrapNonce: Uint8List.fromList(row.wrapNonce),
    );
  }

  Future<void> write({
    required Uint8List kdfSalt,
    required Map<String, dynamic> kdfParams,
    required Uint8List wrappedDek,
    required Uint8List wrapNonce,
  }) async {
    await db
        .into(db.localVaultKeyMaterial)
        .insertOnConflictUpdate(
          LocalVaultKeyMaterialCompanion(
            id: const Value(_rowId),
            kdfSalt: Value(kdfSalt),
            kdfParamsJson: Value(jsonEncode(kdfParams)),
            wrappedDek: Value(wrappedDek),
            wrapNonce: Value(wrapNonce),
          ),
        );
  }

  Future<void> clear() async {
    await (db.delete(
      db.localVaultKeyMaterial,
    )..where((t) => t.id.equals(_rowId))).go();
  }

  Future<LocalVaultKeyMaterialData?> _readRow() {
    return (db.select(
      db.localVaultKeyMaterial,
    )..where((t) => t.id.equals(_rowId))).getSingleOrNull();
  }
}
