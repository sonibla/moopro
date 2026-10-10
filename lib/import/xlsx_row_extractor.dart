import 'dart:typed_data';

import 'package:excel_plus/excel_plus.dart';

List<List<String>> extractXlsxRows(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final rows = <List<String>>[];
  for (final sheetName in excel.tables.keys) {
    for (final row in excel.tables[sheetName]!.rows) {
      rows.add(row.map((cell) => cell?.value.toString() ?? '').toList());
    }
  }
  return rows;
}
