import 'package:decimal/decimal.dart';

import 'bank_parsers/statement_parser.dart';
import '../domain/calendar_date.dart';

class CommittedTransferLeg {
  final String transactionId;
  final CalendarDate effectiveDate;
  final Decimal amount;

  const CommittedTransferLeg({
    required this.transactionId,
    required this.effectiveDate,
    required this.amount,
  });
}

class TransferMatchEngine {
  final int dateWindowDays;

  const TransferMatchEngine({this.dateWindowDays = 3});

  List<StagedTransactionCandidate> applyMatches({
    required List<StagedTransactionCandidate> candidates,
    List<CommittedTransferLeg> existingCommitted = const [],
  }) {
    final result = List<StagedTransactionCandidate>.from(candidates);
    final matched = <int>{
      for (var i = 0; i < result.length; i++)
        if (result[i].matchedTransfer != null) i,
    };

    for (var i = 0; i < result.length; i++) {
      if (matched.contains(i) ||
          result[i].isCashTransaction ||
          result[i].tradeAssetHint != null) {
        continue;
      }

      var foundWithinBatch = false;
      for (var j = i + 1; j < result.length; j++) {
        if (matched.contains(j) ||
            result[j].isCashTransaction ||
            result[j].tradeAssetHint != null) {
          continue;
        }
        if (_isOppositeWithinWindow(
              result[i],
              result[j].effectiveDate,
              result[j].amount,
            ) &&
            result[i].containerHint != result[j].containerHint) {
          final a = result[i];
          final b = result[j];
          result[i] = a.copyWith(
            matchedTransfer: MatchSuggestion.withCandidate(b.candidateKey),
          );
          result[j] = b.copyWith(
            matchedTransfer: MatchSuggestion.withCandidate(a.candidateKey),
          );
          matched.add(i);
          matched.add(j);
          foundWithinBatch = true;
          break;
        }
      }
      if (foundWithinBatch) continue;

      for (final leg in existingCommitted) {
        if (_isOppositeWithinWindow(result[i], leg.effectiveDate, leg.amount)) {
          result[i] = result[i].copyWith(
            matchedTransfer: MatchSuggestion.withCommitted(leg.transactionId),
          );
          matched.add(i);
          break;
        }
      }
    }
    return result;
  }

  bool _isOppositeWithinWindow(
    StagedTransactionCandidate candidate,
    CalendarDate otherDate,
    Decimal otherAmount,
  ) {
    if (candidate.amount + otherAmount != Decimal.zero) {
      return false;
    }
    final days = candidate.effectiveDate.daysUntil(otherDate).abs();
    return days <= dateWindowDays;
  }
}
