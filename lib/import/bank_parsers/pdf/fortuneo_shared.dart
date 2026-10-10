import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'pdf_column_layout.dart';

class FortuneoRawRow {
  final int postDay;
  final int postMonth;
  final DateTime effectiveDate;
  final String description;

  final Decimal amount;

  final int lineIndex;

  final bool? isCreditByPosition;

  const FortuneoRawRow({
    required this.postDay,
    required this.postMonth,
    required this.effectiveDate,
    required this.description,
    required this.amount,
    required this.lineIndex,
    required this.isCreditByPosition,
  });

  DateTime get postingDate =>
      resolveFortuneoDayMonth(postDay, postMonth, effectiveDate);
}

class FortuneoParsedDocument {
  final List<FortuneoRawRow> rows;
  final Decimal? openingBalance;
  final Decimal? closingBalance;

  final List<Decimal>? statedTotals;

  final String? accountNumber;
  final List<StatementRowError> rowErrors;

  const FortuneoParsedDocument({
    required this.rows,
    required this.openingBalance,
    required this.closingBalance,
    required this.statedTotals,
    required this.accountNumber,
    required this.rowErrors,
  });
}

DateTime resolveFortuneoDayMonth(int day, int month, DateTime anchor) {
  DateTime best = DateTime(anchor.year, month, day);
  var bestDistance = (best.difference(anchor).inDays).abs();
  for (final year in [anchor.year - 1, anchor.year + 1]) {
    final candidate = DateTime(year, month, day);
    final distance = (candidate.difference(anchor).inDays).abs();
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
    }
  }
  return best;
}

const _kHardWrapThreshold = 48;

FortuneoParsedDocument parseFortuneoDocument(
  List<PdfPageLayout> pages, {
  required RegExp accountNumberPattern,
}) {
  final rows = <FortuneoRawRow>[];
  final rowErrors = <StatementRowError>[];
  Decimal? openingBalance;
  Decimal? closingBalance;
  List<Decimal>? statedTotals;
  String? accountNumber;
  var globalLineIndex = 0;

  final columnBoundaries = PdfColumnBoundaries.detect(
    pages,
    leftLabel: 'Débit',
    rightLabel: 'Crédit',
  );

  for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
    final page = pages[pageIndex];
    final lines = splitPageLinesWithOffsets(page);

    _PendingRow? pending;
    var lastChunkLength = 0;

    void flushPending() {
      final row = pending;
      if (row == null) return;
      rows.add(
        FortuneoRawRow(
          postDay: row.postDay,
          postMonth: row.postMonth,
          effectiveDate: row.effectiveDate,
          description: row.descriptionParts
              .where((s) => s.isNotEmpty)
              .join(' ')
              .trim(),
          amount: row.amount,
          lineIndex: row.lineIndex,
          isCreditByPosition: row.isCreditByPosition,
        ),
      );
      pending = null;
    }

    for (final lineObj in lines) {
      final line = lineObj.text;
      globalLineIndex++;
      if (line.isEmpty) {
        flushPending();
        continue;
      }

      accountNumber ??= accountNumberPattern.firstMatch(line)?.group(1)?.trim();

      final openingMatch = _ancienSoldePattern.firstMatch(line);
      if (openingMatch != null) {
        flushPending();
        openingBalance = _parseSignedBalance(
          openingMatch.group(1)!,
          openingMatch.group(2)!,
        );
        continue;
      }

      final closingMatch = _nouveauSoldePattern.firstMatch(line);
      if (closingMatch != null) {
        flushPending();
        closingBalance = _parseSignedBalance(
          closingMatch.group(1)!,
          closingMatch.group(2)!,
        );
        continue;
      }

      final totalMatch = _totalOperationsPattern.firstMatch(line);
      if (totalMatch != null) {
        flushPending();
        final second = totalMatch.group(2);
        statedTotals = [
          _parseAmount(totalMatch.group(1)!),
          if (second != null) _parseAmount(second),
        ];
        continue;
      }

      final dateMatch = _dateLineStart.firstMatch(line);
      if (dateMatch != null) {
        flushPending();
        final rest = dateMatch.group(6) ?? '';
        final restStart = line.length - rest.length;
        final trailing = _tryExtractTrailingAmount(
          rest,
          page: page,
          baseOffset: lineObj.start + restStart,
        );
        if (trailing == null) {
          rowErrors.add(
            StatementRowError(
              rowIndex: globalLineIndex,
              message:
                  'Could not find an amount on this transaction row: "$line"',
            ),
          );
          lastChunkLength = 0;
          continue;
        }
        final amountStart = lineObj.start + restStart + trailing.start;
        final amountEnd = lineObj.start + restStart + trailing.end;
        final boundaryX = columnBoundaries.boundaryXForPosition(
          pageIndex,
          amountStart,
        );
        pending = _PendingRow(
          postDay: int.parse(dateMatch.group(1)!),
          postMonth: int.parse(dateMatch.group(2)!),
          effectiveDate: DateTime(
            int.parse(dateMatch.group(5)!),
            int.parse(dateMatch.group(4)!),
            int.parse(dateMatch.group(3)!),
          ),
          lineIndex: globalLineIndex,
          isCreditByPosition: boundaryX == null
              ? null
              : isRightOfColumn(page, amountStart, amountEnd, boundaryX),
        );
        pending!.descriptionParts.add(trailing.before);
        pending!.amount = trailing.amount;
        lastChunkLength = trailing.before.length;
        continue;
      }

      if (pending != null) {
        if (lastChunkLength >= _kHardWrapThreshold) {
          final parts = pending!.descriptionParts;
          parts[parts.length - 1] = '${parts.last}$line';
        } else {
          pending!.descriptionParts.add(line);
        }
        lastChunkLength = line.length;
      }
    }

    flushPending();
  }

  return FortuneoParsedDocument(
    rows: rows,
    openingBalance: openingBalance,
    closingBalance: closingBalance,
    statedTotals: statedTotals,
    accountNumber: accountNumber,
    rowErrors: rowErrors,
  );
}

class _PendingRow {
  final int postDay;
  final int postMonth;
  final DateTime effectiveDate;
  final int lineIndex;
  final bool? isCreditByPosition;
  final List<String> descriptionParts = [];
  Decimal amount = Decimal.zero;

  _PendingRow({
    required this.postDay,
    required this.postMonth,
    required this.effectiveDate,
    required this.lineIndex,
    required this.isCreditByPosition,
  });
}

class _TrailingAmount {
  final String before;
  final Decimal amount;

  final int start;
  final int end;
  _TrailingAmount(this.before, this.amount, this.start, this.end);
}

final _dateLineStart = RegExp(
  r'^(\d{2})/(\d{2})\s+(\d{2})/(\d{2})/(\d{4})\s*(.*)$',
);

final _amountToken = RegExp(r'(?<![\d/,])(\d{1,3}(?:[   ]\d{3})*,\d{2})(?!\d)');

final _amountOnly = r'\d{1,3}(?:[   ]\d{3})*,\d{2}';

final _eurRestatementGlitch = RegExp('($_amountOnly)\\s+EUR\$');

final _ancienSoldePattern = RegExp(
  '^ANCIEN SOLDE (CR[ÉE]DITEUR|D[ÉE]BITEUR) AU .+? ($_amountOnly)\\s*€?\\s*\$',
);

final _nouveauSoldePattern = RegExp(
  '^NOUVEAU SOLDE (CR[ÉE]DITEUR|D[ÉE]BITEUR) AU .+? ($_amountOnly)\\s*€?\\s*\$',
);

final _totalOperationsPattern = RegExp(
  '^TOTAL DES OP[ÉE]RATIONS DU RELEV[ÉE]\\s+($_amountOnly)(?:\\s+($_amountOnly))?',
);

_TrailingAmount? _tryExtractTrailingAmount(
  String text, {
  required PdfPageLayout page,
  required int baseOffset,
}) {
  final matches = _amountToken.allMatches(text).toList();
  if (matches.isEmpty) return null;
  final last = matches.last;
  final tail = text.substring(last.end).trim();
  if (tail.isNotEmpty) return null;

  final (trimmedAbsStart, _) = trimAmountRange(
    page,
    baseOffset + last.start,
    baseOffset + last.end,
  );
  final start = trimmedAbsStart - baseOffset;
  final rawAmount = text.substring(start, last.end);

  var before = text.substring(0, start).trim();
  final glitch = _eurRestatementGlitch.firstMatch(before);
  if (glitch != null) {
    before = before.substring(0, glitch.start).trim();
  }
  before = _stripRestatedAmountGlitch(before, rawAmount);
  return _TrailingAmount(before, _parseAmount(rawAmount), start, last.end);
}

String _stripRestatedAmountGlitch(String before, String rawAmount) {
  if (rawAmount.length < 2) return before;
  final glitchFragment = rawAmount.substring(0, rawAmount.length - 1);
  if (before.endsWith(glitchFragment)) {
    return before.substring(0, before.length - glitchFragment.length).trim();
  }
  return before;
}

Decimal _parseAmount(String raw) =>
    Decimal.parse(raw.replaceAll(RegExp(r'[   ]'), '').replaceAll(',', '.'));

Decimal _parseSignedBalance(String sign, String amountStr) {
  final value = _parseAmount(amountStr);
  final lower = sign.toLowerCase();
  return (lower.startsWith('déb') || lower.startsWith('deb')) ? -value : value;
}

void checkFortuneoStatedTotals({
  required List<Decimal>? statedTotals,
  required Decimal sumExpense,
  required Decimal sumIncome,
  required List<StatementRowError> rowErrors,
  required String containerHint,
}) {
  Decimal? debitTotal;
  Decimal? creditTotal;
  if (statedTotals != null && statedTotals.length == 2) {
    debitTotal = statedTotals[0];
    creditTotal = statedTotals[1];
  } else if (statedTotals != null && statedTotals.length == 1) {
    final n = statedTotals.single;
    if (sumExpense == Decimal.zero && sumIncome != Decimal.zero) {
      debitTotal = Decimal.zero;
      creditTotal = n;
    } else if (sumIncome == Decimal.zero && sumExpense != Decimal.zero) {
      debitTotal = n;
      creditTotal = Decimal.zero;
    }
  }
  if (debitTotal == null || creditTotal == null) return;
  final tolerance = Decimal.parse('0.01');
  if ((sumExpense - debitTotal).abs() > tolerance ||
      (sumIncome - creditTotal).abs() > tolerance) {
    rowErrors.add(
      StatementRowError(
        rowIndex: 0,
        message:
            'Parsed debit/credit totals ($sumExpense / $sumIncome) do not match the '
            'statement\'s stated "TOTAL DES OPÉRATIONS DU RELEVÉ" ($debitTotal / $creditTotal) for '
            '$containerHint — some rows may have the wrong sign.',
      ),
    );
  }
}

List<bool>? resolveSubsetSumCents(List<Decimal> items, Decimal target) {
  if (items.length > 40) return null;
  final targetCents = (target * Decimal.fromInt(100)).toBigInt().toInt();
  if (targetCents < 0 || targetCents > 20000000) return null;
  if (targetCents == 0) return List<bool>.filled(items.length, false);

  final order = List<int>.generate(items.length, (i) => i)
    ..sort((a, b) => items[b].compareTo(items[a]));
  final cents = order
      .map((i) => (items[i] * Decimal.fromInt(100)).toBigInt().toInt())
      .toList();

  final dp = List<int?>.filled(targetCents + 1, null);
  dp[0] = -1;
  for (var pos = 0; pos < cents.length; pos++) {
    final c = cents[pos];
    if (c <= 0 || c > targetCents) continue;
    for (var s = targetCents; s >= c; s--) {
      if (dp[s] == null && dp[s - c] != null) {
        dp[s] = pos;
      }
    }
  }
  if (dp[targetCents] == null) return null;

  final included = List<bool>.filled(items.length, false);
  var remaining = targetCents;
  while (remaining > 0) {
    final pos = dp[remaining]!;
    included[order[pos]] = true;
    remaining -= cents[pos];
  }
  return included;
}
