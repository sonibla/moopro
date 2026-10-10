import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<bool> vaultDatabaseExists(String dbName) async {
  return (await _dbFile(dbName)).exists();
}

Future<void> deleteVaultDatabase(String dbName) async {
  final base = await _dbFile(dbName);
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('${base.path}$suffix');
    if (await file.exists()) await file.delete();
  }
}

Future<String?> vaultDatabaseDisplayPath(String dbName) async {
  return (await _dbFile(dbName)).path;
}

Future<File> _dbFile(String dbName) async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, '$dbName.sqlite'));
}
