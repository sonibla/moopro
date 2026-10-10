import 'package:drift/drift.dart';

import '../domain/calendar_date.dart';
import 'domain_cache_connection.dart';
import 'tables.dart';

part 'domain_cache_database.g.dart';

@DriftDatabase(
  tables: [
    Assets,
    Containers,
    Transactions,
    PriceSnapshots,
    BalanceCheckpoints,
    Settings,
    RecurringTransactionTemplates,
  ],
)
class DomainCacheDatabase extends _$DomainCacheDatabase {
  DomainCacheDatabase([QueryExecutor? executor])
    : super(executor ?? openDomainCacheConnection());

  @override
  int get schemaVersion => 1;
}
