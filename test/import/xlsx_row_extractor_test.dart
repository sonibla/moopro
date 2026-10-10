import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/xlsx_row_extractor.dart';

void main() {
  test('extractXlsxRows reads back rows written to a real workbook', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.updateCell(CellIndex.indexByString('A1'), TextCellValue('date'));
    sheet.updateCell(CellIndex.indexByString('B1'), TextCellValue('amount'));
    sheet.updateCell(
      CellIndex.indexByString('A2'),
      TextCellValue('2024-01-01'),
    );
    sheet.updateCell(CellIndex.indexByString('B2'), DoubleCellValue(10.5));

    final bytes = Uint8List.fromList(excel.save()!);
    final rows = extractXlsxRows(bytes);

    expect(rows, [
      ['date', 'amount'],
      ['2024-01-01', '10.5'],
    ]);
  });

  test(
    'extractXlsxRows concatenates rows across multiple sheets in workbook order',
    () {
      final excel = Excel.createExcel();
      excel['Sheet1'].updateCell(
        CellIndex.indexByString('A1'),
        TextCellValue('sheet1'),
      );
      excel['Sheet2'].updateCell(
        CellIndex.indexByString('A1'),
        TextCellValue('sheet2'),
      );

      final bytes = Uint8List.fromList(excel.save()!);
      final rows = extractXlsxRows(bytes);

      expect(rows.expand((r) => r), containsAll(['sheet1', 'sheet2']));
    },
  );
}
