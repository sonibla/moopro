import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/auth_controller.dart';
import '../vault/vault_registry.dart';

class VaultPickerScreen extends ConsumerWidget {
  const VaultPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final vaults = authState is AuthNeedsVaultSelection
        ? authState.vaults
        : const <VaultRegistryEntry>[];
    final connected = authState is AuthNeedsVaultSelection
        ? authState.connectedEmails
        : const <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Vaults on this device')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (vaults.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No vaults on this device yet.'),
            )
          else
            for (final vault in vaults)
              _VaultTile(
                vault: vault,
                connected:
                    vault.email != null && connected.contains(vault.email),
              ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Log into an account'),
            onTap: () =>
                ref.read(authControllerProvider.notifier).returnToLoginScreen(),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create a new offline vault'),
            subtitle: const Text(
              'No server involved — kept only on this device',
            ),
            onTap: () =>
                ref.read(authControllerProvider.notifier).startOfflineSetup(),
          ),
        ],
      ),
    );
  }
}

class _VaultTile extends ConsumerWidget {
  final VaultRegistryEntry vault;

  final bool connected;

  const _VaultTile({required this.vault, required this.connected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = vault.kind == VaultKind.offline;
    return ListTile(
      leading: Icon(
        isOffline
            ? Icons.lock_outline
            : (connected ? Icons.cloud_done_outlined : Icons.cloud_outlined),
      ),
      title: Text(vault.label),
      subtitle: Text(
        isOffline
            ? 'Offline vault · last opened ${_relativeTime(vault.lastOpenedAt)}'
            : '${vault.email ?? 'Online account'} · '
                  '${connected ? 'Connected' : 'Sign-in required'} · last '
                  'opened ${_relativeTime(vault.lastOpenedAt)}',
      ),
      onTap: () => ref.read(authControllerProvider.notifier).selectVault(vault),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete this vault\'s local data',
        onPressed: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final isOffline = vault.kind == VaultKind.offline;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${vault.label}"?'),
        content: Text(
          isOffline
              ? 'This permanently deletes this vault\'s data. There is no '
                    'server copy — this cannot be undone.'
              : 'This only clears this device\'s local copy. Your data '
                    'stays on the server and re-downloads the next time you '
                    'sign in on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteVault(vault);
    } on ActiveVaultCannotBeDeletedException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Switch to a different vault before deleting this one.',
            ),
          ),
        );
      }
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays >= 1) return DateFormat.yMMMd().format(time);
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
