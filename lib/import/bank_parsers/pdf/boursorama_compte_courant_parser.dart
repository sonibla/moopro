import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'boursorama_shared.dart';
import 'pdf_column_layout.dart';
import '../../../domain/calendar_date.dart';

class BoursoramaCompteCourantParser extends PdfStatementParser {
  @override
  String get parserId => 'boursorama_compte_courant';

  @override
  bool canParse(List<PdfPageLayout> raw) {
    final joined = pdfPagesJoinedText(raw);
    return joined.contains('MOUVEMENTS EN EUR') &&
        joined.contains('Extrait de votre compte en EUR') &&
        !joined.contains('P.E.A.');
  }

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
      _PendingRow? pending;
      var collectingClosing = false;
      final closingValues = <Decimal>[];
      var closingLookahead = 0;

      void flush() {
        final p = pending;
        if (p == null) return;
        rows.add(
          _Row(
            postingDate: p.postingDate,
            effectiveDate: p.effectiveDate,
            description: _joinDescriptionParts(p.descriptionParts),
            amount: p.amount,
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

        if (collectingClosing) {
          final m = _amountOnlyLine.firstMatch(line);
          if (m != null) {
            closingValues.add(parseAmountDotThousands(m.group(1)!));
            if (closingValues.length == 3) {
              closingBalance = closingValues[1];
              collectingClosing = false;
            }
          } else {
            closingLookahead++;
            if (closingLookahead > 8) {
              rowErrors.add(
                StatementRowError(
                  rowIndex: globalLineIndex,
                  message:
                      'Could not find the closing balance figures after "Nouveau solde en '
                      'EUR :" — the statement\'s closing balance is missing from this import.',
                ),
              );
              collectingClosing = false;
            }
          }
          continue;
        }

        final openingMatch = _soldeAuPattern.firstMatch(line);
        if (openingMatch != null) {
          flush();
          openingBalance = parseAmountDotThousands(openingMatch.group(2)!);
          continue;
        }

        if (_nouveauSoldeLabelPattern.hasMatch(line)) {
          flush();
          collectingClosing = true;
          closingValues.clear();
          closingLookahead = 0;
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
            amount: parseAmountDotThousands(amountStr),
            lineIndex: globalLineIndex,
            isCreditByPosition: boundaryX == null
                ? null
                : isRightOfColumn(page, amountStart, amountEnd, boundaryX),
          )..descriptionParts.add(rowMatch.group(2)!);
          continue;
        }

        if (pending != null) {
          pending!.descriptionParts.add(line);
        }
      }
      flush();
    }

    final holderTokens = _extractHolderNameTokens(
      pdfPagesJoinedText(raw).split('\n'),
    );
    final containerHint = accountNumber == null
        ? 'Boursorama Compte Courant'
        : 'Compte Courant n° $accountNumber';

    final ambiguousIndices = <int>[];
    final isIncomeKnown = <int, bool>{};
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isCreditByPosition != null) {
        isIncomeKnown[i] = row.isCreditByPosition!;
        continue;
      }
      final lower = row.description.toLowerCase();
      if (lower.startsWith('prlv')) {
        isIncomeKnown[i] = false;
      } else if (_internalTransferPattern.hasMatch(row.description)) {
        ambiguousIndices.add(i);
      } else if (lower.startsWith('vir')) {
        isIncomeKnown[i] = true;
      } else {
        rowErrors.add(
          StatementRowError(
            rowIndex: row.lineIndex,
            message:
                'Could not tell whether this is a debit or credit from its description — '
                'defaulted to expense, please verify: "${row.description}"',
          ),
        );
      }
    }

    Set<int>? creditSubsetPositions;
    if (ambiguousIndices.isNotEmpty) {
      if (openingBalance != null && closingBalance != null) {
        var netKnown = Decimal.zero;
        isIncomeKnown.forEach((i, isIncome) {
          netKnown += isIncome ? rows[i].amount : -rows[i].amount;
        });
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
                'statement\'s stated opening/closing balance. Defaulted every such row to incoming '
                '— please verify against the linked account statement.',
          ),
        );
      }
    }

    final candidates = <StagedTransactionCandidate>[];
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
      if (_mentionsHolder(row.description, holderTokens) ||
          _internalTransferPattern.hasMatch(row.description)) {
        tags.add('likely-self-transfer');
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
        ),
      );
    }

    return StatementParseResult(
      transactionCandidates: candidates,
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

class _Row {
  final DateTime postingDate;
  final DateTime effectiveDate;
  final String description;
  final Decimal amount;
  final int lineIndex;
  final bool? isCreditByPosition;

  const _Row({
    required this.postingDate,
    required this.effectiveDate,
    required this.description,
    required this.amount,
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

String _joinDescriptionParts(List<String> parts) {
  final cleaned = <String>[];
  for (final raw in parts) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '-') continue;
    final stripped = trimmed.startsWith('- ')
        ? trimmed.substring(2).trim()
        : trimmed;
    if (stripped.isNotEmpty) cleaned.add(stripped);
  }
  return cleaned.join(' ');
}

const _amtDot = r'\d{1,3}(?:\.\d{3})*,\d{2}';

final _rowPattern = RegExp(
  '^(\\d{2}/\\d{2}/\\d{4})\\s+(.+?)\\s+(\\d{2}/\\d{2}/\\d{4})\\s+($_amtDot)\$',
);

final _soldeAuPattern = RegExp(
  '^SOLDE AU\\s*:\\s*(\\d{2}/\\d{2}/\\d{4})\\s+($_amtDot)\$',
);

final _nouveauSoldeLabelPattern = RegExp(r'^Nouveau solde en EUR\s*:\s*$');

final _amountOnlyLine = RegExp('^($_amtDot)\$');

final _accountNumberPattern = RegExp(
  r'^\d{2}/\d{2}/\d{4}\s+([\d ]+?)\s+EUR\s+du\b',
);

final _internalTransferPattern = RegExp(
  r'^VIR\s+Virement\s+(depuis|vers)\s+BoursoBank',
  caseSensitive: false,
);

final _holderNameLinePattern = RegExp(
  "^(?:M\\.?|Mme\\.?|Mlle\\.?)\\s+([A-ZÀ-Þ][A-ZÀ-Þ'\\- ]*)\$",
);

Set<String> _nameTokens(String text) => text
    .toLowerCase()
    .split(RegExp(r"[^a-zà-ÿ']+"))
    .where((t) => t.length > 1)
    .toSet();

Set<String> _extractHolderNameTokens(List<String> lines) {
  for (final line in lines) {
    final m = _holderNameLinePattern.firstMatch(line.trim());
    if (m == null) continue;
    final tokens = _nameTokens(m.group(1)!);
    if (tokens.isNotEmpty) return tokens;
  }
  return const {};
}

bool _mentionsHolder(String description, Set<String> holderTokens) {
  if (holderTokens.isEmpty) return false;
  final descTokens = _nameTokens(description);
  return holderTokens.every(descTokens.contains);
}
