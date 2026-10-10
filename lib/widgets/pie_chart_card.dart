import 'dart:async';
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../domain/container_tree.dart';
import '../domain/multi_asset_rollup.dart';
import 'container_icon.dart';

const List<Color> _categoricalPalette = [
  Color(0xFF6841DD),
  Color(0xFF8132DB),
  Color(0xFFA34DCB),
  Color(0xFFAD28BC),
  Color(0xFF96488D),
  Color(0xFF26808E),
  Color(0xFF1A6696),
  Color(0xFF4073CC),
  Color(0xFF5A65B8),
  Color(0xFF7364D2),
  Color(0xFF637D24),
  Color(0xFF3D7619),
  Color(0xFF3A7136),
  Color(0xFF24863C),
  Color(0xFF186544),
  Color(0xFFA74F23),
  Color(0xFF74522C),
  Color(0xFF8B7128),
  Color(0xFF716B18),
  Color(0xFF565D23),
];

Color categoricalColor(int index) =>
    _categoricalPalette[index % _categoricalPalette.length];

const double kMinLabelShare = 0.01;

Color neutralChartColor(Brightness brightness) => _focusRingColor(brightness);

const double _minChartSize = 300;
const double _maxChartSize = 760;

Color _otherColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF5A5A5A)
    : const Color(0xFFB0B0B0);

Color _focusRingColor(Brightness brightness) => _otherColor(brightness);

@visibleForTesting
double labelChordWidth(PieWedge w, double midRadius) =>
    2 * midRadius * sin(min(w.sweepAngle, pi) / 2);

@visibleForTesting
class PieFoldEntry {
  final String label;
  final double value;
  final PieTreeNode? node;
  final bool isUnassigned;

  final bool isDebt;

  const PieFoldEntry({
    required this.label,
    required this.value,
    this.node,
    this.isUnassigned = false,
    this.isDebt = false,
  });

  String? get icon => node?.icon;
}

class _RawSlice {
  final String label;
  final double value;
  final PieTreeNode? node;
  final bool isUnassigned;
  final bool isDebt;

  const _RawSlice({
    required this.label,
    required this.value,
    this.node,
    this.isUnassigned = false,
    this.isDebt = false,
  });
}

List<PieFoldEntry> _foldRawSlices(List<_RawSlice> slices) {
  final nonNegative = slices.where((s) => s.value >= 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final s in nonNegative)
      PieFoldEntry(
        label: s.label,
        value: s.value,
        node: s.node,
        isUnassigned: s.isUnassigned,
        isDebt: s.isDebt,
      ),
  ];
}

@visibleForTesting
List<PieFoldEntry> foldPieSlices(List<PieTreeNode> nodes) => _foldRawSlices([
  for (final n in nodes) _RawSlice(label: n.label, value: n.value, node: n),
]);

@visibleForTesting
class PieWedge {
  final int ring;
  final bool isFocusRing;
  final double startAngle;
  final double sweepAngle;
  final double innerRadius;
  final double outerRadius;
  final Color color;
  final String? targetId;
  final String label;
  final double value;
  final double displayPercent;

  final bool isUnassigned;

  final String? icon;

  const PieWedge({
    required this.ring,
    this.isFocusRing = false,
    required this.startAngle,
    required this.sweepAngle,
    required this.innerRadius,
    required this.outerRadius,
    required this.color,
    required this.targetId,
    required this.label,
    required this.value,
    required this.displayPercent,
    this.isUnassigned = false,
    this.icon,
  });
}

class _RingBands {
  final double hub;
  final double focusInner, focusOuter;
  final double ring1Inner, ring1Outer;
  final double ring2Inner, ring2Outer;

  const _RingBands({
    required this.hub,
    required this.focusInner,
    required this.focusOuter,
    required this.ring1Inner,
    required this.ring1Outer,
    required this.ring2Inner,
    required this.ring2Outer,
  });

  factory _RingBands.compute(double outerRadius, bool hasFocus) {
    final hub = outerRadius * 0.14;
    final gap = outerRadius * 0.02;
    final focusInner = hub + gap;
    final focusOuter = hasFocus ? focusInner + outerRadius * 0.08 : focusInner;
    final ring1Inner = focusOuter + gap;
    final ring1Outer = ring1Inner + outerRadius * 0.32;
    final ring2Inner = ring1Outer + gap;
    const ring2Outer = 1.0;
    return _RingBands(
      hub: hub,
      focusInner: focusInner,
      focusOuter: focusOuter,
      ring1Inner: ring1Inner,
      ring1Outer: ring1Outer,
      ring2Inner: ring2Inner,
      ring2Outer: max(
        ring2Inner + outerRadius * 0.01,
        ring2Outer == 1.0 ? outerRadius : ring2Outer,
      ),
    );
  }
}

@visibleForTesting
List<PieFoldEntry> entriesForGroup(
  List<PieTreeNode> children,
  PieTreeNode? owner,
) {
  final slices = [
    for (final n in children)
      if (n.value > 0 || !n.hasDebt)
        _RawSlice(label: n.label, value: n.value, node: n),
  ];
  if (owner != null) {
    final childrenSum = children
        .where((n) => n.value > 0)
        .fold<double>(0, (s, n) => s + n.value);
    final remainder = owner.value - childrenSum;
    if (remainder > 1e-9) {
      slices.add(
        _RawSlice(label: 'Unassigned', value: remainder, isUnassigned: true),
      );
    }
  }
  return _foldRawSlices(slices);
}

@visibleForTesting
List<PieFoldEntry> debtEntriesForGroup(
  List<PieTreeNode> children,
  PieTreeNode? owner,
) {
  final slices = [
    for (final n in children)
      if (n.value == 0 && n.hasDebt)
        _RawSlice(label: n.label, value: n.debtValue, node: n, isDebt: true),
  ];
  if (owner != null) {
    final childrenDebtSum = children.fold<double>(0, (s, n) => s + n.debtValue);
    final remainder = owner.debtValue - childrenDebtSum;
    if (remainder < -1e-9) {
      slices.add(
        _RawSlice(
          label: 'Unassigned',
          value: remainder,
          isUnassigned: true,
          isDebt: true,
        ),
      );
    }
  }
  slices.sort((a, b) => a.value.compareTo(b.value));
  return [
    for (final s in slices)
      PieFoldEntry(
        label: s.label,
        value: s.value,
        node: s.node,
        isUnassigned: s.isUnassigned,
        isDebt: true,
      ),
  ];
}

@visibleForTesting
List<PieWedge> layoutPieWedges(
  List<PieTreeNode> children,
  PieTreeNode? focus,
  Brightness brightness,
  double outerRadius,
) {
  final wedges = <PieWedge>[];
  final showFocusRing =
      focus != null || children.any((n) => n.children.isNotEmpty);
  final bands = _RingBands.compute(outerRadius, showFocusRing);

  final ring1Entries = entriesForGroup(children, focus);
  final total = ring1Entries.fold<double>(0, (sum, e) => sum + e.value);
  if (total <= 0) return wedges;

  if (showFocusRing) {
    wedges.add(
      PieWedge(
        ring: 0,
        isFocusRing: true,
        startAngle: 0,
        sweepAngle: 2 * pi,
        innerRadius: bands.focusInner,
        outerRadius: bands.focusOuter,
        color: _focusRingColor(brightness),
        targetId: null,
        label: focus?.label ?? 'Root',
        value: focus?.value ?? total,
        displayPercent: 1.0,
      ),
    );
  }

  var angle = 0.0;
  for (var i = 0; i < ring1Entries.length; i++) {
    final entry = ring1Entries[i];
    final sweep = 2 * pi * entry.value / total;
    final color = entry.node == null
        ? _otherColor(brightness)
        : categoricalColor(entry.node!.colorIndex ?? i);
    wedges.add(
      PieWedge(
        ring: 1,
        startAngle: angle,
        sweepAngle: sweep,
        innerRadius: bands.ring1Inner,
        outerRadius: bands.ring1Outer,
        color: color,
        targetId: entry.node?.id,
        label: entry.label,
        value: entry.value,
        displayPercent: entry.value / total,
        isUnassigned: entry.isUnassigned,
        icon: entry.icon,
      ),
    );

    final node = entry.node;
    if (node != null && node.children.isNotEmpty) {
      final childEntries = entriesForGroup(node.children, node);
      final childTotal = childEntries.fold<double>(
        0,
        (sum, c) => sum + c.value,
      );
      if (childTotal > 0) {
        var childAngle = angle;
        for (final child in childEntries) {
          final childSweep = sweep * child.value / childTotal;
          wedges.add(
            PieWedge(
              ring: 2,
              startAngle: childAngle,
              sweepAngle: childSweep,
              innerRadius: bands.ring2Inner,
              outerRadius: bands.ring2Outer,
              color: color,
              targetId: child.node?.id,
              label: child.label,
              value: child.value,
              displayPercent: child.value / childTotal,
              isUnassigned: child.isUnassigned,
              icon: child.icon,
            ),
          );
          childAngle += childSweep;
        }
      }
    }

    angle += sweep;
  }
  return wedges;
}

@visibleForTesting
PieWedge? pieWedgeAt(
  List<PieWedge> wedges,
  Offset localPosition,
  Offset center,
) {
  final dx = localPosition.dx - center.dx;
  final dy = localPosition.dy - center.dy;
  final radius = sqrt(dx * dx + dy * dy);
  var angle = -atan2(dy, dx);
  angle %= 2 * pi;
  if (angle < 0) angle += 2 * pi;

  for (final w in wedges) {
    final innerRadius = w.ring == 0 ? 0.0 : w.innerRadius;
    if (radius < innerRadius || radius > w.outerRadius) continue;
    final end = w.startAngle + w.sweepAngle;
    final within = end <= 2 * pi
        ? (angle >= w.startAngle && angle < end)
        : (angle >= w.startAngle || angle < end - 2 * pi);
    if (within) return w;
  }
  return null;
}

List<PieTreeNode>? pieAncestorPath(List<PieTreeNode> nodes, String id) {
  for (final n in nodes) {
    if (n.id == id) return [n];
    final found = pieAncestorPath(n.children, id);
    if (found != null) return [n, ...found];
  }
  return null;
}

class PieChartCard extends StatefulWidget {
  final String? title;
  final List<PieTreeNode> nodes;
  final bool loading;

  final String? subtitle;

  final bool showBreadcrumb;

  final bool expandChart;

  final double maxChartSize;

  final String? focusId;
  final ValueChanged<String?>? onFocusChanged;

  final bool drillDown;

  final bool showLegend;

  final EdgeInsetsGeometry? margin;

  final String Function(double value)? amountLabel;

  final bool showAmountsInLegend;

  final Map<String, List<AssetHolding>>? holdingsByContainerId;

  final List<AssetHolding>? rootHoldings;

  final String Function(String assetId, Decimal quantity)? holdingQuantityLabel;

  const PieChartCard({
    super.key,
    this.title,
    required this.nodes,
    this.loading = false,
    this.subtitle,
    this.showBreadcrumb = true,
    this.expandChart = false,
    this.maxChartSize = _maxChartSize,
    this.focusId,
    this.onFocusChanged,
    this.drillDown = true,
    this.showLegend = true,
    this.margin,
    this.amountLabel,
    this.showAmountsInLegend = true,
    this.holdingsByContainerId,
    this.rootHoldings,
    this.holdingQuantityLabel,
  });

  @override
  State<PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<PieChartCard> {
  String? _ownFocusId;
  bool get _controlled => widget.onFocusChanged != null;

  String? get _selectedId => _controlled ? widget.focusId : _ownFocusId;

  String? get _focusId =>
      (_controlled && !widget.drillDown) ? null : _selectedId;

  void _setFocus(String? id) {
    if (_controlled) {
      widget.onFocusChanged!(id);
    } else {
      setState(() => _ownFocusId = id);
    }
  }

  PieWedge? _tooltipWedge;
  Offset? _tooltipAnchor;
  Timer? _tooltipHideTimer;

  bool _showLiabilities = true;

  @override
  void dispose() {
    _tooltipHideTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PieChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = _ownFocusId;
    if (!_controlled &&
        focus != null &&
        pieAncestorPath(widget.nodes, focus) == null) {
      _ownFocusId = null;
    }
  }

  PieTreeNode? get _focusNode {
    final focus = _focusId;
    if (focus == null) return null;
    return pieAncestorPath(widget.nodes, focus)?.last;
  }

  List<PieTreeNode> get _currentChildren =>
      _focusNode?.children ?? widget.nodes;

  List<AssetHolding>? get _currentHoldings {
    final focus = _focusNode;
    return focus == null
        ? widget.rootHoldings
        : widget.holdingsByContainerId?[focus.id];
  }

  List<PieTreeNode> get _breadcrumbPath {
    final focus = _focusId;
    if (focus == null) return const [];
    return pieAncestorPath(widget.nodes, focus) ?? const [];
  }

  void _showTooltip(
    PieWedge? wedge,
    Offset localPosition, {
    bool autoHide = false,
  }) {
    setState(() {
      _tooltipWedge = wedge;
      _tooltipAnchor = wedge == null ? null : localPosition;
    });
    _tooltipHideTimer?.cancel();
    if (autoHide && wedge != null) {
      _tooltipHideTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _tooltipWedge = null);
      });
    }
  }

  void _handleHover(
    Offset localPosition,
    List<PieWedge> wedges,
    double chartSize,
  ) {
    final center = Offset(chartSize / 2, chartSize / 2);
    _showTooltip(pieWedgeAt(wedges, localPosition, center), localPosition);
  }

  void _handleExit() => _showTooltip(null, Offset.zero);

  void _handleTapUp(
    Offset localPosition,
    List<PieWedge> wedges,
    double chartSize,
  ) {
    final center = Offset(chartSize / 2, chartSize / 2);
    final wedge = pieWedgeAt(wedges, localPosition, center);
    _showTooltip(wedge, localPosition, autoHide: true);
    if (wedge == null) return;

    if (wedge.isFocusRing) {
      final focus = _focusId;
      if (focus == null) return;
      final path = pieAncestorPath(widget.nodes, focus);
      final parentId = (path != null && path.length >= 2)
          ? path[path.length - 2].id
          : null;
      _setFocus(parentId);
      return;
    }
    _focusOn(wedge.targetId);
  }

  void _focusOn(String? id) {
    if (id != null && id != _selectedId) _setFocus(id);
  }

  List<Widget> _wedgeIcons(List<PieWedge> wedges, double chartSize) {
    final center = Offset(chartSize / 2, chartSize / 2);
    return [
      for (final w in wedges)
        if (!w.isUnassigned && w.ring != 0)
          if (layoutWedgeLabel(w, center) case final layout?
              when layout.hasIcon)
            Positioned(
              left: layout.iconTopLeft.dx,
              top:
                  layout.iconTopLeft.dy +
                  (layout.text.height - layout.fontSize) / 2,
              child: IgnorePointer(
                child: ContainerIcon(
                  w.icon,
                  size: layout.fontSize,
                  color: Colors.white,
                ),
              ),
            ),
    ];
  }

  String _tooltipText(PieWedge wedge) {
    final parts = <String>[wedge.label];
    final amountLabel = widget.amountLabel;
    if (amountLabel != null) parts.add(amountLabel(wedge.value));
    if (!wedge.isFocusRing) {
      parts.add('${(wedge.displayPercent * 100).round()}%');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusNode = _focusNode;
    final children = _currentChildren;
    final entries = entriesForGroup(children, focusNode);
    final ring1Total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final hasHierarchy = widget.nodes.any((n) => n.children.isNotEmpty);
    final hasAnyDebt = widget.nodes.any((n) => n.hasDebt);

    return Card(
      margin: widget.margin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null || (hasAnyDebt && widget.showLegend))
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? '',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (hasAnyDebt && widget.showLegend)
                    LiabilitiesToggle(
                      value: _showLiabilities,
                      onChanged: (v) => setState(() => _showLiabilities = v),
                    ),
                ],
              ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (hasHierarchy && widget.drillDown && widget.showBreadcrumb) ...[
              const SizedBox(height: 8),
              ContainerBreadcrumb(
                path: _breadcrumbPath,
                onSelectRoot: () => _setFocus(null),
                onSelect: _setFocus,
              ),
            ],
            const SizedBox(height: 16),
            if (widget.loading)
              const SizedBox(
                height: _minChartSize,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (ring1Total <= 0 &&
                (!widget.showLegend || (_currentHoldings?.isEmpty ?? true)))
              SizedBox(
                height: _minChartSize,
                child: Center(
                  child: Text(
                    'No data yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (widget.expandChart)
              Expanded(child: Center(child: _body(children, focusNode)))
            else
              _body(children, focusNode),
          ],
        ),
      ),
    );
  }

  Widget _body(List<PieTreeNode> children, PieTreeNode? focusNode) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = widget.showLegend && constraints.maxWidth > 900;
        final available = wide
            ? constraints.maxWidth * 0.6
            : constraints.maxWidth - 16;
        final chartSize = available
            .clamp(min(_minChartSize, widget.maxChartSize), widget.maxChartSize)
            .toDouble();
        final wedges = layoutPieWedges(
          children,
          focusNode,
          theme.brightness,
          chartSize / 2,
        );
        final chart = AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(_focusId ?? '__root__'),
            child: MouseRegion(
              onHover: (e) => _handleHover(e.localPosition, wedges, chartSize),
              onExit: (_) => _handleExit(),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: const ValueKey('pieChartTapArea'),
                onTapUp: (details) =>
                    _handleTapUp(details.localPosition, wedges, chartSize),
                child: SizedBox(
                  width: chartSize,
                  height: chartSize,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(chartSize, chartSize),
                        painter: _SunburstPainter(
                          wedges,
                          theme.brightness,
                          theme.cardColor,
                          theme.colorScheme.onSurface,
                          selectedId: widget.drillDown ? null : _selectedId,
                        ),
                      ),
                      ..._wedgeIcons(wedges, chartSize),
                      if (_tooltipWedge != null && _tooltipAnchor != null)
                        _Tooltip(
                          text: _tooltipText(_tooltipWedge!),
                          icon: _tooltipWedge!.icon,
                          anchor: _tooltipAnchor!,
                          chartSize: chartSize,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final legend = !widget.showLegend
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PieLegendPanel(
                    nodes: widget.nodes,
                    focusNode: focusNode,
                    selectedId: widget.drillDown ? null : _selectedId,
                    onFocus: _focusOn,
                    amountLabel: widget.amountLabel,
                    showAmounts: widget.showAmountsInLegend,
                    showLiabilities: _showLiabilities,
                  ),
                  if (_currentHoldings case final holdings?
                      when holdings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ActualAssetsHeldPanel(
                      holdings: holdings,
                      quantityLabel: widget.holdingQuantityLabel,
                      amountLabel: widget.amountLabel,
                    ),
                  ],
                ],
              );
        if (!widget.showLegend) return Center(child: chart);
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  chart,
                  const SizedBox(width: 24),
                  Expanded(child: legend),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: chart),
                  const SizedBox(height: 16),
                  legend,
                ],
              );
      },
    );
  }
}

class PieLegendPanel extends StatefulWidget {
  final List<PieTreeNode> nodes;

  final PieTreeNode? focusNode;

  final String? selectedId;
  final ValueChanged<String> onFocus;
  final String Function(double value)? amountLabel;
  final bool showAmounts;
  final bool showLiabilities;

  final Widget? Function(String containerId)? rowTrailing;

  const PieLegendPanel({
    super.key,
    required this.nodes,
    required this.focusNode,
    required this.onFocus,
    this.selectedId,
    this.amountLabel,
    this.showAmounts = true,
    this.showLiabilities = true,
    this.rowTrailing,
  });

  @override
  State<PieLegendPanel> createState() => _PieLegendPanelState();
}

class _PieLegendPanelState extends State<PieLegendPanel> {
  final Set<String> _expandedIds = {};

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expandedIds.add(id)) _expandedIds.remove(id);
    });
  }

  String? _rowAmountLabel(double value) =>
      widget.showAmounts ? widget.amountLabel?.call(value) : null;

  List<Widget> _debtRows(List<PieFoldEntry> debtEntries, {double indent = 0}) {
    if (!widget.showLiabilities) return const [];
    return [
      for (final entry in debtEntries)
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _LegendEntry(
            color: Colors.transparent,
            label: entry.label,
            icon: entry.icon,
            amountLabel: _rowAmountLabel(entry.value),
            percent: null,
            isUnassigned: entry.isUnassigned,
            isDebt: true,
          ),
        ),
    ];
  }

  List<Widget> _legendRows(
    List<PieFoldEntry> entries,
    double ring1Total,
    Brightness brightness,
    List<PieFoldEntry> debtEntries,
  ) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final color = entry.node != null
          ? categoricalColor(entry.node!.colorIndex ?? i)
          : _otherColor(brightness);
      final node = entry.node;
      final hasChildren = node != null && node.children.isNotEmpty;
      final expanded = node != null && _expandedIds.contains(node.id);
      rows.add(
        _LegendEntry(
          color: color,
          label: entry.label,
          icon: entry.icon,
          amountLabel: _rowAmountLabel(entry.value),
          percent: ring1Total > 0 ? entry.value / ring1Total : 0,
          isUnassigned: entry.isUnassigned,
          hasDebtBadge: widget.showLiabilities && (node?.hasDebt ?? false),
          hasUnconvertibleBadge: node?.hasUnconvertible ?? false,
          selected: node != null && node.id == widget.selectedId,
          trailing: node == null ? null : widget.rowTrailing?.call(node.id),
          onTap: node != null ? () => widget.onFocus(node.id) : null,
          expanded: hasChildren ? expanded : null,
          onToggleExpanded: hasChildren ? () => _toggleExpanded(node.id) : null,
        ),
      );

      if (hasChildren && expanded) {
        for (final child in entriesForGroup(node.children, node)) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: _LegendEntry(
                color: color,
                label: child.label,
                icon: child.icon,
                amountLabel: _rowAmountLabel(child.value),
                percent: node.value > 0 ? child.value / node.value : 0,
                isUnassigned: child.isUnassigned,
                hasDebtBadge:
                    widget.showLiabilities && (child.node?.hasDebt ?? false),
                hasUnconvertibleBadge: child.node?.hasUnconvertible ?? false,
                selected:
                    child.node != null && child.node!.id == widget.selectedId,
                trailing: child.node == null
                    ? null
                    : widget.rowTrailing?.call(child.node!.id),
                onTap: child.node != null
                    ? () => widget.onFocus(child.node!.id)
                    : null,
              ),
            ),
          );
        }
        rows.addAll(
          _debtRows(debtEntriesForGroup(node.children, node), indent: 24),
        );
      }
    }
    rows.addAll(_debtRows(debtEntries));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusNode = widget.focusNode;
    final children = focusNode?.children ?? widget.nodes;
    final entries = entriesForGroup(children, focusNode);
    final debtEntries = debtEntriesForGroup(children, focusNode);
    final ring1Total = entries.fold<double>(0, (sum, e) => sum + e.value);
    final displayedTotal = focusNode != null
        ? focusNode.value + focusNode.debtValue
        : children.fold<double>(0, (s, n) => s + n.value + n.debtValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${focusNode?.label ?? 'Total'}: '
          '${widget.amountLabel?.call(displayedTotal) ?? displayedTotal.toStringAsFixed(2)}',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ..._legendRows(entries, ring1Total, theme.brightness, debtEntries),
        if (widget.showLiabilities && debtEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AssetsVsDebtBar(
            assetsValue: ring1Total,
            debtValue: debtEntries.fold<double>(0, (s, e) => s + e.value),
            amountLabel: widget.amountLabel,
          ),
        ],
      ],
    );
  }
}

class ContainerBreadcrumb extends StatelessWidget {
  final List<PieTreeNode> path;
  final VoidCallback onSelectRoot;
  final ValueChanged<String> onSelect;

  const ContainerBreadcrumb({
    super.key,
    required this.path,
    required this.onSelectRoot,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: onSelectRoot,
          child: Text(
            'Root',
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (final n in path) ...[
          Text('  ›  ', style: style),
          InkWell(
            onTap: () => onSelect(n.id),
            child: Text(n.label, style: style),
          ),
        ],
      ],
    );
  }
}

class _Tooltip extends StatelessWidget {
  final String text;
  final String? icon;
  final Offset anchor;
  final double chartSize;
  static const double _maxWidth = 170;
  static const double _estimatedHeight = 60;

  const _Tooltip({
    required this.text,
    this.icon,
    required this.anchor,
    required this.chartSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxLeft = max(0.0, chartSize - _maxWidth);
    final left = (anchor.dx + 12).clamp(0.0, maxLeft);
    final maxTop = max(0.0, chartSize - _estimatedHeight);
    final top = (anchor.dy - 12).clamp(0.0, maxTop);
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: ContainerName(
            text,
            icon: icon,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onInverseSurface,
            ),
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}

const double _labelBaseFontSize = 11;
const double _labelMinFontSize = 7;

@visibleForTesting
class WedgeLabelLayout {
  final TextPainter text;
  final double fontSize;
  final Offset topLeft;

  final double iconExtent;

  const WedgeLabelLayout(
    this.text,
    this.fontSize,
    this.topLeft,
    this.iconExtent,
  );

  bool get hasIcon => iconExtent > 0;
  Offset get iconTopLeft => topLeft;
}

@visibleForTesting
WedgeLabelLayout? layoutWedgeLabel(PieWedge w, Offset center) {
  if (w.displayPercent < kMinLabelShare) return null;
  final hasIcon = ContainerIconKey.parse(w.icon) != null;
  final midRadius = (w.innerRadius + w.outerRadius) / 2;
  final chordWidth = labelChordWidth(w, midRadius);

  double iconExtentAt(double fontSize) => hasIcon ? fontSize * 1.3 : 0;

  TextPainter layoutAt(double fontSize) => TextPainter(
    text: TextSpan(
      text: w.label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  var fontSize = _labelBaseFontSize;
  var tp = layoutAt(fontSize);
  while (tp.width + iconExtentAt(fontSize) > chordWidth &&
      fontSize > _labelMinFontSize) {
    fontSize -= 1;
    tp = layoutAt(fontSize);
  }

  final extent = iconExtentAt(fontSize);
  final midAngle = -(w.startAngle + w.sweepAngle / 2);
  final point = center + Offset(cos(midAngle), sin(midAngle)) * midRadius;
  final topLeft = point - Offset((tp.width + extent) / 2, tp.height / 2);
  return WedgeLabelLayout(tp, fontSize, topLeft, extent);
}

class _SunburstPainter extends CustomPainter {
  final List<PieWedge> wedges;
  final Brightness brightness;
  final Color borderColor;
  final Color centerLabelColor;

  final String? selectedId;
  const _SunburstPainter(
    this.wedges,
    this.brightness,
    this.borderColor,
    this.centerLabelColor, {
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    PieWedge? focusRing;
    for (final w in wedges) {
      if (!w.isUnassigned) {
        final paint = Paint()
          ..color = w.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w.outerRadius - w.innerRadius;
        final radius = (w.innerRadius + w.outerRadius) / 2;
        final rect = Rect.fromCircle(center: center, radius: radius);
        canvas.drawArc(rect, -w.startAngle, -w.sweepAngle, false, paint);
      }
      if (w.ring == 0) focusRing = w;
    }
    _paintBoundaryLines(canvas, center);
    for (final w in wedges) {
      if (selectedId != null && w.ring == 1 && w.targetId == selectedId) {
        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: (w.innerRadius + w.outerRadius) / 2,
          ),
          -w.startAngle,
          -w.sweepAngle,
          false,
          Paint()
            ..color = centerLabelColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = (w.outerRadius - w.innerRadius) + 3,
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: center,
            radius: (w.innerRadius + w.outerRadius) / 2,
          ),
          -w.startAngle,
          -w.sweepAngle,
          false,
          Paint()
            ..color = w.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = (w.outerRadius - w.innerRadius) - 3,
        );
      }
    }
    for (final w in wedges) {
      if (!w.isUnassigned && w.ring != 0) _paintLabel(canvas, w, center);
    }
    if (focusRing != null) {
      _paintCenterLabel(canvas, center, focusRing.innerRadius, focusRing.label);
    }
  }

  void _paintCenterLabel(
    Canvas canvas,
    Offset center,
    double hubRadius,
    String label,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: centerLabelColor,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: max(0, hubRadius * 1.8));
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintBoundaryLines(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final w in wedges) {
      if (w.ring == 0) continue;
      final angle = -w.startAngle;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * w.innerRadius,
        center + direction * w.outerRadius,
        paint,
      );
    }
  }

  void _paintLabel(Canvas canvas, PieWedge w, Offset center) {
    final layout = layoutWedgeLabel(w, center);
    if (layout == null) return;
    layout.text.paint(canvas, layout.topLeft + Offset(layout.iconExtent, 0));
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) =>
      !identical(oldDelegate.wedges, wedges) ||
      oldDelegate.selectedId != selectedId;
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;
  final String? icon;
  final String? amountLabel;

  final double? percent;
  final bool isUnassigned;

  final bool isDebt;

  final bool hasDebtBadge;

  final bool hasUnconvertibleBadge;

  final VoidCallback? onTap;

  final bool selected;

  final Widget? trailing;

  final bool? expanded;

  final VoidCallback? onToggleExpanded;

  const _LegendEntry({
    required this.color,
    required this.label,
    this.icon,
    required this.amountLabel,
    required this.percent,
    this.isUnassigned = false,
    this.isDebt = false,
    this.hasDebtBadge = false,
    this.hasUnconvertibleBadge = false,
    this.onTap,
    this.selected = false,
    this.trailing,
    this.expanded,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debtColor = theme.colorScheme.error;
    final percentText = percent == null
        ? null
        : '${(percent! * 100).toStringAsFixed(0)}%';
    final parts = [label, if (!isDebt) ?amountLabel, ?percentText];
    final swatchAndLabel = Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: isUnassigned
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDebt ? debtColor : color,
                    width: 1.5,
                  ),
                )
              : BoxDecoration(
                  color: isDebt ? debtColor : color,
                  shape: BoxShape.circle,
                ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: ContainerName(
            parts.join(' · '),
            icon: icon,
            style: selected
                ? theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodySmall,
          ),
        ),
        if (hasDebtBadge) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Contains a container with negative balance',
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: debtColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
        if (hasUnconvertibleBadge) ...[
          const SizedBox(width: 4),
          Tooltip(
            message:
                "Contains an asset with no known price — its value "
                "isn't included in this total",
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
        if (isDebt) ...[const SizedBox(width: 6), _DebtPill(color: debtColor)],
      ],
    );
    final content = onTap == null
        ? swatchAndLabel
        : InkWell(onTap: onTap, child: swatchAndLabel);

    final row = Row(
      children: [
        Expanded(child: content),
        if (isDebt && amountLabel != null)
          Text(
            amountLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: debtColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ?trailing,
        if (onToggleExpanded != null)
          InkWell(
            onTap: onToggleExpanded,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                expanded! ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: row,
    );
  }
}

class _DebtPill extends StatelessWidget {
  final Color color;
  const _DebtPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'debt',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LiabilitiesToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const LiabilitiesToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Show liabilities', style: Theme.of(context).textTheme.bodySmall),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _AssetsVsDebtBar extends StatelessWidget {
  final double assetsValue;
  final double debtValue;
  final String Function(double value)? amountLabel;

  const _AssetsVsDebtBar({
    required this.assetsValue,
    required this.debtValue,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debt = -debtValue;
    final total = assetsValue + debt;
    final assetsFraction = total > 0
        ? (assetsValue / total).clamp(0.0, 1.0)
        : 0.0;
    final format = amountLabel ?? (v) => v.toStringAsFixed(2);
    final assetsColor = theme.colorScheme.primary;
    final debtColor = theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Assets · ${format(assetsValue)}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '${format(debt)} debt',
              style: theme.textTheme.bodySmall?.copyWith(
                color: debtColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: (assetsFraction * 1000).round().clamp(1, 999),
                  child: Container(color: assetsColor),
                ),
                Expanded(
                  flex: ((1 - assetsFraction) * 1000).round().clamp(1, 999),
                  child: Container(color: debtColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ActualAssetsHeldPanel extends StatelessWidget {
  final List<AssetHolding> holdings;
  final String Function(String assetId, Decimal quantity)? quantityLabel;
  final String Function(double value)? amountLabel;

  const ActualAssetsHeldPanel({
    super.key,
    required this.holdings,
    required this.quantityLabel,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTUAL ASSETS HELD',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        for (final holding in holdings)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    quantityLabel?.call(holding.assetId, holding.quantity) ??
                        holding.assetId,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  holding.convertedValue != null
                      ? '≈ ${amountLabel?.call(holding.convertedValue!.toDouble()) ?? holding.convertedValue!.toStringAsFixed(2)}'
                      : 'no known price',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: holding.convertedValue == null
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
