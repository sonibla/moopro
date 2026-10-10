import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/domain_cache_database.dart' as ldb;
import '../domain/balance_chart_data.dart';
import '../domain/calendar_date.dart';
import '../domain/models.dart';
import '../providers/app_providers.dart';
import 'asset_view_controls.dart';
import 'amount_text.dart' show kHiddenAmount;
import 'balance_chart_card.dart';

class BalanceChartSection extends ConsumerStatefulWidget {
  final String? title;

  final List<ldb.Container> containers;
  final List<ldb.Asset> assets;
  final String displayAssetId;
  final AssetFilter? assetFilter;

  final String? focusId;
  final ValueChanged<String?> onFocusChanged;

  final CalendarDate asOf;
  final ValueChanged<CalendarDate> onAsOfChanged;

  final double? chartHeight;

  final bool expandChart;
  final bool showLegend;

  const BalanceChartSection({
    super.key,
    this.title,
    required this.containers,
    required this.assets,
    required this.displayAssetId,
    required this.assetFilter,
    required this.focusId,
    required this.onFocusChanged,
    required this.asOf,
    required this.onAsOfChanged,
    this.chartHeight,
    this.expandChart = false,
    this.showLegend = true,
  });

  @override
  ConsumerState<BalanceChartSection> createState() =>
      _BalanceChartSectionState();
}

class _BalanceChartSectionState extends ConsumerState<BalanceChartSection> {
  BalanceRange _range = BalanceRange.year;
  BalanceHorizon _horizon = BalanceHorizon.threeMonths;

  List<Object?>? _memoKey;
  BalanceChartData? _memo;

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionsStreamProvider);
    final templates = ref.watch(recurringTemplatesStreamProvider);
    final prices = ref.watch(priceSnapshotsStreamProvider);
    final prefs = ref.watch(dateTimeFormatPrefsProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);

    final error = txs.error ?? templates.error ?? prices.error;
    final display = widget.assets
        .where((a) => a.id == widget.displayAssetId)
        .firstOrNull;

    BalanceChartData? data;
    if (error == null &&
        txs.hasValue &&
        templates.hasValue &&
        prices.hasValue) {
      data = _compute(
        txs.requireValue,
        templates.requireValue,
        prices.requireValue,
      );
    }

    final focusId = _focusId;
    final focus = focusId == null
        ? null
        : widget.containers.where((c) => c.id == focusId).firstOrNull;

    final unit = data == null
        ? display
        : widget.assets.where((a) => a.id == data!.unitAssetId).firstOrNull;
    final decimals = unit?.kind == AssetKind.crypto.name ? 8 : 2;

    String? unpricedNote;
    if (data != null && data.unpricedAssetIds.isNotEmpty) {
      final names = [
        for (final id in data.unpricedAssetIds)
          widget.assets.where((a) => a.id == id).firstOrNull?.symbol ?? id,
      ]..sort();
      unpricedNote =
          'No ${display?.symbol ?? ''} price on some dates, left out: '
          '${names.join(', ')}';
    }

    return BalanceChartCard(
      title: widget.title,
      data: data,
      errorMessage: error?.toString(),
      hideAmounts: hideAmounts,
      valueLabel: (v) => hideAmounts
          ? '$kHiddenAmount ${unit?.symbol ?? ''}'.trim()
          : '${v.toStringAsFixed(decimals)} ${unit?.symbol ?? ''}'.trim(),
      dateLabel: prefs.formatCalendarDate,
      range: _range,
      onRangeChanged: (r) => setState(() => _range = r),
      horizon: _horizon,
      onHorizonChanged: (h) => setState(() => _horizon = h),
      onBandTap: _drillInto,
      asOf: widget.asOf,
      onAsOfChanged: widget.onAsOfChanged,
      focusLabel: widget.title == null ? null : focus?.name,
      onBack: widget.title == null || focus == null
          ? null
          : () => widget.onFocusChanged(focus.parentId),
      unpricedNote: unpricedNote,
      chartHeight: widget.chartHeight ?? 260,
      expandChart: widget.expandChart,
      showLegend: widget.showLegend,
    );
  }

  String? get _focusId => widget.containers.any((c) => c.id == widget.focusId)
      ? widget.focusId
      : null;

  void _drillInto(String containerId) {
    if (containerId == _focusId) return;
    widget.onFocusChanged(containerId);
  }

  BalanceChartData _compute(
    List<ldb.Transaction> txs,
    List<ldb.RecurringTransactionTemplate> templates,
    List<ldb.PriceSnapshot> prices,
  ) {
    final today = CalendarDate.today();
    final focusId = _focusId;
    final key = <Object?>[
      txs,
      templates,
      prices,
      widget.containers,
      widget.displayAssetId,
      widget.assetFilter,
      _range,
      _horizon,
      focusId,
      today,
    ];
    if (_memo != null && _memoKey != null && _sameKey(_memoKey!, key)) {
      return _memo!;
    }

    final forecaster = ref.read(balanceForecasterProvider)
      ..update(transactions: txs, templates: templates, today: today);
    final end = today.addDays(_horizon.days);
    forecaster.ensureHorizon(end);
    final start = _range.days != null
        ? today.addDays(-_range.days!)
        : (forecaster.earliestDay ?? today.addDays(-30));

    final assetsById = {for (final a in widget.assets) a.id: a};
    final filter = widget.assetFilter;
    final data = buildBalanceChartData(
      forecaster: forecaster,
      containers: widget.containers,
      priceSnapshots: prices,
      displayAssetId: widget.displayAssetId,
      includeAsset: switch (filter) {
        null => (_) => true,
        SingleAssetFilter(:final assetId) => (id) => id == assetId,
        AssetKindFilterSelection(:final kind) =>
          (id) => assetsById[id]?.kind == kind.name,
      },
      rawUnitAssetId: filter is SingleAssetFilter ? filter.assetId : null,
      start: start.isAfter(today) ? today : start,
      end: end,
      focusId: focusId,
    );
    _memoKey = key;
    return _memo = data;
  }

  bool _sameKey(List<Object?> a, List<Object?> b) {
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
    }
    return true;
  }
}
