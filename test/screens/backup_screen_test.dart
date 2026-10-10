import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/vault_api.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/backup/backup_models.dart';
import 'package:moopro/backup/backup_service.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/screens/backup_screen.dart';
import 'package:moopro/sync/sync_engine.dart';

BackupPayload _samplePayload() => BackupPayload(
  schemaVersion: BackupPayload.currentSchemaVersion,
  exportedAt: DateTime.utc(2026, 1, 1),
  entities: [
    const BackupEntity(
      id: 'asset001',
      type: VaultRecordTypes.asset,
      data: {'kind': 'fiat', 'symbol': 'EUR', 'name': 'Euro'},
    ),
  ],
);

BackupService _testBackupService() => BackupService(
  runEncrypt: (args) async => encryptIsolateEntry(args),
  runDecrypt: (args) async => decryptIsolateEntry(args),
);

class _FakeDomainRepository extends DomainRepository {
  BackupPayload? payloadToReturn;
  Object? restoreError;
  List<BackupEntity>? restoredEntities;

  _FakeDomainRepository()
    : super(
        syncDb: AppDatabase(NativeDatabase.memory()),
        cacheDb: DomainCacheDatabase(),
        syncEngine: SyncEngine(
          db: AppDatabase(NativeDatabase.memory()),
          vaultApi: VaultApi(ApiClient()),
        ),
        balanceEngine: BalanceEngine(DomainCacheDatabase()),
        vaultSession: _FakeVaultSessionManager(),
      );

  @override
  Future<BackupPayload> buildBackupPayload() async =>
      payloadToReturn ?? _samplePayload();

  @override
  Future<void> restoreBackup(
    BackupPayload payload, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (restoreError != null) throw restoreError!;
    restoredEntities = payload.entities;
    onProgress?.call(0, payload.entities.length);
    onProgress?.call(payload.entities.length, payload.entities.length);
  }
}

class _FakeVaultSessionManager extends VaultSessionManager {
  _FakeVaultSessionManager()
    : super(
        authApi: AuthApi(ApiClient()),
        localUnlockStore: LocalUnlockStore(),
        localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
          AppDatabase(NativeDatabase.memory()),
        ),
      );
}

class _FakeFilePicker extends FilePicker {
  String? savedFileName;
  Uint8List? savedBytes;
  String? saveReturnPath;

  List<PlatformFile>? filesToReturnOnPick;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    savedFileName = fileName;
    savedBytes = bytes;
    return saveReturnPath;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final files = filesToReturnOnPick;
    if (files == null) return null;
    return FilePickerResult(files);
  }
}

void main() {
  late _FakeDomainRepository repo;
  late _FakeFilePicker filePicker;

  setUp(() {
    repo = _FakeDomainRepository();
    filePicker = _FakeFilePicker();
    FilePicker.platform = filePicker;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: BackupScreen(backupService: _testBackupService()),
        ),
      ),
    );
    await tester.pump();
  }

  group('export', () {
    testWidgets('requires a password before exporting', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();

      expect(find.text('Password is required'), findsOneWidget);
      expect(filePicker.savedBytes, isNull);
    });

    testWidgets('encrypts the payload and saves an armored .asc file', (
      tester,
    ) async {
      filePicker.saveReturnPath = '/home/user/Downloads/moopro-backup.asc';
      await pump(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Vault master password'),
        'hunter2',
      );
      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();

      expect(filePicker.savedBytes, isNotNull);
      final armored = utf8.decode(filePicker.savedBytes!);
      expect(armored, contains('BEGIN PGP MESSAGE'));
      expect(
        find.textContaining('/home/user/Downloads/moopro-backup.asc'),
        findsOneWidget,
      );
    });
  });

  group('restore', () {
    testWidgets('happy path: decrypts, restores, and shows a success message', (
      tester,
    ) async {
      final service = _testBackupService();
      final armored = await service.exportBackup(
        payload: _samplePayload(),
        password: 'correcthorse',
      );
      filePicker.filesToReturnOnPick = [
        PlatformFile(
          name: 'backup.asc',
          size: armored.length,
          bytes: Uint8List.fromList(utf8.encode(armored)),
        ),
      ];
      await pump(tester);

      await tester.ensureVisible(find.text('Choose backup file...'));
      await tester.tap(find.text('Choose backup file...'));
      await tester.pumpAndSettle();
      expect(find.text('backup.asc'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Backup password'),
        'correcthorse',
      );
      await tester.ensureVisible(find.text('Restore'));
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Restore complete'), findsOneWidget);
      expect(repo.restoredEntities, isNotNull);
      expect(repo.restoredEntities!.single.id, equals('asset001'));
    });

    testWidgets('wrong password shows a clear error', (tester) async {
      final service = _testBackupService();
      final armored = await service.exportBackup(
        payload: _samplePayload(),
        password: 'correcthorse',
      );
      filePicker.filesToReturnOnPick = [
        PlatformFile(
          name: 'backup.asc',
          size: armored.length,
          bytes: Uint8List.fromList(utf8.encode(armored)),
        ),
      ];
      await pump(tester);

      await tester.ensureVisible(find.text('Choose backup file...'));
      await tester.tap(find.text('Choose backup file...'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Backup password'),
        'wrongpassword',
      );
      await tester.ensureVisible(find.text('Restore'));
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Incorrect password, or not a valid backup file'),
        findsOneWidget,
      );
      expect(repo.restoredEntities, isNull);
    });

    testWidgets(
      'restoring into a non-empty vault shows the VaultNotEmptyException error',
      (tester) async {
        repo.restoreError = const VaultNotEmptyException();
        final service = _testBackupService();
        final armored = await service.exportBackup(
          payload: _samplePayload(),
          password: 'correcthorse',
        );
        filePicker.filesToReturnOnPick = [
          PlatformFile(
            name: 'backup.asc',
            size: armored.length,
            bytes: Uint8List.fromList(utf8.encode(armored)),
          ),
        ];
        await pump(tester);

        await tester.ensureVisible(find.text('Choose backup file...'));
        await tester.tap(find.text('Choose backup file...'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Backup password'),
          'correcthorse',
        );
        await tester.ensureVisible(find.text('Restore'));
        await tester.tap(find.text('Restore'));
        await tester.pumpAndSettle();

        expect(find.textContaining('already has data'), findsOneWidget);
      },
    );
  });
}
