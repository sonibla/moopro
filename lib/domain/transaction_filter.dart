import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../db/domain_cache_database.dart' as ldb;
import 'models.dart';
import 'calendar_date.dart';

enum DateScope { all, past, future, custom }

enum DateRangePreset {
  last12Months('Last 12 months'),
  yearToDate('Year to date'),
  monthToDate('Month to date');

  final String label;
  const DateRangePreset(this.label);

  DateTimeRange resolve(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      DateRangePreset.last12Months => DateTimeRange(
        start: DateTime(today.year - 1, today.month, today.day + 1),
        end: today,
      ),
      DateRangePreset.yearToDate => DateTimeRange(
        start: DateTime(today.year),
        end: today,
      ),
      DateRangePreset.monthToDate => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      ),
    };
  }
}

class TransactionFilter {
  final Set<TransactionKind> kinds;
  final String? containerId;
  final String? assetId;
  final DateScope dateScope;

  final DateTimeRange? dateRange;

  final Set<String> tags;

  final String? searchQuery;

  const TransactionFilter({
    this.kinds = const {},
    this.containerId,
    this.assetId,
    this.dateScope = DateScope.all,
    this.dateRange,
    this.tags = const {},
    this.searchQuery,
  });

  bool get isEmpty =>
      kinds.isEmpty &&
      containerId == null &&
      assetId == null &&
      dateScope == DateScope.all &&
      tags.isEmpty &&
      (searchQuery == null || searchQuery!.isEmpty);

  int get activeCount =>
      (kinds.isEmpty ? 0 : 1) +
      (containerId == null ? 0 : 1) +
      (assetId == null ? 0 : 1) +
      (dateScope == DateScope.all ? 0 : 1) +
      (tags.isEmpty ? 0 : 1) +
      (searchQuery == null || searchQuery!.isEmpty ? 0 : 1);

  TransactionFilter copyWith({
    Set<TransactionKind>? kinds,
    String? Function()? containerId,
    String? Function()? assetId,
    DateScope? dateScope,
    DateTimeRange? Function()? dateRange,
    Set<String>? tags,
    String? Function()? searchQuery,
  }) => TransactionFilter(
    kinds: kinds ?? this.kinds,
    containerId: containerId != null ? containerId() : this.containerId,
    assetId: assetId != null ? assetId() : this.assetId,
    dateScope: dateScope ?? this.dateScope,
    dateRange: dateRange != null ? dateRange() : this.dateRange,
    tags: tags ?? this.tags,
    searchQuery: searchQuery != null ? searchQuery() : this.searchQuery,
  );

  TransactionFilter withDateScope(DateScope scope, [DateTimeRange? range]) =>
      TransactionFilter(
        kinds: kinds,
        containerId: containerId,
        assetId: assetId,
        dateScope: scope,
        dateRange: scope == DateScope.custom ? range : null,
        tags: tags,
        searchQuery: searchQuery,
      );

  static const empty = TransactionFilter();
}

bool _rowTouchesContainer(ldb.Transaction row, String containerId) =>
    row.legOutContainerId == containerId ||
    row.legInContainerId == containerId ||
    row.budgetLegOutContainerId == containerId ||
    row.budgetLegInContainerId == containerId;

bool _rowTouchesAsset(ldb.Transaction row, String assetId) =>
    row.legOutAssetId == assetId ||
    row.legInAssetId == assetId ||
    row.budgetLegOutAssetId == assetId ||
    row.budgetLegInAssetId == assetId;

bool _rowHasAllTags(ldb.Transaction row, Set<String> tags) =>
    decodeTagsColumn(row.tags).toSet().containsAll(tags);

bool _rowMatchesAmount(ldb.Transaction row, String query) {
  final cleaned = query.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return false;
  final needle = cleaned.startsWith('-') ? cleaned.substring(1) : cleaned;
  if (needle.isEmpty) return false;
  final parsed = Decimal.tryParse(needle);
  for (final q in <String?>[
    row.legOutQuantity,
    row.legInQuantity,
    row.budgetLegOutQuantity,
    row.budgetLegInQuantity,
  ]) {
    if (q == null) continue;
    final text = q.startsWith('-') ? q.substring(1) : q;
    if (text.contains(needle)) return true;
    if (parsed != null && Decimal.tryParse(text) == parsed) return true;
  }
  return false;
}

bool _rowMatchesSearch(
  ldb.Transaction row,
  String query,
  Map<String, String> containerNames,
  Map<String, ldb.Asset> assetsById,
) {
  final needle = query.toLowerCase();
  if (_rowMatchesAmount(row, query)) return true;
  if ((row.note ?? '').toLowerCase().contains(needle)) return true;
  if (decodeTagsColumn(row.tags).any((t) => t.toLowerCase().contains(needle))) {
    return true;
  }
  for (final id in <String?>[
    row.legOutContainerId,
    row.legInContainerId,
    row.budgetLegOutContainerId,
    row.budgetLegInContainerId,
  ]) {
    final name = id == null ? null : containerNames[id];
    if (name != null && name.toLowerCase().contains(needle)) return true;
  }
  for (final id in <String?>[
    row.legOutAssetId,
    row.legInAssetId,
    row.budgetLegOutAssetId,
    row.budgetLegInAssetId,
  ]) {
    final asset = id == null ? null : assetsById[id];
    if (asset == null) continue;
    if (asset.symbol.toLowerCase().contains(needle) ||
        asset.name.toLowerCase().contains(needle)) {
      return true;
    }
  }
  return false;
}

List<String> allTags(List<ldb.Transaction> rows) {
  final tags = <String>{};
  for (final row in rows) {
    tags.addAll(decodeTagsColumn(row.tags));
  }
  final sorted = tags.toList()..sort();
  return sorted;
}

Map<String, int> tagUsageCounts(List<ldb.Transaction> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    for (final tag in decodeTagsColumn(row.tags).toSet()) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return counts;
}

bool _withinRange(CalendarDate date, DateTimeRange range) {
  final start = CalendarDate.fromDateTime(range.start);
  final end = CalendarDate.fromDateTime(range.end);
  return !date.isBefore(start) && !date.isAfter(end);
}

bool _matchesDateScope(
  CalendarDate date,
  TransactionFilter filter,
  DateTime now,
) {
  final day = date;
  final today = CalendarDate.fromDateTime(now);
  switch (filter.dateScope) {
    case DateScope.all:
      return true;
    case DateScope.past:
      return !day.isAfter(today);
    case DateScope.future:
      return day.isAfter(today);
    case DateScope.custom:
      final range = filter.dateRange;
      return range == null || _withinRange(date, range);
  }
}

List<ldb.Transaction> applyTransactionFilter(
  List<ldb.Transaction> rows,
  TransactionFilter filter, {
  Map<String, String> containerNames = const {},
  Map<String, ldb.Asset> assetsById = const {},
  DateTime? now,
}) {
  if (filter.isEmpty) return rows;
  return rows.where((row) {
    if (filter.kinds.isNotEmpty &&
        !filter.kinds.contains(TransactionKind.fromJson(row.kind))) {
      return false;
    }
    if (filter.containerId != null &&
        !_rowTouchesContainer(row, filter.containerId!)) {
      return false;
    }
    if (filter.assetId != null && !_rowTouchesAsset(row, filter.assetId!)) {
      return false;
    }
    if (!_matchesDateScope(row.effectiveDate, filter, now ?? DateTime.now())) {
      return false;
    }
    if (filter.tags.isNotEmpty && !_rowHasAllTags(row, filter.tags)) {
      return false;
    }
    if (filter.searchQuery != null &&
        filter.searchQuery!.isNotEmpty &&
        !_rowMatchesSearch(
          row,
          filter.searchQuery!,
          containerNames,
          assetsById,
        )) {
      return false;
    }
    return true;
  }).toList();
}
