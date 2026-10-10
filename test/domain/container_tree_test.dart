import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/container_tree.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/calendar_date.dart';

ldb.Container _container(
  String id, {
  String? parentId,
  String type = 'budget',
  String? name,
  String? icon,
}) => ldb.Container(
  id: id,
  name: name ?? id,
  containerType: type,
  parentId: parentId,
  icon: icon,
  deleted: false,
);

ldb.Transaction _tx(
  String id, {
  required DateTime postedAt,
  String legOut = externalHolderContainerId,
  String legIn = externalHolderContainerId,
  String? budgetLegOut,
  String? budgetLegIn,
}) => ldb.Transaction(
  id: id,
  postedAt: postedAt,
  effectiveDate: CalendarDate.fromDateTime(postedAt),
  kind: 'income',
  legOutContainerId: legOut,
  legOutAssetId: 'eur',
  legOutQuantity: '1',
  legInContainerId: legIn,
  legInAssetId: 'eur',
  legInQuantity: '1',
  budgetLegOutContainerId: budgetLegOut,
  budgetLegOutAssetId: budgetLegOut == null ? null : 'eur',
  budgetLegOutQuantity: budgetLegOut == null ? null : '1',
  budgetLegInContainerId: budgetLegIn,
  budgetLegInAssetId: budgetLegIn == null ? null : 'eur',
  budgetLegInQuantity: budgetLegIn == null ? null : '1',
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

void main() {
  group('buildPieTree', () {
    test(
      'carries each container\'s icon key onto its node, at every depth',
      () {
        final containers = [
          _container('parent', icon: 'fa:solidHouse'),
          _container('child', parentId: 'parent', icon: 'bank:n26'),
          _container('plain'),
        ];
        final tree = buildPieTree(containers, {
          'child': Decimal.one,
          'plain': Decimal.one,
        }, null);
        final parent = tree.singleWhere((n) => n.id == 'parent');
        expect(parent.icon, 'fa:solidHouse');
        expect(parent.children.single.icon, 'bank:n26');
        expect(tree.singleWhere((n) => n.id == 'plain').icon, isNull);
      },
    );

    test('builds a multi-level tree with subtree-rolled-up values', () {
      final containers = [
        _container('root'),
        _container('child', parentId: 'root'),
        _container('grandchild', parentId: 'child'),
      ];
      final balances = {
        'root': Decimal.fromInt(10),
        'child': Decimal.fromInt(20),
        'grandchild': Decimal.fromInt(5),
      };

      final tree = buildPieTree(containers, balances, null);

      expect(tree, hasLength(1));
      final root = tree.single;
      expect(root.id, 'root');
      expect(root.value, 35);
      expect(root.children, hasLength(1));

      final child = root.children.single;
      expect(child.id, 'child');
      expect(child.value, 25);
      expect(child.children, hasLength(1));

      final grandchild = child.children.single;
      expect(grandchild.id, 'grandchild');
      expect(grandchild.value, 5);
      expect(grandchild.children, isEmpty);
    });

    test('builds independent subtrees for multiple top-level roots', () {
      final containers = [
        _container('a'),
        _container('b'),
        _container('a-child', parentId: 'a'),
      ];
      final balances = {
        'a': Decimal.fromInt(1),
        'b': Decimal.fromInt(2),
        'a-child': Decimal.fromInt(3),
      };

      final tree = buildPieTree(containers, balances, null);

      expect(tree.map((n) => n.id), containsAll(['a', 'b']));
      final a = tree.firstWhere((n) => n.id == 'a');
      final b = tree.firstWhere((n) => n.id == 'b');
      expect(a.value, 4);
      expect(a.children.single.id, 'a-child');
      expect(b.value, 2);
      expect(b.children, isEmpty);
    });

    test('missing balances default to zero', () {
      final containers = [_container('lonely')];
      final tree = buildPieTree(containers, const {}, null);
      expect(tree.single.value, 0);
    });

    test('a negative-balance child never nets down its parent\'s value — '
        'debt is tracked separately in debtValue, positive value stays '
        'the gross positive total', () {
      final containers = [
        _container('housing'),
        _container('credit', parentId: 'housing'),
        _container('taxes', parentId: 'housing'),
        _container('loan', parentId: 'housing'),
      ];
      final balances = {
        'housing': Decimal.zero,
        'credit': Decimal.fromInt(2400),
        'taxes': Decimal.fromInt(1200),
        'loan': Decimal.fromInt(-1550),
      };

      final tree = buildPieTree(containers, balances, null);
      final housing = tree.single;

      expect(housing.value, 3600);
      expect(housing.debtValue, -1550);
      expect(housing.hasDebt, isTrue);

      final loan = housing.children.firstWhere((n) => n.id == 'loan');
      expect(loan.value, 0);
      expect(loan.debtValue, -1550);
      expect(loan.hasDebt, isTrue);

      final credit = housing.children.firstWhere((n) => n.id == 'credit');
      expect(credit.value, 2400);
      expect(credit.hasDebt, isFalse);
    });

    test('debt several levels deep still rolls all the way up to the root '
        'node\'s debtValue, undiminished', () {
      final containers = [
        _container('root'),
        _container('mid', parentId: 'root'),
        _container('leaf', parentId: 'mid'),
      ];
      final balances = {
        'root': Decimal.fromInt(100),
        'mid': Decimal.zero,
        'leaf': Decimal.fromInt(-40),
      };

      final tree = buildPieTree(containers, balances, null);
      final root = tree.single;

      expect(root.value, 100);
      expect(root.debtValue, -40);
      final mid = root.children.single;
      expect(mid.value, 0);
      expect(mid.debtValue, -40);
      expect(mid.hasDebt, isTrue);
    });

    test(
      'builds a flat list directly for non-nesting containers (holder style)',
      () {
        final holders = [
          PieTreeNode(id: 'h1', label: 'Bank', value: 100),
          PieTreeNode(id: 'h2', label: 'Broker', value: 200),
        ];
        expect(holders.every((h) => h.children.isEmpty), isTrue);
      },
    );

    test('with a separate ownDebtBalances map (multi-asset rollup): '
        'a container\'s positive and debt contributions are never netted '
        'against each other, even though they come from the same '
        'container id', () {
      final containers = [
        _container('housing'),
        _container('mixed', parentId: 'housing'),
      ];
      final ownPositive = {'mixed': Decimal.fromInt(1000)};
      final ownDebt = {'mixed': Decimal.fromInt(-200)};

      final tree = buildPieTree(
        containers,
        ownPositive,
        null,
        ownDebtBalances: ownDebt,
      );
      final housing = tree.single;
      final mixed = housing.children.single;

      expect(mixed.value, 1000);
      expect(mixed.debtValue, -200);
      expect(housing.value, 1000);
      expect(housing.debtValue, -200);
    });

    test(
      'omitting ownDebtBalances falls back to the single-map behavior '
      '(reads the debt side from the same ownBalances map passed for '
      'the positive side) — today\'s single-asset callers are unaffected',
      () {
        final containers = [_container('a')];
        final balances = {'a': Decimal.fromInt(-50)};
        final tree = buildPieTree(containers, balances, null);
        expect(tree.single.value, 0);
        expect(tree.single.debtValue, -50);
      },
    );

    test('hasUnconvertible is false by default and true only for a '
        'container in the provided set', () {
      final containers = [
        _container('a'),
        _container('b'),
        _container('a-child', parentId: 'a'),
      ];
      final balances = {
        'a': Decimal.zero,
        'b': Decimal.zero,
        'a-child': Decimal.zero,
      };
      final tree = buildPieTree(
        containers,
        balances,
        null,
        containersWithUnconvertible: {'a', 'a-child'},
      );

      final a = tree.firstWhere((n) => n.id == 'a');
      final b = tree.firstWhere((n) => n.id == 'b');
      expect(a.hasUnconvertible, isTrue);
      expect(b.hasUnconvertible, isFalse);
      expect(a.children.single.hasUnconvertible, isTrue);
    });

    test('hasUnconvertible defaults to false everywhere when the set is '
        'omitted', () {
      final containers = [_container('a')];
      final tree = buildPieTree(containers, const {}, null);
      expect(tree.single.hasUnconvertible, isFalse);
    });
  });

  group('ancestorIds', () {
    test('a top-level container is just itself', () {
      final containers = [_container('root')];
      expect(ancestorIds('root', containers), {'root'});
    });

    test('includes every ancestor up to the top-level root', () {
      final containers = [
        _container('root'),
        _container('mid', parentId: 'root'),
        _container('leaf', parentId: 'mid'),
      ];
      expect(ancestorIds('leaf', containers), {'leaf', 'mid', 'root'});
    });

    test('an unknown id degrades to just itself rather than throwing', () {
      expect(ancestorIds('missing', const []), {'missing'});
    });

    test('a cyclic parentId chain terminates instead of looping forever', () {
      final containers = [
        _container('a', parentId: 'b'),
        _container('b', parentId: 'a'),
      ];
      expect(ancestorIds('a', containers), {'a', 'b'});
    });
  });

  group('subtreePositiveValue / subtreeDebtValue', () {
    test('positive value sums only positive own-balances in the subtree', () {
      final containers = [
        _container('a'),
        _container('b', parentId: 'a'),
        _container('c', parentId: 'a'),
      ];
      final balances = {
        'a': Decimal.fromInt(5),
        'b': Decimal.fromInt(-3),
        'c': Decimal.fromInt(10),
      };
      expect(
        subtreePositiveValue('a', containers, balances),
        Decimal.fromInt(15),
      );
      expect(subtreeDebtValue('a', containers, balances), Decimal.fromInt(-3));
    });

    test(
      'a container with no negative balances anywhere has debtValue zero',
      () {
        final containers = [_container('a'), _container('b', parentId: 'a')];
        final balances = {'a': Decimal.fromInt(1), 'b': Decimal.fromInt(2)};
        expect(subtreeDebtValue('a', containers, balances), Decimal.zero);
      },
    );

    test('missing balances contribute zero to both totals', () {
      final containers = [_container('lonely')];
      expect(
        subtreePositiveValue('lonely', containers, const {}),
        Decimal.zero,
      );
      expect(subtreeDebtValue('lonely', containers, const {}), Decimal.zero);
    });
  });

  group('flattenContainerTree', () {
    test('depth-first, alphabetical siblings, correct depth per row', () {
      final containers = [
        _container('b', name: 'Bravo'),
        _container('a', name: 'Alpha'),
        _container('a-child', parentId: 'a', name: 'Child'),
        _container('a-grandchild', parentId: 'a-child', name: 'Grandchild'),
      ];

      final rows = flattenContainerTree(containers);

      expect(rows.map((r) => r.container.id), [
        'a',
        'a-child',
        'a-grandchild',
        'b',
      ]);
      expect(rows.map((r) => r.depth), [0, 1, 2, 0]);
    });

    test('holders (flat, no nesting) come back as one depth-0 row each', () {
      final holders = [
        _container('h1', type: 'holder', name: 'Bank'),
        _container('h2', type: 'holder', name: 'Broker'),
      ];
      final rows = flattenContainerTree(holders);
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.depth == 0), isTrue);
    });
  });

  group('breadcrumbPath', () {
    test('joins ancestors down to the container itself with " › "', () {
      final containers = [
        _container('root', name: 'Root'),
        _container('mid', parentId: 'root', name: 'Mid'),
        _container('leaf', parentId: 'mid', name: 'Leaf'),
      ];
      expect(breadcrumbPath('leaf', containers), 'Root › Mid › Leaf');
    });

    test('a top-level container is just its own name', () {
      final containers = [_container('root', name: 'Root')];
      expect(breadcrumbPath('root', containers), 'Root');
    });

    test('an unknown id degrades to an empty path rather than throwing', () {
      expect(breadcrumbPath('missing', const []), '');
    });
  });

  group('recentContainerIds', () {
    test('newest-first, deduplicated, capped at limit', () {
      final containers = [
        _container('h1', type: 'holder'),
        _container('h2', type: 'holder'),
        _container('h3', type: 'holder'),
      ];
      final txs = [
        _tx('t1', postedAt: DateTime(2026, 1, 1), legOut: 'h1'),
        _tx('t2', postedAt: DateTime(2026, 1, 3), legOut: 'h2'),
        _tx('t3', postedAt: DateTime(2026, 1, 2), legOut: 'h1'),
        _tx('t4', postedAt: DateTime(2026, 1, 4), legOut: 'h3'),
      ];

      final recent = recentContainerIds(
        txs,
        containers,
        ContainerType.holder,
        limit: 2,
      );

      expect(recent, ['h3', 'h2']);
    });

    test('excludes sentinels and containers of the wrong type', () {
      final containers = [
        _container('h1', type: 'holder'),
        _container('b1', type: 'budget'),
      ];
      final txs = [
        _tx(
          't1',
          postedAt: DateTime(2026, 1, 1),
          legOut: 'h1',
          budgetLegOut: 'b1',
        ),
      ];

      expect(recentContainerIds(txs, containers, ContainerType.holder), ['h1']);
      expect(recentContainerIds(txs, containers, ContainerType.budget), ['b1']);
    });
  });
}
