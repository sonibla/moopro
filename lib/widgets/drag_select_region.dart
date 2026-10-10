import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/selection_range.dart';
import '../domain/transaction_list_grouping.dart';

class DragSelectRegion extends StatefulWidget {
  final List<TransactionListItem> items;
  final double Function(TransactionListItem) heightOf;
  final ScrollController controller;
  final Set<String> selectedIds;

  final ValueChanged<Set<String>> onSelectionChanged;
  final double? mouseDragZoneWidth;
  final Widget child;

  const DragSelectRegion({
    super.key,
    required this.items,
    required this.heightOf,
    required this.controller,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.child,
    this.mouseDragZoneWidth,
  });

  static const double edgeZone = 64;
  static const double maxScrollStep = 18;

  @override
  State<DragSelectRegion> createState() => _DragSelectRegionState();
}

class _DragSelectRegionState extends State<DragSelectRegion> {
  late ListGeometry _geometry;

  int _anchor = -1;
  bool _select = true;
  Set<String> _baseline = const {};
  Set<String> _last = const {};
  double _localY = 0;
  Timer? _autoScroll;
  bool _mouseDragging = false;
  Offset? _mouseDownLocal;

  bool _scrollLocked = false;

  @override
  void initState() {
    super.initState();
    _geometry = ListGeometry.of(widget.items, widget.heightOf);
  }

  @override
  void didUpdateWidget(DragSelectRegion old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) {
      _geometry = ListGeometry.of(widget.items, widget.heightOf);
    }
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  double get _offset =>
      widget.controller.hasClients ? widget.controller.offset : 0;

  int _indexAtLocalY(double y) => _geometry.indexAt(y + _offset);

  void _begin(double localY) {
    final index = _indexAtLocalY(localY);
    if (index < 0) return;
    final item = widget.items[index];
    _baseline = {...widget.selectedIds};
    switch (item) {
      case TransactionRowItem():
        _select = !_baseline.contains(item.id);
      case TransactionGroupItem():
        _select = item.selectionState(_baseline) != true;
      default:
        return;
    }
    _anchor = index;
    _last = _baseline;
    _localY = localY;
    _apply();
  }

  void _update(double localY) {
    if (_anchor < 0) return;
    _localY = localY;
    _apply();
    _syncAutoScroll();
  }

  void _end() {
    _anchor = -1;
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _apply() {
    final index = _indexAtLocalY(_localY);
    if (index < 0) return;
    final next = rangeSelection(
      items: widget.items,
      anchorIndex: _anchor,
      currentIndex: index,
      baseline: _baseline,
      select: _select,
    );
    if (next.length == _last.length && next.containsAll(_last)) return;
    _last = next;
    HapticFeedback.selectionClick();
    widget.onSelectionChanged(next);
  }

  double _scrollStep() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    final height = box.size.height;
    const zone = DragSelectRegion.edgeZone;
    if (_localY < zone) {
      return -DragSelectRegion.maxScrollStep *
          ((zone - _localY) / zone).clamp(0.0, 1.0);
    }
    if (_localY > height - zone) {
      return DragSelectRegion.maxScrollStep *
          ((_localY - (height - zone)) / zone).clamp(0.0, 1.0);
    }
    return 0;
  }

  void _syncAutoScroll() {
    if (_scrollStep() == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final step = _scrollStep();
      if (_anchor < 0 || step == 0 || !widget.controller.hasClients) {
        _autoScroll?.cancel();
        _autoScroll = null;
        return;
      }
      final position = widget.controller.position;
      final target = (position.pixels + step).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (target == position.pixels) return;
      widget.controller.jumpTo(target);
      _apply();
    });
  }

  bool _inMouseZone(PointerEvent e) =>
      widget.mouseDragZoneWidth != null &&
      e.kind == PointerDeviceKind.mouse &&
      e.localPosition.dx <= widget.mouseDragZoneWidth!;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _mouseDownLocal = _inMouseZone(e) ? e.localPosition : null;
        if (_mouseDownLocal != null) setState(() => _scrollLocked = true);
      },
      onPointerMove: (e) {
        if (_mouseDownLocal == null) return;
        if (!_mouseDragging) {
          if ((e.localPosition - _mouseDownLocal!).distance < kTouchSlop) {
            return;
          }
          _mouseDragging = true;
          _begin(_mouseDownLocal!.dy);
        }
        _update(e.localPosition.dy);
      },
      onPointerUp: (_) => _endMouse(),
      onPointerCancel: (_) => _endMouse(),
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(),
                (r) {
                  r.onLongPressStart = (d) {
                    _begin(d.localPosition.dy);
                  };
                  r.onLongPressMoveUpdate = (d) {
                    _update(d.localPosition.dy);
                  };
                  r.onLongPressEnd = (_) {
                    _end();
                  };
                  r.onLongPressCancel = () {
                    if (!_mouseDragging) _end();
                  };
                },
              ),
        },
        child: ScrollConfiguration(
          behavior: _scrollLocked
              ? ScrollConfiguration.of(
                  context,
                ).copyWith(dragDevices: const <PointerDeviceKind>{})
              : ScrollConfiguration.of(context),
          child: widget.child,
        ),
      ),
    );
  }

  void _endMouse() {
    if (_scrollLocked) setState(() => _scrollLocked = false);
    _mouseDownLocal = null;
    if (_mouseDragging) {
      _mouseDragging = false;
      _end();
    }
  }
}
