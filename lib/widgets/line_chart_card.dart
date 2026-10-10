import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartPoint {
  final DateTime date;
  final double value;

  const LineChartPoint({required this.date, required this.value});
}

const double _cardHeight = 220;

class LineChartCard extends StatelessWidget {
  final String title;
  final List<LineChartPoint> points;
  final bool loading;

  final String Function(double value) valueLabel;

  final String Function(DateTime date) dateLabel;

  const LineChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.valueLabel,
    required this.dateLabel,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(
                height: _cardHeight,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sorted.isEmpty)
              SizedBox(
                height: _cardHeight,
                child: Center(
                  child: Text(
                    'No price history yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: _cardHeight,
                child: _Chart(
                  points: sorted,
                  valueLabel: valueLabel,
                  dateLabel: dateLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final List<LineChartPoint> points;
  final String Function(double value) valueLabel;
  final String Function(DateTime date) dateLabel;

  const _Chart({
    required this.points,
    required this.valueLabel,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisColor = theme.colorScheme.onSurfaceVariant;
    final lineColor = theme.colorScheme.primary;
    final gridColor = theme.dividerColor.withValues(alpha: 0.3);

    final xs = [
      for (final p in points) p.date.millisecondsSinceEpoch.toDouble(),
    ];
    final oneDayMs = const Duration(days: 1).inMilliseconds.toDouble();
    final minX = xs.length == 1
        ? xs.first - oneDayMs
        : xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.length == 1
        ? xs.first + oneDayMs
        : xs.reduce((a, b) => a > b ? a : b);

    final values = [for (final p in points) p.value];
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) == 0
        ? (minY.abs() * 0.1).clamp(1, double.infinity)
        : (maxY - minY) * 0.1;

    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(xs[i], points[i].value),
    ];

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY - yPad,
        maxY: maxY + yPad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  valueLabel(value),
                  style: theme.textTheme.bodySmall?.copyWith(color: axisColor),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxX - minX) / 3,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  dateLabel(DateTime.fromMillisecondsSinceEpoch(value.round())),
                  style: theme.textTheme.bodySmall?.copyWith(color: axisColor),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (barData, indicators) => [
            for (final _ in indicators)
              TouchedSpotIndicatorData(
                FlLine(
                  color: axisColor.withValues(alpha: 0.4),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 5,
                        color: lineColor,
                        strokeWidth: 0,
                      ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItems: (touchedSpots) => [
              for (final spot in touchedSpots)
                LineTooltipItem(
                  '${dateLabel(points[spot.spotIndex].date)}\n'
                  '${valueLabel(points[spot.spotIndex].value)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: lineColor,
                strokeWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
