import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'boursorama_shared.dart';
import 'pdf_column_layout.dart';
import '../../../domain/calendar_date.dart';

class BoursoramaPeaCashOldParser extends PdfStatementParser {
  @override
  String get parserId => 'boursorama_pea_cash_old';

  @override
  bool canParse(List<PdfPageLayout> raw) =>
      pdfPagesJoinedText(raw).contains('RELEVE COMPTE ESPECES');

  @override
  StatementParseResult parse(
    List<PdfPageLayout> raw, {
    required String sourceFileName,
  }) {
    final rows = <_Row>[];
    final rowErrors = <StatementRowError>[];
    Decimal? openingBalance;
    Decimal? closingBalance;
    String? accountNumber;
    var globalLineIndex = 0;

    final columnBoundaries = PdfColumnBoundaries.detect(
      raw,
      leftLabel: 'Débit',
      rightLabel: 'Crédit',
    );

    for (var pageIndex = 0; pageIndex < raw.length; pageIndex++) {
      final page = raw[pageIndex];
      final lines = splitPageLinesWithOffsets(page);
      for (final lineObj in lines) {
        final line = lineObj.text;
        globalLineIndex++;
        if (line.isEmpty) continue;

        accountNumber ??= _accountNumberPattern
            .firstMatch(line)
            ?.group(1)
            ?.trim();

        final dateMatch = _dateLineStart.firstMatch(line);
        if (dateMatch == null) continue;

        final date = _parseDdMmYyyy(dateMatch.group(1)!);
        final rest = dateMatch.group(2)!;
        final restStart = line.length - rest.length;

        final openingMatch = _ancienSoldePattern.firstMatch(rest);
        if (openingMatch != null) {
          openingBalance = parseAmountSpaceThousands(openingMatch.group(1)!);
          continue;
        }
        final closingMatch = _nouveauSoldePattern.firstMatch(rest);
        if (closingMatch != null) {
          closingBalance = parseAmountSpaceThousands(closingMatch.group(1)!);
          continue;
        }

        final investmentMatch = _investmentRowPattern.firstMatch(rest);
        if (investmentMatch != null) {
          final label = investmentMatch.group(1)!;
          rows.add(
            _Row(
              date: date,
              description: rest,
              amount: parseAmountSpaceThousands(investmentMatch.group(4)!),
              lineIndex: globalLineIndex,
              kind: label == 'VENTE COMPTANT'
                  ? _RowKind.sell
                  : _RowKind.buyOrCoupon(label),
              securityName: investmentMatch.group(3)!.trim(),
              quantity: parseAmountSpaceThousands(investmentMatch.group(2)!),
            ),
          );
          continue;
        }

        final lastAmount = _lastAmountOnLine(rest);
        bool? isCreditByPosition;
        Decimal amount = Decimal.zero;
        if (lastAmount != null) {
          final (_, localStart, localEnd) = lastAmount;
          final rawAmountStart = lineObj.start + restStart + localStart;
          final rawAmountEnd = lineObj.start + restStart + localEnd;
          final (amountStart, amountEnd, trimmedAmountStr) = trimmedAmountText(
            page,
            rawAmountStart,
            rawAmountEnd,
          );
          amount = parseAmountSpaceThousands(trimmedAmountStr);
          final boundaryX = columnBoundaries.boundaryXForPosition(
            pageIndex,
            amountStart,
          );
          isCreditByPosition = boundaryX == null
              ? null
              : isRightOfColumn(page, amountStart, amountEnd, boundaryX);
        }

        if (rest.startsWith('VIR')) {
          rows.add(
            _Row(
              date: date,
              description: rest,
              amount: amount,
              lineIndex: globalLineIndex,
              kind: _RowKind.ambiguousTransfer,
              isCreditByPosition: isCreditByPosition,
            ),
          );
          continue;
        }

        rowErrors.add(
          StatementRowError(
            rowIndex: globalLineIndex,
            message: isCreditByPosition != null
                ? 'Unrecognized operation type — resolved as a'
                      '${isCreditByPosition ? ' credit' : ' debit'} from its column position, please '
                      'verify: "$rest"'
                : 'Could not tell whether this is a debit or credit from its description — '
                      'defaulted to expense, please verify: "$rest"',
          ),
        );
        rows.add(
          _Row(
            date: date,
            description: rest,
            amount: amount,
            lineIndex: globalLineIndex,
            kind: _RowKind.unrecognized,
            isCreditByPosition: isCreditByPosition,
          ),
        );
      }
    }

    final containerHint = accountNumber == null
        ? 'Boursorama PEA'
        : 'Compte PEA n° $accountNumber';

    final ambiguousIndices = <int>[];
    final isIncomeKnown = <int, bool>{};
    for (var i = 0; i < rows.length; i++) {
      switch (rows[i].kind) {
        case _RowKind.ambiguousTransfer:
          final byPosition = rows[i].isCreditByPosition;
          if (byPosition != null) {
            isIncomeKnown[i] = byPosition;
          } else {
            ambiguousIndices.add(i);
          }
        case _RowKind.buy:
          isIncomeKnown[i] = false;
        case _RowKind.sell:
          isIncomeKnown[i] = true;
        case _RowKind.coupon:
          isIncomeKnown[i] = true;
        case _RowKind.unrecognized:
          final byPosition = rows[i].isCreditByPosition;
          if (byPosition != null) isIncomeKnown[i] = byPosition;
      }
    }

    var netKnown = Decimal.zero;
    isIncomeKnown.forEach((i, isIncome) {
      netKnown += isIncome ? rows[i].amount : -rows[i].amount;
    });

    Set<int>? creditSubsetPositions;
    if (ambiguousIndices.isNotEmpty) {
      if (openingBalance != null && closingBalance != null) {
        final netTargetFromAmbiguous =
            (closingBalance - openingBalance) - netKnown;
        creditSubsetPositions = resolveAmbiguousDirectionsByBalance(
          ambiguousAmounts: [for (final i in ambiguousIndices) rows[i].amount],
          netTargetFromAmbiguous: netTargetFromAmbiguous,
        );
      }
      if (creditSubsetPositions == null) {
        rowErrors.add(
          const StatementRowError(
            rowIndex: 0,
            message:
                'Could not tell which "Virement depuis/vers BoursoBank" row(s) were outgoing: '
                'no split of this period\'s ambiguous transfer amounts reconciles against the '
                'statement\'s stated balance. Defaulted every such row to incoming — please verify '
                'against the linked compte courant statement.',
          ),
        );
      }
    }

    final candidates = <StagedTransactionCandidate>[];
    final priceCandidates = <StagedPriceSnapshotCandidate>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final tags = <String>[];
      bool isIncome;
      if (isIncomeKnown.containsKey(i)) {
        isIncome = isIncomeKnown[i]!;
      } else if (ambiguousIndices.contains(i)) {
        final position = ambiguousIndices.indexOf(i);
        isIncome = creditSubsetPositions?.contains(position) ?? true;
      } else {
        isIncome = false;
      }
      if (row.kind == _RowKind.ambiguousTransfer) {
        tags.add('likely-self-transfer');
      }

      String? tradeAssetHint;
      Decimal? tradeAssetQuantity;
      if (row.kind == _RowKind.buy || row.kind == _RowKind.sell) {
        tradeAssetHint = row.securityName;
        tradeAssetQuantity = row.quantity;
        priceCandidates.add(
          StagedPriceSnapshotCandidate(
            sourceFileName: sourceFileName,
            sourceRowIndex: row.lineIndex,
            assetHint: row.securityName!,
            date: row.date,
            price: (row.amount / row.quantity!).toDecimal(
              scaleOnInfinitePrecision: 6,
            ),
            currencyHint: 'EUR',
          ),
        );
      }

      candidates.add(
        StagedTransactionCandidate(
          sourceFileName: sourceFileName,
          sourceRowIndex: row.lineIndex,
          effectiveDate: CalendarDate.fromDateTime(row.date),
          amount: isIncome ? row.amount : -row.amount,
          description: row.description,
          containerHint: containerHint,
          tags: tags,
          tradeAssetHint: tradeAssetHint,
          tradeAssetQuantity: tradeAssetQuantity,
        ),
      );
    }

    return StatementParseResult(
      transactionCandidates: candidates,
      priceCandidates: priceCandidates,
      rowErrors: rowErrors,
      balanceInfo: (openingBalance == null && closingBalance == null)
          ? null
          : StatementBalanceInfo(
              openingBalance: openingBalance,
              closingBalance: closingBalance,
            ),
    );
  }
}

enum _RowKind {
  ambiguousTransfer,
  buy,
  sell,
  coupon,
  unrecognized;

  static _RowKind buyOrCoupon(String label) =>
      label == 'COUPONS ECHEANCE' ? coupon : buy;
}

class _Row {
  final DateTime date;
  final String description;
  final Decimal amount;
  final int lineIndex;
  final _RowKind kind;
  final String? securityName;
  final Decimal? quantity;

  final bool? isCreditByPosition;

  const _Row({
    required this.date,
    required this.description,
    required this.amount,
    required this.lineIndex,
    required this.kind,
    this.securityName,
    this.quantity,
    this.isCreditByPosition,
  });
}

DateTime _parseDdMmYyyy(String s) {
  final parts = s.split('/');
  return DateTime(
    int.parse(parts[2]),
    int.parse(parts[1]),
    int.parse(parts[0]),
  );
}

(Decimal, int, int)? _lastAmountOnLine(String line) {
  final matches = RegExp(amountSpaceThousandsToken).allMatches(line).toList();
  if (matches.isEmpty) return null;
  final last = matches.last;
  return (parseAmountSpaceThousands(last.group(0)!), last.start, last.end);
}

final _dateLineStart = RegExp(r'^(\d{2}/\d{2}/\d{4})\s+(.+)$');

final _ancienSoldePattern = RegExp(
  '^ANCIEN SOLDE\\s+($amountSpaceThousandsToken)\$',
);
final _nouveauSoldePattern = RegExp(
  '^NOUVEAU SOLDE\\s+($amountSpaceThousandsToken)\$',
);

final _investmentRowPattern = RegExp(
  "^(ACHAT COMPTANT|SOUSCRIPTION D'OPC|VENTE COMPTANT|COUPONS ECHEANCE)(?:\\s+\\d{2}/\\d{2})?"
  "\\s+($flexibleNumberToken)\\s+(.+?)\\s+($amountSpaceThousandsToken)\$",
);

final _accountNumberPattern = RegExp('^RIB du compte espèces\\s*:\\s*(.+)\$');
