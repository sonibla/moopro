import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backup/backup_service.dart';
import '../domain/domain_repository.dart';
import '../providers/app_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  final BackupService? backupService;

  const BackupScreen({super.key, this.backupService});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

enum _RestoreStep { idle, decrypting, restoring }

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _exportPasswordController = TextEditingController();
  final _restorePasswordController = TextEditingController();
  late final BackupService _backupService =
      widget.backupService ?? BackupService();

  bool _exporting = false;
  String? _exportError;
  String? _exportSuccess;

  PlatformFile? _selectedFile;
  _RestoreStep _restoreStep = _RestoreStep.idle;
  int _restoreDone = 0;
  int _restoreTotal = 0;
  String? _restoreError;
  String? _restoreSuccess;

  @override
  void dispose() {
    _exportPasswordController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCreateSection(context),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 32),
                _buildRestoreSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create backup', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Exports all of your data, encrypted with your vault master '
          'password using GPG-compatible OpenPGP — the file can be '
          'decrypted with `gpg --decrypt` even without this app, using '
          'just that password.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _exportPasswordController,
          decoration: const InputDecoration(labelText: 'Vault master password'),
          obscureText: true,
          enabled: !_exporting,
        ),
        const SizedBox(height: 16),
        if (_exportError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _exportError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_exportSuccess != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_exportSuccess!),
          ),
        if (_exporting)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Encrypting backup — this may take a moment for a '
                    'large vault...',
                  ),
                ),
              ],
            ),
          ),
        FilledButton(
          onPressed: _exporting ? null : _exportBackup,
          child: const Text('Export backup'),
        ),
      ],
    );
  }

  Widget _buildRestoreSection(BuildContext context) {
    final isBusy = _restoreStep != _RestoreStep.idle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Restore backup', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Only works into a brand-new, empty vault — refuses if this '
          'vault already has any data.',
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: isBusy ? null : _pickBackupFile,
          child: Text(_selectedFile?.name ?? 'Choose backup file...'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _restorePasswordController,
          decoration: const InputDecoration(labelText: 'Backup password'),
          obscureText: true,
          enabled: !isBusy,
        ),
        const SizedBox(height: 16),
        if (_restoreError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _restoreError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_restoreSuccess != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_restoreSuccess!),
          ),
        if (_restoreStep == _RestoreStep.decrypting)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Decrypting backup...'),
              ],
            ),
          ),
        if (_restoreStep == _RestoreStep.restoring)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _restoreTotal == 0
                      ? 0.0
                      : _restoreDone / _restoreTotal,
                ),
                const SizedBox(height: 8),
                Text('Restoring $_restoreDone of $_restoreTotal records'),
              ],
            ),
          ),
        FilledButton(
          onPressed: (isBusy || _selectedFile == null) ? null : _restoreBackup,
          child: const Text('Restore'),
        ),
      ],
    );
  }

  Future<void> _exportBackup() async {
    final password = _exportPasswordController.text;
    if (password.isEmpty) {
      setState(() => _exportError = 'Password is required');
      return;
    }
    setState(() {
      _exporting = true;
      _exportError = null;
      _exportSuccess = null;
    });
    try {
      final repo = ref.read(domainRepositoryProvider);
      final payload = await repo.buildBackupPayload();
      final armored = await _backupService.exportBackup(
        payload: payload,
        password: password,
      );
      final fileName =
          'moopro-backup-${DateTime.now().toUtc().toIso8601String().split('T').first}.asc';
      final savedPath = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(armored)),
      );
      if (!mounted) return;
      setState(() {
        _exportSuccess = savedPath == null
            ? 'Backup export cancelled.'
            : 'Backup saved: $savedPath';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _exportError = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedFile = result.files.single;
      _restoreError = null;
      _restoreSuccess = null;
    });
  }

  Future<void> _restoreBackup() async {
    final file = _selectedFile;
    final password = _restorePasswordController.text;
    if (file == null) return;
    if (password.isEmpty) {
      setState(() => _restoreError = 'Password is required');
      return;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _restoreError = 'Could not read the selected file.');
      return;
    }
    setState(() {
      _restoreStep = _RestoreStep.decrypting;
      _restoreError = null;
      _restoreSuccess = null;
    });
    try {
      final armored = utf8.decode(bytes);
      final payload = await _backupService.decryptBackup(
        armored: armored,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _restoreStep = _RestoreStep.restoring;
        _restoreDone = 0;
        _restoreTotal = payload.entities.length;
      });
      final repo = ref.read(domainRepositoryProvider);
      await repo.restoreBackup(
        payload,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _restoreDone = done;
            _restoreTotal = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _restoreSuccess =
            'Restore complete — ${payload.entities.length} records restored.';
        _selectedFile = null;
        _restorePasswordController.clear();
      });
    } on BackupDecryptException {
      if (!mounted) return;
      setState(
        () => _restoreError = 'Incorrect password, or not a valid backup file.',
      );
    } on VaultNotEmptyException {
      if (!mounted) return;
      setState(
        () => _restoreError =
            'This vault already has data — restore only works into a '
            'brand-new empty vault.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoreError = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _restoreStep = _RestoreStep.idle);
    }
  }
}
