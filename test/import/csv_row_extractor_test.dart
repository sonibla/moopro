import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/csv_row_extractor.dart';

void main() {
  test('extractCsvRows turns CSV text into rows of stringified cells', () {
    final rows = extractCsvRows(
      'date,amount,description\n2024-01-01,10.50,Coffee\n',
    );

    expect(rows, [
      ['date', 'amount', 'description'],
      ['2024-01-01', '10.5', 'Coffee'],
    ]);
  });

  test('extractCsvRows handles quoted fields containing commas', () {
    final rows = extractCsvRows('a,b\n"1,000.00","Rent, January"\n');

    expect(rows[1], ['1,000.00', 'Rent, January']);
  });
}
