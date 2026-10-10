import 'package:drift/wasm.dart';

Future<bool> vaultDatabaseExists(String dbName) async {
  final probe = await _probe(dbName);
  return probe.existingDatabases.any((entry) => entry.$2 == dbName);
}

Future<void> deleteVaultDatabase(String dbName) async {
  final probe = await _probe(dbName);
  for (final entry in probe.existingDatabases.where((e) => e.$2 == dbName)) {
    await probe.deleteDatabase(entry);
  }
}

Future<String?> vaultDatabaseDisplayPath(String dbName) async => null;

Future<WasmProbeResult> _probe(String dbName) {
  return WasmDatabase.probe(
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    databaseName: dbName,
  );
}
