import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';
import 'package:moopro/import/transfer_match_engine.dart';
import 'package:moopro/domain/calendar_date.dart';

StagedTransactionCandidate _candidate({
  required String file,
  required int row,
  required String date,
  required String amount,
  required String holderHint,
  bool isCashTransaction = false,
  MatchSuggestion? matchedTransfer,
  String? tradeAssetHint,
}) => StagedTransactionCandidate(
  sourceFileName: file,
  sourceRowIndex: row,
  effectiveDate: CalendarDate.parse(date),
  amount: Decimal.parse(amount),
  description: 'desc',
  containerHint: holderHint,
  isCashTransaction: isCashTransaction,
  matchedTransfer: matchedTransfer,
  tradeAssetHint: tradeAssetHint,
  tradeAssetQuantity: tradeAssetHint == null ? null : Decimal.one,
);

void main() {
  group('TransferMatchEngine', () {
    test('matches two within-batch candidates with opposite sign, same amount, '
        'close date, different holder', () {
      final a = _candidate(
        file: 'bankA.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '-100.00',
        holderHint: 'Bank A',
      );
      final b = _candidate(
        file: 'bankB.pdf',
        row: 0,
        date: '2024-01-06',
        amount: '100.00',
        holderHint: 'Bank B',
      );

      final result = const TransferMatchEngine().applyMatches(
        candidates: [a, b],
      );

      expect(result[0].matchedTransfer, isNotNull);
      expect(result[1].matchedTransfer, isNotNull);
      expect(result[0].matchedTransfer!.otherCandidateKey, b.candidateKey);
      expect(result[1].matchedTransfer!.otherCandidateKey, a.candidateKey);
    });

    test('does not match same-holder candidates even if amount/date line up '
        '(that would be a duplicate on one account, not a transfer)', () {
      final a = _candidate(
        file: 'bankA.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '-50.00',
        holderHint: 'Bank A',
      );
      final b = _candidate(
        file: 'bankA.pdf',
        row: 1,
        date: '2024-01-05',
        amount: '50.00',
        holderHint: 'Bank A',
      );

      final result = const TransferMatchEngine().applyMatches(
        candidates: [a, b],
      );

      expect(result[0].matchedTransfer, isNull);
      expect(result[1].matchedTransfer, isNull);
    });

    test('does not match candidates outside the date window', () {
      final a = _candidate(
        file: 'bankA.pdf',
        row: 0,
        date: '2024-01-01',
        amount: '-100.00',
        holderHint: 'Bank A',
      );
      final b = _candidate(
        file: 'bankB.pdf',
        row: 0,
        date: '2024-02-01',
        amount: '100.00',
        holderHint: 'Bank B',
      );

      final result = const TransferMatchEngine(
        dateWindowDays: 3,
      ).applyMatches(candidates: [a, b]);

      expect(result[0].matchedTransfer, isNull);
      expect(result[1].matchedTransfer, isNull);
    });

    test('does not match candidates flagged as cash transactions', () {
      final a = _candidate(
        file: 'bankA.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '-100.00',
        holderHint: 'Bank A',
        isCashTransaction: true,
      );
      final b = _candidate(
        file: 'bankB.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '100.00',
        holderHint: 'Bank B',
      );

      final result = const TransferMatchEngine().applyMatches(
        candidates: [a, b],
      );

      expect(result[0].matchedTransfer, isNull);
      expect(result[1].matchedTransfer, isNull);
    });

    test('does not match a trade candidate\'s fiat leg as a transfer', () {
      final a = _candidate(
        file: 'pea.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '-100.00',
        holderHint: 'PEA',
        tradeAssetHint: 'AIR LIQUIDE',
      );
      final b = _candidate(
        file: 'bankB.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '100.00',
        holderHint: 'Bank B',
      );

      final result = const TransferMatchEngine().applyMatches(
        candidates: [a, b],
      );

      expect(result[0].matchedTransfer, isNull);
      expect(result[1].matchedTransfer, isNull);
    });

    test('does not false-positive on unrelated amounts/dates', () {
      final a = _candidate(
        file: 'bankA.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '-100.00',
        holderHint: 'Bank A',
      );
      final b = _candidate(
        file: 'bankB.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '42.00',
        holderHint: 'Bank B',
      );

      final result = const TransferMatchEngine().applyMatches(
        candidates: [a, b],
      );

      expect(result[0].matchedTransfer, isNull);
      expect(result[1].matchedTransfer, isNull);
    });

    test(
      'matches a candidate against an already-committed transaction leg',
      () {
        final a = _candidate(
          file: 'bankA.pdf',
          row: 0,
          date: '2024-01-05',
          amount: '-100.00',
          holderHint: 'Bank A',
        );
        final committed = [
          CommittedTransferLeg(
            transactionId: 'tx1',
            effectiveDate: CalendarDate.parse('2024-01-06'),
            amount: Decimal.parse('100.00'),
          ),
        ];

        final result = const TransferMatchEngine().applyMatches(
          candidates: [a],
          existingCommitted: committed,
        );

        expect(result[0].matchedTransfer, isNotNull);
        expect(result[0].matchedTransfer!.committedTransactionId, 'tx1');
        expect(result[0].matchedTransfer!.otherCandidateKey, isNull);
      },
    );

    test('each candidate matches at most once', () {
      final a = _candidate(
        file: 'bankA.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '-100.00',
        holderHint: 'Bank A',
      );
      final b = _candidate(
        file: 'bankB.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '100.00',
        holderHint: 'Bank B',
      );
      final c = _candidate(
        file: 'bankC.pdf',
        row: 0,
        date: '2024-01-05',
        amount: '100.00',
        holderHint: 'Bank C',
      );

      final result = const TransferMatchEngine().applyMatches(
        candidates: [a, b, c],
      );

      expect(result[0].matchedTransfer!.otherCandidateKey, b.candidateKey);
      expect(result[2].matchedTransfer, isNull);
    });

    test(
      'leaves a candidate that already has matchedTransfer untouched, and never '
      'reconsiders it as a match for anyone else',
      () {
        final certain = MatchSuggestion.certainPair('other#7');
        final a = _candidate(
          file: 'bankA.pdf',
          row: 0,
          date: '2024-01-05',
          amount: '-100.00',
          holderHint: 'Bank A',
          matchedTransfer: certain,
        );
        final b = _candidate(
          file: 'bankB.pdf',
          row: 0,
          date: '2024-01-05',
          amount: '100.00',
          holderHint: 'Bank B',
        );

        final result = const TransferMatchEngine().applyMatches(
          candidates: [a, b],
        );

        expect(result[0].matchedTransfer, same(certain));
        expect(result[1].matchedTransfer, isNull);
      },
    );
  });
}
