import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../db/domain_cache_database.dart' as ldb;
import 'balance_series.dart';
import 'calendar_date.dart';
import 'models.dart';
import 'recurring_projection.dart';
import 'recurring_template_mapping.dart';
import 'transaction_ordering.dart' show transactionPairKey;

class BalanceForecaster {
  List<ldb.Transaction>? _transactions;
  List<ldb.RecurringTransactionTemplate>? _templateRows;
  List<RecurringTransactionTemplate>? _templates;
  CalendarDate? _today;

  Map<String, StepSeries>? _steps;
  final Map<String, _CumulativeDeltas> _deltas = {};
  CalendarDate? _expandedUpTo;

  @visibleForTesting
  int stepBuildCount = 0;
  @visibleForTesting
  int expandedOccurrenceCount = 0;

  void update({
    required List<ldb.Transaction> transactions,
    required List<ldb.RecurringTransactionTemplate> templates,
    required CalendarDate today,
  }) {
    final day = today;
    if (!identical(transactions, _transactions)) {
      _transactions = transactions;
      _steps = null;
    }
    if (!identical(templates, _templateRows) || day != _today) {
      _templateRows = templates;
      _templates = null;
      _deltas.clear();
      _expandedUpTo = null;
    }
    _today = day;
  }

  CalendarDate get today => _today!;

  Map<String, StepSeries> get _stepSeries {
    final cached = _steps;
    if (cached != null) return cached;
    stepBuildCount++;
    return _steps = buildBalanceSeries(_transactions!);
  }

  void ensureHorizon(CalendarDate horizon) {
    final to = horizon;
    final from = _expandedUpTo ?? today;
    if (!to.isAfter(from)) return;
    _templates ??= [
      for (final r in _templateRows!) recurringTemplateFromRow(r),
    ];
    for (final occurrence in projectOccurrences(
      _templates!,
      from: from,
      to: to,
    )) {
      expandedOccurrenceCount++;
      final day = occurrence.date;
      final t = occurrence.template;
      _addDelta(t.legOut, day, negative: true);
      _addDelta(t.legIn, day, negative: false);
      if (t.budgetLegOut != null) {
        _addDelta(t.budgetLegOut!, day, negative: true);
      }
      if (t.budgetLegIn != null) {
        _addDelta(t.budgetLegIn!, day, negative: false);
      }
    }
    _expandedUpTo = to;
  }

  void _addDelta(RecurringLeg leg, CalendarDate day, {required bool negative}) {
    final key = transactionPairKey(leg.containerId, leg.assetId);
    (_deltas[key] ??= _CumulativeDeltas()).add(
      day,
      negative ? -leg.quantity : leg.quantity,
    );
  }

  Decimal quantityAt(String containerId, String assetId, CalendarDate day) {
    final key = transactionPairKey(containerId, assetId);
    final base = _stepSeries[key]?.valueAt(day) ?? Decimal.zero;
    final delta = _deltas[key]?.valueAt(day) ?? Decimal.zero;
    return base + delta;
  }

  List<({String containerId, String assetId})> pairs() {
    final keys = {..._stepSeries.keys, ..._deltas.keys};
    return [
      for (final key in keys)
        (containerId: key.split('|')[0], assetId: key.split('|')[1]),
    ];
  }

  CalendarDate? get earliestDay {
    CalendarDate? earliest;
    for (final s in _stepSeries.values) {
      final first = s.firstDay;
      if (first != null && (earliest == null || first.isBefore(earliest))) {
        earliest = first;
      }
    }
    return earliest;
  }
}

class _CumulativeDeltas {
  final List<CalendarDate> _days = [];
  final List<Decimal> _totals = [];

  void add(CalendarDate day, Decimal delta) {
    if (_days.isNotEmpty && _days.last == day) {
      _totals[_totals.length - 1] += delta;
    } else {
      _days.add(day);
      _totals.add((_totals.isEmpty ? Decimal.zero : _totals.last) + delta);
    }
  }

  Decimal valueAt(CalendarDate day) => StepSeries(_days, _totals).valueAt(day);
}
