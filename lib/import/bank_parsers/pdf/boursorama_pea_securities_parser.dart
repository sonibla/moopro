import 'package:decimal/decimal.dart';

import '../../pdf_text_extractor.dart';
import '../statement_parser.dart';
import 'boursorama_shared.dart';

class BoursoramaPeaSecuritiesParser extends PdfStatementParser {
  @override
  String get parserId => 'boursorama_pea_securities';

  @override
  bool canParse(List<PdfPageLayout> raw) =>
      pdfPagesJoinedText(raw).contains('RELEVE COMPTE TITRES');

  @override
  StatementParseResult parse(
    List<PdfPageLayout> raw, {
    required String sourceFileName,
  }) {
    final rowErrors = <StatementRowError>[];
    final priceCandidates = <StagedPriceSnapshotCandidate>[];
    DateTime? asOfDate;
    Decimal? statedTotal;
    var sumValuations = Decimal.zero;
    var globalLineIndex = 0;

    for (final page in raw) {
      final lines = page.text.split('\n').map((l) => l.trim()).toList();
      for (final line in lines) {
        globalLineIndex++;
        if (line.isEmpty) continue;

        asOfDate ??= _valuedAsOfPattern.firstMatch(line) != null
            ? _parseDdMmYyyy(_valuedAsOfPattern.firstMatch(line)!.group(1)!)
            : null;

        final totalMatch = _totalEurPattern.firstMatch(line);
        if (totalMatch != null) {
          statedTotal = parseAmountSpaceThousands(totalMatch.group(1)!);
          continue;
        }

        final holdingMatch = _holdingLinePattern.firstMatch(line);
        if (holdingMatch == null) {
          continue;
        }

        final name = holdingMatch.group(2)!.trim();
        final isin = holdingMatch.group(3)!;
        final price = parseAmountSpaceThousands(holdingMatch.group(4)!);
        final valuation = parseAmountSpaceThousands(holdingMatch.group(5)!);
        sumValuations += valuation;

        if (asOfDate == null) {
          rowErrors.add(
            StatementRowError(
              rowIndex: globalLineIndex,
              message:
                  'Could not find this statement\'s "Valorisé au" date — skipping the price '
                  'observation for "$name ($isin)".',
            ),
          );
          continue;
        }

        priceCandidates.add(
          StagedPriceSnapshotCandidate(
            sourceFileName: sourceFileName,
            sourceRowIndex: globalLineIndex,
            assetHint: '$name ($isin)',
            date: asOfDate,
            price: price,
            currencyHint: 'EUR',
          ),
        );
      }
    }

    if (statedTotal != null &&
        (sumValuations - statedTotal).abs() > _tolerance) {
      rowErrors.add(
        StatementRowError(
          rowIndex: 0,
          message:
              'Parsed holdings sum to $sumValuations, which does not match the statement\'s '
              'own stated total ($statedTotal) — some lines may have failed to parse.',
        ),
      );
    }

    return StatementParseResult(
      priceCandidates: priceCandidates,
      rowErrors: rowErrors,
    );
  }
}

final _tolerance = Decimal.parse('0.01');

DateTime _parseDdMmYyyy(String s) {
  final parts = s.split('/');
  return DateTime(
    int.parse(parts[2]),
    int.parse(parts[1]),
    int.parse(parts[0]),
  );
}

final _valuedAsOfPattern = RegExp('^Valorisé au (\\d{2}/\\d{2}/\\d{4})\$');

final _totalEurPattern = RegExp(
  '^TOTAL EUR\\s+($amountSpaceThousandsToken)\\s',
);

final _holdingLinePattern = RegExp(
  '^($flexibleNumberToken)\\s+(.+?)\\s+\\(([A-Z0-9]+)\\)\\s*'
  '(?:\\*\\s*)?(?:N\\s*)?'
  '($flexibleNumberToken)\\s+($flexibleNumberToken)\\s+($flexibleNumberToken)\\s+'
  '($flexibleNumberToken)\$',
);
