import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'providers/auth_controller.dart';
import 'screens/app_shell.dart';
import 'screens/auth_entry_screen.dart';
import 'screens/vault_picker_screen.dart';
import 'screens/vault_unlock_screen.dart';
import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'widgets/app_startup_loading_screen.dart';

void main() {
  runApp(const ProviderScope(child: MooproApp()));
}

class MooproApp extends ConsumerWidget {
  const MooproApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = switch (authState) {
      AuthReady() || AuthOfflineReady() => ref.watch(themeModeProvider),
      _ => ThemeMode.system,
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'moopro',
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    return switch (authState) {
      AuthLoggedOut() || AuthLoggingIn() => const AuthEntryScreen(),
      AuthResumingSession() => const AppStartupLoadingScaffold(),
      AuthNeedsVaultSelection() => const VaultPickerScreen(),
      AuthNeedsVaultSetup() ||
      AuthNeedsUnlock() ||
      AuthUnlocking() => const VaultUnlockScreen(),
      AuthOfflineNeedsSetup() ||
      AuthOfflineNeedsUnlock() ||
      AuthOfflineUnlocking() => const VaultUnlockScreen(),
      AuthReady() || AuthOfflineReady() => const AppShell(),
    };
  }
}
