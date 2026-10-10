import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_filter.dart';
import 'package:moopro/domain/transaction_list_grouping.dart';
import 'package:moopro/domain/calendar_date.dart';

ldb.Transaction _tx({
  required String id,
  TransactionKind kind = TransactionKind.holderTransfer,
  required CalendarDate effectiveDate,
  DateTime? postedAt,
  String? legOutContainerId,
  String legInContainerId = 'holderB',
  String legOutAssetId = 'eur',
  String legInAssetId = 'eur',
  int manualOrderRank = 0,
  String quantity = '10',
}) => ldb.Transaction(
  id: id,
  postedAt: postedAt ?? effectiveDate.toDateTime(),
  effectiveDate: effectiveDate,
  kind: kind.name,
  legOutContainerId: legOutContainerId ?? 'src-$id',
  legOutAssetId: legOutAssetId,
  legOutQuantity: quantity,
  legInContainerId: legInContainerId,
  legInAssetId: legInAssetId,
  legInQuantity: quantity,
  tags: '[]',
  manualOrderRank: manualOrderRank,
  deleted: false,
);

const _eur = ldb.Asset(
  id: 'eur',
  kind: 'fiat',
  symbol: 'EUR',
  name: 'Euro',
  deleted: false,
);
const _btc = ldb.Asset(
  id: 'btc',
  kind: 'crypto',
  symbol: 'BTC',
  name: 'Bitcoin',
  deleted: false,
);

TransactionListGroupInput _input({
  required List<ldb.Transaction> rows,
  TransactionFilter filter = TransactionFilter.empty,
  DateTime? now,
}) => TransactionListGroupInput(
  rows: rows,
  filter: filter,
  containerNames: const {'holderA': 'Holder A', 'holderB': 'Holder B'},
  assetsById: const {'eur': _eur, 'btc': _btc},
  now: now ?? DateTime.utc(2026, 1, 20),
);

void main() {
  group('buildTransactionListItems', () {
    test('an empty (or fully filtered-out) input produces no items', () {
      expect(buildTransactionListItems(_input(rows: const [])), isEmpty);
    });

    test(
      'groups rows under one date header per calendar day, newest first',
      () {
        final rows = [
          _tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 18)),
          _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 20)),
        ];
        final items = buildTransactionListItems(_input(rows: rows));

        expect(items, hasLength(4));
        expect(items[0], isA<DateHeaderItem>());
        expect((items[0] as DateHeaderItem).label, equals('Today'));
        expect((items[1] as TransactionRowItem).id, equals('b'));
        expect(items[2], isA<DateHeaderItem>());
        expect((items[3] as TransactionRowItem).id, equals('a'));
      },
    );

    test('each date header carries the ids of its own rows only', () {
      final rows = [
        _tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 18)),
        _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 20)),
        _tx(id: 'c', effectiveDate: CalendarDate(2026, 1, 20)),
      ];
      final headers = buildTransactionListItems(
        _input(rows: rows),
      ).whereType<DateHeaderItem>().toList();
      expect(headers[0].rowIds.toSet(), equals({'b', 'c'}));
      expect(headers[1].rowIds, equals(['a']));
    });

    test('a day whose rows all have an unresolvable asset gets no header', () {
      final rows = [
        _tx(
          id: 'a',
          effectiveDate: CalendarDate(2026, 1, 18),
          legOutAssetId: 'gone',
        ),
        _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 20)),
      ];
      final items = buildTransactionListItems(_input(rows: rows));
      expect(items, hasLength(2));
      expect((items[1] as TransactionRowItem).id, equals('b'));
    });

    test('DateHeaderItem.selectionState is true / null / false', () {
      const header = DateHeaderItem('Today', ['a', 'b']);
      expect(header.selectionState({}), isFalse);
      expect(header.selectionState({'a'}), isNull);
      expect(header.selectionState({'a', 'b', 'z'}), isTrue);
      expect(const DateHeaderItem('Empty').selectionState({'a'}), isFalse);
    });

    test('"Yesterday" and a plain month/day label for older dates', () {
      final rows = [
        _tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 19)),
        _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 5)),
      ];
      final items = buildTransactionListItems(_input(rows: rows));
      final headers = items
          .whereType<DateHeaderItem>()
          .map((h) => h.label)
          .toList();
      expect(headers, equals(['Yesterday', 'Jan 5']));
    });

    test('applies the filter before grouping', () {
      final rows = [
        _tx(
          id: 'a',
          kind: TransactionKind.income,
          effectiveDate: CalendarDate(2026, 1, 20),
        ),
        _tx(
          id: 'b',
          kind: TransactionKind.holderTransfer,
          effectiveDate: CalendarDate(2026, 1, 20),
        ),
      ];
      final items = buildTransactionListItems(
        _input(
          rows: rows,
          filter: const TransactionFilter(kinds: {TransactionKind.income}),
        ),
      );
      final rowItems = items.whereType<TransactionRowItem>().toList();
      expect(rowItems, hasLength(1));
      expect(rowItems.single.id, equals('a'));
    });

    test('tags a same-day/same-kind cluster of size > 1 for reordering, '
        'but leaves a lone same-day row untagged', () {
      final rows = [
        _tx(
          id: 'a',
          kind: TransactionKind.holderTransfer,
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 9),
        ),
        _tx(
          id: 'b',
          kind: TransactionKind.holderTransfer,
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 10),
        ),
        _tx(
          id: 'c',
          kind: TransactionKind.income,
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 11),
        ),
      ];
      final rowItems = buildTransactionListItems(
        _input(rows: rows),
      ).whereType<TransactionRowItem>().toList();
      final byId = {for (final r in rowItems) r.id: r};

      expect(byId['a']!.reorderClusterSize, equals(2));
      expect(byId['b']!.reorderClusterSize, equals(2));
      expect(byId['a']!.reorderClusterId, equals(byId['b']!.reorderClusterId));
      expect(byId['c']!.reorderClusterSize, equals(1));
      expect(byId['c']!.reorderClusterId, isNull);
    });

    test('manualOrderRank overrides postedAt for same-day display order '
        'when they disagree', () {
      final rows = [
        _tx(
          id: 'a',
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 10),
          manualOrderRank: 1,
        ),
        _tx(
          id: 'b',
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 9),
          manualOrderRank: 2,
        ),
      ];
      final ids = buildTransactionListItems(
        _input(rows: rows),
      ).whereType<TransactionRowItem>().map((r) => r.id).toList();
      expect(ids, equals(['b', 'a']));
    });

    test('a never-manually-ordered row (default rank 0) sorts behind an '
        'explicitly ranked row in the same cluster, regardless of '
        'postedAt — e.g. a transaction added after the cluster was last '
        'reordered', () {
      final rows = [
        _tx(
          id: 'ranked',
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 1),
          manualOrderRank: 1,
        ),
        _tx(
          id: 'unranked',
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 23),
        ),
      ];
      final ids = buildTransactionListItems(
        _input(rows: rows),
      ).whereType<TransactionRowItem>().map((r) => r.id).toList();
      expect(ids, equals(['ranked', 'unranked']));
    });

    test('postedOnDifferentDay is true only when postedAt and effectiveDate '
        'fall on different calendar days', () {
      final rows = [
        _tx(
          id: 'a',
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 20, 23),
        ),
        _tx(
          id: 'b',
          effectiveDate: CalendarDate(2026, 1, 20),
          postedAt: DateTime.utc(2026, 1, 18),
        ),
      ];
      final byId = {
        for (final r in buildTransactionListItems(
          _input(rows: rows),
        ).whereType<TransactionRowItem>())
          r.id: r,
      };
      expect(byId['a']!.postedOnDifferentDay, isFalse);
      expect(byId['b']!.postedOnDifferentDay, isTrue);
    });

    test('the exact reported repro: a same-day trade that spends money a '
        'transfer just brought in shows above the transfer (newest-safe- '
        'first), even though the trade was recorded (postedAt) first', () {
      final day = CalendarDate(2026, 1, 3);
      final trade = _tx(
        id: 'trade',
        kind: TransactionKind.trade,
        effectiveDate: day,
        postedAt: day.toUtcDateTime().add(const Duration(hours: 8)),
        legOutContainerId: 'holderB',
        legOutAssetId: 'eur',
        legInContainerId: 'holderB',
        legInAssetId: 'shares',
      );
      final transfer = _tx(
        id: 'transfer',
        kind: TransactionKind.holderTransfer,
        effectiveDate: day,
        postedAt: day.toUtcDateTime().add(const Duration(hours: 9)),
        legOutContainerId: 'holderA',
        legInContainerId: 'holderB',
        legOutAssetId: 'eur',
        legInAssetId: 'eur',
      );
      final rowItems = buildTransactionListItems(
        _input(rows: [trade, transfer]),
      ).whereType<TransactionRowItem>().map((r) => r.id).toList();
      expect(rowItems, equals(['trade', 'transfer']));
    });

    test('carries the raw row through for screens to open for edit/copy', () {
      final rows = [_tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 20))];
      final rowItem = buildTransactionListItems(
        _input(rows: rows),
      ).whereType<TransactionRowItem>().single;
      expect(rowItem.row.id, equals('a'));
    });

    test('a trade row carries both the "give" (displayQuantity/Asset) and '
        '"get" (tradeQuantityIn/tradeAssetIn) sides — a trade used to only '
        'ever show its give side', () {
      final row = ldb.Transaction(
        id: 'trade',
        postedAt: DateTime.utc(2026, 1, 20),
        effectiveDate: CalendarDate(2026, 1, 20),
        kind: TransactionKind.trade.name,
        legOutContainerId: 'holderA',
        legOutAssetId: 'eur',
        legOutQuantity: '500',
        legInContainerId: 'holderA',
        legInAssetId: 'btc',
        legInQuantity: '0.0071',
        tags: '[]',
        manualOrderRank: 0,
        deleted: false,
      );
      final rowItem = buildTransactionListItems(
        _input(rows: [row]),
      ).whereType<TransactionRowItem>().single;

      expect(rowItem.displayQuantity.toString(), equals('500'));
      expect(rowItem.displayAsset.symbol, equals('EUR'));
      expect(rowItem.tradeQuantityIn.toString(), equals('0.0071'));
      expect(rowItem.tradeAssetIn?.symbol, equals('BTC'));
      expect(rowItem.isTwoAssetTrade, isTrue);
    });

    test('a trade whose "get" asset can\'t be resolved leaves the trade '
        'fields null rather than crashing (isTwoAssetTrade false)', () {
      final row = _tx(
        id: 'trade',
        kind: TransactionKind.trade,
        effectiveDate: CalendarDate(2026, 1, 20),
        legOutAssetId: 'eur',
        legInAssetId: 'unknown-asset',
      );
      final rowItem = buildTransactionListItems(
        _input(rows: [row]),
      ).whereType<TransactionRowItem>().single;

      expect(rowItem.tradeQuantityIn, isNull);
      expect(rowItem.tradeAssetIn, isNull);
      expect(rowItem.isTwoAssetTrade, isFalse);
    });

    test('a non-trade row never populates the trade fields even though its '
        'legIn asset is resolvable', () {
      final row = _tx(
        id: 'a',
        kind: TransactionKind.holderTransfer,
        effectiveDate: CalendarDate(2026, 1, 20),
      );
      final rowItem = buildTransactionListItems(
        _input(rows: [row]),
      ).whereType<TransactionRowItem>().single;

      expect(rowItem.tradeQuantityIn, isNull);
      expect(rowItem.tradeAssetIn, isNull);
      expect(rowItem.isTwoAssetTrade, isFalse);
    });
  });

  group('transfer groups', () {
    final day = CalendarDate(2026, 1, 18);
    ldb.Transaction bt(
      String id,
      String from,
      String to, {
      String quantity = '10',
      String asset = 'eur',
      TransactionKind kind = TransactionKind.budgetTransfer,
      CalendarDate? date,
      int rank = 0,
    }) => _tx(
      id: id,
      kind: kind,
      effectiveDate: date ?? day,
      legOutContainerId: from,
      legInContainerId: to,
      legOutAssetId: asset,
      legInAssetId: asset,
      quantity: quantity,
      manualOrderRank: rank,
    );

    List<TransactionListItem> build(List<ldb.Transaction> rows) =>
        buildTransactionListItems(_input(rows: rows));

    List<TransactionGroupItem> groupsOf(List<TransactionListItem> items) =>
        items.whereType<TransactionGroupItem>().toList();

    test('two transfers from the same source collapse into one group', () {
      final items = build([
        bt('a', 'inc', 'h', quantity: '30'),
        bt('b', 'inc', 's', quantity: '20'),
      ]);
      expect(items, hasLength(2));
      final g = items[1] as TransactionGroupItem;
      expect(g.total, equals(Decimal.parse('50')));
      expect(g.leafIds.toSet(), equals({'a', 'b'}));
      expect(g.destinations.map((d) => d.total), [
        Decimal.parse('30'),
        Decimal.parse('20'),
      ]);
      expect(g.children.whereType<TransactionRowItem>(), hasLength(2));
      expect(g.sourceContainerId, 'inc');
    });

    test('a lone transfer stays a plain row', () {
      final items = build([bt('a', 'inc', 'h')]);
      expect(items[1], isA<TransactionRowItem>());
      expect(groupsOf(items), isEmpty);
    });

    test('destinations to the same container are aggregated', () {
      final g = groupsOf(
        build([
          bt('a', 'inc', 'h', quantity: '5'),
          bt('b', 'inc', 'h', quantity: '7'),
        ]),
      ).single;
      expect(g.destinations, hasLength(1));
      expect(g.destinations.single.total, equals(Decimal.parse('12')));
    });

    test('destinations are sorted by total, largest first', () {
      final g = groupsOf(
        build([
          bt('a', 'inc', 'h', quantity: '5'),
          bt('b', 'inc', 's', quantity: '50'),
          bt('c', 'inc', 'h', quantity: '7'),
          bt('d', 'inc', 'r', quantity: '20'),
        ]),
      ).single;
      expect(g.destinations.map((d) => d.total), [
        Decimal.parse('50'),
        Decimal.parse('20'),
        Decimal.parse('12'),
      ]);
    });

    test('different sources do not merge', () {
      final items = build([bt('a', 'x', 'h'), bt('b', 'y', 'h')]);
      expect(groupsOf(items), isEmpty);
    });

    test('a different asset breaks the run', () {
      final items = build([
        bt('a', 'inc', 'h'),
        bt('b', 'inc', 's', asset: 'btc'),
      ]);
      expect(groupsOf(items), isEmpty);
    });

    test('rows on different days never share a group', () {
      final items = build([
        bt('a', 'inc', 'h'),
        bt('b', 'inc', 's', date: CalendarDate(2026, 1, 17)),
      ]);
      expect(groupsOf(items), isEmpty);
    });

    test('holder and budget transfers never merge', () {
      final items = build([
        bt('a', 'inc', 'h'),
        bt('b', 'inc', 's', kind: TransactionKind.holderTransfer),
      ]);
      expect(groupsOf(items), isEmpty);
    });

    test('holder transfers group too', () {
      final items = build([
        bt('a', 'bank', 'x', kind: TransactionKind.holderTransfer),
        bt('b', 'bank', 'y', kind: TransactionKind.holderTransfer),
      ]);
      expect(groupsOf(items).single.kind, TransactionKind.holderTransfer);
    });

    test(
      'a source that is another group\'s destination nests beneath it, without double-counting',
      () {
        final items = build([
          bt('a', 'inc', 'housing', quantity: '100'),
          bt('b', 'inc', 'invest', quantity: '50'),
          bt('c', 'housing', 'rent', quantity: '60'),
          bt('d', 'housing', 'utils', quantity: '40'),
        ]);
        final roots = groupsOf(items);
        expect(roots, hasLength(1));
        final root = roots.single;
        expect(root.sourceContainerId, 'inc');
        expect(root.total, equals(Decimal.parse('150')));
        expect(root.leafIds.toSet(), equals({'a', 'b', 'c', 'd'}));
        final nested = root.children.whereType<TransactionGroupItem>().single;
        expect(nested.sourceContainerId, 'housing');
        expect(nested.total, equals(Decimal.parse('100')));
        final idxFunding = root.children.indexWhere(
          (c) => c is TransactionRowItem && c.id == 'a',
        );
        expect(root.children[idxFunding + 1], same(nested));
      },
    );

    test('a nested group shares no id with its parent even when it holds '
        'the smallest leaf', () {
      final items = build([
        bt('c', 'inc', 'housing', quantity: '100'),
        bt('d', 'inc', 'invest', quantity: '50'),
        bt('a', 'housing', 'rent', quantity: '60'),
        bt('b', 'housing', 'utils', quantity: '40'),
      ]);
      final root = groupsOf(items).single;
      final nested = root.children.whereType<TransactionGroupItem>().single;
      expect(nested.id, isNot(root.id));
      final visible = visibleItems(items, {root.id});
      expect(visible, contains(same(nested)));
      expect(
        visible.whereType<TransactionRowItem>().map((r) => r.id),
        isNot(containsAll(['a', 'b'])),
      );
      final both = visibleItems(items, {root.id, nested.id});
      expect(
        both.whereType<TransactionRowItem>().map((r) => r.id),
        containsAll(['a', 'b']),
      );
    });

    test('a nested single transfer is a plain row child', () {
      final root = groupsOf(
        build([
          bt('a', 'inc', 'housing'),
          bt('b', 'inc', 'invest'),
          bt('c', 'housing', 'rent'),
        ]),
      ).single;
      expect(root.children.whereType<TransactionGroupItem>(), isEmpty);
      expect(root.children.whereType<TransactionRowItem>(), hasLength(3));
    });

    test('a cycle between sources terminates and still groups', () {
      final items = build([
        bt('a', 'x', 'y'),
        bt('b', 'x', 'z'),
        bt('c', 'y', 'x'),
      ]);
      final all = groupsOf(items);
      expect(all, isNotEmpty);
      final leaves = <String>{for (final g in all) ...g.leafIds};
      expect(leaves, equals({'a', 'b', 'c'}));
    });

    test('rows interleaved with another source still bucket by source', () {
      final items = build([
        bt('a', 'x', 'p', rank: 1),
        bt('b', 'y', 'q', rank: 2),
        bt('c', 'x', 'r', rank: 3),
      ]);
      final g = groupsOf(items).single;
      expect(g.sourceContainerId, 'x');
      expect(g.leafIds.toSet(), equals({'a', 'c'}));
    });

    test(
      'group selectionState is tri-state over its leaves; day header still lists every leaf',
      () {
        final items = build([bt('a', 'inc', 'h'), bt('b', 'inc', 's')]);
        final g = items[1] as TransactionGroupItem;
        expect(g.selectionState({}), isFalse);
        expect(g.selectionState({'a'}), isNull);
        expect(g.selectionState({'a', 'b'}), isTrue);
        expect((items[0] as DateHeaderItem).rowIds.toSet(), equals({'a', 'b'}));
      },
    );
  });

  group('Now marker', () {
    List<String> shape(List<TransactionListItem> items) => [
      for (final i in items)
        switch (i) {
          NowMarkerItem() => 'now',
          DateHeaderItem() => 'header',
          TransactionRowItem(:final id) => id,
          TransactionGroupItem(:final id) => 'group:$id',
        },
    ];

    test('sits between the last future day and today, newest first', () {
      final items = buildTransactionListItems(
        _input(
          rows: [
            _tx(id: 'past', effectiveDate: CalendarDate(2026, 1, 18)),
            _tx(id: 'today', effectiveDate: CalendarDate(2026, 1, 20)),
            _tx(id: 'tomorrow', effectiveDate: CalendarDate(2026, 1, 21)),
            _tx(id: 'later', effectiveDate: CalendarDate(2026, 3, 1)),
          ],
        ),
      );
      expect(shape(items), [
        'header',
        'later',
        'header',
        'tomorrow',
        'now',
        'header',
        'today',
        'header',
        'past',
      ]);
    });

    test('is a single marker even with many future days', () {
      final items = buildTransactionListItems(
        _input(
          rows: [
            for (var d = 21; d < 26; d++)
              _tx(id: 'f$d', effectiveDate: CalendarDate(2026, 1, d)),
            _tx(id: 'p', effectiveDate: CalendarDate(2026, 1, 1)),
          ],
        ),
      );
      expect(items.whereType<NowMarkerItem>(), hasLength(1));
    });

    test('is absent when there is nothing in the future', () {
      final items = buildTransactionListItems(
        _input(
          rows: [_tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 20))],
        ),
      );
      expect(items.whereType<NowMarkerItem>(), isEmpty);
    });

    test('is absent when everything is in the future', () {
      final items = buildTransactionListItems(
        _input(
          rows: [_tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 21))],
        ),
      );
      expect(items.whereType<NowMarkerItem>(), isEmpty);
    });

    test('is absent for an empty list and follows the active filter', () {
      expect(buildTransactionListItems(_input(rows: const [])), isEmpty);
      final rows = [
        _tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 21)),
        _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 19)),
      ];
      final future = buildTransactionListItems(
        _input(
          rows: rows,
          filter: const TransactionFilter(dateScope: DateScope.future),
        ),
      );
      expect(future.whereType<NowMarkerItem>(), isEmpty);
    });

    test(
      'is not part of any date header\'s row ids, and indexOfNowMarker finds it',
      () {
        final items = buildTransactionListItems(
          _input(
            rows: [
              _tx(id: 'a', effectiveDate: CalendarDate(2026, 1, 21)),
              _tx(id: 'b', effectiveDate: CalendarDate(2026, 1, 20)),
            ],
          ),
        );
        final ids = items
            .whereType<DateHeaderItem>()
            .expand((h) => h.rowIds)
            .toList();
        expect(ids, ['a', 'b']);
        expect(indexOfNowMarker(items), 2);
        expect(indexOfNowMarker(const []), -1);
      },
    );

    test('offsetOfItem sums the heights of the preceding items', () {
      final items = <TransactionListItem>[
        const DateHeaderItem('h'),
        const NowMarkerItem(),
        const DateHeaderItem('h2'),
      ];
      double heightOf(TransactionListItem i) => i is NowMarkerItem ? 32 : 40;
      expect(offsetOfItem(items, 0, heightOf), 0);
      expect(offsetOfItem(items, 1, heightOf), 40);
      expect(offsetOfItem(items, 2, heightOf), 72);
    });
  });

  group('calendar-date grouping', () {
    test('rows on the same calendar day group together whatever time of day '
        'they were created', () {
      final items = buildTransactionListItems(
        _input(
          rows: [
            _tx(
              id: 'early',
              effectiveDate: CalendarDate(2026, 1, 10),
              postedAt: DateTime(2026, 1, 9, 8, 15),
            ),
            _tx(
              id: 'late',
              effectiveDate: CalendarDate(2026, 1, 10),
              postedAt: DateTime(2026, 1, 11, 23, 45),
            ),
          ],
        ),
      );

      expect(items.whereType<DateHeaderItem>(), hasLength(1));
      final rows = items.whereType<TransactionRowItem>().toList();
      expect(rows, hasLength(2));
      expect(
        rows.every((r) => r.reorderClusterSize == 2),
        isTrue,
        reason: 'same day + same kind forms one reorder cluster',
      );
    });

    test('a row posted on a different day than it takes effect is flagged', () {
      final items = buildTransactionListItems(
        _input(
          rows: [
            _tx(
              id: 'backdated',
              effectiveDate: CalendarDate(2026, 1, 10),
              postedAt: DateTime(2026, 1, 12, 9),
            ),
            _tx(
              id: 'same',
              effectiveDate: CalendarDate(2026, 1, 11),
              postedAt: DateTime(2026, 1, 11, 9),
            ),
          ],
        ),
      );
      final byId = {
        for (final r in items.whereType<TransactionRowItem>()) r.id: r,
      };
      expect(byId['backdated']!.postedOnDifferentDay, isTrue);
      expect(byId['same']!.postedOnDifferentDay, isFalse);
    });
  });
}
