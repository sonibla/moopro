library;

List<T> sameDaySafeOrder<T>(
  List<T> dayTransactions, {
  required List<String> Function(T) providedPairs,
  required List<String> Function(T) requiredPairs,
  required Comparator<T> tieBreakCompare,
  Object? Function(T)? groupOf,
}) {
  if (dayTransactions.length <= 1) return List.of(dayTransactions);

  final providedPairsWithProvider = <String>{};
  for (final tx in dayTransactions) {
    providedPairsWithProvider.addAll(providedPairs(tx));
  }

  final remainingRequirements = <T, int>{};
  final waitingOn = <String, List<T>>{};
  for (final tx in dayTransactions) {
    final constrained = requiredPairs(
      tx,
    ).toSet().intersection(providedPairsWithProvider);
    remainingRequirements[tx] = constrained.length;
    for (final pair in constrained) {
      (waitingOn[pair] ??= []).add(tx);
    }
  }

  final remaining = List.of(dayTransactions);
  final result = <T>[];
  Object? lastGroup;
  void emit(T tx) {
    remaining.remove(tx);
    result.add(tx);
    lastGroup = groupOf?.call(tx);
    for (final pair in providedPairs(tx)) {
      for (final waiter in waitingOn[pair] ?? const []) {
        final left = remainingRequirements[waiter];
        if (left != null && left > 0) remainingRequirements[waiter] = left - 1;
      }
    }
  }

  while (remaining.isNotEmpty) {
    final ready = remaining
        .where((tx) => remainingRequirements[tx] == 0)
        .toList();
    if (ready.isEmpty) {
      for (final tx in List.of(remaining)..sort(tieBreakCompare)) {
        emit(tx);
      }
      break;
    }
    var candidates = ready;
    if (groupOf != null && lastGroup != null) {
      final sameGroup = ready.where((tx) => groupOf(tx) == lastGroup).toList();
      if (sameGroup.isNotEmpty) candidates = sameGroup;
    }
    emit(candidates.reduce((a, b) => tieBreakCompare(a, b) <= 0 ? a : b));
  }
  return result;
}

String transactionPairKey(String containerId, String assetId) =>
    '$containerId|$assetId';

const _kindRank = {
  'income': 0,
  'expense': 1,
  'holderTransfer': 2,
  'budgetTransfer': 3,
  'trade': 4,
};

int compareSameDayTiebreak(
  ({String id, String kind, int manualOrderRank, DateTime postedAt}) a,
  ({String id, String kind, int manualOrderRank, DateTime postedAt}) b,
) {
  var r = (_kindRank[a.kind] ?? _kindRank.length).compareTo(
    _kindRank[b.kind] ?? _kindRank.length,
  );
  if (r != 0) return r;
  r = a.manualOrderRank.compareTo(b.manualOrderRank);
  if (r != 0) return r;
  r = a.postedAt.compareTo(b.postedAt);
  return r != 0 ? r : a.id.compareTo(b.id);
}
