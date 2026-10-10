import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/selection_range.dart';
import 'package:moopro/domain/transaction_list_grouping.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/widgets/amount_text.dart' show AmountSign;
import 'package:moopro/domain/calendar_date.dart';

TransactionRowItem _row(String id) => TransactionRowItem(
  row: ldb.Transaction(
    id: id,
    postedAt: DateTime(2026, 1, 1),
    effectiveDate: CalendarDate(2026, 1, 1),
    kind: 'income',
    legOutContainerId: 'a',
    legOutAssetId: 'eur',
    legOutQuantity: '1',
    legInContainerId: 'b',
    legInAssetId: 'eur',
    legInQuantity: '1',
    tags: '[]',
    manualOrderRank: 0,
    deleted: false,
  ),
  id: id,
  effectiveDate: CalendarDate(2026, 1, 1),
  postedAt: DateTime(2026, 1, 1),
  title: id,
  displayQuantity: Decimal.one,
  displayAsset: Asset.fromJson('eur', {
    'kind': 'fiat',
    'symbol': 'EUR',
    'name': 'Euro',
  }),
  sign: AmountSign.positive,
  kind: TransactionKind.income,
  tags: const [],
  reorderClusterSize: 1,
);

void main() {
  final items = <TransactionListItem>[
    const DateHeaderItem('Today', ['a', 'b']),
    _row('a'),
    _row('b'),
    const DateHeaderItem('Yesterday', ['c', 'd']),
    _row('c'),
    _row('d'),
  ];

  group('rangeSelection', () {
    test('selects every row in the range, skipping date headers', () {
      final r = rangeSelection(
        items: items,
        anchorIndex: 2,
        currentIndex: 4,
        baseline: {},
        select: true,
      );
      expect(r, {'b', 'c'});
    });

    test('works in either direction', () {
      final down = rangeSelection(
        items: items,
        anchorIndex: 1,
        currentIndex: 5,
        baseline: {},
        select: true,
      );
      final up = rangeSelection(
        items: items,
        anchorIndex: 5,
        currentIndex: 1,
        baseline: {},
        select: true,
      );
      expect(down, {'a', 'b', 'c', 'd'});
      expect(up, down);
    });

    test('keeps the baseline and adds to it', () {
      final r = rangeSelection(
        items: items,
        anchorIndex: 4,
        currentIndex: 5,
        baseline: {'a'},
        select: true,
      );
      expect(r, {'a', 'c', 'd'});
    });

    test('deselect mode removes only rows in the range', () {
      final r = rangeSelection(
        items: items,
        anchorIndex: 1,
        currentIndex: 2,
        baseline: {'a', 'b', 'c'},
        select: false,
      );
      expect(r, {'c'});
    });

    test('dragging back toward the anchor restores rows left behind', () {
      Set<String> at(int i) => rangeSelection(
        items: items,
        anchorIndex: 1,
        currentIndex: i,
        baseline: {},
        select: true,
      );
      expect(at(5), {'a', 'b', 'c', 'd'});
      expect(at(2), {'a', 'b'});
      expect(at(1), {'a'});
    });

    test('out-of-range indices are clamped; an empty list is a no-op', () {
      expect(
        rangeSelection(
          items: items,
          anchorIndex: 4,
          currentIndex: 99,
          baseline: {},
          select: true,
        ),
        {'c', 'd'},
      );
      expect(
        rangeSelection(
          items: const [],
          anchorIndex: 0,
          currentIndex: 3,
          baseline: {'x'},
          select: true,
        ),
        {'x'},
      );
    });
  });

  group('ListGeometry', () {
    final geometry = ListGeometry.of(
      items,
      (i) => i is DateHeaderItem ? 40 : 60,
    );

    test('maps a y offset to the item containing it', () {
      expect(geometry.indexAt(0), 0);
      expect(geometry.indexAt(39.9), 0);
      expect(geometry.indexAt(40), 1);
      expect(geometry.indexAt(159), 2);
      expect(geometry.indexAt(160), 3);
      expect(geometry.indexAt(319), 5);
    });

    test('clamps above and below the content', () {
      expect(geometry.indexAt(-50), 0);
      expect(geometry.indexAt(5000), 5);
      expect(geometry.totalHeight, 320);
    });

    test('an empty list has no index', () {
      expect(ListGeometry.of(const [], (_) => 10).indexAt(5), -1);
    });
  });

  test('indexOfRow finds a row by id, or -1', () {
    expect(indexOfRow(items, 'c'), 4);
    expect(indexOfRow(items, 'zzz'), -1);
  });

  group('with a transfer group', () {
    final eur = Asset.fromJson('eur', {
      'kind': 'fiat',
      'symbol': 'EUR',
      'name': 'Euro',
    });
    final group = TransactionGroupItem(
      id: 'x',
      kind: TransactionKind.budgetTransfer,
      asset: eur,
      sourceContainerId: 's',
      sourceName: 'S',
      total: Decimal.fromInt(2),
      destinations: const [],
      children: [_row('x'), _row('y')],
      leafIds: const ['x', 'y'],
    );
    final withGroup = <TransactionListItem>[
      const DateHeaderItem('Today', ['a', 'x', 'y', 'b']),
      _row('a'),
      group,
      _row('b'),
    ];

    test('a range covering the group selects all of its rows', () {
      final result = rangeSelection(
        items: withGroup,
        anchorIndex: 1,
        currentIndex: 3,
        baseline: {},
        select: true,
      );
      expect(result, {'a', 'x', 'y', 'b'});
    });

    test('deselecting over a group removes all of its rows', () {
      final result = rangeSelection(
        items: withGroup,
        anchorIndex: 2,
        currentIndex: 2,
        baseline: {'a', 'x', 'y'},
        select: false,
      );
      expect(result, {'a'});
    });

    test('indexOfRow finds the group containing a nested row', () {
      expect(indexOfRow(withGroup, 'y'), 2);
      expect(indexOfRow(withGroup, 'b'), 3);
      expect(indexOfRow(withGroup, 'nope'), -1);
    });

    test('visibleItems splices children in only for expanded groups', () {
      List<String> ids(List<TransactionListItem> l) => [
        for (final i in l)
          i is TransactionRowItem
              ? i.id
              : i is TransactionGroupItem
              ? 'G${i.id}'
              : 'H',
      ];
      expect(ids(visibleItems(withGroup, const {})), ['H', 'a', 'Gx', 'b']);
      expect(ids(visibleItems(withGroup, const {'x'})), [
        'H',
        'a',
        'Gx',
        'x',
        'y',
        'b',
      ]);
    });

    test('selectableIds covers a collapsed group via its leaves', () {
      expect(selectableIds(visibleItems(withGroup, const {})), {
        'a',
        'x',
        'y',
        'b',
      });
    });
  });
}
