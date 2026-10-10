import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../db/domain_cache_database.dart';
import 'calendar_date.dart';
import 'models.dart' show externalBudgetContainerId, externalHolderContainerId;
import 'transaction_ordering.dart';

DateTime monthStart(CalendarDate d) => DateTime.utc(d.year, d.month, 1);

class BalanceEngine {
  final DomainCacheDatabase db;
  BalanceEngine(this.db);

  Future<Decimal> currentBalance(String containerId, String assetId) async {
    final row = await _latestCheckpoint(containerId, assetId);
    return row != null ? Decimal.parse(row.quantity) : Decimal.zero;
  }

  Future<Map<String, Decimal>> assetBalances(String containerId) async {
    final rows = await (db.select(
      db.balanceCheckpoints,
    )..where((t) => t.containerId.equals(containerId))).get();
    final latestByAsset = <String, BalanceCheckpoint>{};
    for (final row in rows) {
      final existing = latestByAsset[row.assetId];
      if (existing == null ||
          row.checkpointDate.isAfter(existing.checkpointDate)) {
        latestByAsset[row.assetId] = row;
      }
    }
    final result = <String, Decimal>{};
    for (final entry in latestByAsset.entries) {
      final quantity = Decimal.parse(entry.value.quantity);
      if (quantity != Decimal.zero) result[entry.key] = quantity;
    }
    return result;
  }

  Future<BalanceCheckpoint?> _latestCheckpoint(
    String containerId,
    String assetId,
  ) {
    return (db.select(db.balanceCheckpoints)
          ..where(
            (t) =>
                t.containerId.equals(containerId) & t.assetId.equals(assetId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.checkpointDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<BalanceCheckpoint?> _latestCheckpointBefore(
    String containerId,
    String assetId,
    DateTime beforeMonth,
  ) {
    return (db.select(db.balanceCheckpoints)
          ..where(
            (t) =>
                t.containerId.equals(containerId) &
                t.assetId.equals(assetId) &
                t.checkpointDate.isSmallerThanValue(beforeMonth),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.checkpointDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Set<String>> onTransactionChanged({
    required List<MapEntry<String, String>>? oldLegs,
    CalendarDate? oldDate,
    required List<MapEntry<String, String>>? newLegs,
    CalendarDate? newDate,
  }) async {
    final invalidations = <String, CalendarDate>{};
    void add(String containerId, String assetId, CalendarDate date) {
      final key = '$containerId|$assetId';
      final existing = invalidations[key];
      if (existing == null || date.isBefore(existing)) {
        invalidations[key] = date;
      }
    }

    if (oldLegs != null && oldDate != null) {
      for (final leg in oldLegs) {
        add(leg.key, leg.value, oldDate);
      }
    }
    if (newLegs != null && newDate != null) {
      for (final leg in newLegs) {
        add(leg.key, leg.value, newDate);
      }
    }

    final touched = <String>{};
    for (final entry in invalidations.entries) {
      final parts = entry.key.split('|');
      touched.addAll(await _invalidateFrom(parts[0], parts[1], entry.value));
    }
    return touched;
  }

  Future<Set<String>> _invalidateFrom(
    String containerId,
    String assetId,
    CalendarDate fromDate,
  ) async {
    final fromMonth = monthStart(fromDate);
    await (db.delete(db.balanceCheckpoints)..where(
          (t) =>
              t.containerId.equals(containerId) &
              t.assetId.equals(assetId) &
              t.checkpointDate.isBiggerOrEqualValue(fromMonth),
        ))
        .go();

    final base = await _latestCheckpointBefore(containerId, assetId, fromMonth);
    var running = base != null ? Decimal.parse(base.quantity) : Decimal.zero;
    final baseMonth = base?.checkpointDate;

    final txs =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.deleted.equals(false) &
                    ((t.legInContainerId.equals(containerId) &
                            t.legInAssetId.equals(assetId)) |
                        (t.legOutContainerId.equals(containerId) &
                            t.legOutAssetId.equals(assetId)) |
                        (t.budgetLegInContainerId.equals(containerId) &
                            t.budgetLegInAssetId.equals(assetId)) |
                        (t.budgetLegOutContainerId.equals(containerId) &
                            t.budgetLegOutAssetId.equals(assetId))),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.effectiveDate)]))
            .get();
    final orderedTxs = sameDayReplayOrder(txs);

    final touched = <String>{};
    DateTime? currentMonth;
    for (final tx in orderedTxs) {
      final txMonth = monthStart(tx.effectiveDate);
      if (baseMonth != null && !txMonth.isAfter(baseMonth)) {
        continue;
      }
      if (currentMonth != null && txMonth != currentMonth) {
        await _upsertCheckpoint(containerId, assetId, currentMonth, running);
      }
      currentMonth = txMonth;
      String? legSlot;
      if (tx.legInContainerId == containerId && tx.legInAssetId == assetId) {
        running += Decimal.parse(tx.legInQuantity);
        legSlot = 'legIn';
      }
      if (tx.legOutContainerId == containerId && tx.legOutAssetId == assetId) {
        running -= Decimal.parse(tx.legOutQuantity);
        legSlot = 'legOut';
      }
      if (tx.budgetLegInContainerId == containerId &&
          tx.budgetLegInAssetId == assetId) {
        running += Decimal.parse(tx.budgetLegInQuantity!);
        legSlot = 'budgetLegIn';
      }
      if (tx.budgetLegOutContainerId == containerId &&
          tx.budgetLegOutAssetId == assetId) {
        running -= Decimal.parse(tx.budgetLegOutQuantity!);
        legSlot = 'budgetLegOut';
      }
      if (legSlot != null) {
        await _writeBalanceAfter(tx.id, legSlot, running);
        touched.add(tx.id);
      }
    }
    if (currentMonth != null) {
      await _upsertCheckpoint(containerId, assetId, currentMonth, running);
    }
    return touched;
  }

  Future<void> _writeBalanceAfter(
    String transactionId,
    String legSlot,
    Decimal value,
  ) {
    final companion = switch (legSlot) {
      'legOut' => TransactionsCompanion(
        legOutBalanceAfter: Value(value.toString()),
      ),
      'legIn' => TransactionsCompanion(
        legInBalanceAfter: Value(value.toString()),
      ),
      'budgetLegOut' => TransactionsCompanion(
        budgetLegOutBalanceAfter: Value(value.toString()),
      ),
      'budgetLegIn' => TransactionsCompanion(
        budgetLegInBalanceAfter: Value(value.toString()),
      ),
      _ => throw ArgumentError('Unknown leg slot: $legSlot'),
    };
    return (db.update(
      db.transactions,
    )..where((t) => t.id.equals(transactionId))).write(companion);
  }

  Future<void> _upsertCheckpoint(
    String containerId,
    String assetId,
    DateTime month,
    Decimal quantity,
  ) {
    return db
        .into(db.balanceCheckpoints)
        .insertOnConflictUpdate(
          BalanceCheckpointsCompanion(
            containerId: Value(containerId),
            assetId: Value(assetId),
            checkpointDate: Value(month),
            quantity: Value(quantity.toString()),
          ),
        );
  }

  Future<void> rebuildAll() async {
    await db.delete(db.balanceCheckpoints).go();
    for (final pair in await _distinctPairs()) {
      await db.transaction(
        () => _invalidateFrom(pair.key, pair.value, CalendarDate(1970, 1, 1)),
      );
    }
  }

  Future<List<MapEntry<String, String>>> _distinctPairs() async {
    final txs = await (db.select(
      db.transactions,
    )..where((t) => t.deleted.equals(false))).get();
    final seen = <String>{};
    final result = <MapEntry<String, String>>[];
    for (final tx in txs) {
      for (final pair in [
        MapEntry(tx.legOutContainerId, tx.legOutAssetId),
        MapEntry(tx.legInContainerId, tx.legInAssetId),
        if (tx.budgetLegOutContainerId != null)
          MapEntry(tx.budgetLegOutContainerId!, tx.budgetLegOutAssetId!),
        if (tx.budgetLegInContainerId != null)
          MapEntry(tx.budgetLegInContainerId!, tx.budgetLegInAssetId!),
      ]) {
        final key = '${pair.key}|${pair.value}';
        if (seen.add(key)) result.add(pair);
      }
    }
    return result;
  }
}

List<Transaction> sameDayReplayOrder(List<Transaction> txs) {
  final ordered = <Transaction>[];
  var i = 0;
  while (i < txs.length) {
    var j = i + 1;
    while (j < txs.length && txs[j].effectiveDate == txs[i].effectiveDate) {
      j++;
    }
    ordered.addAll(
      sameDaySafeOrder(
        txs.sublist(i, j),
        providedPairs: _providedPairs,
        requiredPairs: _requiredPairs,
        groupOf: (tx) => tx.kind,
        tieBreakCompare: (a, b) => compareSameDayTiebreak(
          (
            id: a.id,
            kind: a.kind,
            manualOrderRank: a.manualOrderRank,
            postedAt: a.postedAt,
          ),
          (
            id: b.id,
            kind: b.kind,
            manualOrderRank: b.manualOrderRank,
            postedAt: b.postedAt,
          ),
        ),
      ),
    );
    i = j;
  }
  return ordered;
}

List<String> _providedPairs(Transaction t) => [
  if (t.legInContainerId != externalHolderContainerId)
    transactionPairKey(t.legInContainerId, t.legInAssetId),
  if (t.budgetLegInContainerId != null &&
      t.budgetLegInContainerId != externalBudgetContainerId)
    transactionPairKey(t.budgetLegInContainerId!, t.budgetLegInAssetId!),
];

List<String> _requiredPairs(Transaction t) => [
  if (t.legOutContainerId != externalHolderContainerId)
    transactionPairKey(t.legOutContainerId, t.legOutAssetId),
  if (t.budgetLegOutContainerId != null &&
      t.budgetLegOutContainerId != externalBudgetContainerId)
    transactionPairKey(t.budgetLegOutContainerId!, t.budgetLegOutAssetId!),
];
