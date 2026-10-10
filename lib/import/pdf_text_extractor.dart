import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

class PdfPageLayout {
  final String text;
  final List<PdfRect> charRects;

  const PdfPageLayout({required this.text, required this.charRects});
}

Future<List<PdfPageLayout>> extractPdfPageLayouts(Uint8List bytes) async {
  final document = await PdfDocument.openData(
    bytes,
    sourceName: 'statement.pdf',
  );
  try {
    final layouts = <PdfPageLayout>[];
    for (final page in document.pages) {
      final raw = await page.loadText();
      layouts.add(
        PdfPageLayout(
          text: raw?.fullText ?? '',
          charRects: raw?.charRects ?? const [],
        ),
      );
    }
    return layouts;
  } finally {
    await document.dispose();
  }
}

String pdfPagesJoinedText(List<PdfPageLayout> pages) =>
    pages.map((p) => p.text).join('\n');

class PdfTextLine {
  final String text;
  final int start;
  final int end;

  const PdfTextLine({
    required this.text,
    required this.start,
    required this.end,
  });
}

List<PdfTextLine> splitPageLinesWithOffsets(PdfPageLayout page) {
  final lines = <PdfTextLine>[];
  var offset = 0;
  for (final rawLine in page.text.split('\n')) {
    final trimmed = rawLine.trim();
    final leadingWhitespace = rawLine.length - rawLine.trimLeft().length;
    final start = offset + leadingWhitespace;
    lines.add(
      PdfTextLine(text: trimmed, start: start, end: start + trimmed.length),
    );
    offset += rawLine.length + 1;
  }
  return lines;
}
