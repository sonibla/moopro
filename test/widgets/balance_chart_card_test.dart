import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/balance_chart_data.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/widgets/balance_chart_card.dart';
import 'package:moopro/widgets/container_icon.dart';

BalanceChartData _data({int todayIndex = 1}) => BalanceChartData(
  dates: [
    CalendarDate(2026, 1, 1),
    CalendarDate(2026, 1, 2),
    CalendarDate(2026, 1, 3),
  ],
  todayIndex: todayIndex,
  series: const [
    BalanceChartSeries(
      containerId: 'a',
      label: 'Bank A',
      icon: null,
      colorIndex: 0,
      isOwn: false,
      positive: [10, 12, 14],
      debt: [0, 0, 0],
    ),
    BalanceChartSeries(
      containerId: 'b',
      label: 'Bank B',
      icon: null,
      colorIndex: 1,
      isOwn: true,
      positive: [5, 5, 5],
      debt: [-2, -2, -2],
    ),
  ],
  net: const [13, 15, 17],
  unitAssetId: 'eur',
  unpricedAssetIds: const {},
);

Future<void> _pump(
  WidgetTester tester, {
  BalanceChartData? data,
  String? errorMessage,
  String? focusLabel,
  VoidCallback? onBack,
  String? unpricedNote,
  ValueChanged<String>? onBandTap,
  ValueChanged<BalanceRange>? onRangeChanged,
  ValueChanged<BalanceHorizon>? onHorizonChanged,
  CalendarDate? asOf,
  ValueChanged<CalendarDate>? onAsOfChanged,
  bool hideAmounts = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: BalanceChartCard(
          title: 'Balance over time',
          data: data,
          errorMessage: errorMessage,
          valueLabel: (v) => '${v.toStringAsFixed(2)} EUR',
          dateLabel: (d) => '${d.year}-${d.month}-${d.day}',
          range: BalanceRange.year,
          onRangeChanged: onRangeChanged ?? (_) {},
          horizon: BalanceHorizon.threeMonths,
          onHorizonChanged: onHorizonChanged ?? (_) {},
          onBandTap: onBandTap ?? (_) {},
          focusLabel: focusLabel,
          onBack: onBack,
          unpricedNote: unpricedNote,
          asOf: asOf,
          onAsOfChanged: onAsOfChanged,
          hideAmounts: hideAmounts,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('hideAmounts blanks the y-axis values but keeps the plot', (
    tester,
  ) async {
    Finder axisLabels() => find.descendant(
      of: find.byType(LineChart),
      matching: find.byType(Text),
    );

    await _pump(tester, data: _data());
    final shown = axisLabels().evaluate().length;
    expect(shown, greaterThan(0));

    await _pump(tester, data: _data(), hideAmounts: true);
    expect(find.byType(LineChart), findsOneWidget);
    expect(axisLabels().evaluate().length, lessThan(shown));
  });

  testWidgets('loading shows a spinner and no chart', (tester) async {
    await _pump(tester, data: null);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('error shows the message instead of a chart', (tester) async {
    await _pump(tester, errorMessage: 'boom');
    expect(find.textContaining('Failed to load chart: boom'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('empty data shows the empty state', (tester) async {
    await _pump(
      tester,
      data: const BalanceChartData(
        dates: [],
        todayIndex: -1,
        series: [],
        net: [],
        unitAssetId: 'eur',
        unpricedAssetIds: {},
      ),
    );
    expect(find.text('No balance history yet'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('draws one legend chip per band; "(own)" marks own holdings', (
    tester,
  ) async {
    await _pump(tester, data: _data());
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('Bank A'), findsOneWidget);
    expect(find.text('Bank B (own)'), findsOneWidget);
  });

  testWidgets('shows the plotted date range and month-start tick labels', (
    tester,
  ) async {
    final dates = [
      for (var i = 0; i < 366; i += 5) CalendarDate(2025, 10, 7).addDays(i),
    ];
    final n = dates.length;
    await _pump(
      tester,
      data: BalanceChartData(
        dates: dates,
        todayIndex: 0,
        series: [
          BalanceChartSeries(
            containerId: 'a',
            label: 'Bank A',
            icon: null,
            colorIndex: 0,
            isOwn: false,
            positive: List.filled(n, 10.0),
            debt: List.filled(n, 0.0),
          ),
        ],
        net: List.filled(n, 10.0),
        unitAssetId: 'eur',
        unpricedAssetIds: const {},
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('balanceChartRange'))).data,
      '2025-10-7 – ${dates.last.year}-${dates.last.month}-${dates.last.day}',
    );
    for (final label in ['Nov 2025', 'Jan 2026', 'Mar', 'May', 'Jul', 'Sep']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('tapping a legend chip reports that container', (tester) async {
    String? tapped;
    await _pump(tester, data: _data(), onBandTap: (id) => tapped = id);
    await tester.tap(find.byKey(const ValueKey('balance-legend-a')));
    expect(tapped, 'a');
  });

  testWidgets('forecast segment is dashed, past segment solid', (tester) async {
    await _pump(tester, data: _data(todayIndex: 1));
    final bars = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData;
    expect(bars.any((b) => b.dashArray != null), isTrue);
    expect(bars.any((b) => b.dashArray == null), isTrue);
  });

  testWidgets('with no forecast (today is the last date) nothing is dashed', (
    tester,
  ) async {
    await _pump(tester, data: _data(todayIndex: 2));
    final bars = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData;
    expect(bars.every((b) => b.dashArray == null), isTrue);
  });

  testWidgets('range and horizon controls report the picked value', (
    tester,
  ) async {
    BalanceRange? range;
    BalanceHorizon? horizon;
    await _pump(
      tester,
      data: _data(),
      onRangeChanged: (r) => range = r,
      onHorizonChanged: (h) => horizon = h,
    );

    await tester.tap(find.text('6M'));
    await tester.tap(find.text('No forecast'));
    expect(range, BalanceRange.sixMonths);
    expect(horizon, BalanceHorizon.none);
  });

  testWidgets('focused view shows the container name and a back button', (
    tester,
  ) async {
    var back = 0;
    await _pump(
      tester,
      data: _data(),
      focusLabel: 'Parent',
      onBack: () => back++,
    );
    expect(find.text('Balance over time · Parent'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    expect(back, 1);
  });

  testWidgets('no back button at the top level', (tester) async {
    await _pump(tester, data: _data());
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('shows the unpriced-assets note', (tester) async {
    await _pump(tester, data: _data(), unpricedNote: 'left out: BTC');
    expect(find.text('left out: BTC'), findsOneWidget);
  });

  group('balanceChartHit', () {
    final data = _data();
    const size = Size(456, 288);
    final x0 = CalendarDate(
      2026,
      1,
      1,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
    final x2 = CalendarDate(
      2026,
      1,
      3,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();

    String? hit(double dx, double dy) => balanceChartHit(
      data,
      Offset(dx, dy),
      size,
      minX: x0,
      maxX: x2,
      minY: -4,
      maxY: 20,
    );

    test('maps a pixel in the lower positive band to the first series', () {
      expect(hit(56, 191), 'a');
    });

    test('maps a pixel higher up to the second stacked series', () {
      expect(hit(56, 87), 'b');
    });

    test('a pixel below zero hits the debt band', () {
      expect(hit(56, 227.5), 'b');
    });

    test('taps in the axis gutters or above the stack are misses', () {
      expect(hit(20, 100), isNull, reason: 'y-axis gutter');
      expect(hit(200, 275), isNull, reason: 'x-axis gutter');
      expect(hit(56, 5), isNull, reason: 'above the stack');
    });

    test('x picks the nearest sampled date', () {
      expect(hit(456, 87), 'a');
    });
  });

  group('compactAmount', () {
    test('abbreviates thousands and millions', () {
      expect(compactAmount(950), '950');
      expect(compactAmount(1200), '1.2k');
      expect(compactAmount(-45000), '-45k');
      expect(compactAmount(3400000), '3.4M');
      expect(compactAmount(0), '0');
    });
  });

  testWidgets('the as-of cursor is drawn as a vertical line at the date', (
    tester,
  ) async {
    await _pump(tester, data: _data(), asOf: CalendarDate(2026, 1, 2));
    final lines = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .extraLinesData
        .verticalLines;
    expect(lines, hasLength(1));
    expect(
      lines.single.x,
      CalendarDate(
        2026,
        1,
        2,
      ).toUtcDateTime().millisecondsSinceEpoch.toDouble(),
    );
  });

  testWidgets('no cursor without an as-of date', (tester) async {
    await _pump(tester, data: _data());
    expect(
      tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .extraLinesData
          .verticalLines,
      isEmpty,
    );
  });

  group('balanceChartDateAt', () {
    final minX = CalendarDate(
      2026,
      1,
      1,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
    final maxX = CalendarDate(
      2026,
      1,
      11,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
    const size = Size(456, 300);

    test('maps the plot linearly and clamps outside it', () {
      expect(
        balanceChartDateAt(56, size, minX: minX, maxX: maxX),
        CalendarDate(2026, 1, 1),
      );
      expect(
        balanceChartDateAt(456, size, minX: minX, maxX: maxX),
        CalendarDate(2026, 1, 11),
      );
      expect(
        balanceChartDateAt(256, size, minX: minX, maxX: maxX),
        CalendarDate(2026, 1, 6),
      );
      expect(
        balanceChartDateAt(-50, size, minX: minX, maxX: maxX),
        CalendarDate(2026, 1, 1),
      );
      expect(
        balanceChartDateAt(9999, size, minX: minX, maxX: maxX),
        CalendarDate(2026, 1, 11),
      );
    });
  });

  group('layoutBandLabels', () {
    final minX = CalendarDate(
      2026,
      1,
      1,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
    final maxX = CalendarDate(
      2026,
      1,
      3,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();

    List<BandLabel> layout(
      BalanceChartData d, {
      double height = 328,
      double maxY = 30,
    }) => layoutBandLabels(
      d,
      Size(456, height),
      minX: minX,
      maxX: maxX,
      minY: -6,
      maxY: maxY,
    );

    test('labels every band that is thick enough, own band with "(own)"', () {
      final labels = layout(_data());
      expect(
        labels.map((l) => (l.text.text as TextSpan).text),
        containsAll(['Bank A', 'Bank B (own)']),
      );
    });

    test('a band under the shared minimum share gets no label', () {
      final data = BalanceChartData(
        dates: [
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 1, 2),
          CalendarDate(2026, 1, 3),
        ],
        todayIndex: 2,
        series: const [
          BalanceChartSeries(
            containerId: 'big',
            label: 'Big',
            icon: null,
            colorIndex: 0,
            isOwn: false,
            positive: [1000, 1000, 1000],
            debt: [0, 0, 0],
          ),
          BalanceChartSeries(
            containerId: 'tiny',
            label: 'Tiny',
            icon: null,
            colorIndex: 1,
            isOwn: false,
            positive: [1, 1, 1],
            debt: [0, 0, 0],
          ),
        ],
        net: const [1001, 1001, 1001],
        unitAssetId: 'eur',
        unpricedAssetIds: const {},
      );
      final labels = layoutBandLabels(
        data,
        const Size(456, 328),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: 1100,
      );
      final names = labels.map((l) => (l.text.text as TextSpan).text).toList();
      expect(names, ['Big']);
    });

    test('a band too thin in pixels to hold a line of text is skipped', () {
      final data = BalanceChartData(
        dates: [CalendarDate(2026, 1, 1), CalendarDate(2026, 1, 3)],
        todayIndex: 1,
        series: const [
          BalanceChartSeries(
            containerId: 'a',
            label: 'A',
            icon: null,
            colorIndex: 0,
            isOwn: false,
            positive: [10, 10],
            debt: [0, 0],
          ),
          BalanceChartSeries(
            containerId: 'b',
            label: 'B',
            icon: null,
            colorIndex: 1,
            isOwn: false,
            positive: [1, 1],
            debt: [0, 0],
          ),
        ],
        net: const [11, 11],
        unitAssetId: 'eur',
        unpricedAssetIds: const {},
      );
      final labels = layoutBandLabels(
        data,
        const Size(456, 68),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: 30,
      );
      expect(labels.map((l) => (l.text.text as TextSpan).text), ['A']);
    });

    test('label sits vertically inside its own band', () {
      final labels = layout(_data(), maxY: 30);
      final a = labels.firstWhere((l) => l.series.containerId == 'a');
      expect(a.center.dy, closeTo(300 * (30 - 6) / 36, 0.01));
    });
  });

  testWidgets('the cursor shows the selected date on top and moves only via '
      'its handle', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    CalendarDate? moved;
    await _pump(
      tester,
      data: _data(),
      asOf: CalendarDate(2026, 1, 2),
      onAsOfChanged: (d) => moved = d,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('asOfCursorBadge')),
        matching: find.text('2026-1-2'),
      ),
      findsOneWidget,
    );

    await tester.drag(find.byType(LineChart), const Offset(-120, 0));
    await tester.pump();
    expect(moved, isNull);

    await tester.drag(
      find.byKey(const ValueKey('asOfCursorHandle')),
      const Offset(250, 0),
    );
    await tester.pump();
    expect(moved, isNotNull);
    expect(moved!.isAfter(CalendarDate(2026, 1, 2)), isTrue);
  });

  test('all labels share one x, anchored at today', () {
    final minX = CalendarDate(
      2026,
      1,
      1,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
    final maxX = CalendarDate(
      2026,
      1,
      3,
    ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
    final labels = layoutBandLabels(
      _data(todayIndex: 1),
      const Size(456, 328),
      minX: minX,
      maxX: maxX,
      minY: -6,
      maxY: 30,
    );
    expect(labels.length, greaterThan(1));
    for (final l in labels) {
      expect(l.center.dx, closeTo(56 + 200, 0.01));
    }
  });

  testWidgets('legend chips carry the container icon', (tester) async {
    final data = BalanceChartData(
      dates: [CalendarDate(2026, 1, 1), CalendarDate(2026, 1, 2)],
      todayIndex: 1,
      series: const [
        BalanceChartSeries(
          containerId: 'a',
          label: 'Bank A',
          icon: 'fa:piggyBank',
          colorIndex: 0,
          isOwn: false,
          positive: [1, 2],
          debt: [0, 0],
        ),
      ],
      net: const [1, 2],
      unitAssetId: 'eur',
      unpricedAssetIds: const {},
    );
    await _pump(tester, data: data);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('balance-legend-a')),
        matching: find.byType(ContainerName),
      ),
      findsOneWidget,
    );
  });

  group('hover tooltip', () {
    Future<void> hoverAt(WidgetTester tester, double fx, double fy) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final data = BalanceChartData(
        dates: [
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 1, 2),
          CalendarDate(2026, 1, 3),
        ],
        todayIndex: 2,
        series: const [
          BalanceChartSeries(
            containerId: 'a',
            label: 'Bank A',
            icon: 'fa:piggyBank',
            colorIndex: 0,
            isOwn: false,
            positive: [10, 10, 10],
            debt: [0, 0, 0],
          ),
          BalanceChartSeries(
            containerId: 'b',
            label: 'Bank B',
            icon: null,
            colorIndex: 1,
            isOwn: false,
            positive: [10, 10, 10],
            debt: [0, 0, 0],
          ),
        ],
        net: const [20, 20, 20],
        unitAssetId: 'eur',
        unpricedAssetIds: const {},
      );
      await _pump(tester, data: data);
      final rect = tester.getRect(find.byType(LineChart));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      final plot = Rect.fromLTRB(
        rect.left + 56,
        rect.top,
        rect.right,
        rect.bottom - 28,
      );
      await gesture.moveTo(
        Offset(plot.left + plot.width * fx, plot.top + plot.height * fy),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('over one container only that container is shown, with its '
        'icon', (tester) async {
      await hoverAt(tester, 0.5, 0.85);
      final tip = find.byKey(const ValueKey('balanceChartTooltip'));
      expect(tip, findsOneWidget);
      expect(
        find.descendant(
          of: tip,
          matching: find.textContaining('Bank A', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tip,
          matching: find.textContaining('Bank B', findRichText: true),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: tip, matching: find.byType(ContainerIcon)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tip,
          matching: find.textContaining('Net', findRichText: true),
        ),
        findsNothing,
      );
    });

    testWidgets('outside every band all containers and Net are shown', (
      tester,
    ) async {
      await hoverAt(tester, 0.5, 0.02);
      final tip = find.byKey(const ValueKey('balanceChartTooltip'));
      expect(tip, findsOneWidget);
      for (final t in ['Bank A', 'Bank B', 'Net']) {
        expect(
          find.descendant(
            of: tip,
            matching: find.textContaining(t, findRichText: true),
          ),
          findsOneWidget,
          reason: t,
        );
      }
    });
  });

  test(
    'a band label with an icon reserves room for it and sits on the label x',
    () {
      final minX = CalendarDate(
        2026,
        1,
        1,
      ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
      final maxX = CalendarDate(
        2026,
        1,
        3,
      ).toUtcDateTime().millisecondsSinceEpoch.toDouble();
      final data = BalanceChartData(
        dates: [
          CalendarDate(2026, 1, 1),
          CalendarDate(2026, 1, 2),
          CalendarDate(2026, 1, 3),
        ],
        todayIndex: 1,
        series: const [
          BalanceChartSeries(
            containerId: 'a',
            label: 'Bank A',
            icon: 'fa:piggyBank',
            colorIndex: 0,
            isOwn: false,
            positive: [10, 10, 10],
            debt: [0, 0, 0],
          ),
          BalanceChartSeries(
            containerId: 'b',
            label: 'Bank B',
            icon: null,
            colorIndex: 1,
            isOwn: false,
            positive: [10, 10, 10],
            debt: [0, 0, 0],
          ),
        ],
        net: const [20, 20, 20],
        unitAssetId: 'eur',
        unpricedAssetIds: const {},
      );
      final labels = layoutBandLabels(
        data,
        const Size(456, 328),
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: 22,
      );
      final a = labels.firstWhere((l) => l.series.containerId == 'a');
      final b = labels.firstWhere((l) => l.series.containerId == 'b');
      expect(a.hasIcon, isTrue);
      expect(b.hasIcon, isFalse);
      expect(a.blockWidth, greaterThan(a.text.width));
      expect(a.center.dx, b.center.dx);
    },
  );
}
