import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'fortuneo_shared.dart';
import '../../../domain/calendar_date.dart';

class FortuneoCompteCourantParser extends PdfStatementParser {
  @override
  String get parserId => 'fortuneo_compte_courant';

  @override
  bool canParse(List<PdfPageLayout> raw) {
    final joined = pdfPagesJoinedText(raw);
    return joined.contains('FORTUNEO') &&
        joined.contains('COMPTE COURANT') &&
        joined.contains('Relevé de Compte');
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
    final holderTokens = _extractHolderNameTokens(
      pdfPagesJoinedText(raw).split('\n'),
    );
    final containerHint = doc.accountNumber == null
        ? 'Fortuneo Compte Courant'
        : 'Compte Courant n° ${doc.accountNumber}';

    final candidates = <StagedTransactionCandidate>[];
    final rowErrors = List<StatementRowError>.of(doc.rowErrors);
    var sumIncome = Decimal.zero;
    var sumExpense = Decimal.zero;

    for (final row in doc.rows) {
      final isIncome =
          row.isCreditByPosition ??
          _classifyIncome(row.description, holderTokens);
      if (isIncome == null) {
        rowErrors.add(
          StatementRowError(
            rowIndex: row.lineIndex,
            message:
                'Could not tell whether this is a debit or credit from its description — '
                'defaulted to expense, please verify: "${row.description}"',
          ),
        );
      }
      final signed = (isIncome ?? false) ? row.amount : -row.amount;
      if (signed > Decimal.zero) {
        sumIncome += signed;
      } else {
        sumExpense += -signed;
      }

      final lower = row.description.toLowerCase();
      final tags = <String>[
        if (lower.contains('salaire') || lower.contains('salary')) 'salary',
        if (_mentionsHolder(row.description, holderTokens))
          'likely-self-transfer',
      ];

      final carteDate = _cartePostingDatePattern.firstMatch(row.description);
      final postingDate = carteDate == null
          ? row.postingDate
          : resolveFortuneoDayMonth(
              int.parse(carteDate.group(1)!),
              int.parse(carteDate.group(2)!),
              row.effectiveDate,
            );

      candidates.add(
        StagedTransactionCandidate(
          sourceFileName: sourceFileName,
          sourceRowIndex: row.lineIndex,
          effectiveDate: CalendarDate.fromDateTime(row.effectiveDate),
          postingDate: postingDate,
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

final _accountNumberPattern = RegExp(
  r'^NUM[ÉE]RO DE COMPTE\s+(.+)$',
  caseSensitive: false,
);

final _cartePostingDatePattern = RegExp(
  r'^CARTE\s+(\d{2})/(\d{2})\b',
  caseSensitive: false,
);

final _titledNamePattern = RegExp(r'\bM\.?\s+[A-ZÀ-Þ]');

bool? _classifyIncome(String description, Set<String> holderTokens) {
  final lower = description.toLowerCase();
  if (lower.startsWith('carte')) return false;
  if (lower.startsWith('prlv')) return false;
  if (lower.startsWith('vir')) {
    final looksLikeOutgoingToSelf =
        _mentionsHolder(description, holderTokens) &&
        !_titledNamePattern.hasMatch(description);
    return !looksLikeOutgoingToSelf;
  }
  return null;
}

final _holderNameLinePattern = RegExp(
  r'^Titulaire\(s\) du compte\s*:\s*(?:M\.?|Mme\.?|Mlle\.?)\s+(.+)$',
  caseSensitive: false,
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
