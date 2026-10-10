import 'dart:convert';
import 'dart:io';

import 'package:pdfrx/pdfrx.dart' show PdfRect;

import 'package:moopro/import/pdf_text_extractor.dart';

List<PdfPageLayout> pageLayoutsFromText(List<String> pages) => [
  for (final page in pages) PdfPageLayout(text: page, charRects: const []),
];

List<PdfPageLayout> loadPdfLayoutFixture(String name) {
  final file = File('test/import/bank_parsers/pdf/fixtures/$name.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final pages = json['pages']! as List;
  return [
    for (final page in pages.cast<Map<String, Object?>>())
      PdfPageLayout(
        text: page['text']! as String,
        charRects: [
          for (final r in (page['charRects']! as List).cast<List>())
            PdfRect(
              (r[0] as num).toDouble(),
              (r[1] as num).toDouble(),
              (r[2] as num).toDouble(),
              (r[3] as num).toDouble(),
            ),
        ],
      ),
  ];
}
