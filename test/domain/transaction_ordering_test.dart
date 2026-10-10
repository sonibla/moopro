import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/transaction_ordering.dart';

typedef K = ({String id, String kind, int manualOrderRank, DateTime postedAt});

typedef _Node = ({
  String id,
  List<String> provides,
  List<String> requires,
  DateTime postedAt,
  int rank,
});

_Node _node(
  String id, {
  List<String> provides = const [],
  List<String> requires = const [],
  required DateTime postedAt,
  int rank = 0,
}) => (
  id: id,
  provides: provides,
  requires: requires,
  postedAt: postedAt,
  rank: rank,
);

List<String> _ids(List<_Node> nodes) => nodes.map((n) => n.id).toList();

void main() {
  group('sameDaySafeOrder', () {
    List<_Node> order(List<_Node> nodes) => sameDaySafeOrder(
      nodes,
      providedPairs: (n) => n.provides,
      requiredPairs: (n) => n.requires,
      tieBreakCompare: (a, b) {
        final r = a.rank.compareTo(b.rank);
        return r != 0 ? r : a.postedAt.compareTo(b.postedAt);
      },
    );

    test('empty/singleton input is returned as-is', () {
      expect(order(const []), isEmpty);
      final single = [_node('a', postedAt: DateTime.utc(2026, 1, 1))];
      expect(order(single), equals(single));
    });

    test('unrelated transactions keep postedAt order', () {
      final nodes = [
        _node('later', postedAt: DateTime.utc(2026, 1, 1, 10)),
        _node('earlier', postedAt: DateTime.utc(2026, 1, 1, 9)),
      ];
      expect(_ids(order(nodes)), equals(['earlier', 'later']));
    });

    test('the exact reported repro: a transfer that funds a trade sorts '
        'before it, regardless of postedAt recording order', () {
      final trade = _node(
        'trade',
        requires: ['bank2|eur'],
        provides: ['bank2|shares'],
        postedAt: DateTime.utc(2026, 1, 3, 8),
      );
      final transfer = _node(
        'transfer',
        requires: ['bank1|eur'],
        provides: ['bank2|eur'],
        postedAt: DateTime.utc(2026, 1, 3, 9),
      );
      expect(_ids(order([trade, transfer])), equals(['transfer', 'trade']));
    });

    test('a sell trade (providing cash) funds a same-day expense', () {
      final sell = _node(
        'sell',
        requires: ['broker|shares'],
        provides: ['broker|eur'],
        postedAt: DateTime.utc(2026, 1, 3, 12),
      );
      final expense = _node(
        'expense',
        requires: ['broker|eur'],
        provides: ['external|eur'],
        postedAt: DateTime.utc(2026, 1, 3, 8),
      );
      expect(_ids(order([expense, sell])), equals(['sell', 'expense']));
    });

    test('a required pair with no same-day provider is unconstrained, '
        'regardless of postedAt', () {
      final income = _node(
        'income',
        requires: ['external|eur'],
        provides: ['bank1|eur'],
        postedAt: DateTime.utc(2026, 1, 3, 23),
      );
      final expense = _node(
        'expense',
        requires: ['bank1|eur'],
        provides: ['budgetA|eur'],
        postedAt: DateTime.utc(2026, 1, 3, 1),
      );
      expect(_ids(order([expense, income])), equals(['income', 'expense']));
    });

    test(
      'a multi-hop same-day chain orders transitively (A funds B funds C)',
      () {
        final c = _node(
          'c',
          requires: ['pair2'],
          postedAt: DateTime.utc(2026, 1, 3, 3),
        );
        final a = _node(
          'a',
          provides: ['pair1'],
          postedAt: DateTime.utc(2026, 1, 3, 1),
        );
        final b = _node(
          'b',
          requires: ['pair1'],
          provides: ['pair2'],
          postedAt: DateTime.utc(2026, 1, 3, 2),
        );
        expect(_ids(order([c, a, b])), equals(['a', 'b', 'c']));
      },
    );

    test('a same-day funding cycle falls back to postedAt instead of looping '
        'forever', () {
      final x = _node(
        'x',
        requires: ['pairY'],
        provides: ['pairX'],
        postedAt: DateTime.utc(2026, 1, 3, 2),
      );
      final y = _node(
        'y',
        requires: ['pairX'],
        provides: ['pairY'],
        postedAt: DateTime.utc(2026, 1, 3, 1),
      );
      expect(_ids(order([x, y])), equals(['y', 'x']));
    });

    test('an explicit rank overrides postedAt order when it disagrees with '
        'it, for two otherwise-unrelated transactions', () {
      final earlyRank = _node(
        'earlyRank',
        postedAt: DateTime.utc(2026, 1, 3, 23),
        rank: 1,
      );
      final lateRank = _node(
        'lateRank',
        postedAt: DateTime.utc(2026, 1, 3, 1),
        rank: 2,
      );
      expect(
        _ids(order([lateRank, earlyRank])),
        equals(['earlyRank', 'lateRank']),
      );
    });

    test('equal (default) rank falls back to postedAt — unranked '
        'transactions are unaffected by the rank tiebreak', () {
      final nodes = [
        _node('later', postedAt: DateTime.utc(2026, 1, 1, 10)),
        _node('earlier', postedAt: DateTime.utc(2026, 1, 1, 9)),
      ];
      expect(_ids(order(nodes)), equals(['earlier', 'later']));
    });

    test('a never-manually-ordered transaction (default rank 0) sorts '
        'ahead of a manually-ranked one, regardless of postedAt — this is '
        'the "newly added to an already-ordered cluster" case', () {
      final unranked = _node(
        'unranked',
        postedAt: DateTime.utc(2026, 1, 3, 23),
      );
      final ranked = _node(
        'ranked',
        postedAt: DateTime.utc(2026, 1, 3, 1),
        rank: 1,
      );
      expect(_ids(order([ranked, unranked])), equals(['unranked', 'ranked']));
    });
  });

  group('compareSameDayTiebreak', () {
    K k(String kind, {int rank = 0, int minute = 0, String id = ''}) => (
      id: id,
      kind: kind,
      manualOrderRank: rank,
      postedAt: DateTime.utc(2026, 1, 1, 0, minute),
    );

    test('groups by kind before postedAt', () {
      final list = [
        k('budgetTransfer', minute: 1),
        k('expense', minute: 2),
        k('budgetTransfer', minute: 3),
        k('income', minute: 4),
      ]..sort(compareSameDayTiebreak);
      expect(list.map((e) => e.kind), [
        'income',
        'expense',
        'budgetTransfer',
        'budgetTransfer',
      ]);
    });

    test('manual rank only matters within a kind', () {
      final list = [
        k('expense', rank: 9),
        k('income', rank: 99),
        k('expense', rank: 1),
      ]..sort(compareSameDayTiebreak);
      expect(list.map((e) => (e.kind, e.manualOrderRank)), [
        ('income', 99),
        ('expense', 1),
        ('expense', 9),
      ]);
    });

    test('identical kind/rank/postedAt falls back to id, whatever the input '
        'order', () {
      final forward = [k('expense', id: 'a'), k('expense', id: 'b')]
        ..sort(compareSameDayTiebreak);
      final backward = [k('expense', id: 'b'), k('expense', id: 'a')]
        ..sort(compareSameDayTiebreak);
      expect(forward.map((e) => e.id), ['a', 'b']);
      expect(backward.map((e) => e.id), ['a', 'b']);
    });

    test('a funding edge still beats kind', () {
      final t = DateTime.utc(2026, 1, 1);
      final nodes = [
        (
          id: 'expense',
          kind: 'expense',
          provides: <String>[],
          requires: ['b|eur'],
        ),
        (
          id: 'bt',
          kind: 'budgetTransfer',
          provides: ['b|eur'],
          requires: <String>[],
        ),
      ];
      final ordered = sameDaySafeOrder(
        nodes,
        providedPairs: (n) => n.provides,
        requiredPairs: (n) => n.requires,
        tieBreakCompare: (a, b) => compareSameDayTiebreak(
          (id: a.id, kind: a.kind, manualOrderRank: 0, postedAt: t),
          (id: b.id, kind: b.kind, manualOrderRank: 0, postedAt: t),
        ),
      );
      expect(ordered.map((n) => n.id), ['bt', 'expense']);
    });

    test('a funding edge never splits a same-kind run', () {
      final t = DateTime.utc(2026, 1, 1);
      final nodes = [
        (
          id: 'bt1',
          kind: 'budgetTransfer',
          provides: ['b|eur'],
          requires: ['a|eur'],
        ),
        (
          id: 'bt2',
          kind: 'budgetTransfer',
          provides: ['c|eur'],
          requires: ['b|eur'],
        ),
        (
          id: 'bt3',
          kind: 'budgetTransfer',
          provides: ['d|eur'],
          requires: <String>[],
        ),
        (id: 'exp', kind: 'expense', provides: <String>[], requires: ['b|eur']),
      ];
      final ordered = sameDaySafeOrder(
        nodes,
        providedPairs: (n) => n.provides,
        requiredPairs: (n) => n.requires,
        groupOf: (n) => n.kind,
        tieBreakCompare: (a, b) => compareSameDayTiebreak(
          (id: a.id, kind: a.kind, manualOrderRank: 0, postedAt: t),
          (id: b.id, kind: b.kind, manualOrderRank: 0, postedAt: t),
        ),
      );
      expect(ordered.map((n) => n.id), ['bt1', 'bt2', 'bt3', 'exp']);
    });
  });
}
