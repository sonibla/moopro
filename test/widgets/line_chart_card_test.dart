import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/widgets/line_chart_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<LineChartPoint> points, {
    bool loading = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LineChartCard(
            title: 'Price history',
            points: points,
            loading: loading,
            valueLabel: (v) => '${v.toStringAsFixed(2)} EUR',
            dateLabel: (d) =>
                '${d.year}-${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}',
          ),
        ),
      ),
    );
  }

  testWidgets('shows a loading indicator while loading', (tester) async {
    await pump(tester, const [], loading: true);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('shows an empty state for no points', (tester) async {
    await pump(tester, const []);
    expect(find.text('No price history yet'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders a chart for two or more points, title shown', (
    tester,
  ) async {
    await pump(tester, [
      LineChartPoint(date: DateTime.utc(2026, 1, 1), value: 170),
      LineChartPoint(date: DateTime.utc(2026, 1, 20), value: 180),
    ]);
    expect(find.text('Price history'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('renders without throwing for a single point (padded x/y span)', (
    tester,
  ) async {
    await pump(tester, [
      LineChartPoint(date: DateTime.utc(2026, 1, 1), value: 170),
    ]);
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without throwing for a flat series (equal values)', (
    tester,
  ) async {
    await pump(tester, [
      LineChartPoint(date: DateTime.utc(2026, 1, 1), value: 100),
      LineChartPoint(date: DateTime.utc(2026, 1, 10), value: 100),
    ]);
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sorts unsorted points before charting (no exception, still '
      'renders)', (tester) async {
    await pump(tester, [
      LineChartPoint(date: DateTime.utc(2026, 1, 20), value: 180),
      LineChartPoint(date: DateTime.utc(2026, 1, 1), value: 170),
    ]);
    expect(find.byType(LineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
