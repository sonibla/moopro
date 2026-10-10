import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../domain/balance_chart_data.dart';
import '../domain/calendar_date.dart';
import '../domain/chart_ticks.dart';
import 'container_icon.dart';
import 'pie_chart_card.dart'
    show categoricalColor, kMinLabelShare, neutralChartColor;

Color _seriesColor(BalanceChartSeries s, Brightness b) =>
    s.isOwn ? neutralChartColor(b) : categoricalColor(s.colorIndex);

enum BalanceRange {
  month('1M', 30),
  sixMonths('6M', 182),
  year('1Y', 365),
  all('All', null);

  final String label;
  final int? days;
  const BalanceRange(this.label, this.days);
}

enum BalanceHorizon {
  none('No forecast', 0),
  threeMonths('+3M', 91),
  year('+1Y', 365);

  final String label;
  final int days;
  const BalanceHorizon(this.label, this.days);
}

const double _chartHeight = 260;

const double _cursorHeader = 26;
const double _leftReserved = 56;
const double _bottomReserved = 28;

const double _tickSpacing = 72;
const double _tickLabelW = 64;

Widget _noTitle(double value, TitleMeta meta) => const SizedBox.shrink();

@visibleForTesting
String compactAmount(double v) {
  final a = v.abs();
  String trim(double x) =>
      x.toStringAsFixed(x >= 100 ? 0 : 1).replaceFirst(RegExp(r'\.0$'), '');
  if (a >= 1e9) return '${trim(v / 1e9)}B';
  if (a >= 1e6) return '${trim(v / 1e6)}M';
  if (a >= 1e3) return '${trim(v / 1e3)}k';
  return trim(v);
}

class BalanceChartCard extends StatelessWidget {
  final String? title;
  final BalanceChartData? data;
  final String? errorMessage;
  final String Function(double value) valueLabel;
  final String Function(CalendarDate date) dateLabel;

  final BalanceRange range;
  final ValueChanged<BalanceRange> onRangeChanged;
  final BalanceHorizon horizon;
  final ValueChanged<BalanceHorizon> onHorizonChanged;

  final ValueChanged<String> onBandTap;

  final CalendarDate? asOf;
  final ValueChanged<CalendarDate>? onAsOfChanged;

  final String? focusLabel;
  final VoidCallback? onBack;

  final String? unpricedNote;

  final double chartHeight;

  final bool expandChart;

  final bool showLegend;

  final bool hideAmounts;

  const BalanceChartCard({
    super.key,
    this.title,
    required this.data,
    required this.valueLabel,
    required this.dateLabel,
    required this.range,
    required this.onRangeChanged,
    required this.horizon,
    required this.onHorizonChanged,
    required this.onBandTap,
    this.asOf,
    this.onAsOfChanged,
    this.errorMessage,
    this.focusLabel,
    this.onBack,
    this.unpricedNote,
    this.chartHeight = _chartHeight,
    this.expandChart = false,
    this.showLegend = true,
    this.hideAmounts = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final current = data;

    Widget body;
    if (errorMessage != null) {
      body = Center(
        child: Text('Failed to load chart: $errorMessage', style: muted),
      );
    } else if (current == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (current.isEmpty) {
      body = Center(child: Text('No balance history yet', style: muted));
    } else {
      body = _Chart(
        data: current,
        valueLabel: valueLabel,
        dateLabel: dateLabel,
        onBandTap: onBandTap,
        asOf: asOf,
        onAsOfChanged: onAsOfChanged,
        hideAmounts: hideAmounts,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || onBack != null)
              Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack,
                    ),
                  Expanded(
                    child: Text(
                      focusLabel == null
                          ? title ?? ''
                          : '${title ?? ''} · $focusLabel',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            if (title != null || onBack != null) const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SegmentedButton<BalanceRange>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in BalanceRange.values)
                      ButtonSegment(value: r, label: Text(r.label)),
                  ],
                  selected: {range},
                  onSelectionChanged: (s) => onRangeChanged(s.first),
                ),
                SegmentedButton<BalanceHorizon>(
                  showSelectedIcon: false,
                  segments: [
                    for (final h in BalanceHorizon.values)
                      ButtonSegment(value: h, label: Text(h.label)),
                  ],
                  selected: {horizon},
                  onSelectionChanged: (s) => onHorizonChanged(s.first),
                ),
              ],
            ),
            if (current != null && !current.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${dateLabel(current.dates.first)} – '
                '${dateLabel(current.dates.last)}',
                key: const ValueKey('balanceChartRange'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (expandChart)
              Expanded(child: body)
            else
              SizedBox(height: chartHeight + _cursorHeader, child: body),
            if (showLegend && current != null && !current.isEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in current.series)
                    ActionChip(
                      key: ValueKey('balance-legend-${s.containerId}'),
                      avatar: CircleAvatar(
                        backgroundColor: _seriesColor(s, theme.brightness),
                        radius: 6,
                      ),
                      label: ContainerName(
                        s.isOwn ? '${s.label} (own)' : s.label,
                        icon: s.icon,
                      ),
                      onPressed: () => onBandTap(s.containerId),
                    ),
                ],
              ),
            ],
            if (unpricedNote != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      unpricedNote!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Extent {
  final double minX, maxX, minY, maxY;
  const _Extent(this.minX, this.maxX, this.minY, this.maxY);
}

double _x(CalendarDate d) =>
    d.toUtcDateTime().millisecondsSinceEpoch.toDouble();

_Extent _extentOf(BalanceChartData data) {
  final oneDay = const Duration(days: 1).inMilliseconds.toDouble();
  var minX = _x(data.dates.first);
  var maxX = _x(data.dates.last);
  if (minX == maxX) {
    minX -= oneDay;
    maxX += oneDay;
  }
  var top = 0.0;
  var bottom = 0.0;
  for (var i = 0; i < data.dates.length; i++) {
    var up = 0.0;
    var down = 0.0;
    for (final s in data.series) {
      up += s.positive[i];
      down += s.debt[i];
    }
    top = math.max(top, up);
    bottom = math.min(bottom, down);
  }
  final span = top - bottom;
  final pad = span == 0 ? 1.0 : span * 0.08;
  return _Extent(minX, maxX, bottom == 0 ? 0 : bottom - pad, top + pad);
}

@visibleForTesting
int nearestSampleIndexFor(BalanceChartData data, CalendarDate day) {
  final target = _x(day);
  var index = 0;
  var best = double.infinity;
  for (var i = 0; i < data.dates.length; i++) {
    final d = (_x(data.dates[i]) - target).abs();
    if (d < best) {
      best = d;
      index = i;
    }
  }
  return index;
}

@visibleForTesting
String? balanceChartHit(
  BalanceChartData data,
  Offset position,
  Size size, {
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
}) {
  final plotW = size.width - _leftReserved;
  final plotH = size.height - _bottomReserved;
  if (plotW <= 0 || plotH <= 0) return null;
  if (position.dx < _leftReserved || position.dy > plotH || position.dy < 0) {
    return null;
  }
  final xMs = minX + (position.dx - _leftReserved) / plotW * (maxX - minX);
  var nearest = 0;
  var best = double.infinity;
  for (var i = 0; i < data.dates.length; i++) {
    final dist = (_x(data.dates[i]) - xMs).abs();
    if (dist < best) {
      best = dist;
      nearest = i;
    }
  }
  final y = maxY - position.dy / plotH * (maxY - minY);
  return bandAt(data, nearest, y);
}

@visibleForTesting
CalendarDate balanceChartDateAt(
  double dx,
  Size size, {
  required double minX,
  required double maxX,
}) {
  final plotW = math.max(1.0, size.width - _leftReserved);
  final t = ((dx - _leftReserved) / plotW).clamp(0.0, 1.0);
  const dayMs = 86400000.0;
  final days = ((t * (maxX - minX)) / dayMs).round();
  return CalendarDate.fromDateTime(
    DateTime.fromMillisecondsSinceEpoch(
      (minX + days * dayMs).round(),
      isUtc: true,
    ),
  );
}

const double _bandLabelBaseFont = 11;
const double _bandLabelMinFont = 7;

const double _bandLabelEdgePad = 10;

@visibleForTesting
class BandLabel {
  final BalanceChartSeries series;
  final TextPainter text;

  final Offset center;
  final double fontSize;

  final double iconExtent;
  const BandLabel(
    this.series,
    this.text,
    this.center, {
    this.fontSize = _bandLabelBaseFont,
    this.iconExtent = 0,
  });

  double get blockWidth => text.width + iconExtent;
  bool get hasIcon => iconExtent > 0;
  Offset get textTopLeft =>
      center - Offset(blockWidth / 2 - iconExtent, text.height / 2);
  Offset get iconTopLeft => center - Offset(blockWidth / 2, fontSize / 2);
}

@visibleForTesting
List<BandLabel> layoutBandLabels(
  BalanceChartData data,
  Size size, {
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  Color color = Colors.white,
}) {
  final plotW = size.width - _leftReserved;
  final plotH = size.height - _bottomReserved;
  if (plotW <= 0 ||
      plotH <= 0 ||
      maxY <= minY ||
      maxX <= minX ||
      data.dates.isEmpty) {
    return const [];
  }
  double py(double y) => plotH * (maxY - y) / (maxY - minY);
  final index = data.todayIndex >= 0 ? data.todayIndex : 0;
  final anchorX =
      _leftReserved + (_x(data.dates[index]) - minX) / (maxX - minX) * plotW;

  var stackTotal = 0.0;
  for (final o in data.series) {
    stackTotal += o.positive[index] + o.debt[index].abs();
  }
  if (stackTotal <= 0) return const [];

  final result = <BandLabel>[];
  for (final sign in const [1, -1]) {
    var edge = 0.0;
    for (final s in data.series) {
      final value = (sign == 1 ? s.positive : s.debt)[index];
      final mid = edge + value / 2;
      edge += value;
      final thickness = value.abs();
      if (thickness == 0 || thickness / stackTotal < kMinLabelShare) continue;

      final pixelHeight = thickness / (maxY - minY) * plotH;
      var font = _bandLabelBaseFont;
      TextPainter layoutAt(double f) => TextPainter(
        text: TextSpan(
          text: s.isOwn ? '${s.label} (own)' : s.label,
          style: TextStyle(
            fontSize: f,
            fontWeight: FontWeight.w600,
            color: color,
            shadows: const [Shadow(blurRadius: 2, color: Color(0x66000000))],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      var tp = layoutAt(font);
      while (tp.height * 1.1 > pixelHeight && font > _bandLabelMinFont) {
        font -= 1;
        tp = layoutAt(font);
      }
      if (tp.height > pixelHeight) continue;

      final iconExtent = ContainerIconKey.parse(s.icon) != null
          ? font * 1.3
          : 0.0;
      final half = (tp.width + iconExtent) / 2;
      final cx = anchorX
          .clamp(
            _leftReserved + half,
            math.max(
              _leftReserved + half,
              size.width - _bandLabelEdgePad - half,
            ),
          )
          .toDouble();
      result.add(
        BandLabel(
          s,
          tp,
          Offset(cx, py(mid)),
          fontSize: font,
          iconExtent: iconExtent,
        ),
      );
    }
  }
  return result;
}

class _CursorOverlay extends StatefulWidget {
  final double px;
  final double width;
  final double plotBottom;
  final String label;
  final ValueChanged<double>? onDragTo;

  const _CursorOverlay({
    required this.px,
    required this.width,
    required this.plotBottom,
    required this.label,
    required this.onDragTo,
  });

  @override
  State<_CursorOverlay> createState() => _CursorOverlayState();
}

class _CursorOverlayState extends State<_CursorOverlay> {
  static const _badgeW = 120.0;
  static const _handle = 40.0;
  double? _dragPx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final px = widget.px;
    final badgeLeft = (px - _badgeW / 2)
        .clamp(0.0, math.max(0.0, widget.width - _badgeW))
        .toDouble();
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            key: const ValueKey('asOfCursorBadge'),
            left: badgeLeft,
            top: 0,
            width: _badgeW,
            height: _cursorHeader - 2,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment(
                  (px - badgeLeft - _badgeW / 2) / (_badgeW / 2),
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: px - _handle / 2,
            top: widget.plotBottom - _handle + 1,
            width: _handle,
            height: _handle,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                key: const ValueKey('asOfCursorHandle'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _dragPx = px,
                onHorizontalDragUpdate: (d) {
                  final next = (_dragPx ?? px) + d.delta.dx;
                  _dragPx = next;
                  widget.onDragTo?.call(next);
                },
                onHorizontalDragEnd: (_) => _dragPx = null,
                onHorizontalDragCancel: () => _dragPx = null,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.cardColor, width: 2),
                  ),
                  child: Icon(
                    Icons.swap_horiz,
                    size: 22,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BandLabelPainter extends CustomPainter {
  final List<BandLabel> labels;
  const _BandLabelPainter(this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in labels) {
      l.text.paint(canvas, l.textTopLeft);
    }
  }

  @override
  bool shouldRepaint(covariant _BandLabelPainter old) => true;
}

bool _hiddenExtreme(double value, TitleMeta meta) {
  if (value != meta.min && value != meta.max) return false;
  final steps = value / meta.appliedInterval;
  return (steps - steps.roundToDouble()).abs() > 0.02;
}

class _Chart extends StatefulWidget {
  final BalanceChartData data;
  final String Function(double value) valueLabel;
  final String Function(CalendarDate date) dateLabel;
  final ValueChanged<String> onBandTap;
  final CalendarDate? asOf;
  final ValueChanged<CalendarDate>? onAsOfChanged;
  final bool hideAmounts;

  const _Chart({
    required this.data,
    required this.valueLabel,
    required this.dateLabel,
    required this.onBandTap,
    required this.hideAmounts,
    this.asOf,
    this.onAsOfChanged,
  });

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  final ValueNotifier<_Hover?> _hover = ValueNotifier(null);

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ChartBody(
    data: widget.data,
    valueLabel: widget.valueLabel,
    dateLabel: widget.dateLabel,
    onBandTap: widget.onBandTap,
    asOf: widget.asOf,
    onAsOfChanged: widget.onAsOfChanged,
    hideAmounts: widget.hideAmounts,
    hover: _hover,
  );
}

class _ChartBody extends StatelessWidget {
  final ValueNotifier<_Hover?> hover;
  final BalanceChartData data;
  final String Function(double value) valueLabel;
  final String Function(CalendarDate date) dateLabel;
  final ValueChanged<String> onBandTap;
  final CalendarDate? asOf;
  final ValueChanged<CalendarDate>? onAsOfChanged;
  final bool hideAmounts;

  const _ChartBody({
    required this.data,
    required this.valueLabel,
    required this.dateLabel,
    required this.onBandTap,
    required this.hover,
    required this.hideAmounts,
    this.asOf,
    this.onAsOfChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisColor = theme.colorScheme.onSurfaceVariant;
    final gridColor = theme.dividerColor.withValues(alpha: 0.3);
    final ext = _extentOf(data);

    final bars = <LineChartBarData>[];
    final between = <BetweenBarsData>[];

    final last = data.dates.length - 1;
    final segments = <({int from, int to, bool future})>[
      if (data.todayIndex >= 0) (from: 0, to: data.todayIndex, future: false),
      if (data.todayIndex < last)
        (from: math.max(data.todayIndex, 0), to: last, future: true),
    ];

    LineChartBarData line(
      List<double> ys,
      int from,
      int to, {
      required Color color,
      required double width,
      required bool dashed,
    }) => LineChartBarData(
      spots: [
        for (var i = from; i <= to; i++)
          FlSpot(_x(data.dates[i]), ys[i - from]),
      ],
      isCurved: false,
      color: color,
      barWidth: width,
      dotData: const FlDotData(show: false),
      dashArray: dashed ? [5, 4] : null,
    );

    for (final seg in segments) {
      final n = seg.to - seg.from + 1;
      final zeroIndex = bars.length;
      bars.add(
        line(
          List.filled(n, 0),
          seg.from,
          seg.to,
          color: axisColor.withValues(alpha: 0.5),
          width: 1,
          dashed: false,
        ),
      );

      for (final sign in const [1, -1]) {
        final cumulative = List<double>.filled(n, 0);
        var previous = zeroIndex;
        for (final s in data.series) {
          final values = sign == 1 ? s.positive : s.debt;
          if (values.every((v) => v == 0)) continue;
          for (var i = 0; i < n; i++) {
            cumulative[i] += values[seg.from + i];
          }
          final color = _seriesColor(s, theme.brightness);
          bars.add(
            line(
              [...cumulative],
              seg.from,
              seg.to,
              color: color,
              width: 1.5,
              dashed: seg.future,
            ),
          );
          between.add(
            BetweenBarsData(
              fromIndex: previous,
              toIndex: bars.length - 1,
              color: color.withValues(alpha: seg.future ? 0.25 : 0.6),
            ),
          );
          previous = bars.length - 1;
        }
      }

      bars.add(
        line(
          [for (var i = seg.from; i <= seg.to; i++) data.net[i]],
          seg.from,
          seg.to,
          color: theme.colorScheme.onSurface,
          width: 2,
          dashed: seg.future,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth,
          constraints.maxHeight - _cursorHeader,
        );
        final labels = layoutBandLabels(
          data,
          size,
          minX: ext.minX,
          maxX: ext.maxX,
          minY: ext.minY,
          maxY: ext.maxY,
        );
        final cursor = asOf;
        final cursorX = cursor == null
            ? null
            : _x(cursor).clamp(ext.minX, ext.maxX).toDouble();
        final plotW = size.width - _leftReserved;
        final ticks = dateTicks(
          data.dates.first,
          data.dates.last,
          maxTicks: (plotW / _tickSpacing).floor().clamp(2, 10),
        );
        double tickPx(CalendarDate d) =>
            _leftReserved + (_x(d) - ext.minX) / (ext.maxX - ext.minX) * plotW;
        final cursorPx = cursorX == null
            ? null
            : _leftReserved +
                  (cursorX - ext.minX) / (ext.maxX - ext.minX) * plotW;

        final chart = LineChart(
          LineChartData(
            minX: ext.minX,
            maxX: ext.maxX,
            minY: ext.minY,
            maxY: ext.maxY,
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
                  reservedSize: _leftReserved,
                  getTitlesWidget: (value, meta) =>
                      hideAmounts || _hiddenExtreme(value, meta)
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            compactAmount(value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: axisColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                ),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _bottomReserved,
                  getTitlesWidget: _noTitle,
                ),
              ),
            ),
            betweenBarsData: between,
            extraLinesData: ExtraLinesData(
              verticalLines: [
                for (final t in ticks)
                  VerticalLine(x: _x(t.date), color: gridColor, strokeWidth: 1),
                if (cursorX != null)
                  VerticalLine(
                    x: cursorX,
                    color: theme.colorScheme.primary,
                    strokeWidth: 2,
                  ),
              ],
            ),
            lineTouchData: LineTouchData(
              touchCallback: (event, response) {
                final pos = event.localPosition;
                if (pos == null ||
                    event is FlPointerExitEvent ||
                    event is FlPanEndEvent ||
                    event is FlLongPressEnd ||
                    event is FlTapCancelEvent) {
                  hover.value = null;
                  return;
                }
                final over = balanceChartHit(
                  data,
                  pos,
                  size,
                  minX: ext.minX,
                  maxX: ext.maxX,
                  minY: ext.minY,
                  maxY: ext.maxY,
                );
                hover.value =
                    pos.dx >= _leftReserved &&
                        pos.dy <= size.height - _bottomReserved
                    ? _Hover(pos, over)
                    : null;
                if (event is! FlTapUpEvent) return;
                final hit = balanceChartHit(
                  data,
                  pos,
                  size,
                  minX: ext.minX,
                  maxX: ext.maxX,
                  minY: ext.minY,
                  maxY: ext.maxY,
                );
                if (hit != null) onBandTap(hit);
              },
              getTouchedSpotIndicator: (barData, indicators) => [
                for (final _ in indicators)
                  TouchedSpotIndicatorData(
                    FlLine(
                      color: axisColor.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    const FlDotData(show: false),
                  ),
              ],
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [for (final _ in spots) null],
              ),
            ),
            lineBarsData: bars,
          ),
        );
        return Stack(
          children: [
            Positioned(
              top: _cursorHeader,
              left: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                children: [
                  Positioned.fill(child: chart),
                  for (final t in ticks)
                    Positioned(
                      left: (tickPx(t.date) - _tickLabelW / 2)
                          .clamp(0.0, math.max(0.0, size.width - _tickLabelW))
                          .toDouble(),
                      width: _tickLabelW,
                      bottom: 0,
                      height: _bottomReserved,
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            t.label,
                            maxLines: 1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: axisColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BandLabelPainter(labels)),
                    ),
                  ),
                  for (final l in labels)
                    if (l.hasIcon)
                      Positioned(
                        left: l.iconTopLeft.dx,
                        top: l.iconTopLeft.dy,
                        child: IgnorePointer(
                          child: ContainerIcon(
                            l.series.icon,
                            size: l.fontSize,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  Positioned.fill(
                    child: ValueListenableBuilder<_Hover?>(
                      valueListenable: hover,
                      builder: (context, h, _) => h == null
                          ? const SizedBox.shrink()
                          : _HoverTooltip(
                              hover: h,
                              data: data,
                              size: size,
                              valueLabel: valueLabel,
                              dateLabel: dateLabel,
                              nearestIndex: (dx) => nearestSampleIndexFor(
                                data,
                                balanceChartDateAt(
                                  dx,
                                  size,
                                  minX: ext.minX,
                                  maxX: ext.maxX,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            if (cursorPx != null && cursor != null)
              _CursorOverlay(
                px: cursorPx,
                width: constraints.maxWidth,
                plotBottom: _cursorHeader + size.height - _bottomReserved,
                label: dateLabel(cursor),
                onDragTo: onAsOfChanged == null
                    ? null
                    : (dx) => onAsOfChanged!(
                        balanceChartDateAt(
                          dx,
                          size,
                          minX: ext.minX,
                          maxX: ext.maxX,
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _Hover {
  final Offset position;
  final String? containerId;
  const _Hover(this.position, this.containerId);
}

class _HoverTooltip extends StatelessWidget {
  final _Hover hover;
  final BalanceChartData data;
  final Size size;
  final String Function(double value) valueLabel;
  final String Function(CalendarDate date) dateLabel;
  final int Function(double dx) nearestIndex;

  const _HoverTooltip({
    required this.hover,
    required this.data,
    required this.size,
    required this.valueLabel,
    required this.dateLabel,
    required this.nearestIndex,
  });

  static const double _maxWidth = 240;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = nearestIndex(hover.position.dx);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onInverseSurface,
      fontSize: 12,
    );
    final only = data.series
        .where((s) => s.containerId == hover.containerId)
        .firstOrNull;

    Widget row(BalanceChartSeries s) => ContainerName(
      '${s.isOwn ? '${s.label} (own)' : s.label}: '
      '${valueLabel(s.positive[index] + s.debt[index])}',
      icon: s.icon,
      style: style,
      overflow: TextOverflow.visible,
    );

    final rows = <Widget>[
      if (only != null)
        row(only)
      else ...[
        for (final s in data.series)
          if (s.positive[index] + s.debt[index] != 0) row(s),
        Text('Net: ${valueLabel(data.net[index])}', style: style),
      ],
    ];
    final forecast = index > data.todayIndex;

    final left = (hover.position.dx + 12).clamp(
      0.0,
      math.max(0.0, size.width - _maxWidth),
    );
    final top = (hover.position.dy - 12).clamp(
      0.0,
      math.max(0.0, size.height - 40),
    );
    return Stack(
      children: [
        Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
          child: IgnorePointer(
            child: Container(
              key: const ValueKey('balanceChartTooltip'),
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${dateLabel(data.dates[index])}${forecast ? ' (forecast)' : ''}',
                    style: style,
                  ),
                  ...rows,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
