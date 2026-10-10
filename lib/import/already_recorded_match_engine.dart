library;

import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/models.dart';
import 'bank_parsers/statement_parser.dart';
import 'transfer_match_engine.dart';
import '../domain/calendar_date.dart';

class CommittedCandidateSignature {
  final String transactionId;
  final CalendarDate effectiveDate;
  final Decimal amount;
  final String? note;

  const CommittedCandidateSignature({
    required this.transactionId,
    required this.effectiveDate,
    required this.amount,
    this.note,
  });
}

class AlreadyRecordedMatchEngine {
  const AlreadyRecordedMatchEngine();

  List<StagedTransactionCandidate> applyMatches({
    required List<StagedTransactionCandidate> candidates,
    required List<CommittedCandidateSignature> existingCommitted,
  }) {
    final result = List<StagedTransactionCandidate>.from(candidates);

    final seenInBatch = <String, StagedTransactionCandidate>{};
    for (var i = 0; i < result.length; i++) {
      final c = result[i];
      if (c.matchedTransfer != null) continue;
      final key = _signatureKey(c.effectiveDate, c.amount, c.description);
      final earlier = seenInBatch[key];
      if (earlier != null && earlier.sourceFileName != c.sourceFileName) {
        result[i] = c.copyWith(
          matchedTransfer: MatchSuggestion.duplicateOfCandidate(
            earlier.candidateKey,
          ),
        );
      } else {
        seenInBatch[key] = c;
      }
    }

    final bySignature = <String, String>{
      for (final c in existingCommitted)
        _signatureKey(c.effectiveDate, c.amount, c.note): c.transactionId,
    };

    for (var i = 0; i < result.length; i++) {
      final c = result[i];
      if (c.matchedTransfer != null) continue;
      final committedId =
          bySignature[_signatureKey(c.effectiveDate, c.amount, c.description)];
      if (committedId != null) {
        result[i] = c.copyWith(
          matchedTransfer: MatchSuggestion.withCommitted(committedId),
        );
      }
    }
    return result;
  }
}

String _signatureKey(CalendarDate date, Decimal amount, String? note) =>
    '${date.toIso()}|$amount|${note ?? ''}';

List<CommittedTransferLeg> committedTransferLegsFrom(
  List<ldb.Transaction> transactions,
) {
  final legs = <CommittedTransferLeg>[];
  for (final t in transactions) {
    if (t.kind != TransactionKind.holderTransfer.name &&
        t.kind != TransactionKind.budgetTransfer.name) {
      continue;
    }
    legs.add(
      CommittedTransferLeg(
        transactionId: t.id,
        effectiveDate: t.effectiveDate,
        amount: -Decimal.parse(t.legOutQuantity),
      ),
    );
    legs.add(
      CommittedTransferLeg(
        transactionId: t.id,
        effectiveDate: t.effectiveDate,
        amount: Decimal.parse(t.legInQuantity),
      ),
    );
  }
  return legs;
}

List<CommittedCandidateSignature> committedCandidateSignaturesFrom(
  List<ldb.Transaction> transactions, {
  required String? fiatAssetId,
}) {
  final signatures = <CommittedCandidateSignature>[];
  for (final t in transactions) {
    if (t.kind == TransactionKind.income.name) {
      signatures.add(
        CommittedCandidateSignature(
          transactionId: t.id,
          effectiveDate: t.effectiveDate,
          amount: Decimal.parse(t.legInQuantity),
          note: t.note,
        ),
      );
    } else if (t.kind == TransactionKind.expense.name) {
      signatures.add(
        CommittedCandidateSignature(
          transactionId: t.id,
          effectiveDate: t.effectiveDate,
          amount: -Decimal.parse(t.legOutQuantity),
          note: t.note,
        ),
      );
    } else if (t.kind == TransactionKind.trade.name && fiatAssetId != null) {
      if (t.legOutAssetId == fiatAssetId) {
        signatures.add(
          CommittedCandidateSignature(
            transactionId: t.id,
            effectiveDate: t.effectiveDate,
            amount: -Decimal.parse(t.legOutQuantity),
            note: t.note,
          ),
        );
      } else if (t.legInAssetId == fiatAssetId) {
        signatures.add(
          CommittedCandidateSignature(
            transactionId: t.id,
            effectiveDate: t.effectiveDate,
            amount: Decimal.parse(t.legInQuantity),
            note: t.note,
          ),
        );
      }
    }
  }
  return signatures;
}
