import 'package:decimal/decimal.dart';

import '../db/domain_cache_database.dart' as ldb;
import 'balance_forecast.dart';
import 'balance_series.dart';
import 'calendar_date.dart';
import 'container_tree.dart';

class BalanceChartSeries {
  final String containerId;
  final String label;
  final String? icon;

  final int colorIndex;

  final bool isOwn;

  final List<double> positive;

  final List<double> debt;

  const BalanceChartSeries({
    required this.containerId,
    required this.label,
    required this.icon,
    required this.colorIndex,
    required this.isOwn,
    required this.positive,
    required this.debt,
  });
}

class BalanceChartData {
  final List<CalendarDate> dates;

  final int todayIndex;
  final List<BalanceChartSeries> series;

  final List<double> net;
  final String unitAssetId;

  final Set<String> unpricedAssetIds;

  const BalanceChartData({
    required this.dates,
    required this.todayIndex,
    required this.series,
    required this.net,
    required this.unitAssetId,
    required this.unpricedAssetIds,
  });

  bool get hasForecast => todayIndex < dates.length - 1;
  bool get isEmpty => series.isEmpty;
}

List<CalendarDate> sampleDates(
  CalendarDate start,
  CalendarDate end,
  CalendarDate today, {
  int maxPoints = 120,
}) {
  if (end.isBefore(start)) return [start];
  final totalDays = start.daysUntil(end);
  final step = totalDays <= maxPoints - 1
      ? 1
      : (totalDays / (maxPoints - 1)).ceil();
  final dates = <CalendarDate>{};
  for (var offset = 0; offset < totalDays; offset += step) {
    dates.add(start.addDays(offset));
  }
  dates.add(end);
  if (today.isAfter(start) && today.isBefore(end)) dates.add(today);
  return dates.toList()..sort();
}

BalanceChartData buildBalanceChartData({
  required BalanceForecaster forecaster,
  required List<ldb.Container> containers,
  required List<ldb.PriceSnapshot> priceSnapshots,
  required String displayAssetId,
  required bool Function(String assetId) includeAsset,
  String? rawUnitAssetId,
  required CalendarDate start,
  required CalendarDate end,
  String? focusId,
  int maxPoints = 120,
}) {
  final today = forecaster.today;
  final dates = sampleDates(start, end, today, maxPoints: maxPoints);
  final todayIndex = _lastIndexOnOrBefore(dates, today);
  final unitAssetId = rawUnitAssetId ?? displayAssetId;

  final prices = rawUnitAssetId == null
      ? priceSeriesByAsset(priceSnapshots, displayAssetId)
      : const <String, StepSeries>{};
  final unpriced = <String>{};

  final containerIds = {for (final c in containers) c.id};
  final ownPositive = <String, List<double>>{};
  final ownDebt = <String, List<double>>{};
  for (final pair in forecaster.pairs()) {
    if (!containerIds.contains(pair.containerId)) continue;
    if (!includeAsset(pair.assetId)) continue;
    if (rawUnitAssetId != null && pair.assetId != rawUnitAssetId) continue;
    final pos = ownPositive[pair.containerId] ??= List.filled(dates.length, 0);
    final neg = ownDebt[pair.containerId] ??= List.filled(dates.length, 0);
    final priceSeries = pair.assetId == unitAssetId
        ? null
        : prices[pair.assetId];
    for (var i = 0; i < dates.length; i++) {
      final quantity = forecaster.quantityAt(
        pair.containerId,
        pair.assetId,
        dates[i],
      );
      if (quantity == Decimal.zero) continue;
      Decimal value;
      if (pair.assetId == unitAssetId) {
        value = quantity;
      } else {
        final price = priceSeries?.valueAtOrNull(dates[i]);
        if (price == null) {
          unpriced.add(pair.assetId);
          continue;
        }
        value = quantity * price;
      }
      final v = value.toDouble();
      if (quantity > Decimal.zero) {
        pos[i] += v;
      } else {
        neg[i] += v;
      }
    }
  }

  final nodes = directChildren(focusId, containers);
  final series = <BalanceChartSeries>[];
  BalanceChartSeries? build(
    String id,
    String label,
    String? icon,
    Set<String> ids,
    bool isOwn,
    int color,
  ) {
    final pos = List<double>.filled(dates.length, 0);
    final neg = List<double>.filled(dates.length, 0);
    var any = false;
    for (final cid in ids) {
      final p = ownPositive[cid];
      final n = ownDebt[cid];
      if (p == null || n == null) continue;
      for (var i = 0; i < dates.length; i++) {
        pos[i] += p[i];
        neg[i] += n[i];
        if (p[i] != 0 || n[i] != 0) any = true;
      }
    }
    if (!any) return null;
    return BalanceChartSeries(
      containerId: id,
      label: label,
      icon: icon,
      colorIndex: color,
      isOwn: isOwn,
      positive: pos,
      debt: neg,
    );
  }

  if (focusId != null) {
    final focus = containers.where((c) => c.id == focusId).firstOrNull;
    final own = build(
      focusId,
      focus?.name ?? focusId,
      focus?.icon,
      {focusId},
      true,
      0,
    );
    if (own != null) series.add(own);
  }
  for (final node in nodes) {
    final band = build(
      node.id,
      node.name,
      node.icon,
      descendantIds(node.id, containers),
      false,
      containerColorIndex(node.id, containers),
    );
    if (band != null) series.add(band);
  }

  final net = List<double>.filled(dates.length, 0);
  for (final s in series) {
    for (var i = 0; i < dates.length; i++) {
      net[i] += s.positive[i] + s.debt[i];
    }
  }

  return BalanceChartData(
    dates: dates,
    todayIndex: todayIndex,
    series: series,
    net: net,
    unitAssetId: unitAssetId,
    unpricedAssetIds: unpriced,
  );
}

String? bandAt(BalanceChartData data, int index, double y) {
  if (index < 0 || index >= data.dates.length) return null;
  var edge = 0.0;
  if (y >= 0) {
    for (final s in data.series) {
      final next = edge + s.positive[index];
      if (s.positive[index] > 0 && y >= edge && y <= next) return s.containerId;
      edge = next;
    }
  } else {
    for (final s in data.series) {
      final next = edge + s.debt[index];
      if (s.debt[index] < 0 && y <= edge && y >= next) return s.containerId;
      edge = next;
    }
  }
  return null;
}

int _lastIndexOnOrBefore(List<CalendarDate> dates, CalendarDate today) {
  final t = today;
  var result = -1;
  for (var i = 0; i < dates.length; i++) {
    if (dates[i].isAfter(t)) break;
    result = i;
  }
  return result;
}

Map<String, StepSeries> priceSeriesByAsset(
  List<ldb.PriceSnapshot> snapshots,
  String displayAssetId,
) {
  final byAsset = <String, List<ldb.PriceSnapshot>>{};
  for (final s in snapshots) {
    if (s.deleted || s.currencyAssetId != displayAssetId) continue;
    (byAsset[s.assetId] ??= []).add(s);
  }
  return {
    for (final entry in byAsset.entries) entry.key: _toStepSeries(entry.value),
  };
}

StepSeries _toStepSeries(List<ldb.PriceSnapshot> rows) {
  rows.sort((a, b) => a.date.compareTo(b.date));
  final days = <CalendarDate>[];
  final values = <Decimal>[];
  for (final r in rows) {
    final day = CalendarDate.fromDateTime(r.date);
    final price = Decimal.parse(r.price);
    if (days.isNotEmpty && days.last == day) {
      values[values.length - 1] = price;
    } else {
      days.add(day);
      values.add(price);
    }
  }
  return StepSeries(days, values);
}
