import 'package:csv_plus/csv_plus.dart';

List<List<String>> extractCsvRows(String content) {
  final decoded = const CsvCodec().decode(content);
  return decoded
      .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
      .toList();
}
