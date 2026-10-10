import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../crypto/local_unlock_gate.dart';
import '../providers/auth_controller.dart';

class VaultUnlockScreen extends ConsumerStatefulWidget {
  const VaultUnlockScreen({super.key});

  @override
  ConsumerState<VaultUnlockScreen> createState() => _VaultUnlockScreenState();
}

class _VaultUnlockScreenState extends ConsumerState<VaultUnlockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _labelController = TextEditingController(text: 'Offline vault');
  String? _error;

  bool _saveKey = false;

  bool? _lastSubmittedIsFirstSetup;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy =
        authState is AuthUnlocking || authState is AuthOfflineUnlocking;
    final isFirstSetup = isBusy
        ? (_lastSubmittedIsFirstSetup ?? false)
        : (authState is AuthNeedsVaultSetup ||
              authState is AuthOfflineNeedsSetup);
    final isOffline =
        authState is AuthOfflineNeedsSetup ||
        authState is AuthOfflineNeedsUnlock ||
        authState is AuthOfflineUnlocking;

    final title = isOffline
        ? (isFirstSetup ? 'Create local vault' : 'Unlock local vault')
        : (isFirstSetup ? 'Set up vault' : 'Unlock vault');
    final description = isOffline
        ? (isFirstSetup
              ? 'Choose a master password for this device\'s offline vault. '
                    'There is no server involved — this password is the only '
                    'way to decrypt your data.'
              : 'Enter your master password to unlock this device\'s offline '
                    'vault.')
        : (isFirstSetup
              ? 'This is your first login. Choose a master password '
                    'to set up end-to-end encryption for your data.'
              : 'Enter your master password to unlock your data.');

    void goBack() =>
        ref.read(authControllerProvider.notifier).backToVaultList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isBusy) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          automaticallyImplyLeading: false,
          leading: isBusy ? null : BackButton(onPressed: goBack),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(description, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (isOffline && isFirstSetup) ...[
                      TextFormField(
                        controller: _labelController,
                        decoration: const InputDecoration(
                          labelText: 'Vault name',
                          helperText: 'Shown in the vault list on this device',
                        ),
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'A name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Master password',
                      ),
                      obscureText: true,
                      autofocus: true,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Password is required'
                          : null,
                    ),
                    if (isFirstSetup) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                          labelText: 'Confirm master password',
                        ),
                        obscureText: true,
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                    ],
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _saveKey,
                      onChanged: isBusy
                          ? null
                          : (value) =>
                                setState(() => _saveKey = value ?? false),
                      title: const Text('Save master key on this device'),
                      subtitle: Text(
                        localUnlockHasRealGate
                            ? 'Unlock next time with your biometric/PIN '
                                  'instead of typing the password.'
                            : 'Unlock next time without typing the password. '
                                  'Not protected by a biometric or PIN prompt '
                                  'on this platform.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SelectableText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: isBusy
                          ? null
                          : () => _submit(
                              isFirstSetup: isFirstSetup,
                              isOffline: isOffline,
                            ),
                      child: isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isFirstSetup
                                  ? (isOffline
                                        ? 'Create vault'
                                        : 'Set up vault')
                                  : 'Unlock',
                            ),
                    ),
                    if (!isFirstSetup) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isBusy
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .showVaultPicker(),
                        child: const Text('Use a different vault'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit({
    required bool isFirstSetup,
    required bool isOffline,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _lastSubmittedIsFirstSetup = isFirstSetup;
    });
    final controller = ref.read(authControllerProvider.notifier);
    try {
      if (isOffline) {
        if (isFirstSetup) {
          await controller.completeOfflineVaultSetup(
            password: _passwordController.text,
            label: _labelController.text,
            saveKey: _saveKey,
          );
        } else {
          await controller.unlockOffline(
            password: _passwordController.text,
            saveKey: _saveKey,
          );
        }
        return;
      }
      final authState = ref.read(authControllerProvider);
      final user = switch (authState) {
        AuthNeedsVaultSetup(:final user) => user,
        AuthNeedsUnlock(:final user) => user,
        _ => null,
      };
      if (user == null) return;
      if (isFirstSetup) {
        await controller.completeVaultSetup(
          user: user,
          password: _passwordController.text,
          saveKey: _saveKey,
        );
      } else {
        await controller.unlock(
          user: user,
          password: _passwordController.text,
          saveKey: _saveKey,
        );
      }
    } catch (_) {
      setState(
        () => _error = isFirstSetup
            ? 'Vault setup failed. Please try again.'
            : 'Incorrect password.',
      );
    }
  }
}
