import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import 'balance_engine.dart' show sameDayReplayOrder;
import 'calendar_date.dart';
import 'transaction_ordering.dart' show transactionPairKey;

class StepSeries {
  final List<CalendarDate> days;
  final List<Decimal> values;

  const StepSeries(this.days, this.values);

  static const empty = StepSeries([], []);

  bool get isEmpty => days.isEmpty;
  CalendarDate? get firstDay => days.isEmpty ? null : days.first;

  Decimal? valueAtOrNull(CalendarDate day) {
    var lo = 0;
    var hi = days.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (days[mid].isAfter(day)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo == 0 ? null : values[lo - 1];
  }

  Decimal valueAt(CalendarDate day) => valueAtOrNull(day) ?? Decimal.zero;
}

Map<String, StepSeries> buildBalanceSeries(
  Iterable<ldb.Transaction> transactions,
) {
  final byPair = <String, List<ldb.Transaction>>{};
  for (final tx in transactions) {
    if (tx.deleted) continue;
    final keys = {
      transactionPairKey(tx.legInContainerId, tx.legInAssetId),
      transactionPairKey(tx.legOutContainerId, tx.legOutAssetId),
      if (tx.budgetLegInContainerId != null)
        transactionPairKey(tx.budgetLegInContainerId!, tx.budgetLegInAssetId!),
      if (tx.budgetLegOutContainerId != null)
        transactionPairKey(
          tx.budgetLegOutContainerId!,
          tx.budgetLegOutAssetId!,
        ),
    };
    for (final key in keys) {
      (byPair[key] ??= []).add(tx);
    }
  }

  final result = <String, StepSeries>{};
  for (final entry in byPair.entries) {
    final parts = entry.key.split('|');
    final containerId = parts[0];
    final assetId = parts[1];
    final txs = entry.value
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    final days = <CalendarDate>[];
    final values = <Decimal>[];
    var running = Decimal.zero;
    for (final tx in sameDayReplayOrder(txs)) {
      String? cached;
      var matched = false;
      if (tx.legInContainerId == containerId && tx.legInAssetId == assetId) {
        running += Decimal.parse(tx.legInQuantity);
        cached = tx.legInBalanceAfter;
        matched = true;
      }
      if (tx.legOutContainerId == containerId && tx.legOutAssetId == assetId) {
        running -= Decimal.parse(tx.legOutQuantity);
        cached = tx.legOutBalanceAfter;
        matched = true;
      }
      if (tx.budgetLegInContainerId == containerId &&
          tx.budgetLegInAssetId == assetId) {
        running += Decimal.parse(tx.budgetLegInQuantity!);
        cached = tx.budgetLegInBalanceAfter;
        matched = true;
      }
      if (tx.budgetLegOutContainerId == containerId &&
          tx.budgetLegOutAssetId == assetId) {
        running -= Decimal.parse(tx.budgetLegOutQuantity!);
        cached = tx.budgetLegOutBalanceAfter;
        matched = true;
      }
      if (!matched) continue;
      if (cached != null) running = Decimal.parse(cached);

      final day = tx.effectiveDate;
      if (days.isNotEmpty && days.last == day) {
        values[values.length - 1] = running;
      } else {
        days.add(day);
        values.add(running);
      }
    }
    result[entry.key] = StepSeries(days, values);
  }
  return result;
}
