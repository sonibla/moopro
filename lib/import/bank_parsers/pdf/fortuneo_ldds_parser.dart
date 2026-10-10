import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'fortuneo_shared.dart';
import '../../../domain/calendar_date.dart';

class FortuneoLddsParser extends PdfStatementParser {
  @override
  String get parserId => 'fortuneo_ldds';

  @override
  bool canParse(List<PdfPageLayout> raw) {
    final joined = pdfPagesJoinedText(raw);
    return joined.contains('FORTUNEO') && joined.contains('Relevé LDDS');
  }

  @override
  StatementParseResult parse(
    List<PdfPageLayout> raw, {
    required String sourceFileName,
  }) {
    final doc = parseFortuneoDocument(
      raw,
      accountNumberPattern: _accountNumberPattern,
    );
    final containerHint = doc.accountNumber == null
        ? 'Fortuneo LDDS'
        : 'LDDS n° ${doc.accountNumber}';
    final rowErrors = List<StatementRowError>.of(doc.rowErrors);

    final interestIndices = <int>[];
    final transferIndices = <int>[];
    final transferFallbackIndices = <int>[];
    final unknownIndices = <int>[];
    for (var i = 0; i < doc.rows.length; i++) {
      final row = doc.rows[i];
      final lower = row.description.toLowerCase();
      if (lower.startsWith('interets') ||
          lower.startsWith('intérêts') ||
          lower.startsWith('interêts')) {
        interestIndices.add(i);
      } else if (lower.startsWith('vir')) {
        transferIndices.add(i);
        if (row.isCreditByPosition == null) transferFallbackIndices.add(i);
      } else {
        unknownIndices.add(i);
      }
    }

    final outgoingTransferIndices = <int>{};
    if (transferFallbackIndices.isNotEmpty) {
      final statedTotals = doc.statedTotals;
      if (statedTotals != null && statedTotals.isNotEmpty) {
        final alreadyResolvedDebit = transferIndices
            .where(
              (i) =>
                  !transferFallbackIndices.contains(i) &&
                  doc.rows[i].isCreditByPosition == false,
            )
            .fold(Decimal.zero, (sum, i) => sum + doc.rows[i].amount);
        final targetDebit = statedTotals[0] - alreadyResolvedDebit;
        final resolved = resolveSubsetSumCents(
          transferFallbackIndices.map((i) => doc.rows[i].amount).toList(),
          targetDebit,
        );
        if (resolved != null) {
          for (var k = 0; k < resolved.length; k++) {
            if (resolved[k]) {
              outgoingTransferIndices.add(transferFallbackIndices[k]);
            }
          }
        } else {
          rowErrors.add(
            StatementRowError(
              rowIndex: 0,
              message:
                  'Could not tell which transfer(s) were outgoing: no combination of this '
                  'period\'s transfer amounts sums to the statement\'s stated debit total '
                  '($targetDebit). Defaulted every transfer to incoming — please verify against '
                  'the linked checking account statement.',
            ),
          );
        }
      } else {
        rowErrors.add(
          const StatementRowError(
            rowIndex: 0,
            message:
                'Could not tell which transfer(s) were outgoing: this statement does not '
                'state a "TOTAL DES OPÉRATIONS DU RELEVÉ" debit/credit split to derive it from. '
                'Defaulted every transfer to incoming — please verify against the linked checking '
                'account statement.',
          ),
        );
      }
    }

    final candidates = <StagedTransactionCandidate>[];
    var sumIncome = Decimal.zero;
    var sumExpense = Decimal.zero;

    for (var i = 0; i < doc.rows.length; i++) {
      final row = doc.rows[i];
      bool? isIncome;
      final tags = <String>[];
      if (interestIndices.contains(i)) {
        isIncome = true;
      } else if (transferIndices.contains(i)) {
        isIncome =
            row.isCreditByPosition ?? !outgoingTransferIndices.contains(i);
        tags.add('likely-self-transfer');
      } else {
        rowErrors.add(
          StatementRowError(
            rowIndex: row.lineIndex,
            message:
                'Unrecognized LDDS operation type — defaulted to expense, please verify: '
                '"${row.description}"',
          ),
        );
      }

      final signed = (isIncome ?? false) ? row.amount : -row.amount;
      if (signed > Decimal.zero) {
        sumIncome += signed;
      } else {
        sumExpense += -signed;
      }

      candidates.add(
        StagedTransactionCandidate(
          sourceFileName: sourceFileName,
          sourceRowIndex: row.lineIndex,
          effectiveDate: CalendarDate.fromDateTime(row.effectiveDate),
          postingDate: row.postingDate,
          amount: signed,
          description: row.description,
          containerHint: containerHint,
          tags: tags,
        ),
      );
    }

    checkFortuneoStatedTotals(
      statedTotals: doc.statedTotals,
      sumExpense: sumExpense,
      sumIncome: sumIncome,
      rowErrors: rowErrors,
      containerHint: containerHint,
    );

    return StatementParseResult(
      transactionCandidates: candidates,
      rowErrors: rowErrors,
      balanceInfo: (doc.openingBalance == null && doc.closingBalance == null)
          ? null
          : StatementBalanceInfo(
              openingBalance: doc.openingBalance,
              closingBalance: doc.closingBalance,
            ),
    );
  }
}

final _accountNumberPattern = RegExp(r'^Compte\s+([\d ]*\d)$');
