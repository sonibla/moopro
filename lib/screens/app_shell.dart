import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/domain_repository.dart';
import '../providers/app_providers.dart';
import '../providers/auth_controller.dart';
import '../widgets/app_startup_loading_screen.dart';
import '../widgets/consistency_warning_indicator.dart';
import '../widgets/due_recurring_occurrences_dialog.dart';
import '../widgets/hide_amounts_button.dart';
import '../widgets/switch_vault_button.dart';
import '../widgets/sync_summary_indicator.dart';
import 'assets_screen.dart';
import 'budgets_screen.dart';
import 'holders_screen.dart';
import 'recurring_transactions_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final Future<void> _localInit;

  static const _destinations = [
    (icon: Icons.receipt_long, label: 'Transactions'),
    (icon: Icons.pie_chart, label: 'Budgets'),
    (icon: Icons.account_balance, label: 'Holders'),
    (icon: Icons.inventory_2, label: 'Assets'),
    (icon: Icons.repeat, label: 'Recurring'),
    (icon: Icons.settings, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    final repo = ref.read(domainRepositoryProvider);
    _localInit = repo.initializeAfterUnlock();
    _localInit.then((_) async {
      try {
        await _startupWork(repo);
      } catch (e) {
        if (_vaultStillOpen) rethrow;
      }
    });
  }

  bool get _vaultStillOpen {
    if (!mounted) return false;
    final state = ref.read(authControllerProvider);
    return state is AuthReady || state is AuthOfflineReady;
  }

  Future<void> _startupWork(DomainRepository repo) async {
    if (ref.read(authControllerProvider) is! AuthOfflineReady) {
      try {
        await repo.syncNow();
      } catch (e) {
        if (_vaultStillOpen && mounted) {
          final message = 'Could not sync with server: $e';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 15),
              showCloseIcon: true,
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: message)),
              ),
            ),
          );
        }
      }
    }
    if (!_vaultStillOpen) return;
    await repo.seedDefaultFiatAssetIfNeeded();
    if (!_vaultStillOpen) return;

    final due = await repo.dueRecurringOccurrences();
    if (due.isNotEmpty && _vaultStillOpen && mounted) {
      await showDueRecurringOccurrencesDialog(context, due);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(syncConflictMessageProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next)));
        ref.read(syncConflictMessageProvider.notifier).state = null;
      }
    });
    if (ref.read(authControllerProvider) is! AuthOfflineReady) {
      ref.listen<AsyncValue<bool>>(remoteHasNewDataProvider, (previous, next) {
        if (next.value == true) {
          () async {
            try {
              await ref.read(domainRepositoryProvider).syncNow();
            } catch (_) {}
          }();
        }
      });
    }
    return FutureBuilder<void>(
      future: _localInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppStartupLoadingScaffold();
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to initialize: ${snapshot.error}'),
              ),
            ),
          );
        }
        return _buildShell(context);
      },
    );
  }

  Widget _buildShell(BuildContext context) {
    const screens = [
      TransactionsScreen(),
      BudgetsScreen(),
      HoldersScreen(),
      AssetsScreen(),
      RecurringTransactionsScreen(),
      SettingsScreen(),
    ];
    final wide = MediaQuery.sizeOf(context).width > 900;

    final index = ref.watch(selectedTabProvider);
    void select(int i) => ref.read(selectedTabProvider.notifier).state = i;

    final body = IndexedStack(index: index, children: screens);

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[index].label),
        actions: [
          const HideAmountsButton(),
          const ConsistencyWarningIndicator(),
          const SyncSummaryIndicator(),
          const SwitchVaultButton(),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: select,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}
