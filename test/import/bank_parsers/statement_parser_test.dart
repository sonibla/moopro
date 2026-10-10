import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/import/bank_parsers/statement_parser.dart';
import 'package:moopro/domain/calendar_date.dart';

StagedTransactionCandidate _candidate({DateTime? postingDate}) =>
    StagedTransactionCandidate(
      sourceFileName: 'a.pdf',
      sourceRowIndex: 0,
      effectiveDate: CalendarDate(2024, 1, 10),
      postingDate: postingDate,
      amount: Decimal.parse('-10.00'),
      description: 'Test',
      containerHint: 'My Bank',
    );

void main() {
  group('StagedTransactionCandidate.postedAt', () {
    test('falls back to effectiveDate when no postingDate was given', () {
      final c = _candidate();
      expect(c.postedAt, DateTime(2024, 1, 10));
    });

    test('uses the distinct postingDate when the source stated one', () {
      final c = _candidate(postingDate: DateTime.utc(2024, 1, 8));
      expect(c.postedAt, DateTime.utc(2024, 1, 8));
      expect(c.effectiveDate, CalendarDate(2024, 1, 10));
    });

    test('copyWith preserves postingDate when not overridden', () {
      final c = _candidate(postingDate: DateTime.utc(2024, 1, 8));
      final copy = c.copyWith(description: 'Updated');
      expect(copy.postingDate, DateTime.utc(2024, 1, 8));
      expect(copy.postedAt, DateTime.utc(2024, 1, 8));
    });

    test('copyWith can override postingDate', () {
      final c = _candidate(postingDate: DateTime.utc(2024, 1, 8));
      final copy = c.copyWith(postingDate: DateTime.utc(2024, 1, 9));
      expect(copy.postedAt, DateTime.utc(2024, 1, 9));
    });
  });
}
