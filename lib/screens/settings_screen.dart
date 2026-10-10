import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/local_unlock_gate.dart';
import '../db/domain_cache_database.dart' as ldb;
import '../db/vault_storage.dart';
import '../domain/date_time_format_prefs.dart';
import '../domain/models.dart';
import '../domain/theme_mode_prefs.dart';
import '../api/models.dart';
import '../providers/app_providers.dart';
import '../providers/auth_controller.dart';
import '../widgets/hide_amounts_button.dart';
import '../widgets/sync_conflict_dialog.dart';
import '../widgets/sync_status_icon.dart';
import 'backup_screen.dart';
import 'password_change_screen.dart';
import 'statement_import_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _localUnlockEnabled;

  bool? _totpEnabled;
  String? _vaultStoragePath;
  bool _vaultStoragePathLoaded = false;

  @override
  void initState() {
    super.initState();
    ref.read(localUnlockStoreProvider).isOptedIn().then((value) {
      if (mounted) setState(() => _localUnlockEnabled = value);
    });
    final active = ref.read(activeVaultProvider);
    if (active != null) {
      vaultDatabaseDisplayPath(active.dbName).then((path) {
        if (mounted) {
          setState(() {
            _vaultStoragePath = path;
            _vaultStoragePathLoaded = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthReady ? authState.user : null;
    final apiKeySetting = ref
        .watch(settingStreamProvider(SettingIds.alphavantageApiKey))
        .value;
    final apiKeyValue = apiKeySetting?.value;
    final assets = ref.watch(assetsStreamProvider).value;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Signed in as ${user?.email ?? ''}'),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.vpn_key_outlined),
          title: const Text('AlphaVantage API key'),
          subtitle: Text(
            apiKeyValue == null || apiKeyValue.isEmpty
                ? 'Not set — needed for automatic price fetching'
                : '••••••••',
          ),
          trailing: SyncStatusIcon(
            recordId: SettingIds.alphavantageApiKey,
            onTap: () => showSyncConflictDialog(
              context,
              onDismiss: () => ref
                  .read(domainRepositoryProvider)
                  .acknowledgeConflict(SettingIds.alphavantageApiKey),
              onOpen: () => _showApiKeyDialog(apiKeyValue),
            ),
          ),
          onTap: () => _showApiKeyDialog(apiKeyValue),
        ),
        const SizedBox(height: 8),
        if (assets != null) _defaultCurrencySetting(assets),
        const SizedBox(height: 8),
        _themeModeSetting(),
        const SizedBox(height: 8),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off_outlined),
          title: const Text('Hide amounts'),
          subtitle: const Text(
            'Mask balances and amounts across the app. Applies to all your '
            'devices.',
          ),
          value: ref.watch(hideAmountsProvider),
          onChanged: (hidden) => setHideAmounts(ref, hidden),
        ),
        const SizedBox(height: 8),
        _dateTimeFormatSettings(),
        _vaultStorageSection(),
        const SizedBox(height: 8),
        if (_localUnlockEnabled != null)
          SwitchListTile(
            title: Text(
              localUnlockHasRealGate
                  ? 'Unlock with biometrics/PIN'
                  : 'Store master key in keyring',
            ),
            subtitle: Text(
              localUnlockHasRealGate
                  ? 'Store the vault key on this device, gated by your OS '
                        'biometric/PIN prompt, so you don\'t need to type '
                        'your master password every time. Per-device — not '
                        'shared with your other devices.'
                  : 'Cache the vault key on this device\'s keychain so you '
                        'don\'t need to type your master password every '
                        'time. Not gated by a biometric or PIN prompt on '
                        'this platform — anyone with access to this OS '
                        'account can read it. Per-device — not shared with '
                        'your other devices.',
            ),
            value: _localUnlockEnabled!,
            onChanged: _onToggleLocalUnlock,
          ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Change password'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PasswordChangeScreen()),
          ),
        ),
        if (user != null)
          SwitchListTile(
            secondary: const Icon(Icons.security),
            title: const Text('Two-factor authentication (TOTP)'),
            subtitle: const Text(
              'Ask for an authenticator-app code when logging in. Already '
              'logged-in sessions are not asked again.',
            ),
            value: _totpEnabled ?? user.totpEnabled,
            onChanged: _onToggleTotp,
          ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: const Text('Import statements'),
          subtitle: const Text('PDF, CSV, or XLSX — pick one or more at once'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StatementImportScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Backup & Restore'),
          subtitle: const Text('Export or restore an encrypted backup file'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open-source licenses'),
          subtitle: const Text('Licenses of the libraries Moopro is built on'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Moopro',
            applicationLegalese: '© Moopro contributors',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }

  Future<void> _onToggleTotp(bool enable) async {
    final api = ref.read(authApiProvider);
    try {
      if (enable) {
        final totp = await api.enableTotp();
        setState(() => _totpEnabled = true);
        if (mounted) await _showTotpSecretDialog(totp);
      } else {
        await api.disableTotp();
        setState(() => _totpEnabled = false);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update two-factor authentication: ${e.message}',
          ),
        ),
      );
    }
  }

  Future<void> _showTotpSecretDialog(TotpSecretResponse totp) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to your authenticator app'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter this secret in your authenticator app (time-based, '
              '6 digits). It is only shown now — you will need a code to '
              'log in from now on.',
            ),
            const SizedBox(height: 16),
            SelectableText(totp.secret),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: totp.otpauthUri)),
            child: const Text('Copy otpauth link'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _vaultStorageSection() {
    final active = ref.watch(activeVaultProvider);
    final locationText = !_vaultStoragePathLoaded
        ? 'Resolving storage location…'
        : (_vaultStoragePath ??
              'Stored in this browser\'s local database (not a file)');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(active?.label ?? 'This vault'),
          subtitle: Text(locationText),
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('Manage vaults on this device'),
          subtitle: const Text(
            'Switch, create, or delete a vault — without logging out',
          ),
          onTap: () => ref
              .read(authControllerProvider.notifier)
              .lockAndShowVaultPicker(),
        ),
      ],
    );
  }

  Widget _defaultCurrencySetting(List<ldb.Asset> assets) {
    final fiatAssets =
        assets.where((a) => a.kind == AssetKind.fiat.name).toList()
          ..sort((a, b) => a.symbol.compareTo(b.symbol));
    if (fiatAssets.isEmpty) return const SizedBox.shrink();

    final storedId = ref.watch(defaultCurrencyAssetIdProvider);
    final currentId = fiatAssets.any((a) => a.id == storedId)
        ? storedId!
        : fiatAssets.first.id;

    return ListTile(
      leading: const Icon(Icons.attach_money),
      title: const Text('Default currency'),
      subtitle: const Text(
        'Used to convert asset values across Assets, Budgets, and Holders',
      ),
      trailing: DropdownButton<String>(
        value: currentId,
        items: [
          for (final a in fiatAssets)
            DropdownMenuItem(value: a.id, child: Text(a.symbol)),
        ],
        onChanged: (id) {
          if (id != null) {
            ref
                .read(domainRepositoryProvider)
                .setSetting(SettingIds.defaultCurrencyAssetId, id);
          }
        },
      ),
    );
  }

  Widget _themeModeSetting() {
    final mode = ref.watch(themeModeProvider);
    final domainRepository = ref.read(domainRepositoryProvider);
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: const Text('Theme'),
      trailing: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Tooltip(message: 'Light', child: Icon(Icons.light_mode)),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Tooltip(message: 'Dark', child: Icon(Icons.dark_mode)),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Tooltip(
              message: 'System',
              child: Icon(Icons.brightness_auto),
            ),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => domainRepository.setSetting(
          SettingIds.themeMode,
          themeModeStorageValue(selection.first),
        ),
      ),
    );
  }

  Widget _dateTimeFormatSettings() {
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    final domainRepository = ref.read(domainRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined),
          title: const Text('Date format'),
          trailing: DropdownButton<DateFormatOption>(
            value: prefs.dateFormat,
            items: [
              for (final option in DateFormatOption.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
            onChanged: (option) {
              if (option != null) {
                domainRepository.setSetting(
                  SettingIds.dateFormat,
                  option.storageValue,
                );
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('Time format'),
          trailing: DropdownButton<bool>(
            value: prefs.use24HourTime,
            items: const [
              DropdownMenuItem(value: true, child: Text('24-hour')),
              DropdownMenuItem(value: false, child: Text('12-hour (AM/PM)')),
            ],
            onChanged: (use24Hour) {
              if (use24Hour != null) {
                domainRepository.setSetting(
                  SettingIds.timeFormat,
                  use24Hour ? '24h' : '12h',
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onToggleLocalUnlock(bool value) async {
    final vaultSession = ref.read(vaultSessionManagerProvider);
    if (value) {
      await vaultSession.enableLocalUnlock();
    } else {
      await vaultSession.disableLocalUnlock();
    }
    setState(() => _localUnlockEnabled = value);
  }

  Future<void> _showApiKeyDialog(String? currentValue) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ApiKeyDialog(currentValue: currentValue),
    );
    if (result == null || !mounted) return;
    final domainRepository = ref.read(domainRepositoryProvider);
    if (result.isEmpty) {
      await domainRepository.clearSetting(SettingIds.alphavantageApiKey);
    } else {
      await domainRepository.setSetting(SettingIds.alphavantageApiKey, result);
    }
  }
}

class _ApiKeyDialog extends StatefulWidget {
  final String? currentValue;

  const _ApiKeyDialog({required this.currentValue});

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _controller;
  var _obscured = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AlphaVantage API key'),
      content: TextField(
        controller: _controller,
        obscureText: _obscured,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'API key',
          suffixIcon: IconButton(
            icon: Icon(
              _obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
        ),
      ),
      actions: [
        if (widget.currentValue != null && widget.currentValue!.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
