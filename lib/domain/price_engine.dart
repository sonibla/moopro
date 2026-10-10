import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../db/domain_cache_database.dart';

class PriceEngine {
  final DomainCacheDatabase db;
  PriceEngine(this.db);

  Future<Decimal?> latestPrice(
    String assetId,
    String inAssetId,
    DateTime asOf,
  ) async {
    if (assetId == inAssetId) return Decimal.one;
    final row =
        await (db.select(db.priceSnapshots)
              ..where(
                (t) =>
                    t.assetId.equals(assetId) &
                    t.currencyAssetId.equals(inAssetId) &
                    t.deleted.equals(false) &
                    t.date.isSmallerOrEqualValue(asOf),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.date)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : Decimal.parse(row.price);
  }
}
