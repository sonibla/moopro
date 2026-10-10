import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moopro/domain/container_tree.dart';
import 'package:moopro/domain/multi_asset_rollup.dart';
import 'package:moopro/widgets/pie_chart_card.dart';

const _outerRadius = 100.0;

List<PieTreeNode> _twoLevelTree() => const [
  PieTreeNode(
    id: 'groceries',
    label: 'Groceries',
    value: 30,
    children: [
      PieTreeNode(id: 'meat', label: 'Meat', value: 10),
      PieTreeNode(id: 'veg', label: 'Veg', value: 20),
    ],
  ),
  PieTreeNode(id: 'rent', label: 'Rent', value: 70),
];

Offset _midpointOf(PieWedge w, Offset center) {
  final midAngle = -(w.startAngle + w.sweepAngle / 2);
  final midRadius = (w.innerRadius + w.outerRadius) / 2;
  return center + Offset(cos(midAngle), sin(midAngle)) * midRadius;
}

void main() {
  group('pieAncestorPath', () {
    test('finds a nested node and returns the full ancestor path', () {
      final path = pieAncestorPath(_twoLevelTree(), 'meat');
      expect(path, isNotNull);
      expect(path!.map((n) => n.id), ['groceries', 'meat']);
    });

    test('returns null for an id that does not exist', () {
      expect(pieAncestorPath(_twoLevelTree(), 'missing'), isNull);
    });

    test('single-element path for a root-level node', () {
      final path = pieAncestorPath(_twoLevelTree(), 'rent');
      expect(path!.map((n) => n.id), ['rent']);
    });
  });

  group('foldPieSlices', () {
    test('sorts entries largest-to-smallest', () {
      final nodes = [
        const PieTreeNode(id: 'a', label: 'a', value: 5),
        const PieTreeNode(id: 'b', label: 'b', value: 20),
        const PieTreeNode(id: 'c', label: 'c', value: 10),
      ];
      final entries = foldPieSlices(nodes);
      expect(entries.map((e) => e.node?.id), ['b', 'c', 'a']);
    });

    test('leaves any number of entries unfolded — no "Other" bucket, ever', () {
      final nodes = [
        for (var i = 0; i < 6; i++)
          PieTreeNode(id: 'n$i', label: 'n$i', value: (i + 1).toDouble()),
      ];
      final entries = foldPieSlices(nodes);
      expect(entries, hasLength(6));
      expect(entries.every((e) => e.node != null), isTrue);
      expect(entries.any((e) => e.label == 'Other'), isFalse);
    });

    test('excludes negative-value entries but keeps zero-value ones', () {
      final nodes = [
        const PieTreeNode(id: 'a', label: 'a', value: 5),
        const PieTreeNode(id: 'b', label: 'b', value: 0),
        const PieTreeNode(id: 'c', label: 'c', value: -3),
      ];
      expect(foldPieSlices(nodes).map((e) => e.node?.id), ['a', 'b']);
    });
  });

  group('layoutPieWedges', () {
    test(
      'no focus: ring1 is the top-level children, sorted, summing to 2*pi',
      () {
        final wedges = layoutPieWedges(
          _twoLevelTree(),
          null,
          Brightness.light,
          _outerRadius,
        );
        final ring0 = wedges.where((w) => w.ring == 0).toList();
        expect(ring0, hasLength(1));
        expect(ring0.single.label, 'Root');
        expect(ring0.single.value, 100);
        final ring1 = wedges.where((w) => w.ring == 1).toList();
        expect(ring1, hasLength(2));
        final total = ring1.fold<double>(0, (s, w) => s + w.sweepAngle);
        expect(total, closeTo(2 * pi, 1e-9));
        expect(ring1.first.targetId, 'rent');
        final rent = ring1.firstWhere((w) => w.targetId == 'rent');
        final groceries = ring1.firstWhere((w) => w.targetId == 'groceries');
        expect(rent.sweepAngle / groceries.sweepAngle, closeTo(7 / 3, 1e-9));
      },
    );

    test('with a focus: a thin ring0 wedge represents the focus itself', () {
      const focus = PieTreeNode(
        id: 'groceries',
        label: 'Groceries',
        value: 30,
        children: [
          PieTreeNode(id: 'meat', label: 'Meat', value: 10),
          PieTreeNode(id: 'veg', label: 'Veg', value: 20),
        ],
      );
      final wedges = layoutPieWedges(
        focus.children,
        focus,
        Brightness.light,
        _outerRadius,
      );
      final ring0 = wedges.where((w) => w.ring == 0).toList();
      expect(ring0, hasLength(1));
      expect(ring0.single.isFocusRing, isTrue);
      expect(ring0.single.label, 'Groceries');
      expect(ring0.single.value, 30);
      expect(ring0.single.sweepAngle, closeTo(2 * pi, 1e-9));
    });

    test(
      'a focus\'s direct balance beyond its children\'s total shows up as an '
      'explicit, visible "Unassigned" ring1 wedge, not a gap',
      () {
        const focus = PieTreeNode(
          id: 'groceries',
          label: 'Groceries',
          value: 50,
          children: [
            PieTreeNode(id: 'meat', label: 'Meat', value: 10),
            PieTreeNode(id: 'veg', label: 'Veg', value: 20),
          ],
        );
        final wedges = layoutPieWedges(
          focus.children,
          focus,
          Brightness.light,
          _outerRadius,
        );
        final ring1 = wedges.where((w) => w.ring == 1).toList();
        final unassigned = ring1.firstWhere((w) => w.label == 'Unassigned');
        expect(unassigned.value, 20);
        expect(unassigned.targetId, isNull);
        final ring1Total = ring1.fold<double>(0, (s, w) => s + w.sweepAngle);
        expect(ring1Total, closeTo(2 * pi, 1e-9));
      },
    );

    test('no "Unassigned" wedge when a focus\'s children already sum to its '
        'full total', () {
      final wedges = layoutPieWedges(
        _twoLevelTree()[0].children,
        _twoLevelTree()[0],
        Brightness.light,
        _outerRadius,
      );
      expect(wedges.where((w) => w.label == 'Unassigned'), isEmpty);
    });

    test(
      'no "Unassigned" wedge at the root (no single focus to attribute it to)',
      () {
        final wedges = layoutPieWedges(
          _twoLevelTree(),
          null,
          Brightness.light,
          _outerRadius,
        );
        expect(wedges.where((w) => w.label == 'Unassigned'), isEmpty);
      },
    );

    test('a node\'s "Unassigned" remainder is shown consistently whether seen '
        'nested in ring2 (at the root) or promoted to ring1 (after drilling '
        'into it) — same money, same picture either way', () {
      const groceries = PieTreeNode(
        id: 'groceries',
        label: 'Groceries',
        value: 50,
        children: [
          PieTreeNode(id: 'meat', label: 'Meat', value: 10),
          PieTreeNode(id: 'veg', label: 'Veg', value: 20),
        ],
      );
      const tree = [
        groceries,
        PieTreeNode(id: 'rent', label: 'Rent', value: 70),
      ];

      final atRoot = layoutPieWedges(
        tree,
        null,
        Brightness.light,
        _outerRadius,
      );
      final ring2Unassigned = atRoot
          .where((w) => w.ring == 2)
          .firstWhere((w) => w.label == 'Unassigned');
      expect(ring2Unassigned.value, 20);
      expect(ring2Unassigned.isUnassigned, isTrue);
      expect(ring2Unassigned.targetId, isNull);

      final drilledIn = layoutPieWedges(
        groceries.children,
        groceries,
        Brightness.light,
        _outerRadius,
      );
      final ring1Unassigned = drilledIn
          .where((w) => w.ring == 1)
          .firstWhere((w) => w.label == 'Unassigned');
      expect(ring1Unassigned.value, 20);
      expect(ring1Unassigned.isUnassigned, isTrue);
    });

    test('adjacent wedges are perfectly contiguous — no gap between them', () {
      final wedges = layoutPieWedges(
        _twoLevelTree(),
        null,
        Brightness.light,
        _outerRadius,
      );
      final ring1 = wedges.where((w) => w.ring == 1).toList()
        ..sort((a, b) => a.startAngle.compareTo(b.startAngle));
      for (var i = 0; i < ring1.length - 1; i++) {
        expect(
          ring1[i].startAngle + ring1[i].sweepAngle,
          closeTo(ring1[i + 1].startAngle, 1e-9),
        );
      }
    });

    test(
      'ring2 (grandchildren) wedges target their own node directly, not '
      'their ring1 parent — tapping one jumps straight to focusing on it',
      () {
        final wedges = layoutPieWedges(
          _twoLevelTree(),
          null,
          Brightness.light,
          _outerRadius,
        );
        final ring2 = wedges.where((w) => w.ring == 2).toList();
        expect(ring2, hasLength(2));
        final meat = ring2.firstWhere((w) => w.label == 'Meat');
        final veg = ring2.firstWhere((w) => w.label == 'Veg');
        expect(meat.targetId, 'meat');
        expect(veg.targetId, 'veg');
      },
    );

    test('more than 4 real grandchildren each still get their own ring2 '
        'wedge — no folding into "Other"', () {
      const parent = PieTreeNode(
        id: 'p',
        label: 'Parent',
        value: 21,
        children: [
          PieTreeNode(id: 'c0', label: 'c0', value: 1),
          PieTreeNode(id: 'c1', label: 'c1', value: 2),
          PieTreeNode(id: 'c2', label: 'c2', value: 3),
          PieTreeNode(id: 'c3', label: 'c3', value: 4),
          PieTreeNode(id: 'c4', label: 'c4', value: 5),
          PieTreeNode(id: 'c5', label: 'c5', value: 6),
        ],
      );
      final wedges = layoutPieWedges(
        const [parent],
        null,
        Brightness.light,
        _outerRadius,
      );
      final ring2 = wedges.where((w) => w.ring == 2).toList();
      expect(ring2, hasLength(6));
      expect(ring2.any((w) => w.label == 'Other'), isFalse);
      expect(ring2.every((w) => w.targetId != null), isTrue);
    });

    test('ring2 wedges nest inside their parent\'s angular span', () {
      final wedges = layoutPieWedges(
        _twoLevelTree(),
        null,
        Brightness.light,
        _outerRadius,
      );
      final groceries = wedges.firstWhere(
        (w) => w.ring == 1 && w.targetId == 'groceries',
      );
      final ring2 = wedges.where((w) => w.ring == 2).toList();
      final groceriesEnd = groceries.startAngle + groceries.sweepAngle;
      for (final w in ring2) {
        expect(w.startAngle, greaterThanOrEqualTo(groceries.startAngle - 1e-9));
        expect(
          w.startAngle + w.sweepAngle,
          lessThanOrEqualTo(groceriesEnd + 1e-9),
        );
      }
      final ring2Total = ring2.fold<double>(0, (s, w) => s + w.sweepAngle);
      expect(ring2Total, closeTo(groceries.sweepAngle, 1e-9));
    });

    test('a grandchild shares its exact color with its ring1 parent', () {
      final wedges = layoutPieWedges(
        _twoLevelTree(),
        null,
        Brightness.light,
        _outerRadius,
      );
      final groceries = wedges.firstWhere(
        (w) => w.ring == 1 && w.targetId == 'groceries',
      );
      final ring2 = wedges.where((w) => w.ring == 2);
      for (final w in ring2) {
        expect(w.color, groceries.color);
      }
    });

    test('a node with no children produces no ring2 wedges, and no focus ring '
        'either (flat/holder case — nothing to drill into at all)', () {
      final wedges = layoutPieWedges(
        const [PieTreeNode(id: 'h', label: 'Holder', value: 10)],
        null,
        Brightness.light,
        _outerRadius,
      );
      expect(wedges, hasLength(1));
      expect(wedges.single.ring, 1);
    });
  });

  group('entriesForGroup / debtEntriesForGroup', () {
    test('a debt-only child (no positive component at all) is excluded from '
        'entriesForGroup — it never gets a wedge', () {
      const children = [
        PieTreeNode(id: 'credit', label: 'Credit', value: 2400),
        PieTreeNode(id: 'loan', label: 'Loan', value: 0, debtValue: -1550),
      ];
      final entries = entriesForGroup(children, null);
      expect(entries.map((e) => e.node?.id), ['credit']);
    });

    test('a node with both a positive value and subtree debt still gets a '
        'normal wedge entry, sized by its positive total only', () {
      const housing = PieTreeNode(
        id: 'housing',
        label: 'Housing',
        value: 3600,
        debtValue: -1550,
      );
      final entries = entriesForGroup([housing], null);
      expect(entries, hasLength(1));
      expect(entries.single.value, 3600);
      expect(entries.single.node?.hasDebt, isTrue);
    });

    test('debtEntriesForGroup surfaces a debt-only child, sorted '
        'most-negative-first, and it carries isDebt', () {
      const children = [
        PieTreeNode(id: 'loanA', label: 'Loan A', value: 0, debtValue: -500),
        PieTreeNode(id: 'loanB', label: 'Loan B', value: 0, debtValue: -1550),
        PieTreeNode(id: 'credit', label: 'Credit', value: 2400),
      ];
      final debtEntries = debtEntriesForGroup(children, null);
      expect(debtEntries.map((e) => e.node?.id), ['loanB', 'loanA']);
      expect(debtEntries.every((e) => e.isDebt), isTrue);
    });

    test('a node with debt but no debt-only child produces no debt entries '
        'at this level (the debt is nested deeper, surfaced only after '
        'drilling in)', () {
      const housing = PieTreeNode(
        id: 'housing',
        label: 'Housing',
        value: 3600,
        debtValue: -1550,
      );
      expect(debtEntriesForGroup([housing], null), isEmpty);
    });

    test("owner's own direct debt beyond its children's debt total shows up "
        'as an "Unassigned" debt entry', () {
      const focus = PieTreeNode(
        id: 'housing',
        label: 'Housing',
        value: 3600,
        debtValue: -2000,
        children: [
          PieTreeNode(id: 'loan', label: 'Loan', value: 0, debtValue: -1550),
        ],
      );
      final debtEntries = debtEntriesForGroup(focus.children, focus);
      expect(debtEntries, hasLength(2));
      final unassigned = debtEntries.firstWhere((e) => e.isUnassigned);
      expect(unassigned.value, -450);
      expect(unassigned.node, isNull);
    });

    test('no debt entries when neither children nor owner have any debt', () {
      const focus = PieTreeNode(
        id: 'x',
        label: 'X',
        value: 10,
        children: [PieTreeNode(id: 'y', label: 'Y', value: 10)],
      );
      expect(debtEntriesForGroup(focus.children, focus), isEmpty);
    });
  });

  group('labelChordWidth', () {
    test('a lone, full-circle wedge (a single top-level budget with no '
        'siblings) still gets a usable chord width, not 0', () {
      const fullCircle = PieWedge(
        ring: 1,
        startAngle: 0,
        sweepAngle: 2 * pi,
        innerRadius: 50,
        outerRadius: 100,
        color: Colors.blue,
        targetId: 'solo',
        label: 'Solo Budget',
        value: 100,
        displayPercent: 1.0,
      );
      const midRadius = 75.0;
      expect(
        labelChordWidth(fullCircle, midRadius),
        closeTo(2 * midRadius, 1e-9),
      );
    });

    test(
      'a half-circle wedge already gets the maximum (uncapped) chord width',
      () {
        const halfCircle = PieWedge(
          ring: 1,
          startAngle: 0,
          sweepAngle: pi,
          innerRadius: 50,
          outerRadius: 100,
          color: Colors.blue,
          targetId: 'half',
          label: 'Half',
          value: 50,
          displayPercent: 0.5,
        );
        const midRadius = 75.0;
        expect(
          labelChordWidth(halfCircle, midRadius),
          closeTo(2 * midRadius, 1e-9),
        );
      },
    );

    test('a narrow wedge gets a proportionally small chord width', () {
      const narrow = PieWedge(
        ring: 1,
        startAngle: 0,
        sweepAngle: pi / 6,
        innerRadius: 50,
        outerRadius: 100,
        color: Colors.blue,
        targetId: 'sliver',
        label: 'Sliver',
        value: 5,
        displayPercent: 0.05,
      );
      const midRadius = 75.0;
      expect(
        labelChordWidth(narrow, midRadius),
        closeTo(2 * midRadius * sin(pi / 12), 1e-9),
      );
    });
  });

  group('pieWedgeAt', () {
    final wedges = layoutPieWedges(
      _twoLevelTree(),
      null,
      Brightness.light,
      _outerRadius,
    );
    const center = Offset(_outerRadius, _outerRadius);

    test('resolves a tap inside a ring1 wedge to its own node id', () {
      final rent = wedges.firstWhere(
        (w) => w.ring == 1 && w.targetId == 'rent',
      );
      expect(
        pieWedgeAt(wedges, _midpointOf(rent, center), center)?.targetId,
        'rent',
      );
    });

    test('resolves a tap inside a ring2 wedge to its own node id, not its '
        'ring1 parent\'s', () {
      final meat = wedges.firstWhere((w) => w.ring == 2 && w.label == 'Meat');
      expect(
        pieWedgeAt(wedges, _midpointOf(meat, center), center)?.targetId,
        'meat',
      );
    });

    test('a tap at the very center hits the focus ring, not just its thin '
        'painted band — the whole middle is one "zoom out" target', () {
      final hit = pieWedgeAt(wedges, center, center);
      expect(hit?.isFocusRing, isTrue);
    });

    test('tap beyond the outer ring is a no-op', () {
      expect(pieWedgeAt(wedges, center + const Offset(500, 0), center), isNull);
    });

    test('more than 4 ring1 siblings each resolve to their own targetId — '
        'no "Other" wedge to tap', () {
      final nodes = [
        for (var i = 0; i < 6; i++)
          PieTreeNode(id: 'n$i', label: 'n$i', value: (i + 1).toDouble()),
      ];
      final w = layoutPieWedges(nodes, null, Brightness.light, _outerRadius);
      final ring1 = w.where((x) => x.ring == 1).toList();
      expect(ring1, hasLength(6));
      expect(ring1.every((x) => x.targetId != null), isTrue);
    });

    test('tapping the thin focus ring hits a wedge with isFocusRing true', () {
      const focus = PieTreeNode(
        id: 'groceries',
        label: 'Groceries',
        value: 30,
        children: [
          PieTreeNode(id: 'meat', label: 'Meat', value: 10),
          PieTreeNode(id: 'veg', label: 'Veg', value: 20),
        ],
      );
      final w = layoutPieWedges(
        focus.children,
        focus,
        Brightness.light,
        _outerRadius,
      );
      final ring0 = w.firstWhere((x) => x.ring == 0);
      final hit = pieWedgeAt(w, _midpointOf(ring0, center), center);
      expect(hit?.isFocusRing, isTrue);
    });
  });

  group('PieChartCard widget', () {
    Future<void> pump(
      WidgetTester tester,
      List<PieTreeNode> nodes, {
      bool loading = false,
      String Function(double)? amountLabel,
      bool showAmountsInLegend = true,
      Map<String, List<AssetHolding>>? holdingsByContainerId,
      List<AssetHolding>? rootHoldings,
      String Function(String assetId, Decimal quantity)? holdingQuantityLabel,
    }) {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                PieChartCard(
                  title: 'By budget',
                  nodes: nodes,
                  loading: loading,
                  amountLabel: amountLabel,
                  showAmountsInLegend: showAmountsInLegend,
                  holdingsByContainerId: holdingsByContainerId,
                  rootHoldings: rootHoldings,
                  holdingQuantityLabel: holdingQuantityLabel,
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('shows a loading indicator while loading', (tester) async {
      await pump(tester, const [], loading: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an empty state for no data', (tester) async {
      await pump(tester, const []);
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('shows no breadcrumb for a flat (non-nesting) tree', (
      tester,
    ) async {
      await pump(tester, const [
        PieTreeNode(id: 'h1', label: 'Bank', value: 10),
        PieTreeNode(id: 'h2', label: 'Broker', value: 20),
      ]);
      expect(find.text('Root'), findsNothing);
    });

    testWidgets('shows the total for the current level in the legend', (
      tester,
    ) async {
      await pump(
        tester,
        _twoLevelTree(),
        amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
      );
      expect(find.textContaining('100.00 EUR'), findsOneWidget);
    });

    testWidgets(
      'shows every sibling in the legend, including a zero-value one, with '
      'no "Other" bucket',
      (tester) async {
        final nodes = [
          for (var i = 0; i < 6; i++)
            PieTreeNode(
              id: 'n$i',
              label: 'Budget $i',
              value: (i + 1).toDouble(),
            ),
          const PieTreeNode(id: 'n6', label: 'Budget 6', value: 0),
        ];
        await pump(tester, nodes);
        expect(find.textContaining('Other'), findsNothing);
        for (var i = 0; i < 7; i++) {
          expect(find.textContaining('Budget $i ·'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'tapping a ring1 slice drills in and shows its own total; "Root" drills back out',
      (tester) async {
        await pump(
          tester,
          _twoLevelTree(),
          amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
        );
        expect(find.text('Root'), findsOneWidget);
        expect(find.text('Groceries'), findsNothing);

        final rect = tester.getRect(
          find.byKey(const ValueKey('pieChartTapArea')),
        );
        final wedges = layoutPieWedges(
          _twoLevelTree(),
          null,
          Brightness.light,
          rect.width / 2,
        );
        final groceries = wedges.firstWhere(
          (w) => w.ring == 1 && w.targetId == 'groceries',
        );
        final tapPoint = _midpointOf(groceries, rect.center);

        await tester.tapAt(tapPoint);
        await tester.pump();

        expect(find.text('Root'), findsOneWidget);
        expect(find.text('Groceries'), findsOneWidget);
        expect(find.textContaining('30.00 EUR'), findsWidgets);

        await tester.tap(find.text('Root'));
        await tester.pump();

        expect(find.textContaining('100.00 EUR'), findsOneWidget);
      },
    );

    testWidgets(
      'grandchildren are collapsed by default; expanding the parent row '
      'reveals them, indented, and both levels are tappable',
      (tester) async {
        await pump(
          tester,
          _twoLevelTree(),
          amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
        );

        expect(find.textContaining('Meat ·'), findsNothing);
        expect(find.textContaining('Veg ·'), findsNothing);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pump();
        expect(find.text('Root'), findsOneWidget);
        expect(find.textContaining('Meat ·'), findsOneWidget);
        expect(find.textContaining('Veg ·'), findsOneWidget);

        await tester.tap(find.textContaining('Meat ·'));
        await tester.pump();
        expect(find.text('Meat'), findsWidgets);
        expect(find.text('Groceries'), findsOneWidget);

        await tester.tap(find.text('Root'));
        await tester.pump();
        await tester.tap(find.textContaining('Rent ·'));
        await tester.pump();
        expect(find.text('Rent'), findsWidgets);
      },
    );

    testWidgets(
      'tapping anywhere in the center (not just the thin ring) zooms back out',
      (tester) async {
        await pump(
          tester,
          _twoLevelTree(),
          amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
        );
        await tester.tap(find.textContaining('Groceries ·'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Groceries: 30.00 EUR'), findsOneWidget);

        final rect = tester.getRect(
          find.byKey(const ValueKey('pieChartTapArea')),
        );
        await tester.tapAt(rect.center);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();

        expect(find.textContaining('Groceries: 30.00 EUR'), findsNothing);
        expect(find.textContaining('Total: 100.00 EUR'), findsOneWidget);
      },
    );

    testWidgets('hovering a slice shows a tooltip with its name and value '
        'without drilling in', (tester) async {
      await pump(
        tester,
        _twoLevelTree(),
        amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
      );

      final rect = tester.getRect(
        find.byKey(const ValueKey('pieChartTapArea')),
      );
      final wedges = layoutPieWedges(
        _twoLevelTree(),
        null,
        Brightness.light,
        rect.width / 2,
      );
      final rent = wedges.firstWhere(
        (w) => w.ring == 1 && w.targetId == 'rent',
      );
      final hoverPoint = _midpointOf(rent, rect.center);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(hoverPoint);
      await tester.pump();

      expect(find.textContaining('Rent'), findsWidgets);
      expect(find.textContaining('70.00 EUR'), findsWidgets);
      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Groceries · 30.00 EUR · 30%'), findsOneWidget);
    });

    testWidgets(
      'tapping a slice with children drills in and shows a brief tooltip',
      (tester) async {
        await pump(
          tester,
          _twoLevelTree(),
          amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
        );

        final rect = tester.getRect(
          find.byKey(const ValueKey('pieChartTapArea')),
        );
        final wedges = layoutPieWedges(
          _twoLevelTree(),
          null,
          Brightness.light,
          rect.width / 2,
        );
        final groceries = wedges.firstWhere(
          (w) => w.ring == 1 && w.targetId == 'groceries',
        );
        final tapPoint = _midpointOf(groceries, rect.center);

        await tester.tapAt(tapPoint);
        await tester.pump();

        expect(find.textContaining('Groceries'), findsWidgets);
        expect(find.textContaining('30.00 EUR'), findsWidgets);
        expect(find.text('Root'), findsOneWidget);
      },
    );

    List<PieTreeNode> housingTree() => const [
      PieTreeNode(
        id: 'housing',
        label: 'Housing',
        value: 3600,
        debtValue: -1550,
        children: [
          PieTreeNode(id: 'credit', label: 'Credit', value: 2400),
          PieTreeNode(id: 'taxes', label: 'Taxes', value: 1200),
          PieTreeNode(id: 'loan', label: 'Loan', value: 0, debtValue: -1550),
        ],
      ),
      PieTreeNode(id: 'savings', label: 'Savings', value: 5000),
    ];

    testWidgets('the "Show liabilities" toggle only appears when the tree '
        'has debt somewhere in it', (tester) async {
      await pump(tester, _twoLevelTree());
      expect(find.byType(Switch), findsNothing);

      await pump(tester, housingTree());
      expect(find.text('Show liabilities'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('a legend row whose subtree contains debt shows a red-dot '
        'badge, even though the row itself still gets a normal wedge', (
      tester,
    ) async {
      await pump(tester, housingTree());
      expect(
        find.byTooltip('Contains a container with negative balance'),
        findsOneWidget,
      );
      expect(find.textContaining('Savings ·'), findsOneWidget);
    });

    testWidgets('drilling into a container with a debt-only child shows a '
        'no-wedge "debt" pill row with a red amount and the assets-vs-debt '
        'bar, both absent at the root', (tester) async {
      await pump(
        tester,
        housingTree(),
        amountLabel: (v) => '${v.toStringAsFixed(0)} EUR',
      );

      expect(find.text('debt'), findsNothing);
      expect(find.textContaining('Assets ·'), findsNothing);

      await tester.tap(find.textContaining('Housing ·'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Loan'), findsWidgets);
      expect(find.text('debt'), findsOneWidget);
      expect(find.textContaining('-1550 EUR'), findsWidgets);
      expect(find.textContaining('Assets · 3600 EUR'), findsOneWidget);
      expect(find.textContaining('1550 EUR debt'), findsOneWidget);
    });

    testWidgets('turning "Show liabilities" off hides the badge, debt row, '
        'and bar without changing the ring\'s own totals/percentages', (
      tester,
    ) async {
      await pump(
        tester,
        housingTree(),
        amountLabel: (v) => '${v.toStringAsFixed(0)} EUR',
      );
      await tester.tap(find.textContaining('Housing ·'));
      await tester.pumpAndSettle();
      expect(find.text('debt'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(
        find.byTooltip('Contains a container with negative balance'),
        findsNothing,
      );
      expect(find.text('debt'), findsNothing);
      expect(find.textContaining('Assets ·'), findsNothing);
      expect(find.textContaining('Credit · 2400 EUR · 67%'), findsOneWidget);
      expect(find.textContaining('Taxes · 1200 EUR · 33%'), findsOneWidget);
    });

    testWidgets('showAmountsInLegend false hides the per-row amount but the '
        'header "total: …" line still shows one — the filtered-to-one-asset '
        '"Where it lives" mode', (tester) async {
      await pump(
        tester,
        _twoLevelTree(),
        amountLabel: (v) => '${v.toStringAsFixed(2)} BTC',
        showAmountsInLegend: false,
      );

      expect(find.textContaining('100.00 BTC'), findsOneWidget);
      expect(find.text('Rent · 70%'), findsOneWidget);
      expect(find.textContaining('70.00 BTC'), findsNothing);
    });

    testWidgets('the "Actual assets held" panel shows rootHoldings when '
        'nothing is focused, and switches to the per-container entry once '
        'drilled in', (tester) async {
      final holdings = <String, List<AssetHolding>>{
        'groceries': [
          AssetHolding(
            assetId: 'aapl',
            quantity: Decimal.parse('3.2'),
            convertedValue: Decimal.parse('544'),
          ),
        ],
      };
      final root = [
        AssetHolding(
          assetId: 'eur',
          quantity: Decimal.parse('1000'),
          convertedValue: Decimal.parse('1000'),
        ),
      ];
      await pump(
        tester,
        _twoLevelTree(),
        amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
        holdingsByContainerId: holdings,
        rootHoldings: root,
        holdingQuantityLabel: (assetId, qty) =>
            '${assetId.toUpperCase()} — $qty',
      );

      expect(find.text('ACTUAL ASSETS HELD'), findsOneWidget);
      expect(find.text('EUR — 1000'), findsOneWidget);
      expect(find.text('AAPL — 3.2'), findsNothing);

      await tester.tap(find.textContaining('Groceries ·'));
      await tester.pumpAndSettle();

      expect(find.text('AAPL — 3.2'), findsOneWidget);
      expect(find.text('EUR — 1000'), findsNothing);
      expect(find.textContaining('≈ 544.00 EUR'), findsOneWidget);
    });

    testWidgets('an unconvertible holding (no known price) shows a "no '
        'known price" note in the panel instead of a converted amount, '
        'never silently dropped', (tester) async {
      final root = [
        AssetHolding(
          assetId: 'btc',
          quantity: Decimal.parse('0.5'),
          convertedValue: null,
        ),
      ];
      await pump(
        tester,
        _twoLevelTree(),
        amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
        rootHoldings: root,
        holdingQuantityLabel: (assetId, qty) =>
            '${assetId.toUpperCase()} — $qty',
      );

      expect(find.text('BTC — 0.5'), findsOneWidget);
      expect(find.text('no known price'), findsOneWidget);
    });

    testWidgets('the panel is omitted entirely when neither rootHoldings nor '
        'holdingsByContainerId is supplied', (tester) async {
      await pump(
        tester,
        _twoLevelTree(),
        amountLabel: (v) => '${v.toStringAsFixed(2)} EUR',
      );
      expect(find.text('ACTUAL ASSETS HELD'), findsNothing);
    });

    testWidgets('a node with hasUnconvertible shows an amber badge, '
        'distinct from the debt badge', (tester) async {
      const nodes = [
        PieTreeNode(id: 'a', label: 'A', value: 10, hasUnconvertible: true),
        PieTreeNode(id: 'b', label: 'B', value: 20),
      ];
      await pump(tester, nodes);
      expect(
        find.byTooltip(
          "Contains an asset with no known price — its value isn't included in this total",
        ),
        findsOneWidget,
      );
    });

    testWidgets('legend rows and wedge labels show a container\'s icon', (
      tester,
    ) async {
      await pump(tester, const [
        PieTreeNode(id: 'a', label: 'Alpha', value: 60, icon: 'fa:solidHouse'),
        PieTreeNode(id: 'b', label: 'Beta', value: 40),
      ]);
      expect(find.byType(FaIcon), findsNWidgets(2));
    });

    testWidgets('no icons anywhere when no container has one', (tester) async {
      await pump(tester, _twoLevelTree());
      expect(find.byType(FaIcon), findsNothing);
    });
  });

  group('layoutWedgeLabel', () {
    PieWedge wedge({String? icon, double percent = 0.5}) => PieWedge(
      ring: 1,
      startAngle: 0,
      sweepAngle: 2 * pi * percent,
      innerRadius: 40,
      outerRadius: 100,
      color: Colors.blue,
      targetId: 'a',
      label: 'Alpha',
      value: 1,
      displayPercent: percent,
      icon: icon,
    );
    const center = Offset(100, 100);

    test('reserves an icon slot only for a resolvable icon', () {
      expect(layoutWedgeLabel(wedge(), center)!.hasIcon, isFalse);
      expect(
        layoutWedgeLabel(wedge(icon: 'fa:nope'), center)!.hasIcon,
        isFalse,
      );
      final withIcon = layoutWedgeLabel(wedge(icon: 'fa:solidHouse'), center)!;
      expect(withIcon.hasIcon, isTrue);
      expect(withIcon.iconExtent, greaterThan(0));
    });

    test('an icon never hides a label, and the whole block stays centred', () {
      final plain = layoutWedgeLabel(wedge(), center)!;
      final withIcon = layoutWedgeLabel(wedge(icon: 'fa:solidHouse'), center)!;
      double centreX(WedgeLabelLayout l) =>
          l.topLeft.dx + (l.iconExtent + l.text.width) / 2;
      expect(centreX(withIcon), closeTo(centreX(plain), 0.001));
    });

    test('a wedge under 1% still gets no label, icon or not', () {
      expect(
        layoutWedgeLabel(wedge(icon: 'fa:solidHouse', percent: 0.005), center),
        isNull,
      );
    });
  });

  group('stable colors', () {
    test('wedges use their node colorIndex, not their size rank', () {
      const nodes = [
        PieTreeNode(id: 'big', label: 'Zed', value: 90, colorIndex: 3),
        PieTreeNode(id: 'small', label: 'Abe', value: 10, colorIndex: 0),
      ];
      final wedges = layoutPieWedges(
        nodes,
        null,
        Brightness.light,
        _outerRadius,
      ).where((w) => w.ring == 1).toList();
      expect(
        wedges.firstWhere((w) => w.targetId == 'big').color,
        categoricalColor(3),
      );
      expect(
        wedges.firstWhere((w) => w.targetId == 'small').color,
        categoricalColor(0),
      );
    });
  });

  group('controlled focus', () {
    Future<void> pump(
      WidgetTester tester, {
      String? focusId,
      required ValueChanged<String?> onFocusChanged,
      bool drillDown = true,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PieChartCard(
              title: 'T',
              subtitle: 'Balance on today',
              nodes: _twoLevelTree(),
              focusId: focusId,
              onFocusChanged: onFocusChanged,
              drillDown: drillDown,
            ),
          ),
        ),
      ),
    );

    testWidgets('shows the subtitle and reports legend taps instead of '
        'drilling itself', (tester) async {
      String? reported;
      await pump(tester, onFocusChanged: (id) => reported = id);
      expect(find.text('Balance on today'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Rent').first);
      await tester.pump();
      await tester.tap(find.textContaining('Rent').first);
      expect(reported, 'rent');
      expect(find.textContaining('Total:'), findsOneWidget);
    });

    testWidgets('draws the focus the parent passes in', (tester) async {
      await pump(tester, focusId: 'groceries', onFocusChanged: (_) {});
      expect(find.textContaining('Groceries:'), findsOneWidget);
    });

    testWidgets('a focus missing from the nodes falls back to the root', (
      tester,
    ) async {
      await pump(tester, focusId: 'gone', onFocusChanged: (_) {});
      expect(find.textContaining('Total:'), findsOneWidget);
    });

    testWidgets('without drill-down the chart stays on the root while the '
        'selected row is highlighted', (tester) async {
      await pump(
        tester,
        focusId: 'rent',
        onFocusChanged: (_) {},
        drillDown: false,
      );
      expect(find.textContaining('Total:'), findsOneWidget);
      final selected = tester.widget<Text>(find.textContaining('Rent').first);
      expect(
        selected.style?.fontWeight ?? selected.textSpan?.style?.fontWeight,
        isNotNull,
      );
    });
  });
}
