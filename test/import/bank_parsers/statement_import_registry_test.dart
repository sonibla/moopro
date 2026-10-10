import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/statement_import_registry.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';
import 'package:moopro/import/pdf_text_extractor.dart';

import 'pdf/pdf_fixture_helpers.dart';

class _FakePdfParser extends PdfStatementParser {
  @override
  String get parserId => 'fake_pdf';

  @override
  bool canParse(List<PdfPageLayout> raw) =>
      raw.any((page) => page.text.contains('FAKE BANK'));

  @override
  StatementParseResult parse(
    List<PdfPageLayout> raw, {
    required String sourceFileName,
  }) {
    return StatementParseResult(transactionCandidates: const []);
  }
}

class _FakeTabularParser extends TabularStatementParser {
  @override
  String get parserId => 'fake_csv';

  @override
  bool canParse(List<List<String>> raw) =>
      raw.isNotEmpty && raw.first.contains('FAKE_HEADER');

  @override
  StatementParseResult parse(
    List<List<String>> raw, {
    required String sourceFileName,
  }) {
    return StatementParseResult(transactionCandidates: const []);
  }
}

void main() {
  group('StatementImportRegistry', () {
    test('tryParsePdf dispatches to the parser whose canParse matches', () {
      final registry = StatementImportRegistry(pdfParsers: [_FakePdfParser()]);
      final result = registry.tryParsePdf(
        pageLayoutsFromText(['some header', 'FAKE BANK statement']),
        'a.pdf',
      );
      expect(result, isNotNull);
    });

    test('tryParsePdf returns null when no parser recognizes the file', () {
      final registry = StatementImportRegistry(pdfParsers: [_FakePdfParser()]);
      final result = registry.tryParsePdf(
        pageLayoutsFromText(['unrelated content']),
        'a.pdf',
      );
      expect(result, isNull);
    });

    test('tryParseTabular dispatches to the parser whose canParse matches', () {
      final registry = StatementImportRegistry(
        tabularParsers: [_FakeTabularParser()],
      );
      final result = registry.tryParseTabular([
        ['FAKE_HEADER', 'amount'],
        ['2024-01-01', '10.00'],
      ], 'a.csv');
      expect(result, isNotNull);
    });

    test('tryParseTabular returns null when no parser recognizes the rows', () {
      final registry = StatementImportRegistry(
        tabularParsers: [_FakeTabularParser()],
      );
      final result = registry.tryParseTabular([
        ['other', 'header'],
      ], 'a.csv');
      expect(result, isNull);
    });

    test('an empty registry always returns null (no parser exists yet)', () {
      const registry = StatementImportRegistry();
      expect(
        registry.tryParsePdf(pageLayoutsFromText(['anything']), 'a.pdf'),
        isNull,
      );
      expect(
        registry.tryParseTabular([
          ['anything'],
        ], 'a.csv'),
        isNull,
      );
    });
  });
}
