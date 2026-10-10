import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_filter.dart';
import 'package:moopro/domain/calendar_date.dart';

ldb.Transaction _tx({
  required String id,
  TransactionKind kind = TransactionKind.holderTransfer,
  String legOutContainerId = 'holderA',
  String legInContainerId = 'holderB',
  String legOutAssetId = 'eur',
  String legInAssetId = 'eur',
  String? budgetLegOutContainerId,
  String? budgetLegInContainerId,
  CalendarDate? effectiveDate,
  List<String> tags = const [],
  String? note,
  String quantity = '10',
}) => ldb.Transaction(
  id: id,
  postedAt: effectiveDate?.toDateTime() ?? DateTime.utc(2026, 1, 1),
  effectiveDate: effectiveDate ?? CalendarDate(2026, 1, 1),
  kind: kind.name,
  legOutContainerId: legOutContainerId,
  legOutAssetId: legOutAssetId,
  legOutQuantity: quantity,
  legInContainerId: legInContainerId,
  legInAssetId: legInAssetId,
  legInQuantity: quantity,
  budgetLegOutContainerId: budgetLegOutContainerId,
  budgetLegOutAssetId: budgetLegOutContainerId == null ? null : 'eur',
  budgetLegOutQuantity: budgetLegOutContainerId == null ? null : '10',
  budgetLegInContainerId: budgetLegInContainerId,
  budgetLegInAssetId: budgetLegInContainerId == null ? null : 'eur',
  budgetLegInQuantity: budgetLegInContainerId == null ? null : '10',
  tags: encodeTagsColumn(tags),
  note: note,
  manualOrderRank: 0,
  deleted: false,
);

void main() {
  group('applyTransactionFilter', () {
    test('an empty filter returns every row unchanged', () {
      final rows = [_tx(id: 'a'), _tx(id: 'b')];
      expect(
        applyTransactionFilter(rows, TransactionFilter.empty),
        equals(rows),
      );
    });

    test('filters by kind', () {
      final income = _tx(id: 'a', kind: TransactionKind.income);
      final transfer = _tx(id: 'b', kind: TransactionKind.holderTransfer);
      final result = applyTransactionFilter([
        income,
        transfer,
      ], const TransactionFilter(kinds: {TransactionKind.income}));
      expect(result, equals([income]));
    });

    test(
      'filters by container across any leg slot (out, in, budget out/in)',
      () {
        final touchesHolder = _tx(id: 'a', legOutContainerId: 'holderX');
        final other = _tx(
          id: 'b',
          legOutContainerId: 'holderY',
          legInContainerId: 'holderZ',
        );
        final result = applyTransactionFilter([
          touchesHolder,
          other,
        ], const TransactionFilter(containerId: 'holderX'));
        expect(result, equals([touchesHolder]));
      },
    );

    test('filters by asset', () {
      final eur = _tx(id: 'a', legOutAssetId: 'eur', legInAssetId: 'eur');
      final usd = _tx(id: 'b', legOutAssetId: 'usd', legInAssetId: 'usd');
      final result = applyTransactionFilter([
        eur,
        usd,
      ], const TransactionFilter(assetId: 'usd'));
      expect(result, equals([usd]));
    });

    test('filters by date range, inclusive on both ends', () {
      final before = _tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 1));
      final within = _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 15));
      final after = _tx(id: 'c', effectiveDate: CalendarDate(2026, 2, 1));
      final boundary = _tx(id: 'd', effectiveDate: CalendarDate(2026, 1, 31));

      final result = applyTransactionFilter(
        [before, within, after, boundary],
        TransactionFilter(
          dateScope: DateScope.custom,
          dateRange: DateTimeRange(
            start: DateTime.utc(2026, 1, 10),
            end: DateTime.utc(2026, 1, 31),
          ),
        ),
      );
      expect(result, equals([within, boundary]));
    });

    group('date scope', () {
      final now = DateTime(2026, 1, 20, 15, 30);
      final yesterday = _tx(id: 'y', effectiveDate: CalendarDate(2026, 1, 19));
      final todayEarly = _tx(id: 't', effectiveDate: CalendarDate(2026, 1, 20));
      final todayLate = _tx(id: 'l', effectiveDate: CalendarDate(2026, 1, 20));
      final tomorrow = _tx(id: 'm', effectiveDate: CalendarDate(2026, 1, 21));
      final rows = [yesterday, todayEarly, todayLate, tomorrow];

      List<ldb.Transaction> run(TransactionFilter f) =>
          applyTransactionFilter(rows, f, now: now);

      test('past includes the whole of today, future starts tomorrow', () {
        expect(
          run(const TransactionFilter(dateScope: DateScope.past)),
          equals([yesterday, todayEarly, todayLate]),
        );
        expect(
          run(const TransactionFilter(dateScope: DateScope.future)),
          equals([tomorrow]),
        );
      });

      test(
        'all ignores a stale dateRange; custom without a range matches everything',
        () {
          final range = DateTimeRange(
            start: DateTime(2026, 1, 21),
            end: DateTime(2026, 1, 21),
          );
          expect(run(TransactionFilter(dateRange: range)), equals(rows));
          expect(
            run(const TransactionFilter(dateScope: DateScope.custom)),
            equals(rows),
          );
        },
      );

      test('a custom range may lie in the future', () {
        final range = DateTimeRange(
          start: DateTime(2026, 1, 21),
          end: DateTime(2026, 2, 1),
        );
        expect(
          run(TransactionFilter(dateScope: DateScope.custom, dateRange: range)),
          equals([tomorrow]),
        );
      });

      test('is resolved against the given now, not stored', () {
        final later = applyTransactionFilter(
          rows,
          const TransactionFilter(dateScope: DateScope.future),
          now: DateTime(2026, 1, 21, 0, 1),
        );
        expect(later, isEmpty);
      });

      test('counts as one active filter and clears isEmpty', () {
        const f = TransactionFilter(dateScope: DateScope.future);
        expect(f.isEmpty, isFalse);
        expect(f.activeCount, 1);
        expect(const TransactionFilter().activeCount, 0);
      });

      test('withDateScope drops the range unless the scope is custom', () {
        final range = DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 2),
        );
        final custom = const TransactionFilter(
          tags: {'x'},
        ).withDateScope(DateScope.custom, range);
        expect(custom.dateRange, range);
        expect(custom.tags, {'x'});
        final past = custom.withDateScope(DateScope.past);
        expect(past.dateRange, isNull);
        expect(past.dateScope, DateScope.past);
      });
    });

    test('combines multiple criteria with AND semantics', () {
      final matches = _tx(
        id: 'a',
        kind: TransactionKind.income,
        legOutContainerId: 'holderX',
        effectiveDate: CalendarDate(2026, 1, 15),
      );
      final wrongKind = _tx(
        id: 'b',
        kind: TransactionKind.expense,
        legOutContainerId: 'holderX',
        effectiveDate: CalendarDate(2026, 1, 15),
      );
      final result = applyTransactionFilter(
        [matches, wrongKind],
        TransactionFilter(
          kinds: const {TransactionKind.income},
          containerId: 'holderX',
          dateScope: DateScope.custom,
          dateRange: DateTimeRange(
            start: DateTime.utc(2026, 1, 1),
            end: DateTime.utc(2026, 1, 31),
          ),
        ),
      );
      expect(result, equals([matches]));
    });

    test('filters by tag', () {
      final tagged = _tx(id: 'a', tags: const ['Japan trip']);
      final other = _tx(id: 'b', tags: const ['Paris trip']);
      final untagged = _tx(id: 'c');
      final result = applyTransactionFilter([
        tagged,
        other,
        untagged,
      ], const TransactionFilter(tags: {'Japan trip'}));
      expect(result, equals([tagged]));
    });

    test('multiple tags require ALL of them, not any', () {
      final both = _tx(id: 'a', tags: const ['Japan trip', 'Food', 'Extra']);
      final onlyJapan = _tx(id: 'b', tags: const ['Japan trip']);
      final onlyFood = _tx(id: 'c', tags: const ['Food']);
      final untagged = _tx(id: 'd');
      final rows = [both, onlyJapan, onlyFood, untagged];

      expect(
        applyTransactionFilter(
          rows,
          const TransactionFilter(tags: {'Japan trip', 'Food'}),
        ),
        equals([both]),
      );
      expect(
        applyTransactionFilter(
          rows,
          const TransactionFilter(tags: {'Japan trip', 'Nope'}),
        ),
        isEmpty,
      );
    });

    test('filters by search query, case-insensitively against note', () {
      final matching = _tx(id: 'a', note: 'Sushi with friends');
      final other = _tx(id: 'b', note: 'Electricity bill');
      final result = applyTransactionFilter([
        matching,
        other,
      ], const TransactionFilter(searchQuery: 'sushi'));
      expect(result, equals([matching]));
    });

    test('filters by search query against tags too', () {
      final matching = _tx(id: 'a', tags: const ['Japan trip']);
      final other = _tx(id: 'b', tags: const ['Paris trip']);
      final result = applyTransactionFilter([
        matching,
        other,
      ], const TransactionFilter(searchQuery: 'japan'));
      expect(result, equals([matching]));
    });

    test('an empty search query string is treated as no restriction', () {
      final rows = [_tx(id: 'a'), _tx(id: 'b')];
      final result = applyTransactionFilter(
        rows,
        const TransactionFilter(searchQuery: ''),
      );
      expect(result, equals(rows));
    });

    test('filters by search query against leg amounts', () {
      final a = _tx(id: 'a', quantity: '120.5');
      final b = _tx(id: 'b', quantity: '-7');
      final c = _tx(id: 'c', quantity: '3');
      List<String> ids(String q) => applyTransactionFilter([
        a,
        b,
        c,
      ], TransactionFilter(searchQuery: q)).map((r) => r.id).toList();
      expect(ids('120'), ['a']);
      expect(ids('120,50'), ['a']);
      expect(ids('7'), ['b']);
      expect(ids('-7'), ['b']);
      expect(ids('999'), isEmpty);
    });

    test('filters by search query against a holder/budget container name '
        'touched by any leg — not just note/tags', () {
      final matching = _tx(id: 'a', legInContainerId: 'revolut');
      final other = _tx(id: 'b', legInContainerId: 'boursorama');
      final result = applyTransactionFilter(
        [matching, other],
        const TransactionFilter(searchQuery: 'revolut'),
        containerNames: const {
          'revolut': 'Revolut',
          'boursorama': 'Boursorama',
        },
      );
      expect(result, equals([matching]));
    });

    test('filters by search query against a budget-leg container name too', () {
      final matching = _tx(
        id: 'a',
        kind: TransactionKind.income,
        budgetLegInContainerId: 'savings',
      );
      final other = _tx(
        id: 'b',
        kind: TransactionKind.income,
        budgetLegInContainerId: 'spendings',
      );
      final result = applyTransactionFilter(
        [matching, other],
        const TransactionFilter(searchQuery: 'savings'),
        containerNames: const {'savings': 'Savings', 'spendings': 'Spendings'},
      );
      expect(result, equals([matching]));
    });

    test('filters by search query against an asset symbol or name touched '
        'by any leg', () {
      const btc = ldb.Asset(
        id: 'btc',
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        deleted: false,
      );
      const eur = ldb.Asset(
        id: 'eur',
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      );
      final matching = _tx(id: 'a', legOutAssetId: 'eur', legInAssetId: 'btc');
      final other = _tx(id: 'b', legOutAssetId: 'eur', legInAssetId: 'eur');
      final result = applyTransactionFilter(
        [matching, other],
        const TransactionFilter(searchQuery: 'bitcoin'),
        assetsById: const {'btc': btc, 'eur': eur},
      );
      expect(result, equals([matching]));
    });
  });

  group('TransactionFilter', () {
    test('isEmpty/activeCount reflect which fields are set', () {
      expect(TransactionFilter.empty.isEmpty, isTrue);
      expect(TransactionFilter.empty.activeCount, equals(0));

      const withKind = TransactionFilter(kinds: {TransactionKind.income});
      expect(withKind.isEmpty, isFalse);
      expect(withKind.activeCount, equals(1));

      const withAll = TransactionFilter(
        kinds: {TransactionKind.income},
        containerId: 'x',
        assetId: 'y',
        tags: {'z', 'w'},
      );
      expect(withAll.activeCount, equals(4));

      const withTagsOnly = TransactionFilter(tags: {'z'});
      expect(withTagsOnly.isEmpty, isFalse);
      expect(withTagsOnly.activeCount, equals(1));

      const withSearch = TransactionFilter(searchQuery: 'sushi');
      expect(withSearch.isEmpty, isFalse);
      expect(withSearch.activeCount, equals(1));

      const withEmptySearch = TransactionFilter(searchQuery: '');
      expect(withEmptySearch.isEmpty, isTrue);
      expect(withEmptySearch.activeCount, equals(0));
    });
  });

  group('allTags', () {
    test('deduplicated, sorted, across every row', () {
      final rows = [
        _tx(id: 'a', tags: const ['Japan trip', 'Reimbursable']),
        _tx(id: 'b', tags: const ['Japan trip']),
        _tx(id: 'c'),
      ];
      expect(allTags(rows), ['Japan trip', 'Reimbursable']);
    });
  });

  group('tagUsageCounts', () {
    test('counts transactions per tag, once per transaction', () {
      final rows = [
        _tx(id: 'a', tags: const ['Japan trip', 'Reimbursable']),
        _tx(id: 'b', tags: const ['Japan trip', 'Japan trip']),
        _tx(id: 'c'),
      ];
      expect(tagUsageCounts(rows), {'Japan trip': 2, 'Reimbursable': 1});
    });
  });

  group('DateRangePreset.resolve', () {
    final now = DateTime(2026, 10, 8, 15, 30);

    test('month to date starts on the 1st', () {
      final r = DateRangePreset.monthToDate.resolve(now);
      expect(r.start, DateTime(2026, 10));
      expect(r.end, DateTime(2026, 10, 8));
    });

    test('year to date starts on Jan 1', () {
      final r = DateRangePreset.yearToDate.resolve(now);
      expect(r.start, DateTime(2026));
      expect(r.end, DateTime(2026, 10, 8));
    });

    test('last 12 months spans exactly a year inclusive of today', () {
      final r = DateRangePreset.last12Months.resolve(now);
      expect(r.start, DateTime(2025, 10, 9));
      expect(r.end, DateTime(2026, 10, 8));
    });
  });
}
