import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'pdf_column_layout.dart';
import '../../../domain/calendar_date.dart';

class CreditAgricoleReleveCompteParser extends PdfStatementParser {
  @override
  String get parserId => 'credit_agricole_releve_compte';

  @override
  bool canParse(List<PdfPageLayout> raw) {
    final joined = pdfPagesJoinedText(raw);
    return joined.contains('CREDIT AGRICOLE') &&
        joined.contains('RELEVE DE COMPTES');
  }

  @override
  StatementParseResult parse(
    List<PdfPageLayout> raw, {
    required String sourceFileName,
  }) {
    final indexedLines = <_IndexedLine>[
      for (var p = 0; p < raw.length; p++)
        for (final lineObj in splitPageLinesWithOffsets(raw[p]))
          _IndexedLine(p, lineObj),
    ];
    final lines = [for (final l in indexedLines) l.line.text];
    final columnBoundaries = PdfColumnBoundaries.detect(
      raw,
      leftLabel: 'Débit',
      rightLabel: 'Crédit',
    );

    final holderTokens = _extractHolderNameTokens(lines);
    DateTime? statementClosingFallback;
    for (final line in lines) {
      statementClosingFallback ??= _parseDateArrete(line);
    }

    final candidates = <StagedTransactionCandidate>[];
    final rowErrors = <StatementRowError>[];
    final sections = <_SectionResult>[];

    var rowIndex = 0;
    var state = _State.none;
    var anySectionHeaderSeen = false;

    String? containerHint;
    DateTime? openingDate;
    Decimal? openingBalance;
    DateTime? closingDate;
    Decimal? closingBalance;
    List<Decimal>? statedTotals;

    var sectionRows = <_RawRow>[];
    _RawRow? pending;

    void abandonPending(int lineIndex) {
      final row = pending;
      if (row == null) return;
      rowErrors.add(
        StatementRowError(
          rowIndex: row.lineIndex,
          message:
              'Could not find an amount to close this transaction row '
              '(line $lineIndex): "${row.description}"',
        ),
      );
      pending = null;
    }

    void closePending(
      _TrailingAmount trailing, {
      required bool? isCreditByPosition,
    }) {
      final row = pending!;
      if (trailing.before.isNotEmpty) row.descriptionParts.add(trailing.before);
      row.amount = trailing.amount;
      row.isCreditByPosition = isCreditByPosition;
      sectionRows.add(row);
      pending = null;
    }

    void finalizeSection() {
      final hint = containerHint;
      if (hint == null) {
        sectionRows = [];
        return;
      }
      final opened = openingDate;
      if (opened == null) {
        rowErrors.add(
          StatementRowError(
            rowIndex: sectionRows.isEmpty ? 0 : sectionRows.first.lineIndex,
            message:
                'Could not find the opening balance ("Ancien solde") for "$hint" — '
                '${sectionRows.length} transaction row(s) in this section could not be dated '
                'and were skipped. Please check this statement manually.',
          ),
        );
        sectionRows = [];
        return;
      }
      var closed = closingDate;
      if (closed == null) {
        final fallback = statementClosingFallback;
        if (fallback != null && !fallback.isBefore(opened)) {
          closed = fallback;
          rowErrors.add(
            StatementRowError(
              rowIndex: sectionRows.isEmpty ? 0 : sectionRows.first.lineIndex,
              message:
                  'Could not find the closing balance ("Nouveau solde") for "$hint" — used '
                  'the statement\'s own closing date ("Date d\'arrêté") to date these rows '
                  'instead; the running balance for this account was not reconciled, please '
                  'verify manually.',
            ),
          );
        } else {
          rowErrors.add(
            StatementRowError(
              rowIndex: sectionRows.isEmpty ? 0 : sectionRows.first.lineIndex,
              message:
                  'Could not find the closing balance ("Nouveau solde") for "$hint" — '
                  '${sectionRows.length} transaction row(s) in this section could not be dated '
                  'and were skipped. Please check this statement manually.',
            ),
          );
          sectionRows = [];
          return;
        }
      }
      var sumIncome = Decimal.zero;
      var sumExpense = Decimal.zero;
      for (final row in sectionRows) {
        final postingDate = _resolveYear(
          row.postDay,
          row.postMonth,
          opened,
          closed,
        );
        final effectiveDate = _resolveYear(
          row.valDay,
          row.valMonth,
          opened,
          closed,
        );
        final description = row.description;
        final isIncome = row.isCreditByPosition ?? _classifyIncome(description);
        if (isIncome == null) {
          rowErrors.add(
            StatementRowError(
              rowIndex: row.lineIndex,
              message:
                  'Could not tell whether this is a debit or credit from its '
                  'description — defaulted to expense, please verify: "$description"',
            ),
          );
        }
        final signed = (isIncome ?? false) ? row.amount : -row.amount;
        if (signed > Decimal.zero) {
          sumIncome += signed;
        } else {
          sumExpense += -signed;
        }
        final lowerDesc = description.toLowerCase();
        final tags = <String>[
          if (lowerDesc.contains('salary') || lowerDesc.contains('salaire'))
            'salary',
          if (_mentionsHolder(description, holderTokens))
            'likely-self-transfer',
        ];
        candidates.add(
          StagedTransactionCandidate(
            sourceFileName: sourceFileName,
            sourceRowIndex: rowIndex++,
            effectiveDate: CalendarDate.fromDateTime(effectiveDate),
            postingDate: postingDate,
            amount: signed,
            description: description,
            containerHint: hint,
            tags: tags,
          ),
        );
      }

      final totals = statedTotals;
      Decimal? debitTotal;
      Decimal? creditTotal;
      if (totals != null && totals.length == 2) {
        debitTotal = totals[0];
        creditTotal = totals[1];
      } else if (totals != null && totals.length == 1) {
        final n = totals.single;
        if (sumExpense == Decimal.zero && sumIncome != Decimal.zero) {
          debitTotal = Decimal.zero;
          creditTotal = n;
        } else if (sumIncome == Decimal.zero && sumExpense != Decimal.zero) {
          debitTotal = n;
          creditTotal = Decimal.zero;
        }
      }
      if (debitTotal != null && creditTotal != null) {
        final tolerance = Decimal.parse('0.01');
        if ((sumExpense - debitTotal).abs() > tolerance ||
            (sumIncome - creditTotal).abs() > tolerance) {
          rowErrors.add(
            StatementRowError(
              rowIndex: sectionRows.isEmpty ? 0 : sectionRows.first.lineIndex,
              message:
                  'Parsed debit/credit totals ($sumExpense / $sumIncome) do not match '
                  'the statement\'s stated "Total des opérations" ($debitTotal / $creditTotal) '
                  'for $hint — some rows may have the wrong sign.',
            ),
          );
        }
      }

      sections.add(
        _SectionResult(
          openingBalance: openingBalance,
          closingBalance: closingBalance,
        ),
      );
      sectionRows = [];
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final pageIndex = indexedLines[i].pageIndex;
      final page = raw[pageIndex];
      final lineStart = indexedLines[i].line.start;

      final header = _matchSectionHeader(line);
      if (header != null) {
        abandonPending(i);
        if (!header.isContinuation) {
          finalizeSection();
          anySectionHeaderSeen = true;
          containerHint = header.containerHint;
          openingDate = null;
          openingBalance = null;
          closingDate = null;
          closingBalance = null;
          statedTotals = null;
          state = _State.awaitingOpeningBalance;
        } else {
          state = _State.transactions;
        }
        continue;
      }

      switch (state) {
        case _State.none:
          break;

        case _State.awaitingOpeningBalance:
          final m = _ancienSoldePattern.firstMatch(line);
          if (m != null) {
            openingDate = DateTime(
              int.parse(m.group(4)!),
              int.parse(m.group(3)!),
              int.parse(m.group(2)!),
            );
            openingBalance = _parseSignedBalance(m.group(1)!, m.group(5)!);
            state = _State.transactions;
          }
          break;

        case _State.transactions:
          final dateMatch = _dateLineStart.firstMatch(line);
          if (dateMatch != null) {
            abandonPending(i);
            pending = _RawRow(
              postDay: int.parse(dateMatch.group(1)!),
              postMonth: int.parse(dateMatch.group(2)!),
              valDay: int.parse(dateMatch.group(3)!),
              valMonth: int.parse(dateMatch.group(4)!),
              lineIndex: i,
            );
            final rawRest = dateMatch.group(5) ?? '';
            final rest = rawRest.trim();
            if (rest.isNotEmpty) {
              final tailStart = line.length - rawRest.length;
              final leadingWs = rawRest.length - rawRest.trimLeft().length;
              final restStart = tailStart + leadingWs;
              final trailing = _tryExtractTrailingAmount(
                rest,
                page: page,
                baseOffset: lineStart + restStart,
              );
              if (trailing != null) {
                final amountStart = lineStart + restStart + trailing.start;
                final amountEnd = lineStart + restStart + trailing.end;
                final boundaryX = columnBoundaries.boundaryXForPosition(
                  pageIndex,
                  amountStart,
                );
                closePending(
                  trailing,
                  isCreditByPosition: boundaryX == null
                      ? null
                      : isRightOfColumn(
                          page,
                          amountStart,
                          amountEnd,
                          boundaryX,
                        ),
                );
              } else {
                pending!.descriptionParts.add(rest);
              }
            }
            continue;
          }

          final totalMatch = _totalOperationsPattern.firstMatch(line);
          if (totalMatch != null) {
            abandonPending(i);
            final second = totalMatch.group(2);
            statedTotals = [
              _parseAmount(totalMatch.group(1)!),
              if (second != null) _parseAmount(second),
            ];
            state = _State.awaitingClosingBalance;
            continue;
          }

          if (pending != null) {
            final trailing = _tryExtractTrailingAmount(
              line,
              page: page,
              baseOffset: lineStart,
            );
            if (trailing != null) {
              final amountStart = lineStart + trailing.start;
              final amountEnd = lineStart + trailing.end;
              final boundaryX = columnBoundaries.boundaryXForPosition(
                pageIndex,
                amountStart,
              );
              closePending(
                trailing,
                isCreditByPosition: boundaryX == null
                    ? null
                    : isRightOfColumn(page, amountStart, amountEnd, boundaryX),
              );
            } else {
              pending!.descriptionParts.add(line);
            }
          }
          break;

        case _State.awaitingClosingBalance:
          final m = _nouveauSoldePattern.firstMatch(line);
          if (m != null) {
            closingDate = DateTime(
              int.parse(m.group(4)!),
              int.parse(m.group(3)!),
              int.parse(m.group(2)!),
            );
            closingBalance = _parseSignedBalance(m.group(1)!, m.group(5)!);
            state = _State.none;
          }
          break;
      }
    }
    abandonPending(lines.length);
    finalizeSection();

    if (!anySectionHeaderSeen) {
      rowErrors.add(
        const StatementRowError(
          rowIndex: 0,
          message:
              'Recognized this as a Credit Agricole statement, but could not find any '
              'account section in it — this document\'s layout may need a parser update.',
        ),
      );
    }

    StatementBalanceInfo? balanceInfo;
    if (sections.length == 1) {
      balanceInfo = StatementBalanceInfo(
        openingBalance: sections.single.openingBalance,
        closingBalance: sections.single.closingBalance,
      );
    }

    return StatementParseResult(
      transactionCandidates: candidates,
      rowErrors: rowErrors,
      balanceInfo: balanceInfo,
    );
  }
}

enum _State {
  none,
  awaitingOpeningBalance,
  transactions,
  awaitingClosingBalance,
}

class _IndexedLine {
  final int pageIndex;
  final PdfTextLine line;
  const _IndexedLine(this.pageIndex, this.line);
}

class _RawRow {
  final int postDay;
  final int postMonth;
  final int valDay;
  final int valMonth;
  final int lineIndex;
  final List<String> descriptionParts = [];
  Decimal amount = Decimal.zero;
  bool? isCreditByPosition;

  _RawRow({
    required this.postDay,
    required this.postMonth,
    required this.valDay,
    required this.valMonth,
    required this.lineIndex,
  });

  String get description =>
      descriptionParts.where((s) => s.isNotEmpty).join(' ').trim();
}

class _SectionResult {
  final Decimal? openingBalance;
  final Decimal? closingBalance;
  _SectionResult({this.openingBalance, this.closingBalance});
}

class _SectionHeader {
  final String containerHint;
  final bool isContinuation;
  _SectionHeader(this.containerHint, this.isContinuation);
}

class _TrailingAmount {
  final String before;
  final Decimal amount;

  final int start;
  final int end;
  _TrailingAmount(this.before, this.amount, this.start, this.end);
}

final _dateLineStart = RegExp(r'^(\d{2})\.(\d{2})\s+(\d{2})\.(\d{2})\s*(.*)$');

final _amountToken = RegExp(r'(?<![\d/,])(\d{1,3}(?:[   ]\d{3})*,\d{2})(?!\d)');

final _accountNumberPattern = RegExp(r'n[°ø]\s*\d+', caseSensitive: false);
final _suitePattern = RegExp(r'\(suite\)\s*$', caseSensitive: false);

final _ancienSoldePattern = RegExp(
  r'^Ancien solde (cr[ée]diteur|d[ée]biteur) au (\d{2})\.(\d{2})\.(\d{4})\s+'
  r'(\d{1,3}(?:[   ]\d{3})*,\d{2})',
  caseSensitive: false,
);

final _nouveauSoldePattern = RegExp(
  r'^Nouveau solde (cr[ée]diteur|d[ée]biteur) au (\d{2})\.(\d{2})\.(\d{4})\s+'
  r'(\d{1,3}(?:[   ]\d{3})*,\d{2})',
  caseSensitive: false,
);

final _totalOperationsPattern = RegExp(
  r'^Total des op[ée]rations\s+(\d{1,3}(?:[   ]\d{3})*,\d{2})'
  r'(?:\s+(\d{1,3}(?:[   ]\d{3})*,\d{2}))?',
  caseSensitive: false,
);

const _frenchMonths = {
  'janvier': 1,
  'fevrier': 2,
  'février': 2,
  'mars': 3,
  'avril': 4,
  'mai': 5,
  'juin': 6,
  'juillet': 7,
  'aout': 8,
  'août': 8,
  'septembre': 9,
  'octobre': 10,
  'novembre': 11,
  'decembre': 12,
  'décembre': 12,
};

final _dateArretePattern = RegExp(
  r"Date d'arr[êé]t[ée]\s*:\s*(\d{1,2})\s+([A-Za-zÀ-ÿ]+)\s+(\d{4})",
  caseSensitive: false,
);

DateTime? _parseDateArrete(String line) {
  final m = _dateArretePattern.firstMatch(line);
  if (m == null) return null;
  final month = _frenchMonths[m.group(2)!.toLowerCase()];
  if (month == null) return null;
  return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!));
}

final _holderNameLinePattern = RegExp(
  r"^(?:M\.|Mme\.?|Mlle\.?)\s+([A-ZÀ-Þ][A-ZÀ-Þ' -]*)$",
);

Set<String> _nameTokens(String text) => text
    .toLowerCase()
    .split(RegExp(r"[^a-zà-ÿ']+"))
    .where((t) => t.length > 1)
    .toSet();

Set<String> _extractHolderNameTokens(List<String> lines) {
  for (final line in lines) {
    final m = _holderNameLinePattern.firstMatch(line);
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

_SectionHeader? _matchSectionHeader(String line) {
  if (!line.startsWith('M')) return null;
  final isContinuation = _suitePattern.hasMatch(line);
  final body = isContinuation
      ? line.replaceFirst(_suitePattern, '').trim()
      : line;
  final sepIndex = body.lastIndexOf(' - ');
  if (sepIndex == -1) return null;
  final containerHint = body.substring(sepIndex + 3).trim();
  if (!_accountNumberPattern.hasMatch(containerHint)) return null;
  return _SectionHeader(containerHint, isContinuation);
}

_TrailingAmount? _tryExtractTrailingAmount(
  String text, {
  required PdfPageLayout page,
  required int baseOffset,
}) {
  final matches = _amountToken.allMatches(text).toList();
  if (matches.isEmpty) return null;
  final last = matches.last;
  final tail = text.substring(last.end).trim();
  if (tail.length > 1) return null;

  final (trimmedAbsStart, _) = trimAmountRange(
    page,
    baseOffset + last.start,
    baseOffset + last.end,
  );
  final start = trimmedAbsStart - baseOffset;
  final rawAmount = text.substring(start, last.end);

  final before = _stripRestatedAmountGlitch(
    text.substring(0, start).trim(),
    rawAmount,
  );
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
    Decimal.parse(raw.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));

Decimal _parseSignedBalance(String sign, String amountStr) {
  final value = _parseAmount(amountStr);
  final lower = sign.toLowerCase();
  return (lower.startsWith('déb') || lower.startsWith('deb')) ? -value : value;
}

bool? _classifyIncome(String description) {
  final lower = description.toLowerCase();
  if (lower.startsWith('avoir carte')) return true;
  if (lower.startsWith('carte ')) return false;
  if (lower.startsWith('prlv')) return false;
  if (lower.startsWith('ech pr')) {
    return false;
  }
  if (lower.startsWith('règlement') || lower.startsWith('reglement')) {
    return false;
  }
  if (lower.startsWith('intér') || lower.startsWith('inter')) {
    return true;
  }
  if (lower.startsWith('virement')) {
    if (lower.startsWith('virement web')) {
      return false;
    }
    if (RegExp(r'\bvers\b').hasMatch(lower)) {
      return false;
    }
    return true;
  }
  return null;
}

DateTime _resolveYear(int day, int month, DateTime opening, DateTime closing) {
  final years = {opening.year, closing.year};
  for (final year in years) {
    final candidate = DateTime(year, month, day);
    if (!candidate.isBefore(opening) && !candidate.isAfter(closing)) {
      return candidate;
    }
  }
  DateTime? best;
  int? bestDistance;
  for (final year in years) {
    final candidate = DateTime(year, month, day);
    final distance = candidate.isBefore(opening)
        ? opening.difference(candidate).inDays
        : candidate.difference(closing).inDays;
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best!;
}
