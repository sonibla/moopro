import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'boursorama_shared.dart';
import 'pdf_column_layout.dart';
import '../../../domain/calendar_date.dart';

class BoursoramaPeaCashParser extends PdfStatementParser {
  @override
  String get parserId => 'boursorama_pea_cash';

  @override
  bool canParse(List<PdfPageLayout> raw) =>
      pdfPagesJoinedText(raw).contains('Compte à vue P.E.A.');

  @override
  StatementParseResult parse(
    List<PdfPageLayout> raw, {
    required String sourceFileName,
  }) {
    final rows = <_Row>[];
    final rowErrors = <StatementRowError>[];
    Decimal? openingBalance;
    String? closingBalanceRaw;
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
      _PendingRow? pending;

      void flush() {
        final p = pending;
        if (p == null) return;
        rows.add(
          _Row(
            postingDate: p.postingDate,
            effectiveDate: p.effectiveDate,
            description: p.descriptionParts
                .where((s) => s.isNotEmpty)
                .join(' ')
                .trim(),
            amount: p.amount,
            securityName: p.securityName,
            quantity: p.quantity,
            lineIndex: p.lineIndex,
            isCreditByPosition: p.isCreditByPosition,
          ),
        );
        pending = null;
      }

      for (final lineObj in lines) {
        final line = lineObj.text;
        globalLineIndex++;
        if (line.isEmpty) {
          flush();
          continue;
        }

        accountNumber ??= _accountNumberPattern
            .firstMatch(line)
            ?.group(1)
            ?.trim();

        final openingMatch = _soldeAuPattern.firstMatch(line);
        if (openingMatch != null) {
          flush();
          openingBalance = parseAmountSpaceThousands(openingMatch.group(2)!);
          continue;
        }

        final closingMatch = _nouveauSoldePattern.firstMatch(line);
        if (closingMatch != null) {
          flush();
          closingBalanceRaw = closingMatch.group(1)!.trim();
          continue;
        }

        final rowMatch = _rowPattern.firstMatch(line);
        if (rowMatch != null) {
          flush();
          final rawAmountStr = rowMatch.group(4)!;
          final rawAmountStart =
              lineObj.start + (line.length - rawAmountStr.length);
          final rawAmountEnd = lineObj.start + line.length;
          final (amountStart, amountEnd, amountStr) = trimmedAmountText(
            page,
            rawAmountStart,
            rawAmountEnd,
          );
          final boundaryX = columnBoundaries.boundaryXForPosition(
            pageIndex,
            amountStart,
          );
          pending = _PendingRow(
            postingDate: _parseDdMmYyyy(rowMatch.group(1)!),
            effectiveDate: _parseDdMmYyyy(rowMatch.group(3)!),
            amount: parseAmountSpaceThousands(amountStr),
            lineIndex: globalLineIndex,
            isCreditByPosition: boundaryX == null
                ? null
                : isRightOfColumn(page, amountStart, amountEnd, boundaryX),
          )..descriptionParts.add(rowMatch.group(2)!);
          continue;
        }

        if (pending != null) {
          final nameMatch = _securityNamePattern.firstMatch(line);
          final qtyMatch = _quantityPattern.firstMatch(line);
          if (nameMatch != null) {
            pending!.securityName = nameMatch.group(1)!.trim();
          } else if (qtyMatch != null) {
            pending!.quantity = parseAmountSpaceThousands(
              qtyMatch.group(1)!.trim(),
            );
          }
          pending!.descriptionParts.add(line);
        }
      }
      flush();
    }

    final containerHint = accountNumber == null
        ? 'Boursorama PEA'
        : 'Compte PEA n° $accountNumber';

    final ambiguousIndices = <int>[];
    final isIncomeKnown = <int, bool>{};
    final tradeDirectionByIndex = <int, bool>{};
    for (var i = 0; i < rows.length; i++) {
      final desc = rows[i].description;
      if (desc.startsWith('VIR')) {
        final byPosition = rows[i].isCreditByPosition;
        if (byPosition != null) {
          isIncomeKnown[i] = byPosition;
        } else {
          ambiguousIndices.add(i);
        }
      } else if (desc.startsWith('ACHAT COMPTANT') ||
          desc.startsWith("SOUSCRIPTION D'OPC")) {
        isIncomeKnown[i] = false;
        tradeDirectionByIndex[i] = true;
      } else if (desc.startsWith('VENTE COMPTANT')) {
        isIncomeKnown[i] = true;
        tradeDirectionByIndex[i] = false;
      } else if (desc.startsWith('COUPONS ECHEANCE')) {
        isIncomeKnown[i] = true;
      } else if (desc.startsWith('Reprise solde compte')) {
        isIncomeKnown[i] = rows[i].isCreditByPosition ?? true;
      } else {
        final byPosition = rows[i].isCreditByPosition;
        if (byPosition != null) {
          isIncomeKnown[i] = byPosition;
          rowErrors.add(
            StatementRowError(
              rowIndex: rows[i].lineIndex,
              message:
                  'Unrecognized operation type — resolved as a'
                  '${byPosition ? ' credit' : ' debit'} from its column position, please verify: '
                  '"$desc"',
            ),
          );
        } else {
          rowErrors.add(
            StatementRowError(
              rowIndex: rows[i].lineIndex,
              message:
                  'Could not tell whether this is a debit or credit from its description — '
                  'defaulted to expense, please verify: "$desc"',
            ),
          );
        }
      }
    }

    var netKnown = Decimal.zero;
    isIncomeKnown.forEach((i, isIncome) {
      netKnown += isIncome ? rows[i].amount : -rows[i].amount;
    });
    final ambiguousAmounts = [for (final i in ambiguousIndices) rows[i].amount];

    final closingBalance = _resolveClosingBalance(
      raw: closingBalanceRaw,
      opening: openingBalance,
      netKnown: netKnown,
      ambiguousAmounts: ambiguousAmounts,
    );

    Set<int>? creditSubsetPositions;
    if (ambiguousIndices.isNotEmpty) {
      if (openingBalance != null && closingBalance != null) {
        final netTargetFromAmbiguous =
            (closingBalance - openingBalance) - netKnown;
        creditSubsetPositions = resolveAmbiguousDirectionsByBalance(
          ambiguousAmounts: ambiguousAmounts,
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
      if (row.description.startsWith('VIR')) {
        tags.add('likely-self-transfer');
      } else if (row.description.startsWith('Reprise solde compte')) {
        tags.add('account-balance-carryover');
      }

      String? tradeAssetHint;
      Decimal? tradeAssetQuantity;
      final isBuy = tradeDirectionByIndex[i];
      if (isBuy != null) {
        if (row.securityName == null || row.quantity == null) {
          rowErrors.add(
            StatementRowError(
              rowIndex: row.lineIndex,
              message:
                  'Expected a "Nom de la valeur"/"Quantité" pair on this trade row but found '
                  'none — staged as a plain ${isBuy ? 'expense' : 'income'} instead, please verify: '
                  '"${row.description}"',
            ),
          );
        } else {
          tradeAssetHint = row.securityName;
          tradeAssetQuantity = row.quantity;
          priceCandidates.add(
            StagedPriceSnapshotCandidate(
              sourceFileName: sourceFileName,
              sourceRowIndex: row.lineIndex,
              assetHint: row.securityName!,
              date: row.effectiveDate,
              price: (row.amount / row.quantity!).toDecimal(
                scaleOnInfinitePrecision: 6,
              ),
              currencyHint: 'EUR',
            ),
          );
        }
      }

      candidates.add(
        StagedTransactionCandidate(
          sourceFileName: sourceFileName,
          sourceRowIndex: row.lineIndex,
          effectiveDate: CalendarDate.fromDateTime(row.effectiveDate),
          postingDate: row.postingDate,
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

Decimal? _resolveClosingBalance({
  required String? raw,
  required Decimal? opening,
  required Decimal netKnown,
  required List<Decimal> ambiguousAmounts,
}) {
  if (raw == null) return null;
  final naive = parseAmountSpaceThousands(raw);
  final strippedMatch = RegExp(
    '^1[ \u00A0\u202F](\\d{1,3},\\d{2})\$',
  ).firstMatch(raw);
  if (strippedMatch == null || opening == null) return naive;
  final stripped = parseAmountSpaceThousands(strippedMatch.group(1)!);

  bool reconciles(Decimal candidateClosing) {
    final target = (candidateClosing - opening) - netKnown;
    if (ambiguousAmounts.isEmpty) return target == Decimal.zero;
    return resolveAmbiguousDirectionsByBalance(
          ambiguousAmounts: ambiguousAmounts,
          netTargetFromAmbiguous: target,
        ) !=
        null;
  }

  final naiveReconciles = reconciles(naive);
  final strippedReconciles = reconciles(stripped);
  if (strippedReconciles && !naiveReconciles) return stripped;
  if (naiveReconciles && !strippedReconciles) return naive;
  return naive;
}

class _Row {
  final DateTime postingDate;
  final DateTime effectiveDate;
  final String description;
  final Decimal amount;
  final String? securityName;
  final Decimal? quantity;
  final int lineIndex;
  final bool? isCreditByPosition;

  const _Row({
    required this.postingDate,
    required this.effectiveDate,
    required this.description,
    required this.amount,
    required this.securityName,
    required this.quantity,
    required this.lineIndex,
    required this.isCreditByPosition,
  });
}

class _PendingRow {
  final DateTime postingDate;
  final DateTime effectiveDate;
  final Decimal amount;
  final int lineIndex;
  final bool? isCreditByPosition;
  final List<String> descriptionParts = [];
  String? securityName;
  Decimal? quantity;

  _PendingRow({
    required this.postingDate,
    required this.effectiveDate,
    required this.amount,
    required this.lineIndex,
    required this.isCreditByPosition,
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

final _rowPattern = RegExp(
  '^(\\d{2}/\\d{2}/\\d{4})\\s+(.+?)\\s+(\\d{2}/\\d{2}/\\d{4})\\s+($amountSpaceThousandsToken)\$',
);

final _soldeAuPattern = RegExp(
  '^Solde au\\s+(\\d{2}/\\d{2}/\\d{4})\\s+($amountSpaceThousandsToken)\$',
);

final _nouveauSoldePattern = RegExp('^Nouveau solde en EUR\\s*:\\s*(.+)\$');

final _securityNamePattern = RegExp(r'^Nom de la valeur\s*:\s*(.+)$');

final _quantityPattern = RegExp('^Quantité\\s*:\\s*($flexibleNumberToken)\$');

final _accountNumberPattern = RegExp(
  r'^\d{2}/\d{2}/\d{4}\s+([\d ]+?)\s+EUR\s+[Dd]u\b',
);
