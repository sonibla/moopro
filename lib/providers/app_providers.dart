import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../api/api_client.dart';
import '../api/auth_api.dart';
import '../api/misc_api.dart';
import '../api/models.dart';
import '../api/vault_api.dart';
import '../auth/vault_session.dart';
import '../crypto/local_unlock_store.dart';
import '../crypto/local_vault_key_material_store.dart';
import '../db/database.dart';
import '../db/domain_cache_database.dart';
import '../db/vault_registry_database.dart';
import '../domain/balance_engine.dart';
import '../domain/balance_forecast.dart';
import '../domain/date_time_format_prefs.dart';
import '../domain/domain_repository.dart';
import '../domain/theme_mode_prefs.dart' show themeModeFromStorage;
import '../domain/holder_budget_consistency.dart';
import '../domain/models.dart' show SettingIds;
import '../domain/price_engine.dart';
import '../domain/transaction_filter.dart';
import '../domain/transaction_list_grouping.dart';
import '../import/bank_parsers/pdf/boursorama_compte_courant_parser.dart';
import '../import/bank_parsers/pdf/boursorama_pea_cash_old_parser.dart';
import '../import/bank_parsers/pdf/boursorama_pea_cash_parser.dart';
import '../import/bank_parsers/pdf/boursorama_pea_securities_parser.dart';
import '../import/bank_parsers/pdf/credit_agricole_releve_compte_parser.dart';
import '../import/bank_parsers/pdf/fortuneo_compte_courant_parser.dart';
import '../import/bank_parsers/pdf/fortuneo_ldds_parser.dart';
import '../import/bank_parsers/statement_import_registry.dart';
import '../market_data/alphavantage_client.dart';
import '../sync/sync_engine.dart';
import '../vault/vault_registry.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final alphaVantageClientProvider = Provider<AlphaVantageClient>(
  (ref) => AlphaVantageClient(),
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

final vaultApiProvider = Provider<VaultApi>(
  (ref) => VaultApi(ref.watch(apiClientProvider)),
);

final miscApiProvider = Provider<MiscApi>(
  (ref) => MiscApi(ref.watch(apiClientProvider)),
);

final vaultRegistryDatabaseProvider = Provider<VaultRegistryDatabase>((ref) {
  final db = VaultRegistryDatabase();
  ref.onDispose(db.close);
  return db;
});

final vaultRegistryProvider = Provider<VaultRegistry>(
  (ref) => VaultRegistry(ref.watch(vaultRegistryDatabaseProvider)),
);

final activeVaultProvider = StateProvider<VaultRegistryEntry?>((ref) => null);

final localUnlockStoreProvider = Provider<LocalUnlockStore>((ref) {
  final active = ref.watch(activeVaultProvider);
  return LocalUnlockStore(vaultId: active?.id ?? 'default');
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final active = ref.watch(activeVaultProvider);
  if (active == null) {
    throw StateError(
      'appDatabaseProvider read before a vault was selected — see '
      'activeVaultProvider',
    );
  }
  final db = AppDatabase.withName(active.dbName);
  ref.onDispose(db.close);
  return db;
});

final localVaultKeyMaterialStoreProvider = Provider<LocalVaultKeyMaterialStore>(
  (ref) => LocalVaultKeyMaterialStore(ref.watch(appDatabaseProvider)),
);

final vaultSessionManagerProvider = Provider<VaultSessionManager>((ref) {
  return VaultSessionManager(
    authApi: ref.watch(authApiProvider),
    localUnlockStore: ref.watch(localUnlockStoreProvider),
    localVaultKeyMaterialStore: ref.watch(localVaultKeyMaterialStoreProvider),
  );
});

final domainCacheDatabaseProvider = Provider<DomainCacheDatabase>((ref) {
  final db = DomainCacheDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    db: ref.watch(appDatabaseProvider),
    vaultApi: ref.watch(vaultApiProvider),
  );
});

final balanceEngineProvider = Provider<BalanceEngine>((ref) {
  return BalanceEngine(ref.watch(domainCacheDatabaseProvider));
});

final priceEngineProvider = Provider<PriceEngine>((ref) {
  return PriceEngine(ref.watch(domainCacheDatabaseProvider));
});

final balanceForecasterProvider = Provider<BalanceForecaster>((ref) {
  ref.watch(domainCacheDatabaseProvider);
  return BalanceForecaster();
});

final syncConflictMessageProvider = StateProvider<String?>((ref) => null);

final statementImportRegistryProvider = Provider<StatementImportRegistry>(
  (ref) => StatementImportRegistry(
    pdfParsers: [
      CreditAgricoleReleveCompteParser(),
      FortuneoCompteCourantParser(),
      FortuneoLddsParser(),
      BoursoramaCompteCourantParser(),
      BoursoramaPeaCashParser(),
      BoursoramaPeaCashOldParser(),
      BoursoramaPeaSecuritiesParser(),
    ],
    tabularParsers: [],
  ),
);

final domainRepositoryProvider = Provider<DomainRepository>((ref) {
  return DomainRepository(
    syncDb: ref.watch(appDatabaseProvider),
    cacheDb: ref.watch(domainCacheDatabaseProvider),
    syncEngine: ref.watch(syncEngineProvider),
    balanceEngine: ref.watch(balanceEngineProvider),
    vaultSession: ref.watch(vaultSessionManagerProvider),
    onSyncConflict: (conflicts) =>
        ref.read(syncConflictMessageProvider.notifier).state =
            VaultConflictException(conflicts).toString(),
  );
});

final assetsStreamProvider = StreamProvider<List<Asset>>(
  (ref) => ref.watch(domainRepositoryProvider).watchAssets(),
);

final containersStreamProvider = StreamProvider<List<Container>>(
  (ref) => ref.watch(domainRepositoryProvider).watchContainers(),
);

final transactionsStreamProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(domainRepositoryProvider).watchTransactions(),
);

final priceSnapshotsStreamProvider = StreamProvider<List<PriceSnapshot>>(
  (ref) => ref.watch(domainRepositoryProvider).watchPriceSnapshots(),
);

final recurringTemplatesStreamProvider =
    StreamProvider<List<RecurringTransactionTemplate>>(
      (ref) => ref.watch(domainRepositoryProvider).watchRecurringTemplates(),
    );

final settingStreamProvider = StreamProvider.family<Setting?, String>(
  (ref, id) => ref.watch(domainRepositoryProvider).watchSetting(id),
);

final dateTimeFormatPrefsProvider = Provider<DateTimeFormatPrefs>((ref) {
  final dateFormatValue = ref
      .watch(settingStreamProvider(SettingIds.dateFormat))
      .value
      ?.value;
  final timeFormatValue = ref
      .watch(settingStreamProvider(SettingIds.timeFormat))
      .value
      ?.value;
  return DateTimeFormatPrefs(
    dateFormat: DateFormatOption.fromStorage(dateFormatValue),
    use24HourTime: timeFormatValue == null ? true : timeFormatValue == '24h',
  );
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final value = ref
      .watch(settingStreamProvider(SettingIds.themeMode))
      .value
      ?.value;
  return themeModeFromStorage(value);
});

final hideAmountsProvider = Provider<bool>((ref) {
  return ref
          .watch(settingStreamProvider(SettingIds.hideAmounts))
          .value
          ?.value ==
      '1';
});

final defaultCurrencyAssetIdProvider = Provider<String?>((ref) {
  return ref
      .watch(settingStreamProvider(SettingIds.defaultCurrencyAssetId))
      .value
      ?.value;
});

final recordSyncStatusesProvider =
    StreamProvider<Map<String, RecordSyncStatus>>(
      (ref) => ref.watch(domainRepositoryProvider).watchRecordStatuses(),
    );

final syncCountsProvider = StreamProvider<SyncCounts>(
  (ref) => ref.watch(domainRepositoryProvider).watchSyncCounts(),
);

final transactionFilterProvider = StateProvider<TransactionFilter>(
  (ref) => TransactionFilter.empty,
);

const int transactionsTabIndex = 0;
final selectedTabProvider = StateProvider<int>((ref) => transactionsTabIndex);

final transactionListItemsProvider = FutureProvider<List<TransactionListItem>>((
  ref,
) async {
  final transactions = ref.watch(transactionsStreamProvider).value;
  final containers = ref.watch(containersStreamProvider).value;
  final assets = ref.watch(assetsStreamProvider).value;
  final filter = ref.watch(transactionFilterProvider);

  if (transactions == null || containers == null || assets == null) {
    return const [];
  }

  final input = TransactionListGroupInput(
    rows: transactions,
    filter: filter,
    containerNames: {for (final c in containers) c.id: c.name},
    assetsById: {for (final a in assets) a.id: a},
    now: DateTime.now(),
  );
  return buildTransactionListItems(input);
});

final holderBudgetConsistencyProvider =
    FutureProvider<HolderBudgetConsistency?>((ref) async {
      final containers = ref.watch(containersStreamProvider).value;
      ref.watch(transactionsStreamProvider);
      if (containers == null) return null;

      return computeHolderBudgetConsistency(
        balanceEngine: ref.watch(balanceEngineProvider),
        containers: containers,
      );
    });

class SyncSummary {
  final int pendingCount;
  final int conflictedCount;

  const SyncSummary({
    required this.pendingCount,
    required this.conflictedCount,
  });
}

final syncSummaryProvider = Provider<SyncSummary>((ref) {
  final counts =
      ref.watch(syncCountsProvider).value ??
      const SyncCounts(pending: 0, conflicted: 0);
  return SyncSummary(
    pendingCount: counts.pending,
    conflictedCount: counts.conflicted,
  );
});

final serverAvailableProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final miscApi = ref.watch(miscApiProvider);
  while (true) {
    yield await miscApi.checkHealth();
    await Future.delayed(const Duration(seconds: 10));
  }
});

final remoteHasNewDataProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final repo = ref.watch(domainRepositoryProvider);
  while (true) {
    try {
      yield await repo.hasNewRemoteData();
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 20));
  }
});
