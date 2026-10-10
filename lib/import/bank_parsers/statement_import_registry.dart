import '../pdf_text_extractor.dart' show PdfPageLayout;
import 'statement_parser.dart';

class StatementImportRegistry {
  final List<PdfStatementParser> pdfParsers;
  final List<TabularStatementParser> tabularParsers;

  const StatementImportRegistry({
    this.pdfParsers = const [],
    this.tabularParsers = const [],
  });

  StatementParseResult? tryParsePdf(
    List<PdfPageLayout> pages,
    String fileName,
  ) {
    for (final parser in pdfParsers) {
      if (parser.canParse(pages)) {
        return parser.parse(pages, sourceFileName: fileName);
      }
    }
    return null;
  }

  StatementParseResult? tryParseTabular(
    List<List<String>> rows,
    String fileName,
  ) {
    for (final parser in tabularParsers) {
      if (parser.canParse(rows)) {
        return parser.parse(rows, sourceFileName: fileName);
      }
    }
    return null;
  }
}
