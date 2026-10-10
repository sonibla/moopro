import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transfer_flow.dart';
import '../providers/app_providers.dart';
import 'amount_text.dart' show formatAssetQuantity;

class TransferFlowChart extends ConsumerWidget {
  final TransferFlow flow;
  final Color Function(String containerId) colorOf;

  const TransferFlowChart({
    super.key,
    required this.flow,
    required this.colorOf,
  });

  static double widthFor(TransferFlow flow) {
    final w = 200.0 * flow.layerCount + 160;
    return w < 360 ? 360 : w;
  }

  static double heightFor(TransferFlow flow) {
    final perLayer = <int, int>{};
    for (final n in flow.nodes) {
      perLayer.update(n.layer, (c) => c + 1, ifAbsent: () => 1);
    }
    final busiest = perLayer.values.fold<int>(1, (a, b) => a > b ? a : b);
    final h = 44.0 * busiest + 24;
    return h < 240 ? 240 : h;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    return Semantics(
      label:
          'Flow of ${flow.asset.symbol} between ${flow.nodes.length} containers',
      child: SizedBox(
        height: heightFor(flow),
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, heightFor(flow));
            final layout = _layoutFlow(flow, size);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FlowPainter(
                      flow: flow,
                      layout: layout,
                      colorOf: colorOf,
                      textStyle:
                          theme.textTheme.labelSmall ??
                          const TextStyle(fontSize: 11),
                      textColor: theme.colorScheme.onSurface,
                      mutedColor: theme.colorScheme.onSurfaceVariant,
                      backColor: theme.colorScheme.surface,
                      hidden: hidden,
                    ),
                  ),
                ),
                if (layout != null)
                  for (final n in flow.nodes)
                    Positioned.fromRect(
                      rect: _hoverRect(layout.rect[n.id]!),
                      child: Tooltip(
                        message:
                            '${n.name}\n${formatAssetQuantity(n.value, flow.asset, hidden: hidden)}',
                        waitDuration: const Duration(milliseconds: 150),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Rect _hoverRect(Rect bar) =>
      Rect.fromLTRB(bar.left, bar.top, bar.right + 100, bar.bottom);
}

const double _nodeWidth = 12;
const double _gap = 12;
const double _padX = 8;
const double _padY = 12;
const double _minNodeHeight = 16;

_FlowLayout? _layoutFlow(TransferFlow flow, Size size) {
  final layerCount = flow.layerCount;
  if (layerCount == 0) return null;

  final labelMargin = layerCount > 1
      ? (size.width * 0.3).clamp(90.0, 160.0)
      : 0.0;
  final span = size.width - 2 * _padX - _nodeWidth - labelMargin;
  double xOf(int layer) =>
      layerCount == 1 ? _padX : _padX + span * layer / (layerCount - 1);

  final byLayer = <int, List<FlowNode>>{};
  for (final n in flow.nodes) {
    (byLayer[n.layer] ??= []).add(n);
  }
  double scale = double.infinity;
  for (final nodes in byLayer.values) {
    final values = [for (final n in nodes) n.value.toDouble()];
    if (values.every((v) => v <= 0)) continue;
    final room = size.height - 2 * _padY - _gap * (nodes.length - 1);
    var lo = 0.0, hi = room / values.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      final used = values.fold<double>(
        0,
        (a, v) => a + (v * mid < _minNodeHeight ? _minNodeHeight : v * mid),
      );
      if (used <= room) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    if (lo < scale) scale = lo;
  }
  if (!scale.isFinite) return null;
  double heightOf(FlowNode n) {
    final h = n.value.toDouble() * scale;
    return h < _minNodeHeight ? _minNodeHeight : h;
  }

  final rect = <String, Rect>{};
  final slotCenter = <(String, String), double>{};
  final layerKeys = byLayer.keys.toList()..sort();
  for (final layer in layerKeys) {
    final nodes = byLayer[layer]!;
    final heights = [for (final n in nodes) heightOf(n)];
    final desired = <double>[];
    var stackY = _padY;
    for (var i = 0; i < nodes.length; i++) {
      if (layer == layerKeys.first) {
        desired.add(stackY);
        stackY += heights[i] + _gap;
        continue;
      }
      var weighted = 0.0, total = 0.0;
      for (final l in flow.links) {
        final c = slotCenter[(l.from, l.to)];
        if (l.to != nodes[i].id || l.isBack || c == null) continue;
        final w = l.value.toDouble();
        weighted += c * w;
        total += w;
      }
      desired.add(total > 0 ? weighted / total - heights[i] / 2 : _padY);
    }
    final order = List<int>.generate(nodes.length, (i) => i)
      ..sort((a, b) => desired[a].compareTo(desired[b]));
    final tops = List<double>.filled(nodes.length, 0);
    var floor = _padY;
    for (final i in order) {
      tops[i] = desired[i] < floor ? floor : desired[i];
      floor = tops[i] + heights[i] + _gap;
    }
    var ceiling = size.height - _padY;
    for (final i in order.reversed) {
      if (tops[i] + heights[i] > ceiling) tops[i] = ceiling - heights[i];
      ceiling = tops[i] - _gap;
    }
    for (var i = 0; i < nodes.length; i++) {
      final r = Rect.fromLTWH(xOf(layer), tops[i], _nodeWidth, heights[i]);
      rect[nodes[i].id] = r;
      var cursor = r.top;
      for (final l in flow.links) {
        if (l.from != nodes[i].id || l.isBack) continue;
        final w = l.value.toDouble() * scale;
        slotCenter[(l.from, l.to)] = cursor + w / 2;
        cursor += w;
      }
    }
  }

  return _FlowLayout(rect, scale, labelMargin, span);
}

class _FlowLayout {
  final Map<String, Rect> rect;
  final double scale;
  final double labelMargin;
  final double span;
  const _FlowLayout(this.rect, this.scale, this.labelMargin, this.span);
}

class _FlowPainter extends CustomPainter {
  final TransferFlow flow;
  final _FlowLayout? layout;
  final Color Function(String) colorOf;
  final TextStyle textStyle;
  final Color textColor;
  final Color mutedColor;
  final Color backColor;
  final bool hidden;

  _FlowPainter({
    required this.flow,
    required this.layout,
    required this.colorOf,
    required this.textStyle,
    required this.textColor,
    required this.mutedColor,
    required this.backColor,
    required this.hidden,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final layout = this.layout;
    if (layout == null) return;
    final layerCount = flow.layerCount;
    final rect = layout.rect;
    final scale = layout.scale;
    final labelMargin = layout.labelMargin;
    final span = layout.span;

    final outCursor = <String, double>{};
    final inCursor = <String, double>{};
    final outLinks = <String, List<FlowLink>>{};
    final inLinks = <String, List<FlowLink>>{};
    for (final l in flow.links) {
      (outLinks[l.from] ??= []).add(l);
      (inLinks[l.to] ??= []).add(l);
    }
    for (final l in outLinks.values) {
      l.sort((a, b) => rect[a.to]!.top.compareTo(rect[b.to]!.top));
    }
    for (final l in inLinks.values) {
      l.sort((a, b) => rect[a.from]!.top.compareTo(rect[b.from]!.top));
    }
    for (final n in flow.nodes) {
      outCursor[n.id] = rect[n.id]!.top;
      inCursor[n.id] = rect[n.id]!.top;
    }

    final ribbons = <_Ribbon>[];
    for (final n in flow.nodes) {
      for (final l in outLinks[n.id] ?? const <FlowLink>[]) {
        final w = l.value.toDouble() * scale;
        final from = rect[l.from]!;
        final to = rect[l.to]!;
        final y0 = outCursor[l.from]! + w / 2;
        outCursor[l.from] = outCursor[l.from]! + w;
        var inY = rect[l.to]!.top;
        for (final other in inLinks[l.to]!) {
          if (identical(other, l)) break;
          inY += other.value.toDouble() * scale;
        }
        final y1 = inY + w / 2;
        ribbons.add(_Ribbon(l, from.right, y0, to.left, y1, w));
      }
    }

    for (final r in ribbons) {
      final color = colorOf(r.link.from);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width < 1.5 ? 1.5 : r.width
        ..color = color.withValues(alpha: r.link.isBack ? 0.5 : 0.35);
      final from = rect[r.link.from]!;
      final to = rect[r.link.to]!;
      final path = Path()..moveTo(r.x0, r.y0);
      if (!r.link.isBack) {
        final mid = (r.x0 + r.x1) / 2;
        path.cubicTo(mid, r.y0, mid, r.y1, r.x1, r.y1);
      } else if (from.left == to.left) {
        final bulge = ((r.y1 - r.y0).abs() * 0.3).clamp(16.0, 40.0);
        path.cubicTo(
          r.x0 + bulge,
          r.y0,
          to.right + bulge,
          r.y1,
          to.right,
          r.y1,
        );
      } else {
        const reach = 24.0;
        final top = _padY / 2;
        path.cubicTo(r.x0 + reach, top, r.x1 - reach, top, r.x1, r.y1);
      }
      canvas.drawPath(path, paint);
    }

    final colGap = layerCount > 1 ? span / (layerCount - 1) : span;
    for (final n in flow.nodes) {
      final r = rect[n.id]!;
      canvas.drawRect(r, Paint()..color = colorOf(n.id));
      final last = n.layer == layerCount - 1;
      final room = last ? labelMargin - 12 : colGap - _nodeWidth - 16;
      _label(canvas, n, r, maxWidth: room.clamp(60.0, 180.0));
    }
  }

  void _label(Canvas canvas, FlowNode n, Rect bar, {required double maxWidth}) {
    final showAmount = bar.height >= 28;
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: n.name,
            style: textStyle.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showAmount)
            TextSpan(
              text:
                  '\n${formatAssetQuantity(n.value, flow.asset, hidden: hidden)}',
              style: textStyle.copyWith(color: mutedColor),
            ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: showAmount ? 2 : 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = bar.right + 4;
    final dy = bar.center.dy - tp.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 3, dy - 1, tp.width + 6, tp.height + 2),
        const Radius.circular(3),
      ),
      Paint()..color = backColor.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.flow != flow ||
      old.layout?.scale != layout?.scale ||
      old.textColor != textColor ||
      old.mutedColor != mutedColor ||
      old.backColor != backColor ||
      old.hidden != hidden;
}

class _Ribbon {
  final FlowLink link;
  final double x0, y0, x1, y1, width;
  _Ribbon(this.link, this.x0, this.y0, this.x1, this.y1, this.width);
}
