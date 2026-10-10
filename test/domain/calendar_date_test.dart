import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/calendar_date.dart';
import 'package:decimal/decimal.dart';
import 'package:moopro/domain/models.dart';

void main() {
  group('construction', () {
    test('rejects impossible dates', () {
      expect(() => CalendarDate(2026, 2, 29), throwsArgumentError);
      expect(() => CalendarDate(2026, 13, 1), throwsArgumentError);
      expect(() => CalendarDate(2026, 4, 31), throwsArgumentError);
      expect(CalendarDate(2024, 2, 29).day, 29, reason: 'leap year');
    });

    test('fromDateTime keeps the day the value shows in its own zone and drops '
        'the time', () {
      expect(
        CalendarDate.fromDateTime(DateTime(2026, 3, 1, 23, 59)),
        CalendarDate(2026, 3, 1),
      );
      expect(
        CalendarDate.fromDateTime(DateTime.utc(2026, 3, 1, 0, 0, 1)),
        CalendarDate(2026, 3, 1),
      );
    });

    test('today uses the supplied clock', () {
      expect(
        CalendarDate.today(now: DateTime(2026, 7, 4, 15)),
        CalendarDate(2026, 7, 4),
      );
    });
  });

  group('ISO round-trip', () {
    test('toIso/parse', () {
      expect(CalendarDate(2026, 3, 1).toIso(), '2026-03-01');
      expect(CalendarDate.parse('2026-03-01'), CalendarDate(2026, 3, 1));
      expect(
        CalendarDate.parse(CalendarDate(1999, 12, 31).toIso()),
        CalendarDate(1999, 12, 31),
      );
    });

    test('a legacy full ISO instant is read as the local day it falls on', () {
      final instant = DateTime(2026, 3, 1, 12);
      expect(
        CalendarDate.parse(instant.toUtc().toIso8601String()),
        CalendarDate(2026, 3, 1),
      );
    });

    test('garbage is rejected', () {
      expect(() => CalendarDate.parse('not a date'), throwsFormatException);
    });
  });

  group('arithmetic and comparison', () {
    test('equality, hashing and ordering', () {
      expect(CalendarDate(2026, 1, 2), CalendarDate(2026, 1, 2));
      expect({CalendarDate(2026, 1, 2): 1}[CalendarDate(2026, 1, 2)], 1);
      expect(
        CalendarDate(2026, 1, 2).isBefore(CalendarDate(2026, 1, 3)),
        isTrue,
      );
      expect(
        CalendarDate(2026, 2, 1).isAfter(CalendarDate(2026, 1, 31)),
        isTrue,
      );
      final sorted = [
        CalendarDate(2026, 5, 1),
        CalendarDate(2025, 12, 31),
        CalendarDate(2026, 1, 1),
      ]..sort();
      expect(sorted.first, CalendarDate(2025, 12, 31));
    });

    test('addDays crosses month/year/leap boundaries', () {
      expect(CalendarDate(2026, 1, 31).addDays(1), CalendarDate(2026, 2, 1));
      expect(CalendarDate(2025, 12, 31).addDays(1), CalendarDate(2026, 1, 1));
      expect(CalendarDate(2024, 2, 28).addDays(1), CalendarDate(2024, 2, 29));
      expect(CalendarDate(2026, 3, 1).addDays(-1), CalendarDate(2026, 2, 28));
    });

    test('addMonthsClamped keeps the day, clamping to the month length', () {
      expect(
        CalendarDate(2026, 1, 31).addMonthsClamped(1),
        CalendarDate(2026, 2, 28),
      );
      expect(
        CalendarDate(2026, 1, 31).addMonthsClamped(2),
        CalendarDate(2026, 3, 31),
      );
      expect(
        CalendarDate(2024, 1, 31).addMonthsClamped(1),
        CalendarDate(2024, 2, 29),
      );
      expect(
        CalendarDate(2026, 11, 15).addMonthsClamped(3),
        CalendarDate(2027, 2, 15),
      );
      expect(
        CalendarDate(2026, 3, 15).addMonthsClamped(-3),
        CalendarDate(2025, 12, 15),
      );
    });

    test('daysUntil is whole days and signed, unaffected by DST', () {
      expect(CalendarDate(2026, 1, 1).daysUntil(CalendarDate(2026, 1, 11)), 10);
      expect(
        CalendarDate(2026, 1, 11).daysUntil(CalendarDate(2026, 1, 1)),
        -10,
      );
      expect(
        CalendarDate(2026, 1, 1).daysUntil(CalendarDate(2026, 12, 31)),
        364,
      );
    });

    test('startOfMonth and weekday', () {
      expect(CalendarDate(2026, 3, 19).startOfMonth, CalendarDate(2026, 3, 1));
      expect(CalendarDate(2026, 1, 5).weekday, DateTime.monday);
    });

    test('toDateTime is local midnight, toUtcDateTime is UTC midnight', () {
      final d = CalendarDate(2026, 3, 1);
      expect(d.toDateTime(), DateTime(2026, 3, 1));
      expect(d.toDateTime().isUtc, isFalse);
      expect(d.toUtcDateTime(), DateTime.utc(2026, 3, 1));
    });
  });

  group('JSON', () {
    MoneyTransaction tx(CalendarDate d) => MoneyTransaction(
      id: 'tx',
      postedAt: DateTime.utc(2026, 3, 1, 12),
      effectiveDate: d,
      kind: TransactionKind.income,
      legOut: TransactionLeg(
        containerId: 'a',
        assetId: 'eur',
        quantity: Decimal.parse('1'),
      ),
      legIn: TransactionLeg(
        containerId: 'b',
        assetId: 'eur',
        quantity: Decimal.parse('1'),
      ),
    );

    test(
      'MoneyTransaction writes a date-only effectiveDate, instant postedAt',
      () {
        final json = tx(CalendarDate(2026, 3, 1)).toJson();
        expect(json['effectiveDate'], '2026-03-01');
        expect(json['postedAt'], contains('T'));
      },
    );

    test('MoneyTransaction round-trips', () {
      final original = tx(CalendarDate(2026, 3, 1));
      final back = MoneyTransaction.fromJson('tx', original.toJson());
      expect(back.effectiveDate, original.effectiveDate);
      expect(back.postedAt, original.postedAt);
    });

    test('RecurrenceRule and template dates round-trip as date-only', () {
      final rule = RecurrenceRule(
        startDate: CalendarDate(2026, 1, 31),
        unit: RecurrenceUnit.month,
        interval: 1,
        endDate: CalendarDate(2026, 12, 31),
      );
      expect(rule.toJson()['startDate'], '2026-01-31');
      final back = RecurrenceRule.fromJson(rule.toJson());
      expect(back.startDate, rule.startDate);
      expect(back.endDate, rule.endDate);
    });
  });

  group('cache DB converter', () {
    test(
      'a transaction row stores YYYY-MM-DD and reads back the same day',
      () async {
        final db = ldb.DomainCacheDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db
            .into(db.transactions)
            .insert(
              ldb.TransactionsCompanion.insert(
                id: 'tx',
                postedAt: DateTime.utc(2026, 3, 1, 23, 30),
                effectiveDate: CalendarDate(2026, 3, 1),
                kind: 'holderTransfer',
                legOutContainerId: 'a',
                legOutAssetId: 'eur',
                legOutQuantity: '1',
                legInContainerId: 'b',
                legInAssetId: 'eur',
                legInQuantity: '1',
              ),
            );
        final row = await db.select(db.transactions).getSingle();
        expect(row.effectiveDate, CalendarDate(2026, 3, 1));

        final raw = await db
            .customSelect('SELECT effective_date AS d FROM transactions')
            .getSingle();
        expect(raw.read<String>('d'), '2026-03-01');
      },
    );

    test('ordering by the column orders by day', () async {
      final db = ldb.DomainCacheDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (final (id, d) in [
        ('c', CalendarDate(2026, 12, 1)),
        ('a', CalendarDate(2025, 1, 15)),
        ('b', CalendarDate(2026, 2, 1)),
      ]) {
        await db
            .into(db.transactions)
            .insert(
              ldb.TransactionsCompanion.insert(
                id: id,
                postedAt: DateTime.utc(2026),
                effectiveDate: d,
                kind: 'holderTransfer',
                legOutContainerId: 'a',
                legOutAssetId: 'eur',
                legOutQuantity: '1',
                legInContainerId: 'b',
                legInAssetId: 'eur',
                legInQuantity: '1',
              ),
            );
      }
      final rows = await (db.select(
        db.transactions,
      )..orderBy([(t) => OrderingTerm.asc(t.effectiveDate)])).get();
      expect(rows.map((r) => r.id), ['a', 'b', 'c']);
    });
  });
}
