import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/backup/backup_models.dart';
import 'package:moopro/backup/backup_service.dart';
import 'package:moopro/domain/models.dart';

BackupService _service() => BackupService(
  runEncrypt: (args) async => encryptIsolateEntry(args),
  runDecrypt: (args) async => decryptIsolateEntry(args),
);

BackupPayload _samplePayload() => BackupPayload(
  schemaVersion: BackupPayload.currentSchemaVersion,
  exportedAt: DateTime.utc(2026, 1, 1),
  entities: [
    const BackupEntity(
      id: 'asset001',
      type: VaultRecordTypes.asset,
      data: {'kind': 'fiat', 'symbol': 'EUR', 'name': 'Euro'},
    ),
    const BackupEntity(
      id: 'container01',
      type: VaultRecordTypes.container,
      data: {'name': 'Bank', 'containerType': 'holder', 'parentId': null},
    ),
  ],
);

void main() {
  test('export then decrypt with the same password recovers the identical '
      'payload', () async {
    final service = _service();
    final payload = _samplePayload();

    final armored = await service.exportBackup(
      payload: payload,
      password: 'hunter2',
    );

    expect(armored, contains('BEGIN PGP MESSAGE'));

    final decrypted = await service.decryptBackup(
      armored: armored,
      password: 'hunter2',
    );

    expect(decrypted.schemaVersion, equals(payload.schemaVersion));
    expect(decrypted.exportedAt, equals(payload.exportedAt));
    expect(decrypted.entities, hasLength(2));
    expect(decrypted.entities[0].id, equals('asset001'));
    expect(decrypted.entities[0].data, equals(payload.entities[0].data));
    expect(decrypted.entities[1].id, equals('container01'));
  });

  test(
    'decrypting with the wrong password throws BackupDecryptException',
    () async {
      final service = _service();
      final armored = await service.exportBackup(
        payload: _samplePayload(),
        password: 'correct-password',
      );

      await expectLater(
        () => service.decryptBackup(armored: armored, password: 'wrong'),
        throwsA(isA<BackupDecryptException>()),
      );
    },
  );

  test(
    'decrypting non-backup/garbage content throws BackupDecryptException',
    () async {
      final service = _service();

      await expectLater(
        () => service.decryptBackup(
          armored: 'not a real pgp message',
          password: 'x',
        ),
        throwsA(isA<BackupDecryptException>()),
      );
    },
  );
}
